extends GutTest
# Step 3.3 时光之穴单测：薄入口 + 次数 + 通关 + 组校验。

func test_enter_valid_group() -> void:
	var e := ExerciseManager.new()
	assert_true(e.enter(50005), "有效组可进入")
	assert_eq(e.daily_used(50005), 1)

func test_enter_invalid_group() -> void:
	var e := ExerciseManager.new()
	assert_false(e.enter(99999), "无效组不可进入")

func test_enter_respects_daily_limit() -> void:
	var e := ExerciseManager.new()
	assert_true(e.enter(50005))
	assert_false(e.enter(50005), "超 DailyLimit 不可再进")

func test_complete_marks_cleared() -> void:
	var e := ExerciseManager.new()
	e.complete(50006, true)
	assert_true(e.is_cleared(50006))
	e.complete(50007, false)
	assert_false(e.is_cleared(50007), "失败不标记通关")

func test_mode_for_group() -> void:
	var e := ExerciseManager.new()
	assert_eq(e.mode_for_group(50005), ExerciseManager.Mode.HERO_TRIAL)
