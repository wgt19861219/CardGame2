extends RefCounted

## BossSil（照源 BossSil.lua，Sil Boss 版）。atk3 Holy mp 伤害 + atk6 阶段切换（atk4 CD=2 + dps×2）。
## skill6 onAttackFrame startScalingAction(1.2,1)/finish endScalingAction 是 Logic 层缩放标志（unit.lua:1487-1490），actor 渲染读标志。

const ULT_BUFF_ID: int = 56
const ATK4_CD: float = 2.0
const DPS_MULT: float = 2.0
const NEXT_STAGE: int = 2
const SCALE_VALUE: float = 1.2
const SCALE_DURATION: float = 1.0


func _atk3_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var r: Array = BattleSkillEffect.take_effect_on(skill, target, src)
	if bool(r[0]):
		target.take_damage({"amount": float(skill.info.get("Script Arg1", 0)), "damage_type": "Holy", "field": "mp", "source": skill.caster})
	return r


func _skill6_start(skill: Variant, target: Variant) -> void:
	var binfo: Variant = skill.caster.cm.lookup(&"Buff", "", ULT_BUFF_ID)
	skill.caster.add_buff(binfo, skill.caster)
	skill._start_default(null)

func _skill6_on_attack_frame(skill: Variant) -> void:
	skill._on_attack_frame_default()
	skill.caster.start_scaling_action(SCALE_VALUE, SCALE_DURATION)


func _skill6_finish(skill: Variant) -> void:
	skill._finish_default()
	var caster: Variant = skill.caster
	if caster != null:
		caster.enter_action_stage_from_one_stage(NEXT_STAGE)
	var skill2: Variant = caster.skills.get("BossSil_atk4")
	if skill2:
		skill2.custom_data["originfo"] = skill2.info
		var wrapped: Dictionary = skill2.info.duplicate()
		wrapped["CD"] = ATK4_CD
		skill2.info = wrapped
	var dps_raw: Variant = caster.config.get("dps_mod", null)
	if dps_raw != null:
		caster.config["dps_mod"] = float(dps_raw) * DPS_MULT
	caster.end_scaling_action()


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("BossSil_atk3")
	if skill:
		skill.hero_hooks["takeEffectOn"] = Callable(self, "_atk3_take_effect_on")
	var skill6: Variant = hero.skills.get("BossSil_atk6")
	if skill6:
		skill6.hero_hooks["start"] = Callable(self, "_skill6_start")
		skill6.hero_hooks["onAttackFrame"] = Callable(self, "_skill6_on_attack_frame")
		skill6.hero_hooks["finish"] = Callable(self, "_skill6_finish")
