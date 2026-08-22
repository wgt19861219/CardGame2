extends GutTest
# 修复轮（2026-08-20）：系统设置面板测试（装配/音效开关接线/图标文案随动）。
# toggle_sound 副作用：翻转全局 sound_switch + 写 user://audio.cfg + BGM 停/恢复
# （headless 下 BGM player 无流，守卫安全）——测试先记原值，测完直接赋回 + 落盘还原
#（test_battle_pause_layer_sound 同款还原方式，不污染其他测试）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_panel() -> SetupPanel:
	var panel := SetupPanel.new("setup_test", {})
	panel.setup_panel(cm)
	add_child_autofree(panel)
	return panel


func _restore_switch(before: bool) -> void:
	AudioPlayer.sound_switch = before
	AudioPlayer._save_sound_cfg()


func test_panel_assemble() -> void:
	var panel := _make_panel()
	assert_ne(panel.container, null, "container 创建（PopWindow 基类）")
	assert_ne(panel._content, null, "content 锚定层创建（frame 局部坐标系）")
	assert_gt(panel._content.get_child_count(), 2, "frame/title/close/音效行/开关网格组装（>2 content 子节点）")


# 初始态照 AudioPlayer.sound_switch（battle_pause_layer 图标反相同款守卫：初始传真值）。
func test_sound_row_initial_state() -> void:
	var panel := _make_panel()
	var expected_path: String = SetupPanel.SOUND_ON_RES if AudioPlayer.sound_switch else SetupPanel.SOUND_OFF_RES
	assert_eq((panel._sound_btn.texture_normal as Texture2D).resource_path, expected_path, "初始图标照全局开关")
	assert_eq(panel._sound_label.text, cm.get_lstr("BATTLE_SCENE.SOUND__ON" if AudioPlayer.sound_switch else "BATTLE_SCENE.SOUND__OFF"), "初始文案照全局开关")


# 点击翻转：全局开关翻转 + 图标/文案随动（照源 doClickSoundButton:129-132 + refreshSoundButton）。
func test_sound_toggle_wired() -> void:
	var panel := _make_panel()
	var before: bool = AudioPlayer.sound_switch
	panel._sound_btn.pressed.emit()
	assert_ne(AudioPlayer.sound_switch, before, "pressed → AudioPlayer.toggle_sound 翻转全局开关")
	var after_path: String = SetupPanel.SOUND_OFF_RES if before else SetupPanel.SOUND_ON_RES
	assert_eq((panel._sound_btn.texture_normal as Texture2D).resource_path, after_path, "图标随开关刷新")
	assert_eq(panel._sound_label.text, cm.get_lstr("BATTLE_SCENE.SOUND__OFF" if before else "BATTLE_SCENE.SOUND__ON"), "文案随开关刷新")
	_restore_switch(before)


# 两遍翻转回原态：图标也回原值（往返一致）。
func test_sound_toggle_roundtrip() -> void:
	var panel := _make_panel()
	var before: bool = AudioPlayer.sound_switch
	panel._sound_btn.pressed.emit()
	panel._sound_btn.pressed.emit()
	assert_eq(AudioPlayer.sound_switch, before, "两遍翻转回原态")
	var expected_path: String = SetupPanel.SOUND_ON_RES if before else SetupPanel.SOUND_OFF_RES
	assert_eq((panel._sound_btn.texture_normal as Texture2D).resource_path, expected_path, "图标回原值")


# configure 接线守卫（grep 先例）：_on_setup 不再 Toast 占位，改开 SetupPanel。
func test_configure_wiring_guard() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/configure_panel.gd")
	assert_false(src.contains("单机版暂缓"), "Toast 占位文案退役")
	assert_true(src.contains("SetupPanel.open"), "系统设置接 SetupPanel")


# 7 通知开关 cell 装配（2026-08-21 二轮：照源 notification.lua 4 排双列全量）。
func test_switch_cells_assembled() -> void:
	var panel := _make_panel()
	assert_eq(panel._switch_btns.size(), 7, "7 个开关按钮（id1-7；r4 右列源隐藏不建）")
	for id: int in range(1, 8):
		assert_ne(panel._switch_btns[id], null, "id%d 开关按钮存在" % id)


# 开关点击翻转 + 图标随动（照源 doClickSwitch:143-147 + refreshSwitchButton）。
func test_switch_toggle_flips_state_and_icon() -> void:
	NotifySettings.cfg_path = "user://notify_setup_test.cfg"
	var panel := _make_panel()
	var before: bool = NotifySettings.get_switch(2)
	var btn: TextureButton = panel._switch_btns[2] as TextureButton
	btn.pressed.emit()
	assert_ne(NotifySettings.get_switch(2), before, "pressed → NotifySettings 开关翻转")
	var expected: String = SetupPanel.SWITCH_OFF_RES if before else SetupPanel.SWITCH_ON_RES
	assert_eq((btn.texture_normal as Texture2D).resource_path, expected, "图标随开关刷新")
	NotifySettings.set_switch(2, before)   # 还原
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://notify_setup_test.cfg"))
	NotifySettings.cfg_path = "user://notify.cfg"


# 音效图标显示尺寸口径（uieditor scaleSize=55 显示值不 ÷CS，二轮修正守卫）。
func test_sound_icon_display_size() -> void:
	var panel := _make_panel()
	assert_almost_eq(panel._sound_btn.size.x, 55.0, 0.01, "音效图标 55×55（scaleSize 直译）")
	assert_almost_eq(panel._sound_btn.size.y, 55.0, 0.01, "音效图标高 55")


# 分隔线×4 守卫（2026-08-21 修复轮：源 delimeter 补全，治列表区「占位感」）。
func test_delimiters_assembled() -> void:
	var panel := _make_panel()
	var count: int = 0
	for c in panel._content.get_children():
		if c is TextureRect and (c as TextureRect).texture != null 				and (c as TextureRect).texture.resource_path == SetupPanel.DELIM_RES:
			count += 1
	assert_eq(count, SetupPanel.DELIM_YS.size(), "分隔线 4 条已装配")


# frame cap 直译守卫（setup.lua capInsets 直译，防回退 savemanager 错源）。
func test_frame_cap_from_setup_source() -> void:
	var src_text := FileAccess.get_file_as_string("res://scripts/ui/setup_panel.gd")
	assert_true(src_text.contains("FRAME_CAP_RIGHT: int = 14"), "cap R=14（setup.lua cap px÷CS）")
	assert_true(src_text.contains("FRAME_CAP_TOP: int = 12"), "cap T=12（setup.lua cap px÷CS）")
