extends CanvasLayer

## autoload HudOverlay（全局 HUD 覆盖层）— 跨场景统一的顶部货币栏 + 快捷栏。
##
## 治方案 A 的固有缺陷：
## - 位置不一致：每个 panel 自挂 HUD，坐标虽同但视觉受 panel 内层影响
## - 嵌套叠加：panel 套 panel 时多份 HUD 堆叠
##
## 方案 B：CanvasLayer 独立于 Control 的 z_index 体系，layer=150 永远盖在所有
## PopWindow（z_index=100）之上。全局唯一 HUD，panel 打开时只切 identity
## （crusade 隐藏 shortcut 等），remove_window 恢复 main。跨场景（main/hero_scene）
## 共享同一份（autoload 不随场景销毁）。
##
## 显隐规则照搬源 framework.lua:989-1004 + statusbar.lua:554-557 + shortcut.lua:260-262。
## battle_scene 源里无 HUD，本项目 apply_identity("battle") 也隐藏整体。
##
## 两套 StatusBar（照源 statusbar.lua:554-557 createHead 仅 main）：
## - main 版：含头像（HEAD_POS x=82~219）+ 货币条
## - 子场景版：仅 3 货币条（x=331~754），左上角空出给 panel CloseBtn（避 CanvasLayer 盖住）
## CanvasLayer 整体高于 Control z_index 体系，故头像区会盖住左上角按钮，子场景必须切精简版。

const MainStatusBar = preload("res://scripts/ui/main_status_bar.gd")
const ShortcutPanel = preload("res://scripts/ui/shortcut_panel.gd")
const ShortcutRouter = preload("res://scripts/ui/shortcut_router.gd")

const HUD_LAYER: int = 150   # 高于 PopWindow z_index=100，低于 Toast layer=200
const STATUS_BAR_H: float = 52.0   # StatusBar 容器高度（照 main_scene 原 BAR_H，货币条绝对坐标在其外）
const MAIN_IDENTITY: String = "main"
const SHORTCUT_HIDDEN_IDENTITIES: Array[String] = ["crusade", "battle"]
const SHORTCUT_HIDDEN_SUFFIXES: Array[String] = ["GWMode"]
const HUD_HIDDEN_IDENTITIES: Array[String] = ["battle", "battleprepare", "handbook"]   # 整体隐藏 HUD（battle_scene/battle_prepare/handbook 源里无 HUD——handbook extends basescene 非 framework，2026-08-18 用户实跑反馈）

var _status_parent_main: Panel = null   # main 版容器（含头像）
var _status_parent_sub: Panel = null    # 子场景版容器（仅货币条）
var _status_refs_main: Dictionary = {}   # main 版 label/bar 引用
var _status_refs_sub: Dictionary = {}    # 子场景版 label/bar 引用
var _shortcut: ShortcutPanel = null
var _current_identity: String = MAIN_IDENTITY
var _built: bool = false


func _ready() -> void:
	layer = HUD_LAYER


## 首次惰性建 HUD（player/cm 从 GameData 取，避 loading_scene 阶段 GameData 未就绪）。
func _build_once() -> void:
	if _built:
		return
	var player: PlayerData = GameData.player
	var cm: ConfigManager = GameData.config
	# main 版：含头像完整版（MainStatusBar.build）。容器 mouse_filter IGNORE 避吞点击。
	_status_parent_main = _create_status_container()
	add_child(_status_parent_main)
	_status_refs_main = MainStatusBar.build(_status_parent_main,
		Callable(self, "_on_vitality_plus"),
		Callable(self, "_on_head_click"),
		Callable(self, "_on_gold_plus"),
		player, cm)
	# 子场景版：仅 3 货币条（build_bars_only，无头像）。左上角空出给 panel CloseBtn。
	_status_parent_sub = _create_status_container()
	add_child(_status_parent_sub)
	_status_refs_sub = MainStatusBar.build_bars_only(_status_parent_sub,
		MainStatusBar.BAR_POS_X, MainStatusBar.BAR_Y,
		Callable(self, "_on_vitality_plus"),
		Callable(self, "_on_gold_plus"))
	# Shortcut：5 按钮抽屉，路由走 ShortcutRouter（parent 用 current_scene 顶层）。
	_shortcut = ShortcutPanel.new()
	_shortcut.setup_panel(true)   # main 默认展开
	_shortcut.open_requested.connect(_on_shortcut_open)
	add_child(_shortcut)
	_refresh_status()
	_built = true


