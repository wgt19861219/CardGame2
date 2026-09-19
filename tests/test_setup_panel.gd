extends GutTest
# 修复轮（2026-08-20）+ 五轮（2026-09-19 双通道声音设置）测试：
# 装配/双通道开关独立接线/图标随动/音量滑条初值与回调/裁剪守卫（通知系退役）。
# toggle 副作用：翻转对应通道 + 停播（headless 下 BGM 无流守卫安全）；cfg 写入被
# 测试环境守卫拦截不落真实文件——测试先记原值，测完直接赋回（不污染其他测试，
# 先例 test_battle_pause_layer_sound）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_panel() -> SetupPanel:
	var panel := SetupPanel.new("setup_test", {})
	panel.setup_panel(cm)
	add_child_autofree(panel)
	return panel


func _restore_channels(sfx: bool, bgm: bool) -> void:
	AudioPlayer.sfx_switch = sfx
	AudioPlayer.bgm_switch = bgm


func test_panel_assemble() -> void:
	var panel := _make_panel()
	assert_ne(panel.container, null, "container 创建（PopWindow 基类）")
	assert_ne(panel._content, null, "content 锚定层创建（frame 局部坐标系）")
	assert_gt(panel._content.get_child_count(), 2, "frame/title/close/双通道行组装（>2 content 子节点）")


# 初始态照 AudioPlayer 双通道真值（battle_pause_layer 图标反相同款守卫：初始传真值）。
func test_channel_rows_initial_state() -> void:
	var panel := _make_panel()
	var bgm_path: String = SetupPanel.SOUND_ON_RES if AudioPlayer.bgm_switch else SetupPanel.SOUND_OFF_RES
	assert_eq((panel._bgm_btn.texture_normal as Texture2D).resource_path, bgm_path, "BGM 行初始图标照 bgm_switch")
	var sfx_path: String = SetupPanel.SOUND_ON_RES if AudioPlayer.sfx_switch else SetupPanel.SOUND_OFF_RES
	assert_eq((panel._sfx_btn.texture_normal as Texture2D).resource_path, sfx_path, "音效行初始图标照 sfx_switch")
	assert_eq(panel._bgm_bar.get_value(), AudioPlayer.bgm_volume, "BGM 滑条初值照 bgm_volume")
	assert_eq(panel._sfx_bar.get_value(), AudioPlayer.sfx_volume, "音效滑条初值照 sfx_volume")


# 双通道独立（五轮核心断言）：BGM 行点击只翻 bgm_switch，不动 sfx_switch。
func test_bgm_toggle_independent() -> void:
	var panel := _make_panel()
	var sfx_before: bool = AudioPlayer.sfx_switch
	var bgm_before: bool = AudioPlayer.bgm_switch
	panel._bgm_btn.pressed.emit()
	assert_ne(AudioPlayer.bgm_switch, bgm_before, "BGM 行 pressed → toggle_bgm 翻转")
	assert_eq(AudioPlayer.sfx_switch, sfx_before, "BGM 行不动 sfx_switch（双通道独立）")
	var after_path: String = SetupPanel.SOUND_OFF_RES if bgm_before else SetupPanel.SOUND_ON_RES
	assert_eq((panel._bgm_btn.texture_normal as Texture2D).resource_path, after_path, "BGM 图标随开关刷新")
	_restore_channels(sfx_before, not bgm_before)


# 音效行同构：只翻 sfx_switch，不动 bgm_switch。
func test_sfx_toggle_independent() -> void:
	var panel := _make_panel()
	var sfx_before: bool = AudioPlayer.sfx_switch
	var bgm_before: bool = AudioPlayer.bgm_switch
	panel._sfx_btn.pressed.emit()
	assert_ne(AudioPlayer.sfx_switch, sfx_before, "音效行 pressed → toggle_sfx 翻转")
	assert_eq(AudioPlayer.bgm_switch, bgm_before, "音效行不动 bgm_switch（双通道独立）")
	_restore_channels(not sfx_before, bgm_before)


# 两遍翻转回原态：图标回原值（往返一致）。
func test_bgm_toggle_roundtrip() -> void:
	var panel := _make_panel()
	var bgm_before: bool = AudioPlayer.bgm_switch
	panel._bgm_btn.pressed.emit()
	panel._bgm_btn.pressed.emit()
	assert_eq(AudioPlayer.bgm_switch, bgm_before, "两遍翻转回原态")
	var expected_path: String = SetupPanel.SOUND_ON_RES if bgm_before else SetupPanel.SOUND_OFF_RES
	assert_eq((panel._bgm_btn.texture_normal as Texture2D).resource_path, expected_path, "图标回原值")


# 音量滑条接线：value_changed → set_xxx_volume（总线 + 持久化）+ 百分比随动。
func test_volume_bar_wired() -> void:
	var panel := _make_panel()
	panel._bgm_bar.value_changed.emit(0.4)
	assert_almost_eq(AudioPlayer.bgm_volume, 0.4, 0.001, "BGM 滑条 → set_bgm_volume")
	assert_eq(panel._bgm_pct.text, "40%", "BGM 百分比随动")
	panel._sfx_bar.value_changed.emit(0.75)
	assert_almost_eq(AudioPlayer.sfx_volume, 0.75, 0.001, "音效滑条 → set_sfx_volume")
	assert_eq(panel._sfx_pct.text, "75%", "音效百分比随动")
	AudioPlayer.bgm_volume = 1.0   # 复位（总线已改，同步复位防跨用例残留）
	AudioPlayer.sfx_volume = 1.0
	AudioPlayer._apply_bus_volumes()


