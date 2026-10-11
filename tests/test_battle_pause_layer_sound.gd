extends GutTest
# 暂停层音效开关接线（设计 2.2 定案 1，三审 MAJOR-R1）：
# setup 第三参 dismiss 回调 + 内部自接三信号（sound_toggled→AudioPlayer.toggle_all）；
# 初始态由调用方传真值（AudioPlayer.is_audio_on），治图标反相（二审 M-B）。
# 五轮（2026-09-19）：单开关演进为双通道后，暂停层按钮=总开关（toggle_all 任一开→全关）。

const PauseLayerScript = preload("res://scripts/view/battle/battle_pause_layer.gd")

# 整档备份恢复（2026-10-10）：本套件直改 AudioPlayer 单例并 emit toggle_all（落盘），
# 守卫依赖 GODOT_TEST_MODE——手动裸跑 GUT（无 env）时写脏用户真实 audio.cfg
# （用户"默认静音被去掉"实锤；照 battle.cfg CI 互抹三段式判例，与 test_setup_panel 同款）。
const REAL_AUDIO_CFG := "user://audio.cfg"
var _cfg_backup: String = ""
var _cfg_existed: bool = false


func before_all() -> void:
	_cfg_existed = FileAccess.file_exists(REAL_AUDIO_CFG)
	if _cfg_existed:
		_cfg_backup = FileAccess.get_file_as_string(REAL_AUDIO_CFG)


func after_all() -> void:
	if _cfg_existed:
		var f := FileAccess.open(REAL_AUDIO_CFG, FileAccess.WRITE)
		if f:
			f.store_string(_cfg_backup)
			f.close()
	elif FileAccess.file_exists(REAL_AUDIO_CFG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(REAL_AUDIO_CFG))


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
	AudioPlayer.sfx_switch = true   # 显式「有开」起步（双关时 toggle_all 走全开分支）
	AudioPlayer.bgm_switch = false
	var before_sfx: bool = AudioPlayer.sfx_switch
	var before_bgm: bool = AudioPlayer.bgm_switch
	var layer := PauseLayerScript.new()
	var ui := CanvasLayer.new()
	add_child(ui)
	layer.setup(ui, AudioPlayer.is_audio_on())
	layer.sound_toggled.emit()   # 信号直连 AudioPlayer.toggle_all
	assert_false(AudioPlayer.sfx_switch or AudioPlayer.bgm_switch,
		"sound_toggled → toggle_all（有开即全关，暂停层静音语义）")
	AudioPlayer.sfx_switch = before_sfx   # 精确还原双通道，避免污染其他测试
	AudioPlayer.bgm_switch = before_bgm
	ui.queue_free()
	layer.queue_free()


func test_battle_scene_wiring_guards() -> void:
	# 守卫断言（grep 先例）：battle_scene 不再自接三信号 + BGM 两处接线 + 开战音 battle_begin。
	var scene_src := FileAccess.get_file_as_string("res://scripts/view/battle/battle_scene.gd")
	assert_false(scene_src.contains("exit_requested.connect"), "connect 已下沉 pause layer")
	assert_true(scene_src.contains("AudioPlayer.play_battle_bgm"), "进战斗播战斗 BGM")
	var main_src := FileAccess.get_file_as_string("res://scenes/main_menu/main_scene.gd")
	assert_true(main_src.contains("AudioPlayer.play_bgm(\"map\")"), "主场景播地图 BGM")
	var prep_src := FileAccess.get_file_as_string("res://scripts/ui/battle_prepare_panel.gd")
	assert_true(prep_src.contains("AudioPlayer.play_sfx(\"battle_begin\")"), "开战音 battle_begin")