# StatusBar 容器：透明 Panel 占顶部，mouse_filter IGNORE 不吞点击（避盖住 panel 按钮）。
func _create_status_container() -> Panel:
	var p := Panel.new()
	p.set_anchors_preset(Control.PRESET_TOP_WIDE)
	p.custom_minimum_size = Vector2(0, STATUS_BAR_H)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	return p


## 切换场景 identity，应用 StatusBar/Shortcut 显隐规则。
## panel show_window / scene _ready 调本方法；remove_window / 切回 main 调 apply_identity("main")。
func apply_identity(identity: String) -> void:
	_build_once()
	_current_identity = identity
	# 整体隐藏（battle_scene）
	var hide_all: bool = identity in HUD_HIDDEN_IDENTITIES
	# StatusBar 切换：main 用完整版（含头像），子场景用精简版（避头像盖左上角 CloseBtn）。
	var is_main: bool = identity == MAIN_IDENTITY
	_status_parent_main.visible = not hide_all and is_main
	_status_parent_sub.visible = not hide_all and not is_main
	# Shortcut 显隐：用户决策（2026-07-27）只 main 显示，其他界面全隐藏（避各 panel 右上角抽屉叠加）。
	# 源 framework.lua:989-992 非 main 强制展开规则不采纳（本项目 PopWindow 嵌套与源 pushScene 语义不同）。
	_shortcut.visible = not hide_all and is_main
	_refresh_status()


## 当前 identity（battle_prepare 等弹窗进入前记录、退出时恢复用）。
func get_identity() -> String:
	return _current_identity


## 从 GameData 刷新 StatusBar 数值（两套都刷，避切换时显示旧值）。
func refresh() -> void:
	_refresh_status()


## 设置 StatusBar 可见性（hero_scene 点英雄进 hero_detail 时隐藏，避 shade 半透露出）。
func set_status_visible(v: bool) -> void:
	if _status_parent_main != null:
		_status_parent_main.visible = v and _current_identity == MAIN_IDENTITY
	if _status_parent_sub != null:
		_status_parent_sub.visible = v and _current_identity != MAIN_IDENTITY


func _refresh_status() -> void:
	if not _built:
		return
	var p: PlayerData = GameData.player
	if p == null:
		return
	MainStatusBar.refresh(_status_refs_main, p.team_level, p.hero_manager.gold, p.diamond, p.vitality, p.vitality_max, p.player_name, p.vip_level, p.avatar)
	MainStatusBar.refresh(_status_refs_sub, p.team_level, p.hero_manager.gold, p.diamond, p.vitality, p.vitality_max, p.player_name, p.vip_level, p.avatar)


# StatusBar 回调 ──────────────────────────────────────────
# 体力加号（照源 statusbar vitality_add_icon→buyVitality；单机化直接买 + Toast）。
func _on_vitality_plus() -> void:
	var p: PlayerData = GameData.player
	if p == null:
		return
	if not VitalityManager.can_buy(p):
		Toast.show_message("今日购买体力次数已达上限")
		return
	if VitalityManager.buy(p):
		Toast.show_message("购买体力 +120")   # 存档标脏已内聚 buy_vitality（save_hook，T2）
		_refresh_status()
	else:
		Toast.show_message("钻石不足")


# 头像点击 → configure（仅 main identity 生效，子场景无头像）。
func _on_head_click() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	ConfigurePanel.open(scene)


# 金币条整条点击 → midas（照源 statusbar.lua:42-49 registerTitleTouchHandler）。
func _on_gold_plus() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	MainSceneEntryRouter.open_midas(scene)


# shortcut 按钮路由（parent 用 current_scene 顶层，新 panel 挂场景根）。
func _on_shortcut_open(key: String) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	ShortcutRouter.route(scene, key)


# 源 framework.lua:994-1004 shortcut 显隐规则
func _should_hide_shortcut(identity: String) -> bool:
	if identity in SHORTCUT_HIDDEN_IDENTITIES:
		return true
	for suffix in SHORTCUT_HIDDEN_SUFFIXES:
		if identity.ends_with(suffix):
			return true
	return false
