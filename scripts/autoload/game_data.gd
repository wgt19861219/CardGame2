extends Node

## 全局数据访问（autoload GameData）：ConfigManager + PlayerData + 技能库/技能组单例。
## View 层只读访问数据；Logic 模块依赖（skill_lib/sfx_hook 等）在 _ready 手工注入。
## _ready 加载配置 + 存档（无存档则新游戏）。存档用 SaveManager 原子写。
## 存档调度照源 main.lua：登录首存(:1120) + 脏标 mark_save_dirty + 60s startAutoSave(:761)。
## 测试隔离：check.sh 设 GODOT_TEST_MODE=1（或编辑器内跑 GUT）→ 不 load 不写真实存档，
## 避免 test_main_scene_entry 等 add main_scene 触发登录首存写盘污染下次门禁 _ready load
## （[[gamedata-save-pollutes-user-save-test-isolation]]）。

const PlayerDataScript = preload("res://scripts/data/player_data.gd")
const SaveManagerScript = preload("res://scripts/data/save_manager.gd")
const AUTO_SLOT: String = "auto"
const AUTOSAVE_INTERVAL: float = 60.0

var config: ConfigManager
var player: PlayerData
var skills: SkillLibrary
var skill_groups: SkillGroupData
var last_result: Dictionary = {}  # 最近战斗结算 param（结算场景 _ready 读，等价源 stagefailed/stagedone create(param)；battle 衔接存）
var battle_context: Dictionary = {}  # 战斗上下文（assemble 存 / battle_scene._ready 装配 + _finalize 结算读）
var pending_excavate: Dictionary = {}  # excavate 战斗结束待重弹标记（battle_scene._finalize_excavate 存 / main_scene._ready 读后清）
var pending_pvp: Dictionary = {}  # pvp 战斗结束待重弹标记（battle_scene._finalize_pvp 存 / main_scene._read 读后清）
var _dirty: bool = false  # 脏标（照源 ed.saveDirty，60s Timer 合并刷盘）
var _test_mode: bool = false  # 测试模式（env GODOT_TEST_MODE / 编辑器 hint），隔离真实存档

func _ready() -> void:
	_test_mode = OS.get_environment("GODOT_TEST_MODE") != "" or Engine.is_editor_hint()
	config = ConfigManager.new()
	config.load_all()
	player = _load_or_new_player()
	_wire_player(player)
	skills = SkillLibrary.new(config)
	skill_groups = SkillGroupData.new(config)
	_start_autosave_timer()
	save()


# PlayerData 依赖注入（事件总线/存脏钩子/战斗音效钩子）。_ready 与 apply_imported_save
# （导入存档换 player 实例）共用——换实例必须重挂全部 hook，否则自动存档/音效断链。
func _wire_player(p_pd: PlayerData) -> void:
	p_pd.events = Events.bus  # 注入 EventBus（check_unlocks 升级解锁发 feature_unlocked → main_scene 弹公告）
	# T2 依赖倒置：Logic 写操作自动标脏（buy_vitality/midas exchange 等；缺省 Callable headless 可测）。
	p_pd.save_hook = mark_save_dirty
	p_pd.midas.save_hook = mark_save_dirty
	# T3 依赖倒置：战斗胜/败音效由 Logic 钩子回调（battle_engine 不再直调 AudioPlayer autoload）。
	var sfx: Callable = func(name: String) -> void: AudioPlayer.play_sfx(name)
	p_pd.stage_manager.sfx_hook = sfx; p_pd.stage_manager.skill_lib = skills
	p_pd.crusade_manager.sfx_hook = sfx
	p_pd.excavate.sfx_hook = sfx
	p_pd.ladder.sfx_hook = sfx

func _start_autosave_timer() -> void:
	var timer := Timer.new()
	timer.name = "AutosaveTimer"
	timer.wait_time = AUTOSAVE_INTERVAL
	timer.autostart = true
	timer.timeout.connect(_on_autosave_timeout)
	add_child(timer)

func _on_autosave_timeout() -> void:
	if _dirty:
		save()
		_dirty = false

func _notification(what: int) -> void:
	# 引擎适配补强（源 hello.lua:431 applicationDidEnterBackground 无 saveGame，源疏漏）：
	# 窗口关闭/返回键时强制存盘，避免杀进程丢最多 60s 进度。
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		save()

func _load_or_new_player() -> PlayerData:
	if _test_mode:
		var def_pd := PlayerDataScript.new(config)
		def_pd.apply_default_data()
		return def_pd
	var sm := SaveManagerScript.new()
	var data: Dictionary = sm.load_slot(AUTO_SLOT)
	if data.is_empty():
		var new_pd := PlayerDataScript.new(config)
		new_pd.apply_default_data()
		return new_pd
	return PlayerDataScript.from_dict(data, config)

## 存档到 auto 槽（原子写，治旧版崩溃丢档）。测试模式 no-op（隔离真实存档）。
func save() -> int:
	if _test_mode:
		return OK
	var sm := SaveManagerScript.new()
	return sm.save_slot(AUTO_SLOT, player.to_dict())

## 标脏（照源 ed.saveDirty=true）：等 60s Timer 合并刷盘，避免高频操作每次写盘。
func mark_save_dirty() -> void:
	_dirty = true


## 导入存档落地（save_manager_panel 导入确认后调，源 savemanager.lua:235-251 等价）：
## 从 dict 重建 PlayerData + 重挂全部 hook（_wire_player）+ 立即存盘。返回是否成功。
## 失败（from_dict 异常/存盘错误码非 OK）时 player 保持原实例不动。测试模式存盘 no-op（OK）。
func apply_imported_save(data: Dictionary) -> int:
	var new_pd: PlayerData = PlayerDataScript.from_dict(data, config)
	if new_pd == null:
		return ERR_INVALID_DATA
	player = new_pd
	_wire_player(player)
	return save()
