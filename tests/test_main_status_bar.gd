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


# 加号视觉尺寸守卫（2026-08-15 两轮修正：初版 Button.icon 原尺寸渲染+撑大 min size 55×55，
# 终版口径：显示尺寸 = 纹理÷CONTENT_SCALE（cocos 点尺寸，无条目散图 Sprite 实际显示），Button 透明命中区与视觉同尺寸，视觉走子 TextureRect 不走 Button.icon）。
func _assert_plus_button_visual_ok() -> void:
	var plus_tex := load(MainStatusBar.PLUS_ICON_RES) as Texture2D
	var expected: Vector2 = plus_tex.get_size() / MainStatusBar.CONTENT_SCALE
	for b in _collected:
		var btn := b as Button
		assert_null(btn.icon, "视觉不走 Button.icon（min size 不可控）")
		assert_almost_eq(btn.size.x, expected.x, 0.01, "Button 命中区宽=加号显示尺寸")
		assert_almost_eq(btn.size.y, expected.y, 0.01, "Button 命中区高=加号显示尺寸")
		var icon_tr: TextureRect = btn.get_node_or_null("plus_icon")
		assert_not_null(icon_tr, "加号视觉为子 TextureRect plus_icon")
		if icon_tr != null:
			assert_almost_eq(icon_tr.size.x, expected.x, 0.01, "加号显示宽=纹理÷CS")
			assert_almost_eq(icon_tr.size.y, expected.y, 0.01, "加号显示高=纹理÷CS")
			assert_eq(icon_tr.mouse_filter, Control.MOUSE_FILTER_IGNORE, "视觉层 IGNORE 不吞点击")


func test_plus_button_visual_source_size_build() -> void:
	# build 版（main identity：vitality plus 为 Button）
	var parent := Control.new()
	add_child_autofree(parent)
	MainStatusBar.build(parent, func() -> void: pass)
	_collect_buttons(parent)
	assert_eq(_collected.size(), 1, "vitality plus 装配为 1 个 Button")
	_assert_plus_button_visual_ok()


func test_plus_button_visual_source_size_bars_only() -> void:
	# 子场景版（build_bars_only：gold + vitality plus 均为 Button，diamond 静态）
	var parent := Control.new()
	add_child_autofree(parent)
	var handler: Callable = func() -> void: pass
	MainStatusBar.build_bars_only(parent, [331.0, 514.0, 681.0], 50.0, handler, handler)
	_collect_buttons(parent)
	assert_eq(_collected.size(), 2, "gold+vitality plus 装配为 2 个 Button")
	_assert_plus_button_visual_ok()


# 货币图标等比缩放 + 中心点守卫（2026-08-15 用户实测：三图标变形且对齐偏）。
# 三图标纹理均非正方形（金币 43×39/钻石 50×38/体力 44×50），统一正方形 rect 强拉会变形；
# 正确行为 = 显示尺寸 纹理÷CONTENT_SCALE（cocos 点尺寸换算），
# 中心点照源 BAR_ICON_CENTER。
func _collect_icons(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is TextureRect and c.name == &"icon":
			out.append(c)
		_collect_icons(c, out)


func test_currency_icons_keep_aspect_and_source_center() -> void:
	var parent := Control.new()
	add_child_autofree(parent)
	MainStatusBar.build(parent)
	var icons: Array = []
	_collect_icons(parent, icons)
	assert_eq(icons.size(), 3, "三条货币图标")
	# 中心点集合按 x 排序后应与源 BAR_ICON_CENTER 排序一致（vit 125 < rmb 156 < money 158）
	var centers: Array = []
	for tr in icons:
		var rect: TextureRect = tr as TextureRect
		var tex := rect.texture as Texture2D
		var disp: Vector2 = tex.get_size() / MainStatusBar.CONTENT_SCALE
		# 等比：显示纵横比 == 显示口径纵横比（不变形）
		assert_almost_eq(rect.size.x / rect.size.y, disp.x / disp.y, 0.01,
			"图标等比缩放（%s 显示 %.2f vs 口径 %.2f）" % [rect.get_parent().name, rect.size.x / rect.size.y, disp.x / disp.y])
		assert_almost_eq(rect.size.x, disp.x, 0.01, "显示宽=纹理÷CS")
		assert_almost_eq(rect.size.y, disp.y, 0.01, "显示高=纹理÷CS")
		centers.append(rect.position + rect.size / 2.0)
	centers.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var expected: Array = (MainStatusBar.BAR_ICON_CENTER as Array).duplicate()
	expected.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for i in range(expected.size()):
		assert_almost_eq((centers[i] as Vector2).x, (expected[i] as Vector2).x, 0.1, "图标中心 x 照源")
		assert_almost_eq((centers[i] as Vector2).y, (expected[i] as Vector2).y, 0.1, "图标中心 y 照源")
