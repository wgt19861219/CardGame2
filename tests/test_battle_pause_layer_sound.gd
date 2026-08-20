extends GutTest
# 暂停层音效开关接线（设计 2.2 定案 1，三审 MAJOR-R1）：
# setup 第三参 dismiss 回调 + 内部自接三信号（sound_toggled→AudioPlayer.toggle_sound）；
# 初始态由调用方传真值（AudioPlayer.sound_switch），治图标反相（二审 M-B）。

const PauseLayerScript = preload("res://scripts/view/battle/battle_pause_layer.gd")


func test_setup_takes_sound_on_and_dismiss() -> void:
	var layer := PauseLayerScript.new()
	var ui := CanvasLayer.new()
	add_child(ui)
	var dismissed: Array = []
	layer.setup(ui, false, func() -> void: dismissed.append(1))
	assert_false(layer._sound_on, "初始态取传入真值（false 分支贴 sound_off）")
	assert_eq(dismissed.size(), 0, "尚未 dismiss")
	layer.exit_requested.emit()
	layer.resume_requested.emit()
	assert_eq(dismissed.size(), 2, "exit/resume 都回调 on_dismiss")
	ui.queue_free()
	layer.queue_free()


func test_sound_toggled_flips_audio_player_switch() -> void:
	var before: bool = AudioPlayer.sound_switch
	var layer := PauseLayerScript.new()
	var ui := CanvasLayer.new()
	add_child(ui)
	layer.setup(ui, AudioPlayer.sound_switch)
	layer.sound_toggled.emit()   # 信号直连 AudioPlayer.toggle_sound
	assert_ne(AudioPlayer.sound_switch, before, "sound_toggled 翻转全局开关")
	AudioPlayer.sound_switch = before   # 还原，避免污染其他测试
	AudioPlayer._save_sound_cfg()
	ui.queue_free()
	layer.queue_free()


func test_battle_scene_wiring_guards() -> void:
	# 守卫断言（grep 先例）：battle_scene 不再自接三信号 + BGM 两处接线 + 开战音 battle_begin。
	var scene_src := FileAccess.get_file_as_string("res://scripts/view/battle/battle_scene.gd")
	assert_false(scene_src.contains("exit_requested.connect"), "connect 已下沉 pause layer")
	assert_true(scene_src.contains("AudioPlayer.play_battle_bgm"), "进战斗播战斗 BGM")
	var main_src := FileAccess.get_file_as_string("res://scenes/main_menu/main_scene.gd")
	assert_true(main_src.contains("AudioPlayer.play_bgm(\"map\")"), "主场景播地图 BGM")
	var prep_src := FileAccess.get_file_as_string("res://scripts/view/battle/battle_prepare_panel.gd")
	assert_true(prep_src.contains("AudioPlayer.play_sfx(\"battle_begin\")"), "开战音 battle_begin")
