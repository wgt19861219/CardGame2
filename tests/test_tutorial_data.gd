extends GutTest
# Phase 8 TutorialData 步骤序列测试（2026-07-02）— 照源 tutorialres FT 链。

func test_default_ft_steps_linear() -> void:
	var steps: Array = TutorialData.DEFAULT_FT_STEPS
	# 源 FT 链 13 步骤（id 1-16 跳过 _NOT_SET_1-3）
	assert_eq(steps.size(), 13, "FT 链 13 步骤")
	assert_eq(steps[0], &"FTintoMain", "首步 FTintoMain")
	assert_eq(steps[steps.size() - 1], &"gotoBattle", "末步 gotoBattle")


func test_default_steps_duplicate() -> void:
	var s1: Array = TutorialData.default_steps()
	var s2: Array = TutorialData.default_steps()
	s1[0] = &"modified"
	# duplicate 不影响原常量
	assert_eq(s2[0], &"FTintoMain", "default_steps 返副本（互不影响）")


func test_get_description() -> void:
	assert_eq(TutorialData.get_description(&"FTintoMain"), "Here you can recruit the most powerful teammates", "FTintoMain 说明")
	assert_eq(TutorialData.get_description(&"FTBronzeOne"), "", "FTBronzeOne 无对话（空）")
	assert_eq(TutorialData.get_description(&"unknown_step"), "", "未知步骤空")


func test_tutorial_manager_with_ft_steps() -> void:
	var mgr := TutorialManager.new(TutorialData.default_steps())
	mgr.start()
	assert_eq(mgr.current_step(), &"FTintoMain", "首步")
	mgr.complete_current()
	assert_eq(mgr.current_step(), &"FTBronzeOpen", "推进第二步")
	# 完成全部
	while not mgr.is_done():
		mgr.complete_current()
	assert_true(mgr.is_done(), "全完成 is_done")
