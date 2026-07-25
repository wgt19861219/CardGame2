class_name BattleUnitActionStage
extends RefCounted

## 单位行动阶段（Boss 多阶段，Logic 层）— 照源 unit.lua:545-693 + 1410 翻译（Phase 2.6，2026-07-01）。
## HP 触发阶段切换（Period 表数据驱动）+ rewritePuppetStack（puppet 换装）+ resetSkillList（技能切换）。
## usePuppet/Enter Action 动画/buff removeEffectAndShader（View）Phase 4。
## getActionStageInfo 在 _init/rebuild（有 cm）填 infos；update/enter 系列只读 infos（不依赖 cm，
##   适配 unit.update 链无 cm）；enter_action_stage 从 infos 取 stageData（源再查表，infos 已含，等价）。

const HP_RATIO_DENOM: float = 100.0
const BASIC_RANGE_OFFSET: int = 5

static func get_action_stage_info(u: Variant, cm: ConfigManager) -> void:
	if int(u.action_stage_id) == 0:
		return
	var infos: Array = []
	var n_stage: int = 1
	var period_table: Dictionary = cm.get_raw_table("Period")
	var group: Dictionary = period_table.get(str(u.action_stage_id), {})
	while true:
		var stage_data: Dictionary = group.get(str(n_stage), {})
		if stage_data.is_empty():
			break
		infos.append(stage_data)
		n_stage += 1
	u.action_stage_infos = infos


static func check_action_stage_valid(u: Variant, condition: Dictionary) -> bool:
	if condition.is_empty():
		return false
	if str(condition.get("Trigger Type", "")) == "HP":
		var condition_value: float = float(condition.get("HP Ratio", 0.0)) / HP_RATIO_DENOM
		var hp_value: float = float(u.hp) / float(u.attribs.get("HP", 1.0))
		if condition_value >= hp_value:
			return true
	return false


static func enter_action_stage_from_one_stage(u: Variant, n_stage: int) -> void:
	if not bool(u.is_action_stage_change_by_manual):
		if int(u.current_action_stage) != 0 and n_stage <= int(u.current_action_stage):
			return
		if n_stage != 0:
			u.current_action_stage = n_stage
			enter_action_stage(u, n_stage)
	else:
		u.current_action_stage = n_stage
		enter_action_stage(u, n_stage)


static func update_action_stage(u: Variant) -> void:
	var infos: Array = u.action_stage_infos
	if infos.size() > 0:
		if int(u.current_action_stage) == 0:
			enter_action_stage_from_one_stage(u, 1)
		elif not bool(u.is_action_stage_change_by_manual):
			var stage_num: int = infos.size()
			if stage_num > int(u.current_action_stage):
				var condition: Dictionary = infos[int(u.current_action_stage) - 1]
				if check_action_stage_valid(u, condition):
					enter_action_stage_from_one_stage(u, int(u.current_action_stage) + 1)


static func enter_action_stage(u: Variant, n_stage: int) -> void:
	if int(u.action_stage_id) == 0:
		return
	var stage_data: Dictionary = _infos_stage_data(u, n_stage)
	if stage_data.is_empty():
		return
	rewrite_puppet_stack(u, 1, str(stage_data.get("Puppet ID", "")))
	reset_skill_list(u, stage_data)
	var enter_action: String = str(stage_data.get("Enter Action", ""))
	if enter_action != "":
		u.set_action(enter_action)
		u.state = BattleUnit.State.ACTION_TRANSITION


# infos 取第 n_stage 阶段数据（源 lookupDataTable 再查；infos 已含全部，等价）
static func _infos_stage_data(u: Variant, n_stage: int) -> Dictionary:
	var infos: Array = u.action_stage_infos
	if n_stage >= 1 and n_stage <= infos.size():
		return infos[n_stage - 1]
	return {}


static func reset_skill_list(u: Variant, stage_data: Dictionary) -> void:
	u.current_skill = null
	u.action_name = null
	u.action_duration = 0.0
	u.action_elapsed = 0.0
	for skill in u.skill_list:
		skill.reset()
		skill.pause()
	var normal_skill_id: int = int(stage_data.get("Basic Skill", 0))
	for id in stage_data.get("Skill List", []):
		var sid: int = int(id)
		for skill in u.skill_list:
			if sid == int(skill.info.get("Skill Group ID", 0)):
				skill.resume_update()
	if u.skills is Dictionary and u.skills.has(normal_skill_id):
		var basic: Variant = u.skills[normal_skill_id]
		u.basic_skill = basic
		u.attack_range = float(basic.info.get("Max Range", 0.0)) - BASIC_RANGE_OFFSET
	u.rebuild()
	u.idle()


static func rewrite_puppet_stack(u: Variant, index: int, name: String) -> bool:
	var is_ret: bool = true
	if index > u.puppet_stack.size():
		is_ret = false
	else:
		u.puppet_stack[index - 1] = name  # Lua 1-based → Godot 0-based
	return is_ret
