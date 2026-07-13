extends RefCounted

## 幻影长矛手（PL/Lancer）— 照源 PL.lua 翻译。
## 多幻象召唤：Lancer_atk2 召唤 2 幻象（Mirror21/22）+ Lancer_atk3 召唤 Mirror3 + Lancer_ult onAttackFrame 第2击召唤 Mirrorult。
## Lancer_atk start 完全重写（距离判断切 AOE Shape rectangle 远/halfcircle 近 + startPhase 1远/2近）。
## Lancer_ult power 第2击 0 + onAttackFrame attack_counter 2-6 切 Shape Arg1。die 6 幻象同死。
## 复用续8 createMirrorClone（TB/Naga 幻象模式）+ 续6 power 双值 + 续3 start hook + 新 onPhaseFinished hook。

const MIRROR_TIME: float = 12.0          # 源 :3 幻象持续
const MIRROR_TID: int = 147              # 源 :23 幻象 tid
const MIRROR_BUFF_ID: int = 89           # 源 :35 幻象 buff
const ATK2_OFFSET_X: float = 40.0        # 源 :71 atk2 幻象 x 偏移
const ATK2_OFFSET_Y: float = 30.0        # 源 :72 atk2 幻象 y 偏移
const ATK3_OFFSET_X: float = 70.0        # 源 :59 atk3 幻象 x 偏移
const STAGE_MAX_X: int = 799             # 源 :62 幻象 x 上限
const STAGE_MIN_X: int = 1               # 源 :62 幻象 x 下限
const ATK_COUNTER_SECOND: int = 2        # 源 :85/182 第2击
const ULT_ATK_LOW: int = 2               # 源 :169 attack_counter 2-6
const ULT_ATK_HIGH: int = 6              # 源 :169
const SHAPE_FAR_ARG1: int = 231          # 源 :128/171 远/中段 Shape Arg1
const SHAPE_NEAR_ARG1: int = 140         # 源 :134 近 Shape Arg1
const SHAPE_ULT_FAR_ARG1: int = 300      # 源 :177 ult 首尾 Shape Arg1
const SHAPE_RECT_H: int = 150            # 源 :129 rectangle Shape Arg2
const START_PHASE_FAR: int = 1           # 源 :139 startPhase(1) 远距离
const START_PHASE_NEAR: int = 2          # 源 :141 startPhase(2) 近距离
const SKILL_MIN_SQ: float = 18225.0      # 源 :111 远近判定距离平方
const CDR_DENOM: float = 100.0           # 源 :146 CDR/100
const DEFAULT_MOD: float = 1.0           # 源 hp_mod/dps_mod 缺省


# 源 :21-48 createMirrorClone：UnitCreate tid=147 + Buff 89 + mDuration + update + setDeathWithEffect + summonUnit。
func _create_mirror_clone(caster: Variant, position: Vector2) -> Variant:
	var proto: Dictionary = {"_tid": MIRROR_TID, "_level": int(caster.level), "_stars": int(caster.stars), "_rank": int(caster.rank)}
	var config: Dictionary = {"is_monster": true, "estimate_rank": true, "hp_mod": float(caster.config.get("hp_mod", DEFAULT_MOD)), "dps_mod": float(caster.config.get("dps_mod", DEFAULT_MOD))}
	var mirror: BattleUnit = BattleUnit.new(proto, int(caster.camp), config, caster.cm, caster.engine, {}, caster.skill_lib)
	var binfo: Variant = caster.cm.lookup(&"Buff", "", MIRROR_BUFF_ID)
	mirror.add_buff(binfo, caster)
	mirror.custom_data["mDuration"] = MIRROR_TIME
	mirror.hero_hooks["update"] = Callable(self, "_mirror_update")
	mirror.isDeathWithEffect = true
	mirror.direction = int(caster.direction)
	caster.engine.summon_unit(mirror, position, caster)
	return mirror


