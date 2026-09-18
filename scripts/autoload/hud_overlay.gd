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
# 弹窗遮蔽表现（2026-09-08 通用治理，二轮用户观感裁决）：**整体隐藏**。
# 一轮 modulate 0.41 压暗（源黑遮罩 150/255 的乘性等效）被用户复验否定——CanvasLayer(150)
# 恒浮弹窗之上，压暗后货币栏仍"显示在最前"；源"隐约可见"是在弹窗遮罩**之下**、Godot 的
# "隐约可见"是在一切**之上**，同亮度不同层级观感完全不同→隐藏是恒顶层 HUD 语境下的正解
# （打地鼠时代 5 面板隐藏视觉已被用户长期接受）。隐藏后 Control 不参与命中，无需禁点逻辑。
const HUD_HIDDEN_IDENTITIES: Array[String] = ["battle", "battleprepare", "handbook", "ranklist", "equipstrengthen"]   # 整体隐藏 HUD（battle/battleprepare 战斗系场景源无 HUD；handbook extends basescene 非 framework 无 HUD，2026-08-18；ranklist 源 pushScene 全屏场景无 HUD，批 C C1 2026-08-27；equipstrengthen 源 extends basescene pushScene 无 HUD，2026-08-29。均为"场景无 HUD"语义保留——A 族；task/dailyTask 源 popup 挂 scene z=101 盖 HUD 属 B 族弹窗，2026-09-08 通用遮蔽治理退役，走 PopWindow 栈驱动的遮蔽态）
# 通知轮询间隔（秒）：5 定时提醒到点检测（源 localnotify 手机推送 → 单机游戏内 Toast，
# 30s 粒度足够——源时间点粒度为分钟；2026-08-21 SetupPanel 二轮）。
const NOTIFY_TICK_SEC: float = 30.0

var _status_parent_main: Panel = null   # main 版容器（含头像）
var _status_parent_sub: Panel = null    # 子场景版（仅货币条）
var _status_refs_main: Dictionary = {}   # main 版 label/bar 引用
var _status_refs_sub: Dictionary = {}   # 子场景版 label/bar 引用
var _shortcut: ShortcutPanel = null
var _current_identity: String = MAIN_IDENTITY
var _built: bool = false
# 弹窗遮蔽态（2026-09-08 通用治理）：PopWindow._open_stack 栈内存在遮蔽弹窗时置位，
# HUD 层内两块局部黑罩（顶栏区/右侧快捷栏区）盖住 HUD 元素——只盖 HUD 实际区域，
# 不能全屏（CanvasLayer(150) 恒高于默认 canvas 的弹窗，全屏罩会盖住弹窗自身内容）。
var _occluded: bool = false
# 货币自动同步缓存（2026-09-07 抽卡扣费货币栏不刷根修）：扣费/入账点分散在
# Data 层多处（抽卡 consume_tavern_cost/商店 buy·refresh/升星·技能·进阶/技能点
# 购买/卖出/发奖），无全局货币变化信号——_process 每帧对比 int（开销可忽略），
# 变化即 _refresh_status，一处覆盖全部现在与未来的货币变化场景。
# 2026-09-17 加 vitality 对比：GameData 60s 体力恢复接线后，恢复入账同机制刷新 HUD。
var _last_gold: int = -1
var _last_diamond: int = -1
var _last_vitality: int = -1


func _ready() -> void:
	layer = HUD_LAYER
	var timer := Timer.new()
	timer.wait_time = NOTIFY_TICK_SEC
	timer.autostart = true
	timer.timeout.connect(_on_notify_tick)
	add_child(timer)


func _process(_delta: float) -> void:
	if not _built:
		return
	var p: PlayerData = GameData.player
	if p == null:
		return
	if p.hero_manager.gold != _last_gold or p.diamond != _last_diamond or p.vitality != _last_vitality:
		_last_gold = p.hero_manager.gold
		_last_diamond = p.diamond
		_last_vitality = p.vitality
		_refresh_status()


