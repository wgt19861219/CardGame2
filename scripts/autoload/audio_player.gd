extends Node

## 音频播放（View 层 autoload AudioPlayer）— 照源 sound.lua:46 playEffect + BGM 播放。
## 持有 AudioManager（Logic 查询，SoundRes 注册 deo）+ 8 池 SFX + BGM AudioStreamPlayer。
## 资源缺失守卫：ResourceLoader.exists 跳过（源 pcall 吞 C++ 错误，新版静默 + am push_error）。
## 音效路径源 "sound_menu/xx.mp3"（相对 res/）→ res://assets/sound_menu/xx.mp3。
## autoload 脚本不用 class_name（autoload 名即全局，仿 events.gd），依赖类 preload const。
##
## 双通道音频设置（2026-09-19 用户指示「背景音和音效分开设置+音量调节」）：
##   - sfx_switch/bgm_switch 独立开关（播放侧短路，off 不出声不占池；源单 sound_switch 演进）；
##   - sfx_volume/bgm_volume 用户音量走 Music/Sfx 总线（AudioServer 一处生效，含未来新播放器）；
##   - 战斗暂停临时压低走播放器侧 duck_bgm_volume（battle_scene），与总线用户音量两层相乘
##     正交——用户 50% × duck 25% = 实际 12.5%，互不覆盖（原 set_bgm_volume/restore 语义）；
##   - cfg 四键 sfx_on/bgm_on/sfx_volume/bgm_volume；拆分前旧单键 sound_on 自动迁移。
##   - sound_switch 兼容属性（get=双开才开/set=双写）：拆分前测试与旧调用方零改动存活。

const AudioManagerScript = preload("res://scripts/systems/audio_manager.gd")
const SoundResScript = preload("res://scripts/data/sound_res.gd")

const RES_PREFIX: String = "res://assets/"
const SFX_VOLUME: float = 1.0       # 播放器侧基准 0db（实际音量 = 总线用户音量 × 本值）
const BGM_VOLUME: float = 1.0
const SFX_POOL_SIZE: int = 8   # 池大小（源 SimpleAudioEngine 多通道等价；const 免魔法数字）
const SOUND_CFG_PATH: String = "user://audio.cfg"   # 默认路径（应用级设置，源 CCUserDefault 等价）
const MIN_VOLUME_DB: float = -80.0   # linear_to_db(0)=-inf，压到 -80db 下限（听阈下等效静音）
# cfg 实际路径（测试可注入沙箱隔离路径，勿真覆盖用户音频设置——先例 SaveManagerPanel.save_file_path）。
var sound_cfg_path: String = SOUND_CFG_PATH

var am: AudioManager = null
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_cursor: int = 0
var _last_sfx_frame: Dictionary = {}  # rel_path → Engine.get_process_frames()（同帧同名去重，源 sound.lua:30-42）
var bgm_player: AudioStreamPlayer = null
# 双通道默认静音（用户指示 2026-08-30；游戏内系统设置可开，持久化到 audio.cfg）。
var sfx_switch: bool = false    # 音效开关
var bgm_switch: bool = false    # 背景音乐开关
var sfx_volume: float = 1.0     # 0~1 线性（Sfx 总线）
var bgm_volume: float = 1.0     # 0~1 线性（Music 总线）
var _sfx_path_cache: Dictionary = {}  # play_sfx_by_path 缓存（rel_path→AudioStream，避重复 load）
var _bgm_key: String = ""  # 记忆曲 key（含 off 期间记账；源 sound.lua:79 按 audioParam.music 短路）

# 兼容层（2026-09-19 拆分前单开关语义）：get=双开才开（battle_pause 初始图标/旧断言）；set=双写
# （拆分前测试的 sound_switch = true 赋值即"两类全开"，18 处零改动存活）。
var sound_switch: bool:
	get:
		return sfx_switch and bgm_switch
	set(v):
		sfx_switch = v
		bgm_switch = v


func _init() -> void:
	am = AudioManagerScript.new()
	SoundResScript.register_all(am)


func _ready() -> void:
	_load_sound_cfg()   # 测试隔离守卫在方法内（默认路径 + 门禁/编辑器环境 no-op）
	_apply_bus_volumes()   # 无条件应用（测试实例复位 0db 基线，真实实例应用用户音量）
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


# 战斗暂停临时压低 BGM（battle_scene.create_pause_layer 调）。播放器侧 duck 与总线用户
# 音量相乘正交；-80db 下限防 linear_to_db(0) 的 -inf（2026-09-19 原 set_bgm_volume 改名）。
func duck_bgm_volume(ratio: float) -> void:
	if bgm_player != null:
		bgm_player.volume_db = maxf(linear_to_db(ratio), MIN_VOLUME_DB)


func unduck_bgm_volume() -> void:
	duck_bgm_volume(BGM_VOLUME)


# 用户音量（系统设置面板滑条调）→ 总线。clamp 防越界；持久化随写。
func set_sfx_volume(ratio: float) -> void:
	sfx_volume = clampf(ratio, 0.0, 1.0)
	_apply_bus_volume(&"Sfx", sfx_volume)
	_save_sound_cfg()