# 源 :5-20 mirror update：mDuration 倒计 ≤0 die；else basefunc。
func _mirror_update(unit: Variant, dt: float) -> void:
	var dur: float = float(unit.custom_data.get("mDuration", MIRROR_TIME)) - dt
	unit.custom_data["mDuration"] = dur
	if dur <= 0.0:
		unit.die(null)
	else:
		unit._update_default(dt)


# 源 :90-110 hero_die：6 幻象同死（Mirror1/21/22/3/4/ult，1/4 恒 nil 安全）+ basefunc。
func _die(hero: Variant, killer: Variant) -> void:
	for key in ["LancerMirror1", "LancerMirror21", "LancerMirror22", "LancerMirror3", "LancerMirror4", "LancerMirrorult"]:
		var m: Variant = hero.custom_data.get(key, null)
		if m != null and bool(m.is_alive()):
			m.die(null)
	hero._die_default(killer)


# 源 :49-51 ult takeEffectAt：basefunc only（空包装）。
func _ult_take_effect_at(skill: Variant, location: Vector2, src: Variant) -> void:
	BattleSkillEffect.take_effect_at(skill, location, src)


# 源 :82-89 ult power：basefunc 双值，attack_counter==2 → power=0（第2击无伤）。
func _ult_power(skill: Variant, src: Variant, target: Variant) -> Array:
	var r: Array = BattleSkillEffect.power(skill, src, target)
	if int(skill.attack_counter) == ATK_COUNTER_SECOND:
		return [0.0, r[1]]
	return r


# 源 :166-190 ult onAttackFrame：attack_counter 2-6 切 Shape Arg1=231 / else 300 + basefunc + counter==2 召唤 Mirrorult。
func _ult_on_attack_frame(skill: Variant) -> void:
	var originfo: Dictionary = skill.info
	var counter: int = int(skill.attack_counter)
	var arg1: int = SHAPE_FAR_ARG1 if (counter >= ULT_ATK_LOW and counter <= ULT_ATK_HIGH) else SHAPE_ULT_FAR_ARG1
	var wrapped: Dictionary = originfo.duplicate()
	wrapped["Shape Arg1"] = arg1
	skill.info = wrapped
	skill._on_attack_frame_default()
	skill.info = originfo
	if int(skill.attack_counter) == ATK_COUNTER_SECOND and bool(skill.caster.is_alive()):
		var caster: Variant = skill.caster
		caster.custom_data["LancerMirrorult"] = _create_mirror_clone(caster, Vector2(caster.position.x, caster.position.y))


# 源 :67-81 atk2 takeEffectAt：basefunc + 召唤 2 幻象（Mirror21/22）+ caster.x-40。
func _atk2_take_effect_at(skill: Variant, location: Vector2, src: Variant) -> void:
	BattleSkillEffect.take_effect_at(skill, location, src)
	var caster: Variant = skill.caster
	var m21: Variant = _create_mirror_clone(caster, Vector2(location.x + float(caster.direction) * ATK2_OFFSET_X, location.y + float(caster.direction) * ATK2_OFFSET_Y))
	var m22: Variant = _create_mirror_clone(caster, Vector2(location.x + float(caster.direction) * ATK2_OFFSET_X, location.y - float(caster.direction) * ATK2_OFFSET_Y))
	caster.position = Vector2(caster.position.x - float(caster.direction) * ATK2_OFFSET_X, caster.position.y)
	caster.custom_data["LancerMirror21"] = m21
	caster.custom_data["LancerMirror22"] = m22


# 源 :52-66 atk3 takeEffectOn：basefunc + caster alive 召唤 Mirror3（target.x+70，越界反向）。
func _atk3_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var r: Array = BattleSkillEffect.take_effect_on(skill, target, src)
	var caster: Variant = skill.caster
	if not bool(caster.is_alive()):
		return r
	var mx: float = float(target.position.x) + float(caster.direction) * ATK3_OFFSET_X
	if mx > STAGE_MAX_X or mx < STAGE_MIN_X:
		mx = float(target.position.x) - float(caster.direction) * ATK3_OFFSET_X
	caster.custom_data["LancerMirror3"] = _create_mirror_clone(caster, Vector2(mx, target.position.y))
	return r


