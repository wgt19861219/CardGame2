extends GutTest
# MainStatusBar 装配测试：
# - vitality plus 接 buy_vitality（照源 statusbar.lua:59-68 vitality_add_icon 圆形按钮）
# - gold bar 整条可点 → doClickMidas（照源 statusbar.lua:41-49 money_bg；gold_plus_handler）
# - diamond plus 无 handler → IGNORE（避 STOP 吞点击无响应，P1-复审2-3）

var _collected: Array = []


func before_each() -> void:
	_collected.clear()


# 递归收集所有 Button 子节点（plus 是否装配为可点 Button）。
func _collect_buttons(node: Node) -> void:
	for c in node.get_children():
		if c is Button:
			_collected.append(c)
		_collect_buttons(c)


func test_vitality_plus_clickable_with_handler() -> void:
	# build 传 handler → vitality plus 装配为 Button，pressed 触发 handler（buy_vitality 入口）
	var counter: Array[int] = [0]
	var handler: Callable = func() -> void: counter[0] += 1
	var parent := Control.new()
	add_child_autofree(parent)
	var refs: Dictionary = MainStatusBar.build(parent, handler)
	assert_true(refs.has("vitality"), "vitality label ref 存在")
	_collect_buttons(parent)
	assert_eq(_collected.size(), 1, "有 handler → vitality plus 装配为 1 个 Button")
	if _collected.size() > 0:
		(_collected[0] as Button).pressed.emit()
		assert_eq(counter[0], 1, "vitality plus pressed → 调用 handler")


func test_no_button_without_handler() -> void:
	# 无 handler：gold/diamond/vitality 三条 plus 都 TextureRect IGNORE，0 Button（不吞点击）
	var parent := Control.new()
	add_child_autofree(parent)
	MainStatusBar.build(parent)
	_collect_buttons(parent)
	assert_eq(_collected.size(), 0, "无 handler → 三条 plus 都 IGNORE，0 Button")


# B1 入口接线（第九轮 P1-B1）：gold bar 整条可点 → doClickMidas（照源 statusbar.lua:41-49 money_bg）。
# gold_plus_handler 非 empty → bar Control gui_input 连接 + gold Label IGNORE（避吞点击）。
func test_gold_bar_clickable_with_handler() -> void:
	var counter: Array[int] = [0]
	var handler: Callable = func() -> void: counter[0] += 1
	var parent := Control.new()
	add_child_autofree(parent)
	var refs: Dictionary = MainStatusBar.build(parent, Callable(), Callable(), handler)
	assert_true(refs.has("gold"), "gold label ref 存在")
	var gold_lbl: Label = refs["gold"] as Label
	assert_eq(gold_lbl.mouse_filter, Control.MOUSE_FILTER_IGNORE, "gold Label IGNORE 避吞点击")
	var gold_bar: Control = gold_lbl.get_parent()
	# 模拟鼠标左键点击 bar（照引擎 gui 系统触发 gui_input 信号）
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	gold_bar.gui_input.emit(ev)
	assert_eq(counter[0], 1, "gold bar 点击 → 调用 handler（照源 money_bg→doClickMidas→midas 面板）")
