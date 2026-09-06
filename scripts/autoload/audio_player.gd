extends Node

## 音频播放（View 层 autoload AudioPlayer）— 照源 sound.lua:46 playEffect + BGM 播放。
## 持有 AudioManager（Logic 查询，SoundRes 注册 deo）+ 8 池 SFX + BGM AudioStreamPlayer。
## 资源缺失守卫：ResourceLoader.exists 跳过（源 pcall 吞 C++ 错误，新版静默 + am push_error）。
## 音效路径源 "sound_menu/xx.mp3"（相对 res/）→ res://assets/sound_menu/xx.mp3。
## autoload 脚本不用 class_name（autoload 名即全局，仿 events.gd），依赖类 preload const。

const AudioManagerScript = preload("res://scripts/systems/audio_manager.gd")
const SoundResScript = preload("res://scripts/data/sound_res.gd")

const RES_PREFIX: String = "res://assets/"
const SFX_VOLUME: float = 1.0
const BGM_VOLUME: float = 1.0
const SFX_POOL_SIZE: int = 8   # 池大小（源 SimpleAudioEngine 多通道等价；const 免魔法数字）
const SOUND_CFG_PATH: String = "user://audio.cfg"   # 默认路径（应用级设置，源 CCUserDefault 等价）
# cfg 实际路径（测试可注入沙箱隔离路径，勿真覆盖用户音频设置——先例 SaveManagerPanel.save_file_path）。
var sound_cfg_path: String = SOUND_CFG_PATH

var am: AudioManager = null
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_cursor: int = 0
var _last_sfx_frame: Dictionary = {}  # rel_path → Engine.get_process_frames()（同帧同名去重，源 sound.lua:30-42）
var bgm_player: AudioStreamPlayer = null
# 默认静音（用户指示 2026-08-30；游戏内系统设置可开，持久化到 audio.cfg）。
var sound_switch: bool = false
var _sfx_path_cache: Dictionary = {}  # play_sfx_by_path 缓存（rel_path→AudioStream，避重复 load）
var _bgm_key: String = ""  # 记忆曲 key（含 off 期间记账；源 sound.lua:79 按 audioParam.music 短路）


func _init() -> void:
	am = AudioManagerScript.new()
	SoundResScript.register_all(am)


func _ready() -> void:
	_load_sound_cfg()   # 测试隔离守卫在方法内（默认路径 + 门禁/编辑器环境 no-op）
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.volume_db = linear_to_db(SFX_VOLUME)
		p.bus = "Sfx"
		add_child(p)
		_sfx_pool.append(p)
	bgm_player = AudioStreamPlayer.new()
	bgm_player.volume_db = linear_to_db(BGM_VOLUME)
	bgm_player.bus = "Music"
	add_child(bgm_player)


func set_bgm_volume(ratio: float) -> void:
	if bgm_player != null:
		bgm_player.volume_db = linear_to_db(ratio)


func restore_bgm_volume() -> void:
	set_bgm_volume(BGM_VOLUME)


# 源 sound.lua:46 playEffect(name) — am 查 path → 池播。soundSwitch 关 / 资源缺失 → 跳过。
# UI 音通道：不做同帧去重（照源 playEffect 无去重；连点截断由池化缓解——设计文档三-9）。
func play_sfx(key: String) -> void:
	if not sound_switch:
		return
	var path: String = am.get_sfx_path(StringName(key))
	if path.is_empty():
		return
	_play_pooled(path)


# "sound/<NAME>_ULT|_DEATH.mp3"）。按相对路径直载（res://assets/<rel_path>）。
# 资源缺失静默跳过；缓存 AudioStream（缺失缓存 null 只查一次）。
# 语音/打击音通道：per-name 同帧去重（源 sound.lua:30-42；三-2 受控偏离：镜像对战同帧同名 2→1 次）。
func play_sfx_by_path(rel_path: String) -> void:
	if not sound_switch or rel_path == "":
		return
	var frame: int = Engine.get_process_frames()
	if int(_last_sfx_frame.get(rel_path, -1)) == frame:
		return
	_last_sfx_frame[rel_path] = frame
	_play_pooled(rel_path)