# 源 :157-165 atk3 createProjectile：basefunc + enableTrack。
func _atk3_create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = skill._create_projectile_default()
	var target: Variant = projectile.skill.target
	if target == null:
		return null
	projectile.enable_track(target)
	return projectile


# 源 :112-153 atk start：完全重写（target/selectTarget/cd/casting/attack_counter + 距离切 AOE Shape + startPhase 1远/2近 + global_cd/setMP）。
func _atk_start(skill: Variant, target: Variant) -> void:
	var info: Dictionary = skill.info
	skill.target = target
	skill._select_target(target)
	skill.cd_remaining = float(info.get("CD", 0))
	skill.casting = true
	skill.attack_counter = 0
	var caster: Variant = skill.caster
	var dx: float = float(skill.target.position.x) - float(caster.position.x)
	var dsq: float = dx * dx
	skill.custom_data["originfo"] = skill.info
	var wrapped: Dictionary = skill.info.duplicate()
	if dsq > SKILL_MIN_SQ:
		wrapped["AOE Shape"] = "rectangle"
		wrapped["Shape Arg1"] = SHAPE_FAR_ARG1
		wrapped["Shape Arg2"] = SHAPE_RECT_H
	else:
		wrapped["AOE Shape"] = "halfcircle"
		wrapped["Shape Arg1"] = SHAPE_NEAR_ARG1
		wrapped["Shape Arg2"] = false
	skill.info = wrapped
	if dsq > SKILL_MIN_SQ:
		skill._start_phase(START_PHASE_FAR)
	else:
		skill._start_phase(START_PHASE_NEAR)
	skill.is_update = true
	caster.global_cd = float(info.get("Global CD", 0))
	var cdr: float = float(caster.attribs.get("CDR", 0)) / CDR_DENOM
	caster.set_mp(float(caster.mp) - float(info.get("Cost MP", 0)) * (1.0 - cdr))
	# 源 :147-152 caster.actor addEffect View 跳过


# 源 :154-156 atk onPhaseFinished：finish（不推进下一 phase，override 默认推进逻辑）。
func _atk_on_phase_finished(skill: Variant) -> void:
	skill.finish()


# 源 :191-194 atk finish：originfo 备份 + basefunc。
func _atk_finish(skill: Variant) -> void:
	skill.custom_data["originfo"] = skill.info
	skill._finish_default()


func apply(hero: Variant) -> void:
	hero.hero_hooks["die"] = Callable(self, "_die")
	var skillult: Variant = hero.skills.get("Lancer_ult")
	if skillult:
		skillult.hero_hooks["takeEffectAt"] = Callable(self, "_ult_take_effect_at")
		skillult.hero_hooks["power"] = Callable(self, "_ult_power")
		skillult.hero_hooks["onAttackFrame"] = Callable(self, "_ult_on_attack_frame")
	var skillatk2: Variant = hero.skills.get("Lancer_atk2")
	if skillatk2:
		skillatk2.hero_hooks["takeEffectAt"] = Callable(self, "_atk2_take_effect_at")
	hero.info["mDuration"] = MIRROR_TIME
	var skillatk: Variant = hero.skills.get("Lancer_atk")
	if skillatk:
		skillatk.hero_hooks["onPhaseFinished"] = Callable(self, "_atk_on_phase_finished")
		skillatk.hero_hooks["start"] = Callable(self, "_atk_start")
		skillatk.hero_hooks["finish"] = Callable(self, "_atk_finish")
	var skillatk3: Variant = hero.skills.get("Lancer_atk3")
	if skillatk3:
		skillatk3.hero_hooks["takeEffectOn"] = Callable(self, "_atk3_take_effect_on")
		skillatk3.hero_hooks["createProjectile"] = Callable(self, "_atk3_create_projectile")