func set_bgm_volume(ratio: float) -> void:
	bgm_volume = clampf(ratio, 0.0, 1.0)
	_apply_bus_volume(&"Music", bgm_volume)
	_save_sound_cfg()


func _apply_bus_volume(bus_name: StringName, ratio: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return   # 总线缺失兜底（default_bus_layout 未载的异常环境）
	AudioServer.set_bus_volume_db(idx, maxf(linear_to_db(ratio), MIN_VOLUME_DB))


func _apply_bus_volumes() -> void:
	_apply_bus_volume(&"Sfx", sfx_volume)
	_apply_bus_volume(&"Music", bgm_volume)


# 源 sound.lua:46 playEffect(name) — am 查 path → 池播。sfx_switch 关 / 资源缺失 → 跳过。
# UI 音通道：不做同帧去重（照源 playEffect 无去重；连点截断由池化缓解——设计文档三-9）。
func play_sfx(key: String) -> void:
	if not sfx_switch:
		return
	var path: String = am.get_sfx_path(StringName(key))
	if path.is_empty():
		return
	_play_pooled(path)


# "sound/<NAME>_ULT|_DEATH.mp3"）。按相对路径直载（res://assets/<rel_path>）。
# 资源缺失静默跳过；缓存 AudioStream（缺失缓存 null 只查一次）。
# 语音/打击音通道：per-name 同帧去重（源 sound.lua:30-42；三-2 受控偏离：镜像对战同帧同名 2→1 次）。
func play_sfx_by_path(rel_path: String) -> void:
	if not sfx_switch or rel_path == "":
		return
	var frame: int = Engine.get_process_frames()
	if int(_last_sfx_frame.get(rel_path, -1)) == frame:
		return
	_last_sfx_frame[rel_path] = frame
	_play_pooled(rel_path)


# BGM 播放（源 ed.music[chapter]）。同名短路按 _bgm_key 记账值判断（源 :79）；
# 切歌停旧播新（源 playMusic 自动 stopMusic）；loop=true（一审 MAJOR-2）；
# bgm_switch off 期间仍记账+换流不出声（源 :73-98，toggle on 按记忆曲恢复——Task 4）。
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
	if bgm_switch:
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


# 音效开关（源 sound.lua:109-127 turnSoundSwitch 的音效通道拆分）：翻转+持久化+停池中 SFX。
func toggle_sfx() -> void:
	sfx_switch = not sfx_switch
	_save_sound_cfg()
	if not sfx_switch:
		for p in _sfx_pool:
			p.stop()


# 背景音乐开关：翻转+持久化；off pause 保流（供 resume 分支），on 双分支恢复
# （源 :112-121——paused → resume；否则按 _bgm_key 实际 play，off 期间切歌场景，三审 MAJOR-R3）。
func toggle_bgm() -> void:
	bgm_switch = not bgm_switch
	_save_sound_cfg()
	if bgm_switch:
		_resume_bgm()
	elif bgm_player != null and bgm_player.playing:
		bgm_player.stream_paused = true


# 总开关（battle_pause_layer 单按钮）：任一开 → 全关；否则全开（混合态先归零，再按恢复）。
func toggle_all() -> void:
	var target: bool = not (sfx_switch or bgm_switch)
	if target != sfx_switch:
		toggle_sfx()
	if target != bgm_switch:
		toggle_bgm()


# 旧名兼容（battle_pause_layer sound_toggled 历史直连 + 拆分前 toggle 语义用例）。
func toggle_sound() -> void:
	toggle_all()


# 战斗暂停层初始图标：任一通道有声即显示开（混合态不误显关）。
func is_audio_on() -> bool:
	return sfx_switch or bgm_switch


func _resume_bgm() -> void:
	if bgm_player == null:
		return
	if bgm_player.stream_paused:
		bgm_player.stream_paused = false
	elif _bgm_key != "" and bgm_player.stream != null:
		bgm_player.play()


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
	if cfg.load(sound_cfg_path) != OK:
		return
	# 旧单键迁移（2026-09-19 拆分前 sound_on 同管两类）：新键缺失才迁移，防覆盖用户新设置。
	if not cfg.has_section_key("audio", "sfx_on"):
		var legacy: bool = bool(cfg.get_value("audio", "sound_on", false))
		sfx_switch = legacy
		bgm_switch = legacy
	else:
		sfx_switch = bool(cfg.get_value("audio", "sfx_on", false))
		bgm_switch = bool(cfg.get_value("audio", "bgm_on", false))
	sfx_volume = float(cfg.get_value("audio", "sfx_volume", 1.0))
	bgm_volume = float(cfg.get_value("audio", "bgm_volume", 1.0))


func _save_sound_cfg() -> void:
	if _is_test_env_with_default_cfg():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx_on", sfx_switch)
	cfg.set_value("audio", "bgm_on", bgm_switch)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "bgm_volume", bgm_volume)
	cfg.save(sound_cfg_path)