# BGM 播放（源 ed.music[chapter]）。同名短路按 _bgm_key 记账值判断（源 :79）；
# 切歌停旧播新（源 playMusic 自动 stopMusic）；loop=true（一审 MAJOR-2）；
# sound_switch off 期间仍记账+换流不出声（源 :73-98，toggle on 按记忆曲恢复——Task 4）。
func play_bgm(chapter: String) -> void:
	if chapter == _bgm_key:
		return
	_bgm_key = chapter
	if bgm_player == null:
		return
	var path: String = SoundRes.get_music(chapter)
	if path.is_empty():
		return
	var stream: AudioStream = _load_stream(RES_PREFIX + path)
	if stream == null:
		return
	if stream is AudioStreamMP3:
		stream.loop = true
	bgm_player.stop()
	bgm_player.stream = stream
	if sound_switch:
		bgm_player.play()


# 战斗 BGM（源 battle_scene.lua:135-136 "chapter"..stage_info["Chapter ID"] 查表）。
# 变体全在 MUSIC_MAP（chapter-1=arena / chapter-3=crusade / 其余 battle_bgm），代码无 if-else。
# .get 兜底 -1：excavate 装配链可产无该 key 的空 stage_info（三审 MAJOR-R2）。
func play_battle_bgm(stage_info: Dictionary) -> void:
	play_bgm("chapter" + str(int(stage_info.get("Chapter ID", -1))))


func _load_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


# 池轮转播放：游标轮转取 player，覆盖式 set stream + play（快速连音不互截）。
func _play_pooled(rel_path: String) -> void:
	if _sfx_pool.is_empty():
		return
	var stream: AudioStream = null
	if _sfx_path_cache.has(rel_path):
		stream = _sfx_path_cache[rel_path]
	else:
		stream = _load_stream(RES_PREFIX + rel_path)
		_sfx_path_cache[rel_path] = stream
	if stream == null:
		return
	var p: AudioStreamPlayer = _sfx_pool[_sfx_pool_cursor]
	_sfx_pool_cursor = (_sfx_pool_cursor + 1) % _sfx_pool.size()
	p.stream = stream
	p.play()


# ---- 测试访问器（headless 断言池状态；GUT 已实证 playing 属性可靠——设计文档五-1） ----
func get_playing_sfx_count() -> int:
	var n: int = 0
	for p in _sfx_pool:
		if p.playing:
			n += 1
	return n


func has_playing_sfx_stream(res_path: String) -> bool:
	for p in _sfx_pool:
		if p.playing and p.stream != null and p.stream.resource_path == res_path:
			return true
	return false


func has_bgm_stream_path(res_path: String) -> bool:
	return bgm_player != null and bgm_player.stream != null \
		and bgm_player.stream.resource_path == res_path


# 音效开关（源 sound.lua:109-127 turnSoundSwitch）：翻转+持久化+全停/恢复。
# off：BGM pause（保留流，供 resume 分支）+ 停池中 SFX；on：双分支恢复（源 :112-121）——
#   流 paused → resume（stream_paused=true 时 playing 必为 false，不能复合判 playing）；
#   否则按 _bgm_key 实际 play（off 期间切歌场景，三审 MAJOR-R3）。
func toggle_sound() -> void:
	sound_switch = not sound_switch
	_save_sound_cfg()
	if sound_switch:
		_resume_bgm()
	else:
		_pause_all_audio()


func _resume_bgm() -> void:
	if bgm_player == null:
		return
	if bgm_player.stream_paused:
		bgm_player.stream_paused = false
	elif _bgm_key != "" and bgm_player.stream != null:
		bgm_player.play()


func _pause_all_audio() -> void:
	if bgm_player != null and bgm_player.playing:
		bgm_player.stream_paused = true
	for p in _sfx_pool:
		p.stop()


# 测试环境守卫（2026-08-21 踩坑史：门禁 GODOT_TEST_MODE=1 下自建实例 _ready 曾读用户
# audio.cfg 的 sound_on=false，毒化 9 个 SFX 用例短路全挂）：门禁/编辑器内默认路径
# 不读不写真实用户 cfg，防测试 toggle 写脏用户设置；注入沙箱 sound_cfg_path 时放行，
# 供持久化往返用例显式验证。
func _is_test_env_with_default_cfg() -> bool:
	return sound_cfg_path == SOUND_CFG_PATH \
		and (OS.get_environment("GODOT_TEST_MODE") != "" or Engine.is_editor_hint())


func _load_sound_cfg() -> void:
	if _is_test_env_with_default_cfg():
		return
	var cfg := ConfigFile.new()
	if cfg.load(sound_cfg_path) == OK:
		sound_switch = bool(cfg.get_value("audio", "sound_on", false))


func _save_sound_cfg() -> void:
	if _is_test_env_with_default_cfg():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sound_on", sound_switch)
	cfg.save(sound_cfg_path)
