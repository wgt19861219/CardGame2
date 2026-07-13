extends RefCounted

## ExLoz 英雄 hook（Logic 层）— 照源 ExLoz.lua（202 行）翻译。
## 多弹道（ult 双弹 + counter 1/4/8 额外 atk4×2 / atk4 双弹）+ 3D 追踪 projectile（zSpeed 衰减 + targetV·dv·8）+
##   周期 AP 伤害 buff（hurtcounts%3==1 且非 uncontrollable）+ takeDamage 免疫（hp field→0.01，致死 die）。
## 复用续3 createProjectile + 续4 buff update/createBuff/onAttackFrame/单位 takeDamage + 续7 projectile update（3D）。
## 源 skill2_createChain/chain_jump 逻辑等价默认 BattleChain（续6 jump 同 affect_times++ + takeEffectOn），不挂。

const UNIT_NAME: String = "ExLoz"
const ULT_PROJ2_X: float = 93.2715           # 源 :9 ult 弹道2 x 偏移
const ULT_PROJ2_H: float = 52.6295            # 源 :10
const ULT_PROJ3_X: float = -2.9768            # 源 :21 counter 额外弹道3 x
const ULT_PROJ3_H: float = 86.9535            # 源 :22
const ULT_PROJ4_X: float = 21.87              # 源 :30
const ULT_PROJ4_H: float = 85.27275           # 源 :31
const ATK4_PROJ2_X: float = 13.284            # 源 :83 atk4 弹道2 x 偏移
const ATK4_PROJ2_H: float = 71.28             # 源 :84
const GRAVITY_DV: float = 600.0               # 源 :40 dv=600*dt
const TRACK_DV_MULT: float = 8.0              # 源 :68 *8
const ATK2_BUFF_ID: int = 160                 # 源 :154 atk2 start buff
const HURT_PERIOD: int = 3                    # 源 :98 hurtcounts%3
const HURT_FIRST: int = 1                     # 源 :98 ==1
const DAMAGE_MIN: float = 0.01                # 源 :180 takeDamage hp 最小伤
const ULT_COUNTER_1: int = 1                  # 源 :12 attack_counter
const ULT_COUNTER_4: int = 4
const ULT_COUNTER_8: int = 8
const DEFAULT_ATTRIB: float = 0.0             # 源 :99 or 0 fallback


# 源 :3-36 ult createProjectile：basefunc×2（弹道 + 弹道2 偏移）+ counter 1/4/8 额外 atk4 追踪弹道×2。
func _ult_create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = skill._create_projectile_default()
	var projectile2: Variant = skill._create_projectile_default()
	var attack_counter: int = int(skill.attack_counter)
	var pos: Vector2 = skill.caster.position
	var dir: int = int(skill.caster.direction)
	projectile2.position = Vector2(pos.x + ULT_PROJ2_X * dir, pos.y)
	projectile2.height = ULT_PROJ2_H
	skill.caster.engine.add_projectile(projectile2)
	if attack_counter == ULT_COUNTER_1 or attack_counter == ULT_COUNTER_4 or attack_counter == ULT_COUNTER_8:
		var skill4: Variant = skill.caster.skills.get(UNIT_NAME + "_atk4")
		if skill4:
			skill4._select_target(null)
			_add_tracked_proj(skill4, pos, dir, ULT_PROJ3_X, ULT_PROJ3_H)
			skill4._select_target(null)
			_add_tracked_proj(skill4, pos, dir, ULT_PROJ4_X, ULT_PROJ4_H)
	return projectile


# 辅助（源 :16-32）：建 atk4 追踪弹道（basefunc + enableTrack/mytarget + 偏移 + add_projectile）。
func _add_tracked_proj(skill4: Variant, pos: Vector2, dir: int, x_off: float, h: float) -> void:
	if skill4 == null:
		return
	var proj: Variant = skill4._create_projectile_default()
	if skill4.target != null and bool(skill4.target.is_alive()):
		proj.enable_track(skill4.target)
		proj.custom_data["mytarget"] = skill4.target
	proj.position = Vector2(pos.x + x_off * dir, pos.y)
	proj.height = h
	skill4.caster.engine.add_projectile(proj)


# 源 :37-71 atk4 projectile update：basefunc + zSpeed 衰减 gravity + 3D 追踪（targetV 单位向量·dv·8 加速）。
func _atk4_projectile_update(projectile: Variant, dt: float) -> void:
	projectile._update_default(dt)
	var info: Dictionary = projectile.skill.info
	projectile.z_speed = float(projectile.z_speed) - float(info.get("Tile Gravity", 0.0)) * dt
	var dv: float = GRAVITY_DV * dt
	var target_unit: Variant = projectile.custom_data.get("mytarget", null)
	if target_unit == null:
		return
	var tpos: Vector2 = target_unit.position
	var xy: Vector2 = projectile.velocity
	var zs: float = float(projectile.z_speed)
	var targetxy_v: Vector2 = tpos - projectile.position
	var targetz_v: float = -float(projectile.height)
	var denom: float = targetxy_v.x * targetxy_v.x + targetxy_v.y * targetxy_v.y + targetz_v * targetz_v
	var u: float = 1.0 / sqrt(denom)  # 源 ^-0.5（逆平方根）
	if zs > 0.0 and dv < zs:
		projectile.z_speed = zs - dv
		dv = 0.0
	elif zs > 0.0:
		dv = dv - zs
		projectile.z_speed = 0.0
	projectile.velocity = Vector2(xy.x + u * targetxy_v.x * dv * TRACK_DV_MULT, xy.y + u * targetxy_v.y * dv * TRACK_DV_MULT)
	projectile.z_speed = float(projectile.z_speed) + u * targetz_v * dv * TRACK_DV_MULT


