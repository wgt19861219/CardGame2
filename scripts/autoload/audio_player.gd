extends Node

## 音频播放（View 层 autoload AudioPlayer）— 照源 sound.lua:46 playEffect + BGM 播放。
## 持有 AudioManager（Logic 查询，SoundRes 注册 deo）+ AudioStreamPlayer（sfx/bgm）。
## 资源缺失守卫：ResourceLoader.exists 跳过（源 pcall 吞 C++ 错误，新版静默 + am push_error）。
## 音效路径源 "sound_menu/xx.mp3"（相对 res/）→ res://assets/sound_menu/xx.mp3。
## autoload 脚本不用 class_name（autoload 名即全局，仿 events.gd），依赖类 preload const。

const AudioManagerScript = preload("res://scripts/systems/audio_manager.gd")
const SoundResScript = preload("res://scripts/data/sound_res.gd")

const RES_PREFIX: String = "res://assets/"
const SFX_VOLUME: float = 1.0   # 源 audioParam.effectVolume = 1
const BGM_VOLUME: float = 1.0   # 源 audioParam.musicVolume = 1

var am: AudioManager = null
var sfx_player: AudioStreamPlayer = null
var bgm_player: AudioStreamPlayer = null
var sound_switch: bool = true   # 源 ed.soundSwitch（CCUserDefault 读取，默认 true）
var _sfx_path_cache: Dictionary = {}  # play_sfx_by_path 缓存（rel_path→AudioStream，避重复 load）


func _init() -> void:
	am = AudioManagerScript.new()
	SoundResScript.register_all(am)


func _ready() -> void:
	sfx_player = AudioStreamPlayer.new()
	sfx_player.volume_db = linear_to_db(SFX_VOLUME)
	add_child(sfx_player)
	bgm_player = AudioStreamPlayer.new()
	bgm_player.volume_db = linear_to_db(BGM_VOLUME)
	add_child(bgm_player)


## 源 battle_scene.lua:215 setMusicVolume(ratio)：暂停时降音到 25%。
func set_bgm_volume(ratio: float) -> void:
	if bgm_player != null:
		bgm_player.volume_db = linear_to_db(ratio)


## 源 battle_scene.lua:298 resetMusicVolume：恢复音乐音量。
func restore_bgm_volume() -> void:
	set_bgm_volume(BGM_VOLUME)


# 源 sound.lua:46 playEffect(name) — am 查 path → load → play。soundSwitch 关 / 资源缺失 → 跳过。
func play_sfx(key: String) -> void:
	if not sound_switch or sfx_player == null:
		return
	var path: String = am.get_sfx_path(StringName(key))
	if path.is_empty():
		return
	var stream: AudioStream = _load_stream(RES_PREFIX + path)
	if stream == null:
		return
	sfx_player.stream = stream
	sfx_player.play()


# 源 sound.lua:46 playEffect(name) — 按文件路径播英雄/怪物音效（源 unit.lua:1113/1158
# "sound/<NAME>_ULT|_DEATH.mp3"）。与 play_sfx(key) 区别：key 走 SoundRes 注册表，本方法按相对
# 路径直载（res://assets/<rel_path>）。资源缺失静默跳过（照源文件不存在 + ResourceLoader 守卫）。
# 缓存 AudioStream 避重复 load（缺失资源缓存 null，只查一次）。
func play_sfx_by_path(rel_path: String) -> void:
	if not sound_switch or sfx_player == null or rel_path == "":
		return
	var stream: AudioStream = null
	if _sfx_path_cache.has(rel_path):
		stream = _sfx_path_cache[rel_path]
	else:
		stream = _load_stream(RES_PREFIX + rel_path)
		_sfx_path_cache[rel_path] = stream
	if stream == null:
		return
	sfx_player.stream = stream
	sfx_player.play()


# BGM 播放（源 ed.music[chapter]）。
func play_bgm(chapter: String) -> void:
	if not sound_switch or bgm_player == null:
		return
	var path: String = SoundRes.get_music(chapter)
	if path.is_empty():
		return
	var stream: AudioStream = _load_stream(RES_PREFIX + path)
	if stream == null:
		return
	bgm_player.stream = stream
	bgm_player.play()


func _load_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
