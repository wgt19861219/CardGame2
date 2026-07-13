extends GutTest
# Phase 7 PopWindow 基类测试（2026-07-02）。


func test_show_remove_window() -> void:
	var root := Node.new()
	add_child(root)
	var w := PopWindow.new("test", {})
	w.show_window(root)
	assert_not_null(w.shade_layer, "show → shade_layer 创建")
	assert_not_null(w.container, "container 创建")
	assert_true(root.is_ancestor_of(w), "挂到 parent")
	var enter_called: Array[bool] = [false]
	var w2 := PopWindow.new("t2", {})
	w2.register_on_enter(func() -> void: enter_called[0] = true)
	w2.show_window(root)
	assert_eq(enter_called[0], true, "show → enter handler 触发")
	w.remove_window()
	w2.remove_window()
	root.queue_free()


func test_set_swallow() -> void:
	var w := PopWindow.new()
	w.setup()
	assert_eq(w.shade_layer.mouse_filter, Control.MOUSE_FILTER_STOP, "默认 swallow=STOP")
	w.set_swallow(false)
	assert_eq(w.shade_layer.mouse_filter, Control.MOUSE_FILTER_IGNORE, "swallow=false → IGNORE")
	w.queue_free()
