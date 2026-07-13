extends GutTest
# BattleSkillPhase 技能 phase 时序（照源 skill.lua phase 推进拆出）。
# rebuild_phase_list 依赖 Puppet/AnimDuration/AnimAtkFrame 表（集成测试另覆盖），
# 此测 phase 操纵逻辑：start_phase / goto_event_idx / on_phase_finished。

class _MockCaster:
	extends RefCounted
	var cm: Variant = null
	var info: Dictionary = {}   # BattleSkill 构造/方法可能读 caster.info（duck-type 契约）
	var actions: Array = []
	func set_action(n: String, _l: bool, _i: bool) -> void:
		actions.append(n)


func _make_skill() -> BattleSkill:
	var c := _MockCaster.new()
	var info: Dictionary = {"Damage Type": "AD", "Plus Ratio": 1.0, "Plus Attr": "AD", "Basic Num": 0}
	return BattleSkill.new(info, c, 1)


# 源 startPhase：进 phase idx（1-based）→ 设 current_phase/elapsed/next_event
func test_start_phase_sets_current() -> void:
	var s := _make_skill()
	s.phase_list = [{"action_name": "atk", "duration": 0.5, "event_list": [{"Time": 0.2, "Type": "Attack"}]}]
	BattleSkillPhase.start_phase(s, 1)
	assert_eq(s.current_phase_idx, 1, "current_phase_idx=1")
	assert_eq(str(s.current_phase["action_name"]), "atk", "current_phase=phase_list[0]")
	assert_eq(s.next_event_idx, 0, "next_event_idx=0")
	assert_eq(float(s.current_phase_elapsed), 0.0, "elapsed 重置 0")


# 源 gotoEventIdx:235-244：跳 event_list 指定 idx（1-based）→ 设 next_event_idx + elapsed
func test_goto_event_idx_advances() -> void:
	var s := _make_skill()
	var evs: Array = [{"Time": 0.1}, {"Time": 0.3}, {"Time": 0.5}]
	s.phase_list = [{"action_name": "atk", "duration": 0.5, "event_list": evs}]
	BattleSkillPhase.start_phase(s, 1)
	BattleSkillPhase.goto_event_idx(s, 2)   # 跳到 event idx 2
	assert_eq(s.next_event_idx, 2, "next_event_idx=2")
	assert_eq(float(s.current_phase_elapsed), 0.3, "elapsed=evs[1].Time=0.3")


# 源 onPhaseFinished:464-472：phase 完成推进 idx+1（_start_phase 转发）
func test_on_phase_finished_advances() -> void:
	var s := _make_skill()
	s.phase_list = [
		{"action_name": "a", "duration": 0.5, "event_list": []},
		{"action_name": "b", "duration": 0.5, "event_list": []},
	]
	BattleSkillPhase.start_phase(s, 1)
	BattleSkillPhase.on_phase_finished(s)   # idx 1 → 推进 2
	assert_eq(s.current_phase_idx, 2, "推进到 phase 2")
	assert_eq(str(s.current_phase["action_name"]), "b", "current_phase=phase_list[1]")
