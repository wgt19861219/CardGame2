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
	assert_eq(SoundRes.get_music("map"), "sound/stage_select_bgm.mp3", "music map（installer 迁移产物 bug 修复）")
	assert_eq(SoundRes.get_music("chapter-1"), "sound_menu/battle_bgm_arena.mp3", "music arena")
	assert_eq(SoundRes.get_music("unknown"), "", "未知 chapter 空")


# 设计文档 2.2：MUSIC_MAP 全 21 条 value + DEO_MAP 全量 value 落盘存在性（防死键/路径断链回归）。
func test_sound_res_all_registered_files_exist() -> void:
	for key in SoundRes.MUSIC_MAP:
		var path: String = String(SoundRes.MUSIC_MAP[key])
		assert_true(ResourceLoader.exists("res://assets/" + path),
			"MUSIC_MAP[%s] 文件存在: %s" % [key, path])
	for key in SoundRes.DEO_MAP:
		var path2: String = String(SoundRes.DEO_MAP[key])
		assert_true(ResourceLoader.exists("res://assets/" + path2),
			"DEO_MAP[%s] 文件存在: %s" % [key, path2])


# 设计文档三-3：common_exp_up 源 nil 禁用，本项目受控偏离启用（资产在 + 调用方守卫就绪）。
func test_common_exp_up_registered() -> void:
	var am := AudioManager.new()
	SoundRes.register_all(am)
	assert_true(am.has_sfx(&"common_exp_up"), "common_exp_up 已注册（受控偏离启用）")
	assert_false(SoundRes.DEO_MAP.has("map_bgm"), "map_bgm 死键已删除")


func test_audio_player_play_sfx_no_crash() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.play_sfx("common_click_feedback")
	assert_true(player.has_playing_sfx_stream("res://assets/sound_menu/common_click_feedback.mp3"),
		"play_sfx 应在池中触发播放")
	player.queue_free()


func test_audio_player_sound_switch_off() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.sound_switch = false
	player.play_sfx("common_click_feedback")
	assert_eq(player.get_playing_sfx_count(), 0, "sound_switch off 不应播放")
	player.queue_free()


func test_audio_player_play_bgm_no_crash() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.play_bgm("chapter1")
	assert_not_null(player.bgm_player.stream, "play_bgm 应设置 stream（chapter1 资源存在）")
	player.queue_free()


func test_play_sfx_by_path_real_resource() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.play_sfx_by_path("sound/AM_ULT.mp3")
	assert_true(player.has_playing_sfx_stream("res://assets/sound/AM_ULT.mp3"), "真实资源播")
	assert_true(player._sfx_path_cache.has("sound/AM_ULT.mp3"), "缓存已记录")
	player.queue_free()


func test_play_sfx_by_path_missing_resource() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.play_sfx_by_path("sound/NOTEXIST_ULT.mp3")
	assert_eq(player.get_playing_sfx_count(), 0, "缺失资源不播")
	assert_true(player._sfx_path_cache.has("sound/NOTEXIST_ULT.mp3"), "缺失资源也缓存 null（只查一次）")
	assert_null(player._sfx_path_cache["sound/NOTEXIST_ULT.mp3"], "缓存值为 null")
	player.queue_free()


func test_play_sfx_by_path_sound_off() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.sound_switch = false
	player.play_sfx_by_path("sound/AM_ULT.mp3")
	assert_eq(player.get_playing_sfx_count(), 0, "sound_switch off 不播")
	assert_false(player._sfx_path_cache.has("sound/AM_ULT.mp3"), "switch off 不缓存")
	player.queue_free()


func test_play_sfx_by_path_empty_path() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.play_sfx_by_path("")
	assert_eq(player.get_playing_sfx_count(), 0, "空路径不播")
	player.queue_free()


# 池轮转：两个不同音效占用池中不同 player 且都 playing（不互截，治单 player 覆盖缺陷）。
func test_sfx_pool_round_robin_no_truncate() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.play_sfx_by_path("sound/AM_ULT.mp3")
	player.play_sfx_by_path("sound/ZEUS_ULT.mp3")
	assert_true(player.has_playing_sfx_stream("res://assets/sound/AM_ULT.mp3"), "第一个音效仍在播")
	assert_true(player.has_playing_sfx_stream("res://assets/sound/ZEUS_ULT.mp3"), "第二个音效也在播")
	player.queue_free()


# 同帧同名去重（源 sound.lua:30-42 last_played_frame per-name）：同帧同路径只播 1 次。
func test_sfx_dedupe_same_frame_same_path() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.play_sfx_by_path("sound/AM_ULT.mp3")
	player.play_sfx_by_path("sound/AM_ULT.mp3")
	assert_eq(player.get_playing_sfx_count(), 1, "同帧同名去重为 1 次")
	player.queue_free()


# 同帧不同名不去重（三审 MAJOR-5：全局单帧标记会互杀不同音效，per-name 键不会）。
func test_sfx_dedupe_same_frame_diff_path_all_play() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.play_sfx_by_path("sound/AM_ULT.mp3")
	player.play_sfx_by_path("sound/ZEUS_ULT.mp3")
	assert_eq(player.get_playing_sfx_count(), 2, "同帧不同名都播")
	player.queue_free()


# 跨帧后同路径可再播（await 推进 process frame）。第一次占池[0]仍在播，第二次放行占池[1]，
# 故 playing 计数为 2（两个池位各自活跃）——这正是"去重只拦同帧"的可观测证据。
func test_sfx_dedupe_cross_frame_replays() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.play_sfx_by_path("sound/AM_ULT.mp3")
	assert_eq(player.get_playing_sfx_count(), 1, "第一次播（池[0]）")
	await get_tree().process_frame
	player.play_sfx_by_path("sound/AM_ULT.mp3")
	assert_eq(player.get_playing_sfx_count(), 2, "跨帧后同路径再播（占第二池位，非同帧拦截）")
	player.queue_free()
