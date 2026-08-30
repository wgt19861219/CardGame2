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
	player.sound_switch = true   # 默认已静音（2026-08-30）
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
	player.sound_switch = true   # 默认已静音（2026-08-30）
	player.play_bgm("chapter1")
	assert_not_null(player.bgm_player.stream, "play_bgm 应设置 stream（chapter1 资源存在）")
	player.queue_free()


func test_play_sfx_by_path_real_resource() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.sound_switch = true   # 默认已静音（2026-08-30）
	player.play_sfx_by_path("sound/AM_ULT.mp3")
	assert_true(player.has_playing_sfx_stream("res://assets/sound/AM_ULT.mp3"), "真实资源播")
	assert_true(player._sfx_path_cache.has("sound/AM_ULT.mp3"), "缓存已记录")
	player.queue_free()


func test_play_sfx_by_path_missing_resource() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.sound_switch = true   # 默认已静音（2026-08-30）
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
	player.sound_switch = true   # 默认已静音（2026-08-30）
	player.play_sfx_by_path("")
	assert_eq(player.get_playing_sfx_count(), 0, "空路径不播")
	player.queue_free()


# 池轮转：两个不同音效占用池中不同 player 且都 playing（不互截，治单 player 覆盖缺陷）。
func test_sfx_pool_round_robin_no_truncate() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.sound_switch = true   # 默认已静音（2026-08-30）
	player.play_sfx_by_path("sound/AM_ULT.mp3")
	player.play_sfx_by_path("sound/ZEUS_ULT.mp3")
	assert_true(player.has_playing_sfx_stream("res://assets/sound/AM_ULT.mp3"), "第一个音效仍在播")
	assert_true(player.has_playing_sfx_stream("res://assets/sound/ZEUS_ULT.mp3"), "第二个音效也在播")
	player.queue_free()


# 同帧同名去重（源 sound.lua:30-42 last_played_frame per-name）：同帧同路径只播 1 次。
func test_sfx_dedupe_same_frame_same_path() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.sound_switch = true   # 默认已静音（2026-08-30）
	player.play_sfx_by_path("sound/AM_ULT.mp3")
	player.play_sfx_by_path("sound/AM_ULT.mp3")
	assert_eq(player.get_playing_sfx_count(), 1, "同帧同名去重为 1 次")
	player.queue_free()


# 同帧不同名不去重（三审 MAJOR-5：全局单帧标记会互杀不同音效，per-name 键不会）。
func test_sfx_dedupe_same_frame_diff_path_all_play() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.sound_switch = true   # 默认已静音（2026-08-30）
	player.play_sfx_by_path("sound/AM_ULT.mp3")
	player.play_sfx_by_path("sound/ZEUS_ULT.mp3")
	assert_eq(player.get_playing_sfx_count(), 2, "同帧不同名都播")
	player.queue_free()


# 跨帧后同路径可再播（await 推进 process frame）。第一次占池[0]仍在播，第二次放行占池[1]，
# 故 playing 计数为 2（两个池位各自活跃）——这正是"去重只拦同帧"的可观测证据。
func test_sfx_dedupe_cross_frame_replays() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.sound_switch = true   # 默认已静音（2026-08-30）
	player.play_sfx_by_path("sound/AM_ULT.mp3")
	assert_eq(player.get_playing_sfx_count(), 1, "第一次播（池[0]）")
	await get_tree().process_frame
	player.play_sfx_by_path("sound/AM_ULT.mp3")
	assert_eq(player.get_playing_sfx_count(), 2, "跨帧后同路径再播（占第二池位，非同帧拦截）")
	player.queue_free()


# BGM 循环（一审 MAJOR-2：AudioStreamMP3.loop 默认 false，不设则播一遍停）。
func test_bgm_loop_enabled() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.sound_switch = true   # 默认已静音（2026-08-30）
	player.play_bgm("chapter1")
	var stream := player.bgm_player.stream as AudioStreamMP3
	assert_not_null(stream, "chapter1 资源在")
	assert_true(stream.loop, "BGM 流应 loop=true")
	player.queue_free()


# 同名短路（源 sound.lua:79-81 按 audioParam.music 判断，非播放器当前流）。
func test_bgm_same_key_shortcircuit() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.sound_switch = true   # 默认已静音（2026-08-30）
	player.play_bgm("chapter1")
	var first: AudioStream = player.bgm_player.stream
	player.play_bgm("chapter1")
	assert_eq(player.bgm_player.stream, first, "同 key 第二次调用不换流不重播")
	player.queue_free()


# off 期间记账（源 sound.lua:73-98：soundSwitch=false 仍 stopMusic + 更新曲目记忆，不出声）。
func test_bgm_off_records_key_without_playing() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.sound_switch = false
	player.play_bgm("chapter2")
	assert_eq(player._bgm_key, "chapter2", "off 期间仍记账 _bgm_key")
	assert_false(player.bgm_player.playing, "off 期间不出声")
	player.queue_free()


