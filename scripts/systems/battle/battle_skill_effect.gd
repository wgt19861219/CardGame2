class_name BattleSkillEffect
extends RefCounted

## 技能效果结算（Logic 层）：照源 skill.lua:474-644 拆出（AOE 形状 + power + 伤害/治疗/闪避/吸血/命中/击退）。
## 从 BattleSkill 拆分以满足单文件 ≤300 行铁律；静态方法接 skill 实例（读 info/caster/level）。
## 伤害数值/暴击/免疫在单位侧 take_damage（Phase 2.2续，源 unit.lua:1252 支持 table 参数）。

const DODGE_DENOM: float = 100.0  # 源 takeEffectOn:573 dodg/(100+dodg)
const HEAL_DENOM: float = 100.0   # 源 :565 (1+heal/100)
const LFS_DENOM: float = 100.0    # 源 :601 lfs/(100+lfs+level)
const LFS_SCALE: float = 0.01     # 源 :601 *LFS%*0.01
const CRIT_DEFAULT: int = 100     # 源 CRIT% 默认满 → crit_mod=1
const SHAPE_HALF: float = 0.5     # 源 testPointInShape:476 rectangle y 半宽

## 源 testPointInShape（:474-487）：AOE 形状判定
static func test_point_in_shape(p: Vector2, shape: String, arg1: float, arg2: float) -> bool:
	match shape:
		"rectangle":
			return p.x >= 0.0 and arg1 >= p.x and p.y >= -arg2 * SHAPE_HALF and p.y <= arg2 * SHAPE_HALF
		"circle":
			return p.x * p.x + p.y * p.y <= arg1 * arg1
		"halfcircle":
			return p.x >= 0.0 and p.x * p.x + p.y * p.y <= arg1 * arg1
		"quartercircle":
			return p.x >= 0.0 and p.y <= p.x and p.y >= -p.x and p.x * p.x + p.y * p.y <= arg1 * arg1
	return false

## 源 takeEffectAt（:489-528）：AOE Origin + X Shift + 形状过滤 → take_effect_on
static func take_effect_at(skill: BattleSkill, location: Vector2, src: Variant = null) -> void:
	var info: Dictionary = skill.info
	var caster: Variant = skill.caster
	var aoe: String = str(info.get("AOE Origin", ""))
	var direction: float = float(caster.direction)
	if aoe == "self":
		location = caster.position
	var origin: Vector2 = Vector2(location.x + float(info.get("X Shift", 0.0)) * direction, location.y)
	var dt: String = str(info.get("Damage Type", ""))
	if aoe != "":
		var shape: String = str(info.get("AOE Shape", ""))
		var arg1: float = float(info.get("Shape Arg1", 0.0))
		var arg2: float = float(info.get("Shape Arg2", 0.0))
		for unit in caster.engine.foreach_alive_unit(skill._affected_camp()):
			if (dt == "AD" or dt == "AP") and unit == caster:
				continue
			var p2: Vector2 = unit.position - origin
			p2 = Vector2(p2.x * direction, p2.y)
			if test_point_in_shape(p2, shape, arg1, arg2):
				take_effect_on(skill, unit, null)  # 源 :515 AOE 不传 source（默认 caster；projectile.camp==caster.camp 故实际无差异，P2-1 照源）
	else:
		take_effect_on(skill, skill.target, src)
	# 源 skill.lua:517-527 Point Effect（命中地面特效，走 scene.playEffectOnScene 场景级）
	# 经 caster.actor.play_effect 转发（actor 有 scene 父链查找桥，三层分离）
	var point_eff: String = String(info.get("Point Effect", ""))
	if point_eff != "":
		var c_actor: Variant = caster.get("actor")
		if c_actor != null and c_actor.has_method("play_effect"):
			c_actor.play_effect(point_eff, origin, 1.0, 0.0, int(info.get("Point Zorder", 0)))