# 定时提醒轮询（源 localnotify data 1/2/4/5/7 定时项）：到点 + 开启 + 当天未推 → Toast。
# GameData.config 未就绪（loading 阶段）静默跳过，下轮 tick 补。
# 时间 + 日期两个 dict 合并（Time.get_time_dict_from_system 只含时分秒，
# 年月日须 get_date_dict_from_system——2026-08-21 实测 fired 写出 "00000000" 抓出）。
func _on_notify_tick() -> void:
	var cm: ConfigManager = GameData.config
	if cm == null:
		return
	var time_dict: Dictionary = Time.get_time_dict_from_system()
	time_dict.merge(Time.get_date_dict_from_system())
	for id: int in NotifySettings.check_time_due(time_dict):
		NotifySettings.mark_fired(id, time_dict)
		Toast.show_message(cm.get_lstr(NotifySettings.entry_fire_lstr(id)))



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
	_apply_visibility()
	_refresh_status()


## 当前 identity（battle_prepare 等弹窗进入前记录、退出时恢复用）。
func get_identity() -> String:
	return _current_identity


## 从 GameData 刷新 StatusBar 数值（两套都刷，避切换时显示旧值）。
func refresh() -> void:
	_refresh_status()


## ── 弹窗遮蔽态（2026-09-08 通用治理）──────────────────────────
## PopWindow._refresh_stack_z 栈重算驱动：栈内存在遮蔽弹窗 → HUD 三容器整体隐藏
## （二轮用户观感裁决；隐藏后 Control 不参与命中=不可点，源 popwindow swallow 等价）。
## 与 identity 正交：identity 管版式（main/sub/全隐），遮蔽管"当前版式是否整体让位"。
func set_occluded(v: bool) -> void:
	if not v and not _built:
		_occluded = false   # 关闭方向无需构建（loading 阶段栈重算可能早于 GameData 就绪）
		return
	_build_once()
	if _occluded == v:
		return
	_occluded = v
	_apply_occlusion()


func is_occluded() -> bool:
	return _occluded


# 应用遮蔽：隐藏时三容器 visible=false（弹窗期间 HUD 整体让位）；解除时按当前
# identity 重放版式显隐（不硬编码恢复值，嵌套弹窗/版式切换中间态天然正确）。
func _apply_occlusion() -> void:
	if _status_parent_main == null:
		return
	if _occluded:
		_status_parent_main.visible = false
		_status_parent_sub.visible = false
		_shortcut.visible = false
	else:
		_apply_visibility()


# 按当前 identity 计算三容器显隐（apply_identity 与解除遮蔽共用；extract 自 apply_identity）。
func _apply_visibility() -> void:
	# 整体隐藏（battle_scene）
	var hide_all: bool = _current_identity in HUD_HIDDEN_IDENTITIES
	# StatusBar 切换：main 用完整版（含头像），子场景用精简版（避头像盖左上角 CloseBtn）。
	var is_main: bool = _current_identity == MAIN_IDENTITY
	_status_parent_main.visible = not hide_all and is_main
	_status_parent_sub.visible = not hide_all and not is_main
	# Shortcut 显隐：用户决策（2026-07-27）只 main 显示，其他界面全隐藏（避各 panel 右上角抽屉叠加）。
	# 源 framework.lua:989-992 非 main 强制展开规则不采纳（本项目 PopWindow 嵌套与源 pushScene 语义不同）。
	var shortcut_visible: bool = not hide_all and is_main
	_shortcut.visible = shortcut_visible
	# 红点重算（2026-09-18 红点体系排查）：源场景制 shortcut 随场景重建即重算（shortcut.lua:253
	# createButtons 末尾 refreshTags）+ 弹窗关闭回调刷（framework.lua:36/:645 task·dailyTask 关闭）；
	# 本项目 HudOverlay 常驻只建一次，identity 流转（回主城/弹窗关闭恢复）与遮蔽解除都过本咽喉——
	# shortcut 重新可见时重算，穿装备/领任务/召唤/战斗计数变化后红点不滞留。
	if shortcut_visible:
		_shortcut.refresh_tags()


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
