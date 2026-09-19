extends GutTest
# VolumeBar 音量滑条控件测试（2026-09-19 五轮）：装配/region 裁剪/静默初值/
# 点击与拖动定位/边界 clamp/同值不重发。_gui_input 用构造事件直调（逻辑层验证）。

const BAR_W: float = 190.0   # 与 VolumeBar.BAR_SIZE.x 一致（点击换算基准）


func _make_bar() -> VolumeBar:
	var bar := VolumeBar.new(55.0)   # 行高命中区（setup_panel 用法）
	add_child_autofree(bar)
	return bar


func _press(bar: VolumeBar, x: float) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(x, 10.0)
	bar._gui_input(ev)


func _drag(bar: VolumeBar, x: float) -> void:
	var ev := InputEventMouseMotion.new()
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	ev.position = Vector2(x, 10.0)
	bar._gui_input(ev)


func test_initial_build() -> void:
	var bar := _make_bar()
	assert_ne(bar._bg, null, "底槽创建")
	assert_ne(bar._fill, null, "填充创建")
	assert_almost_eq(bar._bg.offset_right, BAR_W, 0.01, "底槽宽 190（BAR_SIZE）")
	assert_almost_eq(bar.get_value(), 1.0, 0.001, "默认满值 100%")
	assert_almost_eq(bar.size.y, 55.0, 0.01, "非容器宿主 size 兜底=命中区高")


func test_set_value_silent_no_signal() -> void:
	var bar := _make_bar()
	var received: Array = []
	bar.value_changed.connect(func(r: float) -> void: received.append(r))
	bar.set_value(0.3)
	assert_almost_eq(bar.get_value(), 0.3, 0.001, "set_value 应用值")
	assert_eq(received.size(), 0, "set_value 静默不发信号（宿主初值防回环）")


func test_set_value_clamps() -> void:
	var bar := _make_bar()
	bar.set_value(1.5)
	assert_almost_eq(bar.get_value(), 1.0, 0.001, "上限 clamp 1")
	bar.set_value(-0.2)
	assert_almost_eq(bar.get_value(), 0.0, 0.001, "下限 clamp 0")


# 裁剪式填充：显示宽与 AtlasTexture.region 裁剪区同比例，条体图案不变形。
func test_refresh_fill_region_crops() -> void:
	var bar := _make_bar()
	bar.set_value(0.5)
	var atlas: AtlasTexture = bar._fill.texture as AtlasTexture
	assert_almost_eq(atlas.region.size.x, atlas.atlas.get_width() * 0.5, 0.5, "纹理裁剪区宽 50%")
	assert_almost_eq(bar._fill.offset_right, BAR_W * 0.5, 0.01, "显示宽 95（190×50%）")


func test_click_sets_ratio_and_emits() -> void:
	var bar := _make_bar()
	var received: Array = []
	bar.value_changed.connect(func(r: float) -> void: received.append(r))
	_press(bar, BAR_W * 0.5)
	assert_almost_eq(bar.get_value(), 0.5, 0.001, "点击中点 ratio=0.5")
	assert_eq(received.size(), 1, "交互发 value_changed")
	assert_almost_eq(float(received[0]), 0.5, 0.001, "信号携带新值")


func test_click_clamps_edges() -> void:
	var bar := _make_bar()
	_press(bar, -30.0)
	assert_almost_eq(bar.get_value(), 0.0, 0.001, "点击左侧越界 clamp 0")
	_press(bar, 999.0)
	assert_almost_eq(bar.get_value(), 1.0, 0.001, "点击右侧越界 clamp 1")


func test_drag_motion_updates() -> void:
	var bar := _make_bar()
	_press(bar, 10.0)
	_drag(bar, 150.0)
	assert_almost_eq(bar.get_value(), 150.0 / BAR_W, 0.001, "按住拖动定位 150/190")


func test_same_ratio_no_reemit() -> void:
	var bar := _make_bar()
	bar.set_value(0.5)
	var received: Array = []
	bar.value_changed.connect(func(r: float) -> void: received.append(r))
	_press(bar, BAR_W * 0.5)   # 同值点击
	assert_eq(received.size(), 0, "同值不重发（防宿主重复 set）")
