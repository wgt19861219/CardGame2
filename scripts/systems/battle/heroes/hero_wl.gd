extends RefCounted

## 术士（WL）— 照源 WL.lua 翻译。
## WL_ult 召唤地狱火（Infernal）：createProjectile 3D 追踪抛物线弹道（enableTrack + height + 单位向量×v）
## → takeEffectAt 旧地狱火先 die + 召唤新地狱火（UnitCreate tid=128）+ 周期 Infernal_atk3 buff（attack_timer 倒计 takeEffectAt）
## + basefunc（原 AOE 伤害）。WL_atk2 友军治疗/敌人中毒 createBuff 分支。die 联动地狱火同死。
## 复用续7 TK 3D 追踪 + DP 周期 buff + 续8 Necromancersr UnitCreate + 续3 createBuff 友敌 + 续4 die 模式。

const TRACK_SPEED: float = 900.0
const PROJECTILE_HEIGHT: float = 300.0
const TARGET_OFFSET: float = 60.0
const NORM_POWER: float = -0.5
const INFERNAL_TID: int = 128
const BUFF_INTERVAL: float = 1.0
const HEAL_DENOM: float = 100.0
const ENEMY_GUILD_HP_MOD: float = 2.0
const DEFAULT_HP_MOD: float = 1.0

var _target_pos: Vector2 = Vector2.ZERO  # 跨 hook 共享（源文件 local targetpos：createProjectile 设，takeEffectAt summonUnit 用）


func _create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = skill._create_projectile_default()
	var target: Variant = projectile.skill.target
	if target == null:
		return null
	var caster: Variant = skill.caster
	projectile.enable_track(target)
	projectile.height = PROJECTILE_HEIGHT
	projectile.position = Vector2(caster.position.x, caster.position.y)
	_target_pos = Vector2(target.position.x - TARGET_OFFSET * float(caster.direction), target.position.y)
	var targetxy: Vector2 = _target_pos - projectile.position
	var targetz: float = -float(projectile.height)
	var u: float = pow(targetxy.x * targetxy.x + targetxy.y * targetxy.y + targetz * targetz, NORM_POWER)
	projectile.velocity = Vector2(u * targetxy.x * TRACK_SPEED, u * targetxy.y * TRACK_SPEED)
	projectile.z_speed = u * targetz * TRACK_SPEED
	return projectile


func _take_effect_at(skill: Variant, location: Vector2, src: Variant) -> void:
	var caster: Variant = skill.caster
	var s_atk3: Variant = caster.skills.get("WL_atk3")
	var s_atk4: Variant = caster.skills.get("WL_atk4")
	var atk3_lv: int = int(s_atk3.level) if s_atk3 != null else 0
	var atk4_lv: int = int(s_atk4.level) if s_atk4 != null else 0
	var old_infernal: Variant = caster.custom_data.get("infernal", null)
	if old_infernal != null and bool(old_infernal.is_alive()):
		old_infernal.die(null)
	if caster != null and bool(caster.is_alive()):
		var proto: Dictionary = {
			"_tid": INFERNAL_TID,
			"_level": int(skill.level),
			"_stars": int(caster.stars),
			"_skill_levels": {"3": atk3_lv, "4": atk4_lv}
		}
		var hp_mod: float = ENEMY_GUILD_HP_MOD if (int(caster.camp) == BattleEngine.CAMP_ENEMY and bool(caster.engine.guild_instance_mode)) else float(caster.config.get("hp_mod", DEFAULT_HP_MOD))
		var config: Dictionary = {"is_monster": true, "estimate_rank": true, "hp_mod": hp_mod, "summoner": caster}
		var infernal: BattleUnit = BattleUnit.new(proto, int(caster.camp), config, caster.cm, caster.engine, {}, caster.skill_lib)
		infernal.direction = int(caster.direction)
		caster.engine.summon_unit(infernal, _target_pos, caster)
		caster.custom_data["infernal"] = infernal
		var infernal_atk3: Variant = infernal.skills.get("Infernal_atk3")
		if infernal_atk3 != null:
			var bid: int = int(infernal_atk3.info.get("Script Arg2", 0))
			var binfo: Variant = caster.cm.lookup(&"Buff", "", bid)
			var buff: Variant = infernal.add_buff(binfo, caster)
			buff.custom_data["attack_timer"] = BUFF_INTERVAL
			buff.hero_hooks["update"] = Callable(self, "_infernal_buff_update")
	BattleSkillEffect.take_effect_at(skill, location, src)  # basefunc（源 :81，原 AOE 伤害）


func _infernal_buff_update(buff: Variant, dt: float) -> void:
	var timer: float = float(buff.custom_data.get("attack_timer", BUFF_INTERVAL)) - dt
	while timer <= 0.0:
		timer += BUFF_INTERVAL
		var infernal_atk3: Variant = buff.owner.skills.get("Infernal_atk3")
		if infernal_atk3 != null:
			infernal_atk3.take_effect_at(buff.owner.position)
	buff.custom_data["attack_timer"] = timer


func _create_buff(skill: Variant, target: Variant) -> Variant:
	var caster: Variant = skill.caster
	if int(caster.camp) == int(target.camp):
		# 友军治疗：HPR 按 caster HEAL 加成。必须在局部副本上计算——skill.info 是
		# SkillLibrary 共享缓存（get_skill_info 返共享引用），写回会跨单位/跨场次
		# 指数累积（2026-09-28 审查 P0-2 根修，原 apply 写回方案废弃）。
		var heal_info: Dictionary = skill.info.get("buff_info", {}).duplicate()
		var heal: float = float(caster.attribs.get("HEAL", 0))
		heal_info["HPR"] = float(heal_info.get("HPR", 0)) * (1.0 + heal / HEAL_DENOM)
		return BattleBuff.new(heal_info, target, caster)
	var bid: int = int(skill.info.get("Script Arg2", 0))
	var binfo: Dictionary = caster.cm.lookup(&"Buff", "", bid).duplicate()  # duplicate 避免 HPR 改污染 cm 表
	binfo["HPR"] = -float(skill.info.get("Script Arg1", 0))
	return BattleBuff.new(binfo, target, caster)


func _die(hero: Variant, killer: Variant) -> void:
	var infernal: Variant = hero.custom_data.get("infernal", null)
	if infernal != null and bool(infernal.is_alive()):
		infernal.die(null)
	hero._die_default(killer)


func apply(hero: Variant) -> void:
	var skillult: Variant = hero.skills.get("WL_ult")
	var skillatk2: Variant = hero.skills.get("WL_atk2")
	hero.hero_hooks["die"] = Callable(self, "_die")
	if skillult:
		skillult.hero_hooks["createProjectile"] = Callable(self, "_create_projectile")
		skillult.hero_hooks["takeEffectAt"] = Callable(self, "_take_effect_at")
	if skillatk2:
		skillatk2.hero_hooks["createBuff"] = Callable(self, "_create_buff")
