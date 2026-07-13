extends GutTest
# Step 4.11 新手引导单测：步骤状态机 + 完成/DONE 边界（治 STEP_DONE→0 坑）。

func _make() -> TutorialManager:
	return TutorialManager.new([&"welcome", &"first_hero", &"first_battle"])

func test_start_advances_to_first() -> void:
	var t := _make()
	t.start()
	assert_eq(str(t.current_step()), "welcome", "起始步骤 0")
	assert_false(t.is_done())

func test_complete_advances() -> void:
	var t := _make()
	t.start()
	t.complete_current()
	assert_eq(str(t.current_step()), "first_hero", "完成 0 → 步骤 1")

func test_complete_all_marks_done() -> void:
	# 治旧版 STEP_DONE→0 坑：末步完成 → DONE，current_step 不回 0
	var t := _make()
	t.start()
	t.complete_current()  # → first_hero
	t.complete_current()  # → first_battle
	t.complete_current()  # → DONE
	assert_true(t.is_done(), "全部完成 → DONE")
	assert_eq(str(t.current_step()), "", "DONE 后 current_step 为空（非回步骤 0）")

func test_complete_after_done_noop() -> void:
	var t := _make()
	t.start()
	t.skip_all()
	assert_true(t.is_done())
	t.complete_current()  # DONE 后再完成无效
	assert_true(t.is_done())

func test_empty_steps_immediately_done() -> void:
	var t := TutorialManager.new([])
	t.start()
	assert_true(t.is_done(), "空步骤直接 DONE")

func test_skip_all() -> void:
	var t := _make()
	t.start()
	t.skip_all()
	assert_true(t.is_done())


# 源 ed.tutorial.checkDone 等价：事件驱动推进（UI 动作调，匹配当前步骤才完成）。
func test_try_complete_advances_on_match() -> void:
	var t := _make()
	t.start()
	assert_true(t.try_complete(&"welcome"), "匹配当前步骤 welcome → 完成，返 true")
	assert_eq(str(t.current_step()), "first_hero", "推进 first_hero")
	assert_false(t.try_complete(&"welcome"), "已过 welcome，不匹配 → false")
	assert_false(t.try_complete(&"first_battle"), "当前 first_hero，不匹配 first_battle → false")


func test_try_complete_done_noop() -> void:
	var t := TutorialManager.new([])
	t.start()   # 空 → DONE
	assert_false(t.try_complete(&"any"), "DONE 状态 try_complete 返 false 无操作")


# 源 tutorial 多 stage（FT→EE/unlock/SU 条件触发）：switch_steps 切新链重置 index。
func test_switch_steps_resets_to_new_chain() -> void:
	var t := _make()
	t.start()
	t.skip_all()   # FT done
	assert_true(t.is_done())
	t.switch_steps([&"EE1", &"EE2"])
	assert_false(t.is_done(), "switch 后 IN_PROGRESS")
	assert_eq(str(t.current_step()), "EE1", "新链首步")
	assert_true(t.try_complete(&"EE1"), "推进 EE1")
	assert_eq(str(t.current_step()), "EE2", "→ EE2")


func test_switch_empty_steps_done() -> void:
	var t := _make()
	t.start()
	t.switch_steps([])
	assert_true(t.is_done(), "空链 switch → DONE")