## 源 power（:531-537）：返 (power, crit_mod) 双值（GDScript Array 等价 Lua 多返回值）。
## power = Plus Ratio × caster.attribs[Plus Attr] + Basic Num（源 :534 用 caster，非 source）；
## crit_mod = info CRIT%/100（默认 100→1.0，源 :536 info["CRIT%"]/100 or 1）。
static func power(skill: BattleSkill, _src: Variant, _target: Variant = null) -> Array:
	var info: Dictionary = skill.info
	var mult: float = float(info.get("Plus Ratio", 0.0))
	var attr: float = float(skill.caster.attribs.get(str(info.get("Plus Attr", "")), 0.0))
	var p_power: float = mult * attr + float(info.get("Basic Num", 0.0))
	var crit_mod: float = float(info.get("CRIT%", CRIT_DEFAULT)) / float(CRIT_DEFAULT)
	return [p_power, crit_mod]

## 源 getDamage（:540-549）：调单位 take_damage（table 参数，源 unit.lua:1252-1260 解包）
static func get_damage(p_target: Variant, p_power: float, dt: String, field: String, src: Variant, crit_mod: float) -> float:
	return float(p_target.take_damage({
		"amount": p_power,
		"damage_type": dt,
		"field": field,
		"source": src,
		"crit_mod": crit_mod,
	}))

## 源 createBuff（:459-462）：BuffCreate(info.buff_info, target, caster)
static func create_buff(skill: BattleSkill, p_target: Variant) -> BattleBuff:
	return BattleBuff.new(skill.info.get("buff_info", {}), p_target, skill.caster)

## 源 takeEffectOn（:552-644）：Heal/AD 闪避/伤害/LFS 吸血/Buff 命中/击退（popup/effect 分层 Phase 4）。
## 返 [succ, dmg]（源末尾 return true, dmg；早返 false → [false, 0.0]）— 英雄 hook（Sil/OD）succ = basefunc[0]，DP buff.update 累计 dmg 依赖。
static func take_effect_on(skill: BattleSkill, p_target: Variant, src: Variant = null) -> Array:
	var info: Dictionary = skill.info
	var caster: Variant = skill.caster
	var source: Variant = src if src != null else caster
	if not bool(p_target.is_alive()) or bool(p_target.buff_effects.get("invulnerable", false)):
		return [false, 0.0]
	if bool(p_target.manually_casting) and int(source.camp) != int(p_target.camp):
		return [false, 0.0]
	var pr: Array = skill.power(source, p_target)  # 走 skill.power 分发（英雄 hook，如 Luna/SF/Med），返 [power, crit_mod]
	var p_power: float = float(pr[0])
	var crit_mod: float = float(pr[1])
	var dt: String = str(info.get("Damage Type", ""))
	var affect_field: String = "mp" if bool(info.get("Affect MP", false)) else "hp"
	var dmg: float = 0.0  # 源 :562 local dmg = 0（Heal/无伤害类保持 0，末尾 return true, dmg）
	if dt == "Heal":
		var heal: float = float(caster.attribs.get("HEAL", 0.0)) if affect_field == "hp" else 0.0
		p_target.take_heal(p_power * (1.0 + heal / HEAL_DENOM), affect_field, caster)
		# 源 :563-569 Heal 分支不 return，fall-through 到 :610 buff 命中（P0-1 修复：原 :102 提前 return 跳过 buff 命中）
	elif dt == "":
		return [false, 0.0]  # 无 damage_type（保留既有行为；源 damage_type=nil 实际 fall-through buff 命中，此偏差 P0-1 范围外）
	else:
		# 源 :570-608 elseif damage_type then（AD/AP/Holy 等非 Heal 伤害类）
		if dt == "AD" and not bool(info.get("No Dodge", false)):
			var dodg: float = max(0.0, float(p_target.attribs.get("DODG", 0.0)) - float(caster.attribs.get("HIT", 0.0)))
			if dodg / (DODGE_DENOM + dodg) > caster.engine.rng.randf():
				_show_dodge_popup(p_target)  # 源 :580-583 dodge 文本
				# 源 C++ compiled onHitMiss：目标闪避时触发目标 onHitMiss hook（Naga 觉醒召唤幻象）。
				var hh: Variant = p_target.get("hero_hooks")
				if hh is Dictionary:
					var miss_hook: Callable = hh.get("onHitMiss", Callable())
					if miss_hook.is_valid():
						miss_hook.call(p_target, skill)
				return [false, 0.0]  # Miss（源 :574-585）
		dmg = skill.get_damage(p_target, p_power, dt, affect_field, caster, crit_mod)  # crit_mod 来自 skill.power 双值（源 takeEffectOn 解构 power 第二返回值）
		# 源 skill.lua:591-595 buffImpactEffect（受 buff 命中时特效，挂 target actor）
		var buff_impact: Variant = p_target.get("buffImpactEffect")
		if buff_impact != null and buff_impact.has("value"):
			var bi_eff: String = String(buff_impact.value.get("ImpactEffect", ""))
			if bi_eff != "":
				_play_puppet_effect(p_target, bi_eff, int(buff_impact.value.get("ImpactEffectZorder", 0)))
		if dmg <= 0.0:
			return [false, 0.0]
		if float(info.get("LFS%", 0.0)) > 0.0:
			var lfs: float = float(caster.attribs.get("LFS", 0.0))
			var heal: float = dmg * lfs / (LFS_DENOM + lfs + float(p_target.level)) * float(info.get("LFS%", 0.0)) * LFS_SCALE
			if heal > 1.0:
				caster.take_heal(heal, affect_field, null)
	var buff_miss: bool = false
	if bool(p_target.is_alive()) and int(info.get("Buff ID", 0)) > 0:
		var buff_res: Array = BattleBuff.check_add_buff(info.get("buff_info", {}), skill.level, int(p_target.level), p_target.attribs, caster.engine.rng)
		if bool(buff_res[0]):
			p_target.add_buff(create_buff(skill, p_target), caster)
		else:
			_show_buff_resist_popup(p_target, str(buff_res[1]))  # 源 :616-620 reason 区分 resist/miss（P1-2）
			buff_miss = true
	if not buff_miss and (float(info.get("Knock Up", 0.0)) > 0.0 or float(info.get("Knock Back", 0.0)) > 0.0):
		var time_: float = float(info.get("Knock Up", 0.0))
		var distance: float = float(info.get("Knock Back", 0.0))
		var delta: Vector2 = p_target.position - caster.position
		var dir: Vector2 = Vector2(delta.x, 0.0) if delta != Vector2.ZERO else Vector2(float(caster.direction), 0.0)
		p_target.knockup(time_, dir.normalized() * distance)
	# 源 skill.lua:638-641 Impact Effect（命中结算特效，挂 target actor）
	var impact_eff: String = String(info.get("Impact Effect", ""))
	if impact_eff != "":
		_play_puppet_effect(p_target, impact_eff, int(info.get("Impact Zorder", 0)))
	return [true, dmg]


