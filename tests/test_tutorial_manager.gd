extends GutTest
# Phase 8 TutorialManager 测试（2026-07-02）。旧版步骤状态机。


func test_start_complete() -> void:
	var tm := TutorialManager.new([&"useSkill", &"nextWave"])
	tm.start()
	assert_eq(String(tm.current_step()), "useSkill", "start → 第一步")
	tm.complete_current()
	assert_eq(String(tm.current_step()), "nextWave", "complete → 推进")
	tm.complete_current()
	assert_true(tm.is_done(), "末步完成 → DONE")


func test_empty_steps_done() -> void:
	var tm := TutorialManager.new([])
	tm.start()
	assert_true(tm.is_done(), "空步骤 → start 即 DONE")


func test_skip_all() -> void:
	var tm := TutorialManager.new([&"a", &"b"])
	tm.skip_all()
	assert_true(tm.is_done(), "skip_all → DONE")
