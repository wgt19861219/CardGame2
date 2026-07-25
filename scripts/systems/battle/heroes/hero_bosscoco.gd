extends RefCounted

## BossCoco（照源 BossCoco.lua，Coco Boss 版）。atk4 launchPoint 反向 400 + atk5 takeEffectOn（View）+ atk6 阶段切换（atk2 CD=1/Shape500 + dps×1.5）。
## skill6 onAttackFrame startScalingAction(1.2,1)/finish endScalingAction 是 Logic 层缩放标志（unit.lua:1487-1490），actor 渲染读标志。

const ULT_BUFF_ID: int = 56
const LAUNCH_OFFSET: float = 400.0
const LAUNCH_HEIGHT: float = 10.0
const STAGE_MIN_X: float = 1.0
const STAGE_MAX_X: float = 799.0
const ATK2_CD: float = 1.0
const ATK2_SHAPE_ARG1: int = 500
const DPS_MULT: float = 1.5
const NEXT_STAGE: int = 2
const SCALE_VALUE: float = 1.2
const SCALE_DURATION: float = 1.0


func _atk4_launch_point(skill: Variant) -> Array:
	var r: Array = skill._launch_point_default()
	var position: Vector2 = r[0]
	var direction: float = float(skill.caster.direction)
	position.x = position.x - LAUNCH_OFFSET * direction
	position.x = clampf(position.x, STAGE_MIN_X, STAGE_MAX_X)
	position.y = 0.0
	return [position, LAUNCH_HEIGHT]


func _atk5_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	return BattleSkillEffect.take_effect_on(skill, target, src)


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
	var dps_raw: Variant = caster.config.get("dps_mod", null)
	if dps_raw != null:
		caster.config["dps_mod"] = float(dps_raw) * DPS_MULT
	caster.enter_action_stage_from_one_stage(NEXT_STAGE)
	var skill2: Variant = caster.skills.get("BossCoco_atk2")
	if skill2:
		skill2.custom_data["originfo"] = skill2.info
		var wrapped: Dictionary = skill2.info.duplicate()
		wrapped["CD"] = ATK2_CD
		wrapped["Shape Arg1"] = ATK2_SHAPE_ARG1
		skill2.info = wrapped
	caster.end_scaling_action()


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("BossCoco_atk4")
	if skill:
		skill.hero_hooks["launchPoint"] = Callable(self, "_atk4_launch_point")
	var skill5: Variant = hero.skills.get("BossCoco_atk5")
	if skill5:
		skill5.hero_hooks["takeEffectOn"] = Callable(self, "_atk5_take_effect_on")
	var skill6: Variant = hero.skills.get("BossCoco_atk6")
	if skill6:
		skill6.hero_hooks["start"] = Callable(self, "_skill6_start")
		skill6.hero_hooks["onAttackFrame"] = Callable(self, "_skill6_on_attack_frame")
		skill6.hero_hooks["finish"] = Callable(self, "_skill6_finish")