# 源 skill.lua:580-583 闪避 "dodge" 文本（camp enemy→red/else→blue）。
static func _show_dodge_popup(target: Variant) -> void:
	var actor: Variant = target.get("actor")
	if actor == null or not actor.has_method("spawn_popup"):
		return
	var color: String = "red" if int(target.camp) == BattleEngine.CAMP_ENEMY else "blue"
	actor.spawn_popup("dodge", color, false, "text")


# 源 skill.lua:616-620 buff 抗性 popup（reason 区分 "resist"/"miss"；camp enemy→red/else→blue）。
static func _show_buff_resist_popup(target: Variant, reason: String) -> void:
	var actor: Variant = target.get("actor")
	if actor == null or not actor.has_method("spawn_popup"):
		return
	var text: String = "resist" if reason == "resist" else "miss"  # 源 :617 reason=="resist" and "resist" or "miss"
	var color: String = "red" if int(target.camp) == BattleEngine.CAMP_ENEMY else "blue"
	actor.spawn_popup(text, color, false, "text")


# 源 puppet:addEffect 鸭子桥——Logic 层调 target.actor.add_effect(name, zorder)（三层分离）。
static func _play_puppet_effect(target: Variant, effect_name: String, zorder: int) -> void:
	var actor: Variant = target.get("actor")
	if actor != null and actor.has_method("add_effect"):
		actor.add_effect(effect_name, zorder)