# 源 :72-92 atk4 createProjectile：basefunc + enableTrack/mytarget + update hook + 额外弹道2（偏移 + 追踪）。
func _atk4_create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = skill._create_projectile_default()
	if skill.target != null and bool(skill.target.is_alive()):
		projectile.enable_track(skill.target)
		projectile.custom_data["mytarget"] = skill.target
	projectile.hero_hooks["update"] = Callable(self, "_atk4_projectile_update")
	var pos: Vector2 = skill.caster.position
	var dir: int = int(skill.caster.direction)
	skill._select_target(null)
	var projectile2: Variant = skill._create_projectile_default()
	projectile2.position = Vector2(pos.x + ATK4_PROJ2_X * dir, pos.y)
	projectile2.height = ATK4_PROJ2_H
	if skill.target != null and bool(skill.target.is_alive()):
		projectile2.enable_track(skill.target)
		projectile2.custom_data["mytarget"] = skill.target
	skill.caster.engine.add_projectile(projectile2)
	projectile2.hero_hooks["update"] = Callable(self, "_atk4_projectile_update")
	return projectile


# 源 :93-104 buff update：hurtcounts++ + %3==1 且非 uncontrollable → takeDamage AP（Basic Num+Plus Ratio·attribs）+ hurt。
func _buff_update(buff: Variant, dt: float) -> void:
	var caster: Variant = buff.caster
	var owner: Variant = buff.owner
	var skill2: Variant = caster.skills.get(UNIT_NAME + "_atk2")
	var hurtcounts: int = int(buff.custom_data.get("hurtcounts", 0)) + 1
	buff.custom_data["hurtcounts"] = hurtcounts
	if hurtcounts % HURT_PERIOD == HURT_FIRST and not bool(owner.buff_effects.get("uncontrollable", false)) and skill2 != null:
		var info2: Dictionary = skill2.info
		var plus_attr: String = str(info2.get("Plus Attr", ""))
		var damage: float = float(info2.get("Basic Num", 0.0)) + float(info2.get("Plus Ratio", 0.0)) * float(caster.attribs.get(plus_attr, DEFAULT_ATTRIB))
		owner.take_damage({"amount": damage, "damage_type": "AP", "field": "hp", "source": owner})
		owner.hurt()
	buff._update_default(dt)


# 源 :105-115 atk2 createBuff：basefunc + total_dmg/times/hurtcounts + buff update hook + skill2target/skill2buff。
func _atk2_create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)
	buff.custom_data["total_dmg"] = 0
	buff.custom_data["total_times"] = 0
	buff.custom_data["hurtcounts"] = 0
	buff.hero_hooks["update"] = Callable(self, "_buff_update")
	skill.caster.custom_data["skill2target"] = target
	skill.caster.custom_data["skill2buff"] = buff
	return buff


# 源 :143-151 atk2 onAttackFrame：counter==0 basefunc / else removeBuff skill2buff。
func _atk2_on_attack_frame(skill: Variant) -> void:
	if int(skill.attack_counter) == 0:
		skill._on_attack_frame_default()
	else:
		var caster: Variant = skill.caster
		var t: Variant = caster.custom_data.get("skill2target", null)
		var b: Variant = caster.custom_data.get("skill2buff", null)
		if t != null and b != null:
			t.remove_buff(b)


# 源 :152-158 atk2 start：加 Buff 160 + basefunc。
func _atk2_start(skill: Variant, target: Variant) -> void:
	var binfo: Variant = skill.caster.cm.lookup(&"Buff", "", ATK2_BUFF_ID)
	skill.caster.add_buff(binfo, skill.caster)
	skill._start_default(target)


# 源 :159-184 takeDamage（单位）：field=hp → hp<=1 setHP0 die 返1 / 否则返0.01（免疫）；else basefunc。
func _take_damage(unit: Variant, params: Dictionary) -> float:
	var field: String = str(params.get("field", "hp"))
	if field == "hp":
		if int(unit.hp) <= 1:
			unit.set_hp(0)
			unit.die(params.get("source", null))
			return 1.0
		_show_zero_popup(unit)  # 源 :170-173 免疫 -0 飘字
		return DAMAGE_MIN
	return unit._take_damage_default(params)


# 源 :185-201 init_hero：ult createProjectile + atk2（start/createBuff/onAttackFrame）+ atk4 createProjectile + 单位 takeDamage。
func apply(hero: Variant) -> void:
	var skillult: Variant = hero.skills.get(UNIT_NAME + "_ult")
	if skillult:
		skillult.hero_hooks["createProjectile"] = Callable(self, "_ult_create_projectile")
	var skillatk2: Variant = hero.skills.get(UNIT_NAME + "_atk2")
	if skillatk2:
		skillatk2.hero_hooks["start"] = Callable(self, "_atk2_start")
		skillatk2.hero_hooks["createBuff"] = Callable(self, "_atk2_create_buff")
		skillatk2.hero_hooks["onAttackFrame"] = Callable(self, "_atk2_on_attack_frame")
	var skillatk4: Variant = hero.skills.get(UNIT_NAME + "_atk4")
	if skillatk4:
		skillatk4.hero_hooks["createProjectile"] = Callable(self, "_atk4_create_projectile")
	hero.hero_hooks["takeDamage"] = Callable(self, "_take_damage")


# 源 ExLoz.lua:170-173 免疫 -0 飘字（unit actor，orange，damage style）。
func _show_zero_popup(unit: Variant) -> void:
	var actor: Variant = unit.get("actor")
	if actor == null or not actor.has_method("spawn_popup"):
		return
	actor.spawn_popup("-0", "orange", false, "damage")
