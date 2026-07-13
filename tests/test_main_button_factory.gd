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