# 缺 Chapter ID key 不崩且默认 -1=arena 曲（三审 MAJOR-R2：excavate 链可产空 stage_info）。
func test_play_battle_bgm_missing_chapter_key_defaults_arena() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.sound_switch = true   # 默认已静音（2026-08-30）
	player.play_battle_bgm({})
	assert_true(player.has_bgm_stream_path("res://assets/sound_menu/battle_bgm_arena.mp3"),
		"空 stage_info 取默认 chapter-1（arena 曲）")
	player.queue_free()


func test_play_battle_bgm_normal_chapter() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.sound_switch = true   # 默认已静音（2026-08-30）
	player.play_battle_bgm({"Chapter ID": 5})
	assert_true(player.has_bgm_stream_path("res://assets/sound_menu/battle_bgm.mp3"),
		"chapter5 → battle_bgm.mp3")
	player.queue_free()


# toggle on 恢复双分支（三审 MAJOR-R3 照源 sound.lua:112-121）：
# 分支一：曾播且被 pause → resume 保位置续播（源 :114-115 语义；headless 下
# get_playback_position 可靠，审查实证）。
func test_toggle_off_pause_then_on_resume() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.sound_switch = true   # 默认已改静音（2026-08-30），显式回开保 toggle 语义
	player.play_bgm("chapter1")
	player.toggle_sound()   # off：BGM paused
	assert_true(player.bgm_player.stream_paused, "off 后 BGM paused")
	var pos_before: float = player.bgm_player.get_playback_position()
	player.toggle_sound()   # on：resume 分支
	assert_false(player.bgm_player.stream_paused, "on 后恢复播放")
	assert_true(player.bgm_player.playing, "playing")
	assert_almost_eq(player.bgm_player.get_playback_position(), pos_before, 0.05,
		"resume 保位置续播（非从头播）")
	player.queue_free()


# 分支二：off 期间切歌（play_bgm 记账新曲 + stop 清 paused，不出声）→ on 走 play
# 重播分支（stream_paused 已被 stop 清空）。真实产品序列，不经手动 sound_switch 构造。
func test_toggle_on_replays_bgm_after_off_switch() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.sound_switch = true   # 默认已静音（2026-08-30）
	player.play_bgm("chapter1")
	player.toggle_sound()          # off（chapter1 被 pause）
	player.play_bgm("chapter2")    # off 期间切歌：记账新曲+stop（清 paused）不出声
	player.toggle_sound()          # on → 重播分支（paused 已被 stop 清，走 play）
	assert_true(player.bgm_player.playing, "off 期间切歌后 on 应实际重播记忆曲")
	assert_true(player.has_bgm_stream_path("res://assets/sound_menu/battle_bgm.mp3"), "记忆曲=chapter2")
	player.queue_free()


# 持久化（user://audio.cfg，源 CCUserDefault 等价；先例 language_manager lang.cfg——二审 S-4）。
func test_sound_cfg_persist_and_load() -> void:
	var cfg_path := ProjectSettings.globalize_path("user://audio.cfg")
	DirAccess.remove_absolute(cfg_path)   # 清环境
	var player = AudioPlayerScript.new()
	add_child(player)
	player.sound_switch = true   # 默认已静音（2026-08-30）
	var initial: bool = player.sound_switch
	player.toggle_sound()
	var toggled: bool = player.sound_switch
	assert_ne(toggled, initial, "开关已翻转")
	player.queue_free()
	var player2 = AudioPlayerScript.new()
	add_child(player2)
	player2._load_sound_cfg()
	assert_eq(player2.sound_switch, toggled, "新实例读 cfg 继承开关状态")
	player2.queue_free()
	DirAccess.remove_absolute(cfg_path)   # 还原环境，不污染真实用户配置


# 总线布局（二审 m-7）：default_bus_layout.tres 在 res:// 根，headless AudioServer 正常加载。
func test_audio_buses_exist() -> void:
	assert_ne(AudioServer.get_bus_index("Music"), -1, "Music 总线存在")
	assert_ne(AudioServer.get_bus_index("Sfx"), -1, "Sfx 总线存在")


func test_players_assigned_to_buses() -> void:
	var player = AudioPlayerScript.new()
	add_child(player)
	player.sound_switch = true   # 默认已静音（2026-08-30）
	assert_eq(player.bgm_player.bus, "Music", "bgm_player → Music 总线")
	player.play_sfx("common_click_feedback")
	var sfx_bus_ok: bool = false
	for p in player._sfx_pool:
		if p.bus == "Sfx":
			sfx_bus_ok = true
	assert_true(sfx_bus_ok, "SFX 池 → Sfx 总线")
	player.queue_free()


# 兜底清理：任何 toggle 类测试中途失败导致 cfg 残留（sound_on=false 会毒化后续
# 新实例 _ready 的 _load_sound_cfg → play_sfx 全被跳过），after_all 统一清除。
func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://audio.cfg"))
