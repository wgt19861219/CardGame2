extends GutTest
# MainButtonFactory._add_press press 光效（照源 ui/main.lua:592-604 createMainButton）。
# press = main_button_press.png × lightSize，中心 = 按钮中心 + lightPos（翻 Y），默认隐藏，button_down/up 控制显隐。


# 有 light → 创建 press TextureRect，默认隐藏，尺寸 = lightSize × scale。
func test_press_created_hidden_with_scale() -> void:
	var btn := Button.new()
	btn.size = Vector2(200, 200)
	add_child(btn)
	MainButtonFactory._add_press(btn, {"light": [0, 40, 300, 300], "scale": 0.9})
	var press: TextureRect = _find_press(btn)
	assert_not_null(press, "press TextureRect 已创建")
	assert_false(press.visible, "press 默认隐藏（源 :599 setVisible(false)）")
	assert_eq(press.size, Vector2(270, 270), "尺寸 = lightSize × scale = 300×0.9（源 :602-603）")
	btn.free()


# button_down → press 可见；button_up → press 隐藏（源 btRegisterClick 按下显示）。
func test_press_visibility_toggle() -> void:
	var btn := Button.new()
	btn.size = Vector2(200, 200)
	add_child(btn)
	MainButtonFactory._add_press(btn, {"light": [0, 40, 300, 300]})
	var press: TextureRect = _find_press(btn)
	btn.emit_signal("button_down")
	assert_true(press.visible, "button_down → press 显示")
	btn.emit_signal("button_up")
	assert_false(press.visible, "button_up → press 隐藏")
	btn.free()


# 无 light → 不创建 press（lightning 等无 press 的入口）。
func test_no_light_no_press() -> void:
	var btn := Button.new()
	btn.size = Vector2(200, 200)
	add_child(btn)
	MainButtonFactory._add_press(btn, {})
	assert_null(_find_press(btn), "无 light 字段不创建 press")
	btn.free()


# press 中心 = btn 中心 + lightPos（源 y 上 → Godot y 下，翻 Y）。
func test_press_position_lightpos_flipped_y() -> void:
	var btn := Button.new()
	btn.size = Vector2(200, 200)   # 中心 (100, 100)
	add_child(btn)
	MainButtonFactory._add_press(btn, {"light": [10, 40, 100, 100]})   # scale 默认 1
	var press: TextureRect = _find_press(btn)
	# 中心 = (100+10, 100-40) = (110, 60)；左上 = 中心 - size/2 = (60, 10)
	assert_eq(press.position, Vector2(60, 10), "press 中心 = btn 中心 + lightPos（翻 Y）")
	btn.free()


# 找 press：btn 子节点里默认隐藏的 TextureRect（title 是 visible=true，press 是 visible=false）。
func _find_press(btn: Button) -> TextureRect:
	for c in btn.get_children():
		if c is TextureRect and not c.visible:
			return c
	return null


# 三层 z 序守卫（2026-09-12 回归：附件 slot z 盖住建筑文字标签）：press 最底 < Spine 骨架 < title，
# 且骨架内最高附件 z（slot 索引）叠加后仍不超 title——标签恒在图标之上。
func test_layer_z_order_press_below_spine_below_title() -> void:
	var btn := MainButtonFactory.make_entry(
		{"id": "mailbox", "title": "mainres.Mailbox", "pos": [1000, 410], "res": "eff_UI_Main_Mailbox", "gap": [2, 4, 0, 0, 0], "touch": [0, 40], "radius": 60, "light": [8, 45, 200, 200]},
		func() -> void: pass, false)
	add_child(btn)
	var press: TextureRect = _find_press(btn)
	assert_not_null(press, "press 已创建")
	var spine_z: int = 0
	var title_z: int = 0
	var max_attach_z: int = 0
	for c in btn.get_children():
		if c is SpineSkeleton:
			spine_z = (c as SpineSkeleton).z_index
			max_attach_z = _max_descendant_canvas_z(c as SpineSkeleton, 0)
		elif c is TextureRect and c.visible and (c as TextureRect).texture != null:
			title_z = c.z_index
	assert_true(press.z_index < spine_z, "press(%d) < 骨架(%d)" % [press.z_index, spine_z])
	assert_true(spine_z + max_attach_z < title_z, "骨架+最高附件(%d+%d) < title(%d)" % [spine_z, max_attach_z, title_z])
	# 上界守卫（2026-09-12 三连回归：TITLE_Z=1024 越层，建筑标签浮在所有弹窗上）：
	# title 不得达 PopWindow.Z_BASE(100)——否则压过全部弹窗（栈 z=100/200/…）。
	assert_true(title_z < 100, "title(%d) < PopWindow.Z_BASE(100)，弹窗须盖住主城标签" % title_z)
	btn.free()


# 骨架子树内 CanvasItem 的最高 z_index（附件 slot 索引叠加判定用）。
func _max_descendant_canvas_z(root: Node, acc: int) -> int:
	var best: int = acc
	for c in root.get_children():
		if c is CanvasItem:
			best = maxi(best, (c as CanvasItem).z_index)
		best = maxi(best, _max_descendant_canvas_z(c, acc))
	return best
