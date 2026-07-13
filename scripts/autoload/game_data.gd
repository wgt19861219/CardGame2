extends Node

## 全局数据访问（autoload GameData）：ConfigManager + PlayerData + 技能库/技能组单例。
## View 层只读访问数据；Logic 模块仍通过 ModuleRegistry 注入。
## _ready 加载配置 + 存档（无存档则新游戏）。存档用 SaveManager 原子写。

const PlayerDataScript = preload("res://scripts/data/player_data.gd")
const SaveManagerScript = preload("res://scripts/data/save_manager.gd")
const AUTO_SLOT: String = "auto"

var config: ConfigManager
var player: PlayerData
var skills: SkillLibrary
var skill_groups: SkillGroupData
var last_result: Dictionary = {}  # 最近战斗结算 param（结算场景 _ready 读，等价源 stagefailed/stagedone create(param)；battle 衔接存）
var battle_context: Dictionary = {}  # 战斗上下文（assemble 存 / battle_scene._ready 装配 + _finalize 结算读）
var pending_excavate: Dictionary = {}  # excavate 战斗结束待重弹标记（battle_scene._finalize_excavate 存 / main_scene._ready 读后清）
var pending_pvp: Dictionary = {}  # pvp 战斗结束待重弹标记（battle_scene._finalize_pvp 存 / main_scene._ready 读后清）

func _ready() -> void:
	config = ConfigManager.new()
	config.load_all()
	player = _load_or_new_player()
	player.events = Events.bus  # 注入 EventBus（check_unlocks 升级解锁发 feature_unlocked → main_scene 弹公告）
	skills = SkillLibrary.new(config)
	skill_groups = SkillGroupData.new(config)

func _load_or_new_player() -> PlayerData:
	var sm := SaveManagerScript.new()
	var data: Dictionary = sm.load_slot(AUTO_SLOT)
	if data.is_empty():
		var new_pd := PlayerDataScript.new(config)
		new_pd.apply_default_data()   # 源 local_server.lua:44 DEFAULT_DATA 新玩家初始英雄/经济/物品
		return new_pd
	return PlayerDataScript.from_dict(data, config)

## 存档到 auto 槽（原子写，治旧版崩溃丢档）。
func save() -> int:
	var sm := SaveManagerScript.new()
	return sm.save_slot(AUTO_SLOT, player.to_dict())

## 通知 View 刷新（Logic 层改数据后调，触发 EventBus.data_changed）。
func notify_changed(scope: StringName) -> void:
	Events.bus.emit_data_changed(scope)