# 音效图标显示尺寸口径（uieditor scaleSize=55 显示值不 ÷CS，二轮修正守卫）。
func test_sound_icon_display_size() -> void:
	var panel := _make_panel()
	assert_almost_eq(panel._bgm_btn.size.x, 55.0, 0.01, "BGM 图标 55×55（scaleSize 直译）")
	assert_almost_eq(panel._bgm_btn.size.y, 55.0, 0.01, "BGM 图标高 55")
	assert_almost_eq(panel._sfx_btn.size.x, 55.0, 0.01, "音效图标 55×55")
	assert_almost_eq(panel._sfx_btn.size.y, 55.0, 0.01, "音效图标高 55")


# configure 接线守卫（grep 先例）：_on_setup 不再 Toast 占位，改开 SetupPanel。
func test_configure_wiring_guard() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/configure_panel.gd")
	assert_false(src.contains("单机版暂缓"), "Toast 占位文案退役")
	assert_true(src.contains("SetupPanel.open"), "系统设置接 SetupPanel")


# 四轮裁剪守卫（2026-09-18 用户指示「消息提醒去掉+全局提醒去掉」）：通知开关 UI/
# 分隔线/NotifySettings 全退役——源码不得再引用通知系符号。五轮双通道后弹窗 190。
func test_notify_system_retired() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/setup_panel.gd")
	assert_false(src.contains("_add_notice_bar"), "通知栏构建函数退役")
	assert_false(src.contains("_add_switch_grid"), "开关网格构建函数退役")
	assert_false(src.contains("_add_delimiters"), "分隔线构建函数退役")
	assert_almost_eq(SetupPanel.FRAME_RECT.size.y, 190.0, 0.01, "弹窗高 190（title+双通道行，五轮）")
	assert_almost_eq(SetupPanel.FRAME_RECT.position.y, 145.0, 0.01, "垂直居中 (480-190)/2")
	# 五轮实机修正守卫：x 须水平居中=(800-544.53)/2（四轮 208.13 为源 128.13 手误偏右 80 点，
	# 2026-09-19 实机截图量化检测抓出）。
	assert_almost_eq(SetupPanel.FRAME_RECT.position.x, 127.74, 0.01, "水平居中 (800-544.53)/2")
	var hud := FileAccess.get_file_as_string("res://scripts/autoload/hud_overlay.gd")
	assert_false(hud.contains("_on_notify_tick"), "HudOverlay 定时提醒轮询退役")


# frame cap 直译守卫（setup.lua capInsets 直译，防回退 savemanager 错源）。
func test_frame_cap_from_setup_source() -> void:
	var src_text := FileAccess.get_file_as_string("res://scripts/ui/setup_panel.gd")
	assert_true(src_text.contains("FRAME_CAP_RIGHT: int = 14"), "cap R=14（setup.lua cap px÷CS）")
	assert_true(src_text.contains("FRAME_CAP_TOP: int = 12"), "cap T=12（setup.lua cap px÷CS）")
	assert_true(src_text.contains("FRAME_CAP_LEFT: int = 12"), "cap L=12（纹理px15÷CS，防 4dd3b7c 双重÷CS=9 回归）")
	assert_true(src_text.contains("FRAME_CAP_BOTTOM: int = 12"), "cap B=12（纹理px16÷CS；B9 曾泄底边框带致 TILE_FIT 平铺横纹）")
	# 二轮守卫（2026-09-18）：frame 拉伸模式须默认 STRETCH——TILE_FIT 平铺在 tile 边界
	# 产生 1px 采样接缝暗线（实测 4 条）；中间区纯色，平铺与拉伸观感一致但 STRETCH 无缝。
	assert_false(src_text.contains("AXIS_STRETCH_MODE_TILE_FIT"),
		"frame 禁 TILE_FIT 平铺（接缝暗线），保持默认 STRETCH 拉伸")


# 九宫格中间区不得泄漏贴图边框带（纹理 y≥49 为底边框深色带，须划入 B 边框区；
# TILE_FIT 平铺下泄漏即"一横一横"横纹，2026-09-18 修复守卫）。
func test_frame_cap_wraps_border_band() -> void:
	var tex: Texture2D = load(SetupPanel.FRAME_RES) as Texture2D
	# B cap 必须包住底边框带起点（纹理 y=49）：B >= h - 49 = 12
	assert_true(SetupPanel.FRAME_CAP_BOTTOM >= tex.get_height() - 49,
		"B=%d 须包住底边框带（贴图 %dpx 高，边框带 y=49 起）" % [SetupPanel.FRAME_CAP_BOTTOM, tex.get_height()])
	assert_true(SetupPanel.FRAME_CAP_LEFT >= 8, "L 须包住左边框带（贴图 x=0~7）")
	assert_true(SetupPanel.FRAME_CAP_RIGHT >= tex.get_width() - 95, "R 须包住右边框带（x=95 起）")
	assert_true(SetupPanel.FRAME_CAP_TOP >= 6, "T 须包住顶边框带（y=0~5）")
