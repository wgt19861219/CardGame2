extends GutTest
# AudioPlayer + SoundRes 测试（照源 sound.lua:46 playEffect + soundres deo/music）。
# autoload 脚本无 class_name，测试 preload 后 new。

const AudioPlayerScript = preload("res://scripts/autoload/audio_player.gd")

func test_sound_res_register_all() -> void:
	var am := AudioManager.new()
	SoundRes.register_all(am)
	assert_true(am.has_sfx(&"common_click_feedback"), "deo common_click_feedback 注册")
	assert_true(am.has_sfx(&"battle_win"), "deo battle_win 注册")
	assert_true(am.has_sfx(&"skill_upgrade_success_gold"), "deo skill_upgrade_success_gold 注册")


func test_sound_res_get_music() -> void:
	assert_eq(SoundRes.get_music("chapter1"), "sound_menu/battle_bgm.mp3", "music chapter1")
	assert_eq(SoundRes.get_music("map"), "installer/stage_select_bgm.mp3", "music map")
	assert_eq(SoundRes.get_music("chapter-1"), "sound_menu/battle_bgm_arena.mp3", "music arena")
	assert_eq(SoundRes.get_music("unknown"), "", "未知 chapter 空")


func test_audio_player_play_sfx_no_crash() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.play_sfx("common_click_feedback")   # 资源在，load + play
	# P1-GUT-5：强化为验证实际播放（stream 已设 + playing=true），非占位 assert_true(true)
	assert_not_null(player.sfx_player.stream, "play_sfx 应设置 stream")
	assert_true(player.sfx_player.playing, "play_sfx 应触发播放")
	player.queue_free()


func test_audio_player_sound_switch_off() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.sound_switch = false
	player.play_sfx("common_click_feedback")   # switch 关 → 跳过
	# P1-GUT-5：强化为验证 switch 关时不播放（stream 未设）
	assert_null(player.sfx_player.stream, "sound_switch off 不应设置 stream")
	player.queue_free()


func test_audio_player_play_bgm_no_crash() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.play_bgm("chapter1")   # battle_bgm.mp3 资源在/不在均守卫
	# P1-GUT-5：强化为验证 bgm 实际播放（资源存在时 stream 已设）
	assert_not_null(player.bgm_player.stream, "play_bgm 应设置 stream（chapter1 资源存在）")
	player.queue_free()


# 源 sound.lua:46 playEffect(name) — play_sfx_by_path 按文件路径播英雄/怪物音效（源 unit.lua:1113/1158）。
func test_play_sfx_by_path_real_resource() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.play_sfx_by_path("sound/AM_ULT.mp3")   # 资源存在（assets/sound/AM_ULT.mp3）
	assert_not_null(player.sfx_player.stream, "真实资源设 stream")
	assert_true(player.sfx_player.playing, "触发播放")
	assert_true(player._sfx_path_cache.has("sound/AM_ULT.mp3"), "缓存已记录")
	player.queue_free()


func test_play_sfx_by_path_missing_resource() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.play_sfx_by_path("sound/NOTEXIST_ULT.mp3")   # 资源缺失 → 静默跳过
	assert_null(player.sfx_player.stream, "缺失资源不设 stream")
	assert_true(player._sfx_path_cache.has("sound/NOTEXIST_ULT.mp3"), "缺失资源也缓存 null（只查一次）")
	assert_null(player._sfx_path_cache["sound/NOTEXIST_ULT.mp3"], "缓存值为 null")
	player.queue_free()


func test_play_sfx_by_path_sound_off() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.sound_switch = false
	player.play_sfx_by_path("sound/AM_ULT.mp3")   # switch 关 → 跳过
	assert_null(player.sfx_player.stream, "sound_switch off 不设 stream")
	assert_false(player._sfx_path_cache.has("sound/AM_ULT.mp3"), "switch off 不缓存")
	player.queue_free()


func test_play_sfx_by_path_empty_path() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.play_sfx_by_path("")   # 空路径 → 跳过
	assert_null(player.sfx_player.stream, "空路径不设 stream")
	player.queue_free()
