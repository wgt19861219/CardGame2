extends GutTest
# Phase 2.6 BattleUnitActionStage（照源 unit.lua:545-693）。
# 验 HP 触发阶段切换（updateActionStage）+ checkActionStageValid。


class MockUnit:
	extends RefCounted
	var hp: float = 500.0
	var attribs: Dictionary = {"HP": 1000.0}
	var action_stage_id: int = 1
	var action_stage_infos: Array = []
	var current_action_stage: int = 0
	var is_action_stage_change_by_manual: bool = false
	var puppet_stack: Array = []
	var skills: Dictionary = {}
	var skill_list: Array = []
	var basic_skill: Variant = null
	var attack_range: float = 0.0
	var state: int = 0
	var current_skill: Variant = null
	var action_name: Variant = null
	var action_duration: float = 0.0
	var action_elapsed: float = 0.0
	func set_action(_a: String, _l: bool = false, _i: bool = false) -> void:
		pass
	func rebuild() -> void:
		pass
	func idle() -> void:
		pass


func test_check_action_stage_valid_hp() -> void:
	var u := MockUnit.new()
	u.hp = 500.0
	u.attribs = {"HP": 1000.0}
	var cond := {"Trigger Type": "HP", "HP Ratio": 80.0}  # 0.8 阈值
	# hp/HP = 0.5 < 0.8 → 不触发（需 HP 降到 80% 以下）
	assert_true(BattleUnitActionStage.check_action_stage_valid(u, cond), "HP 50% < 阈值 80% → 触发")
	u.hp = 900.0  # 0.9 > 0.8 → 不触发
	assert_false(BattleUnitActionStage.check_action_stage_valid(u, cond), "HP 90% > 阈值 80% → 不触发")


func test_update_advances_stage_on_hp() -> void:
	var u := MockUnit.new()
	u.hp = 500.0
	u.attribs = {"HP": 1000.0}
	u.action_stage_infos = [
		{"Trigger Type": "HP", "HP Ratio": 80.0, "Skill List": []},
		{"Trigger Type": "HP", "HP Ratio": 50.0, "Skill List": []},
	]
	u.current_action_stage = 1  # 已在阶段1
	BattleUnitActionStage.update_action_stage(u)
	assert_eq(u.current_action_stage, 2, "HP 50% ≤ 阈值 80% → 进阶段2")
