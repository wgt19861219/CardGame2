extends GutTest
# Phase 8 TutorialGuideView 测试（2026-07-02）。

func test_panel_assembles() -> void:
	var root := Node.new()
	add_child(root)
	var tm := TutorialManager.new(TutorialData.default_steps())
	tm.start()
	var view := TutorialGuideView.new("tutorial", {})
	view.setup_panel(tm)
	view.show_window(root)
	# skip + bubble + head + label + next = 5
	assert_eq(view.container.get_child_count(), 5, "skip + bubble + head + label + next")
	assert_true(view.step_label.text.find("FTintoMain") >= 0, "显示首步 FTintoMain")
	view.remove_window()
	root.queue_free()


func test_next_advances() -> void:
	var root := Node.new()
	add_child(root)
	var tm := TutorialManager.new(TutorialData.default_steps())
	tm.start()
	var view := TutorialGuideView.new("tutorial", {})
	view.setup_panel(tm)
	view.show_window(root)
	view._on_next()
	assert_true(view.step_label.text.find("FTBronzeOpen") >= 0, "下一步 FTBronzeOpen")
	view.remove_window()
	root.queue_free()


func test_skip_completes() -> void:
	var root := Node.new()
	add_child(root)
	var tm := TutorialManager.new(TutorialData.default_steps())
	tm.start()
	var skipped: Array[bool] = [false]
	var view := TutorialGuideView.new("tutorial", {})
	view.setup_panel(tm)
	view.show_window(root)
	view.tutorial_skipped.connect(func() -> void: skipped[0] = true)
	view._on_skip()
	assert_true(skipped[0], "跳过信号")
	assert_true(tm.is_done(), "tutorial 完成")
	root.queue_free()


# 源 tutorialmaker fadeIn：setup 后 modulate.a=0（register_on_enter 在 show_window 时触发 tween）
func test_setup_fade_in_initial_alpha_zero() -> void:
	var root := Node.new()
	add_child(root)
	var tm := TutorialManager.new(TutorialData.default_steps())
	tm.start()
	var view := TutorialGuideView.new("tutorial", {})
	view.setup_panel(tm)
	assert_eq(view.modulate.a, 0.0, "setup 后 modulate.a=0（fadeIn 初始）")
	view.show_window(root)
	view.remove_window()
	root.queue_free()


# 源完成自动 destroy：推进到 done → _refresh → _fade_out_and_remove（不崩 + 显示引导完成）
func test_complete_fades_out() -> void:
	var root := Node.new()
	add_child(root)
	var tm := TutorialManager.new(TutorialData.default_steps())
	tm.start()
	var view := TutorialGuideView.new("tutorial", {})
	view.setup_panel(tm)
	view.show_window(root)
	while not tm.is_done():
		view._on_next()
	assert_true(tm.is_done(), "推进到完成")
	assert_eq(view.step_label.text, "引导完成", "完成显示引导完成")
	root.queue_free()


# 源 tutorialmaker getFinger（:151-178）：finger type 步骤显示 circle + finger 高亮。
func test_highlight_shows_circle_finger_for_finger_step() -> void:
	var root := Node.new()
	add_child(root)
	var tm := TutorialManager.new([&"gotoSelectStage"])
	tm.start()
	var view := TutorialGuideView.new("tutorial", {})
	view.setup_panel(tm)
	view.show_window(root)
	assert_not_null(view._circle, "gotoSelectStage finger 步骤创建 circle（源 :151）")
	assert_not_null(view._finger, "创建 finger（源 :160）")
	if view._circle != null:
		assert_almost_eq(float(view._circle.position.x), 810.0, 0.1, "circle x = STEP_HIGHLIGHTS circle_center（战役按钮）")
	if view._finger != null:
		assert_almost_eq(float(view._finger.position.x), 806.0, 0.1, "finger x = pos-4（源 :161 ccp(x-4)）")
	view.remove_window()
	root.queue_free()


# 非 finger 步骤（tips/无 highlight）不创建 circle/finger。
func test_highlight_skips_non_finger_step() -> void:
	var root := Node.new()
	add_child(root)
	var tm := TutorialManager.new([&"FTintoMain"])
	tm.start()
	var view := TutorialGuideView.new("tutorial", {})
	view.setup_panel(tm)
	view.show_window(root)
	assert_null(view._circle, "FTintoMain 无 highlight 不创建 circle")
	assert_null(view._finger, "无 finger")
	view.remove_window()
	root.queue_free()
