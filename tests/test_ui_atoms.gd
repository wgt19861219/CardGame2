extends GutTest
# Step 4.1.5 UI 原子库单测：NumberRoll 插值 + ConfirmDialog 状态 + StarDisplay 星级。

func test_number_roll_advances_to_target() -> void:
	var r := NumberRoll.new()
	r.current = 0
	r.roll_to(5)
	for i in range(10):
		r.tick_step()
	assert_eq(r.current, 5, "插值到 target")
	assert_false(r.is_rolling(), "到 target 停止滚动")

func test_number_roll_descending() -> void:
	var r := NumberRoll.new()
	r.current = 10
	r.roll_to(7)
	for i in range(10):
		r.tick_step()
	assert_eq(r.current, 7, "向下插值")

func test_confirm_dialog_callback() -> void:
	var d := ConfirmDialog.new()
	var flag: Array[bool] = [false]
	d.open(func() -> void: flag[0] = true)
	assert_true(d.is_open())
	d.confirm()
	assert_true(flag[0], "confirm 触发回调")
	assert_false(d.is_open(), "confirm 后关闭")

func test_confirm_dialog_cancel() -> void:
	var d := ConfirmDialog.new()
	var confirmed: Array[bool] = [false]
	var cancelled: Array[bool] = [false]
	d.open(
		func() -> void: confirmed[0] = true,
		func() -> void: cancelled[0] = true
	)
	d.cancel()
	assert_false(confirmed[0], "cancel 不触发 confirm")
	assert_true(cancelled[0], "cancel 触发 cancel 回调")

func test_star_display_clamps() -> void:
	var s := StarDisplay.new()
	s.set_stars(3)
	assert_eq(s.filled_count(), 3)
	assert_eq(s.empty_count(), 2)
	s.set_stars(99)  # 超上限
	assert_eq(s.filled_count(), 5, "星级 clamp 到 5")
