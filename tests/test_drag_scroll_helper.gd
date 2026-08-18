extends GutTest
# 修复轮四（2026-08-18）：拖拽滚动 helper + 点击位移判别。

func test_helper_drag_scrolls() -> void:
	var sc := ScrollContainer.new()
	sc.size = Vector2(200.0, 100.0)
	sc.position = Vector2(0.0, 0.0)
	var host := Control.new()
	host.add_child(sc)
	var big := Control.new()
	big.custom_minimum_size = Vector2(200.0, 500.0)
	sc.add_child(big)
	add_child(host)
	var st: Dictionary = {}
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(50, 90)
	press.global_position = Vector2(50, 90)
	DragScrollHelper.handle_input(sc, press, st)
	assert_true(st.has("press_y"), "press 记录基准")
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = Vector2(50, 10)
	motion.global_position = Vector2(50, 10)
	DragScrollHelper.handle_input(sc, motion, st)
	assert_gt(sc.scroll_vertical, 0.0, "向上拖 80px → scroll_vertical 增（内容上移，源 draglist 手势语义）")

func test_is_tap_threshold() -> void:
	assert_true(DragScrollHelper.is_tap(Vector2(10, 10), Vector2(12, 12)), "位移 2.8px < 8 = 点击")
	assert_false(DragScrollHelper.is_tap(Vector2(10, 10), Vector2(30, 10)), "位移 20px ≥ 8 = 拖动非点击")
	assert_false(DragScrollHelper.is_tap(null, Vector2(0, 0)), "无 press 基准不触发")
