extends RefCounted

## NEC（死灵法师）英雄 hook（Logic 层）— 照源 battle/heroes/NEC.lua（91 行）。
## NEC_ult：castManualSkill（basefunc 后 target.unfreezeActor + Buff 19）/ takeEffectOn（按已损血算 power 设 Basic Num）/
##   update（phase_elapsed>0.1 设特效标志，View 防重复）/ start（重置标志）。
## NEC_atk2：takeEffectOn（同营 Heal / 异营 AP）/ createProjectile（自施效 + 圆形 AOE 多目标追踪弹，return nil）。

const NEC_BUFF_ID: int = 19
const NEC_EFFECT_DELAY: float = 0.1
const SHAPE_CIRCLE: String = "circle"
const NEC_ATK2_RADIUS: float = 220.0


func apply(hero: Variant) -> void:
	var skillult: Variant = hero.skills.get("NEC_ult")
	if skillult:
		hero.hero_hooks["castManualSkill"] = Callable(self, "_cast_manual_skill")
		skillult.hero_hooks["takeEffectOn"] = Callable(self, "_ult_take_effect_on")
		skillult.hero_hooks["update"] = Callable(self, "_ult_update")
		skillult.hero_hooks["start"] = Callable(self, "_ult_start")
	var skillatk2: Variant = hero.skills.get("NEC_atk2")
	if skillatk2:
		skillatk2.hero_hooks["takeEffectOn"] = Callable(self, "_atk2_take_effect_on")
		skillatk2.hero_hooks["createProjectile"] = Callable(self, "_atk2_create_projectile")


func _cast_manual_skill(hero: Variant) -> void:
	hero._cast_manual_skill_default()
	var target: Variant = hero.skills.get("NEC_ult").target
	if target == null:
		return
	target.unfreeze_actor()
	var binfo: Variant = hero.cm.lookup(&"Buff", "", NEC_BUFF_ID)
	target.add_buff(binfo, hero)


func _ult_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	if not bool(target.is_alive()):
		return [false, 0.0]
	var lost_hp: float = float(target.attribs.get("HP", 0.0)) - float(target.hp)
	var ratio: float = float(skill.info.get("Script Arg1", 0.0))
	var power: float = lost_hp * ratio
	var power_max: float = float(skill.info.get("Script Arg3", 0.0))
	var power_min: float = float(skill.info.get("Script Arg4", 0.0))
	power = clamp(power, power_min, power_max)
	skill.info["Basic Num"] = power
	return BattleSkillEffect.take_effect_on(skill, target, src)  # basefunc


func _ult_update(skill: Variant, dt_action: float, dt_cd: float) -> void:
	skill._update_default(dt_action, dt_cd)
	if not bool(skill.custom_data.get("nec_ult_effect", false)) and skill.current_phase_elapsed > NEC_EFFECT_DELAY:
		skill.custom_data["nec_ult_effect"] = true
		# playEffect（View）Phase 4


func _ult_start(skill: Variant, target: Variant) -> void:
	skill.custom_data["nec_ult_effect"] = false
	skill._start_default(target)


func _atk2_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var caster: Variant = skill.caster
	if int(caster.camp) == int(target.camp):
		skill.info["Damage Type"] = "Heal"
		skill.info["Impact Effect"] = "eff_impact_heal.cha"
	else:
		skill.info["Damage Type"] = "AP"
		skill.info["Impact Effect"] = "eff_impact_slash.cha"
	return BattleSkillEffect.take_effect_on(skill, target, src)


func _atk2_create_projectile(skill: Variant) -> Variant:
	var caster: Variant = skill.caster
	skill.take_effect_on(caster)
	for unit in caster.engine.foreach_alive_unit(skill._affected_camp()):
		if unit == caster:
			continue
		var p2: Vector2 = unit.position - caster.position
		if BattleSkillEffect.test_point_in_shape(p2, SHAPE_CIRCLE, NEC_ATK2_RADIUS, 0.0):
			var projectile: Variant = skill._create_projectile_default()  # basefunc 创建（每目标一个）
			projectile.enable_track(unit)
			caster.engine.add_projectile(projectile)
	return null
