extends "res://scenes/base_ui.gd"

## 主界面（View 层 Step 4.2）：游戏入口。拖拽地图 + 入口按钮 + 状态栏。
## View 纯 UI：建 UI + 按钮→SceneManager + 状态栏订阅 data_changed 刷新（GameData 只读）。
## 业务逻辑在 Logic/Data 层。布局坐标复用旧版 mainres.lua（800x480→960x640）。

const MAP_H: float = 536.0
const BAR_H: float = 52.0
# 源 exercise.lua:1506/1509 em→英雄副本 50005-7 / equip→装备副本 50001-4
const EM_GROUPS: Array[int] = [50005, 50006, 50007]
const EQUIP_GROUPS: Array[int] = [50001, 50002, 50003, 50004]
const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"
const TutorialGuideView = preload("res://scripts/ui/tutorial_guide_view.gd")
const MainButtonFactory = preload("res://scripts/ui/main_button_factory.gd")
const FcaAnimation = preload("res://scripts/view/battle/fca_animation.gd")
const AtlasSprite = preload("res://scripts/view/battle/atlas_sprite.gd")
const GapLoopAnimator = preload("res://scripts/ui/gap_loop_animator.gd")
const MainMapBuilder = preload("res://scripts/ui/main_map_builder.gd")
const MainParallax = preload("res://scripts/ui/main_parallax.gd")
const MailPanel = preload("res://scripts/ui/mail_panel.gd")
const ExcavateSearchPanel = preload("res://scripts/ui/excavate_search_panel.gd")
const ExcavateMapPanel = preload("res://scripts/ui/excavate_map_panel.gd")
const AvatarPanel = preload("res://scripts/ui/avatar_panel.gd")
const NameInputPanel = preload("res://scripts/ui/name_input_panel.gd")
const TaskPanel = preload("res://scripts/ui/task_panel.gd")
const RanklistPanel = preload("res://scripts/ui/ranklist_panel.gd")
const MainStatusBar = preload("res://scripts/ui/main_status_bar.gd")
const MidasPanel = preload("res://scripts/ui/midas_panel.gd")
const DailyLoginPanel = preload("res://scripts/ui/daily_login_panel.gd")
const HandbookPanel = preload("res://scripts/ui/handbook_panel.gd")
const LadderPanel = preload("res://scripts/ui/ladder_panel.gd")
# P1-2026-07-10：补全未 preload 的 class_name 类（消除跨脚本强引用）
const BattleRng = preload("res://scripts/systems/battle/battle_rng.gd")
const CrusadePanel = preload("res://scripts/ui/crusade_panel.gd")
const DungeonMapPanel = preload("res://scripts/ui/dungeon_map_panel.gd")
const FeatureLimit = preload("res://scripts/systems/feature_limit.gd")
const PackagePanel = preload("res://scripts/ui/package_panel.gd")
const PlayerData = preload("res://scripts/data/player_data.gd")
const RanklistManager = preload("res://scripts/systems/ranklist_manager.gd")
const ShopManager = preload("res://scripts/systems/shop_manager.gd")
const ShopPanel = preload("res://scripts/ui/shop_panel.gd")
const ShortcutPanel = preload("res://scripts/ui/shortcut_panel.gd")
const StageSelectPanel = preload("res://scripts/ui/stage_select_panel.gd")
const StarShopPanel = preload("res://scripts/ui/star_shop_panel.gd")
const TaskManager = preload("res://scripts/systems/task_manager.gd")
const ConfigurePanel = preload("res://scripts/ui/configure_panel.gd")
const TavernPanel = preload("res://scripts/ui/tavern_panel.gd")
const TutorialManager = preload("res://scripts/systems/tutorial_manager.gd")
# lightning 背景装饰 FCA（照源 mainres.lightning:56-65，button_key 无 → 非按钮纯装饰；createMainFca 加 topContainer）
const FCA_LIGHTNING_RES: String = "effect/eff_UI_Main_Lightning"
const FCA_LIGHTNING_ANI: String = "res://assets/anim_frames/effect/eff_UI_Main_Lightning.ani"
const LIGHTNING_POS: Array = [205, 206]       # 源 ccp(205,330) → Godot(205, MAP_H-330=206)
const LIGHTNING_GAP: Array = [1.71, 1.71, 1.71, 3, 10]  # 源 mainres:60-64 gap/loop
const EXCAVATE_WIN_TEXT: String = "占领成功！矿点开始产出资源"     # excavate 战斗胜利 Toast（_maybe_resume_excavate）
const EXCAVATE_LOSE_TEXT: String = "战斗失败，再接再厉"          # excavate 战斗失败 Toast

# 15 入口按钮（照源 mainres.lua res_pos + button_key）。pos = 源 ccp(左下原点) → Godot(左上原点)：godot_y = MAP_H - cocos_y。
# pos 存源按钮中心点（CCSprite anchorPoint 0.5），_make_entry 转 Button 左上角（pos - BTN_SIZE/2）。
# title 存源 mainres.lua 的 LSTR key（mainres.Campaign / TimeRift / Trials / Crusade 等，zh-CN.lua:4857-4871），_make_entry 显示时 get_lstr 解析中文（照源 main.lua:533 br.title=T(LSTR(...))）。
# scale 照源（defence=0.9 / shop=0.8 / starshop=0.8，其余默认 1；mainres 多数 scale 注释掉）。
# unlock 照源 unlock_keys（defence=COT/pvp=PVP/shop=shop/estren=Enhance/exercise=Exercise/volcano=Crusade/handbook=Guild/excavate=Excavate）。
#   shop/Crusade/Guild/Excavate 不在 PlayerLevel.Unlock 表 → FeatureLimit 默认解锁（照源 playerlimit 设计）+ push_warning（照源 :74 print）。
#   sshop/ssshop 子商店走 PlayerLevel.Unlock（源 shopButtonType summon/into，简化为等级解锁）。
# light 照源 mainres.lightPos + lightSize（[px, py, sw, sh]；py 源 y 上 → Godot y 下翻 Y），press 光效按下显示（源 :592-604）。
# 路由照源 getMainButtonHandler（main.lua:1328-1514），见 _on_entry_pressed。
# starshop 源走 FCA（无 aniType，.abc），本项目 spine/ 无资源 → load_skeleton 失败降级（待 FcaAnimation 接入）。
const ENTRIES: Array = [
	{"id": "pve", "title": "mainres.Campaign", "pos": [625, 401], "parent": 4, "res": "eff_UI_Main_Pve", "touch": [-10, 0], "radius": 100, "light": [0, 19, 230, 350]},
	{"id": "pvp", "title": "mainres.Arean", "pos": [355, 386], "unlock": "PVP", "res": "eff_UI_Main_Pvp", "touch": [-15, 0], "radius": 65, "light": [0, 40, 350, 400]},
	{"id": "shop", "title": "mainres.Merchant", "pos": [1000, 311], "unlock": "shop", "scale": 0.8, "res": "eff_UI_Main_Shop", "gap": [2.75, 2.75, 1.71, 2, 6], "touch": [25, 0], "radius": 68, "light": [0, 50, 300, 300]},
	{"id": "tavern", "title": "mainres.Chests", "pos": [1290, 446], "res": "eff_UI_Main_Tarven", "touch": [0, 13], "radius": 100, "light": [0, 30, 300, 200]},
	{"id": "defence", "title": "mainres.TimeRift", "pos": [1270, 256], "unlock": "COT", "scale": 0.9, "res": "eff_UI_Main_Guard", "touch": [-10, 10], "radius": 65, "light": [0, 40, 300, 300]},
	{"id": "estren", "title": "mainres.Enchanting", "pos": [475, 261], "unlock": "Enhance", "res": "eff_UI_Main_Skill", "touch": [-10, 2], "radius": 85, "light": [0, 60, 250, 250]},
	{"id": "exercise", "title": "mainres.Trials", "pos": [1150, 351], "unlock": "Exercise", "res": "eff_UI_Main_Exercise", "touch": [0, 13], "radius": 85, "light": [0, 35, 200, 250]},
	{"id": "volcano", "title": "mainres.Crusade", "pos": [670, 186], "parent": 2, "unlock": "Crusade", "res": "eff_UI_Main_Volcano", "touch": [0, -30], "radius": 100, "light": [0, 40, 250, 250]},
	{"id": "handbook", "title": "mainres.Guild", "pos": [115, 446], "unlock": "Guild", "res": "eff_UI_Main_Guild", "touch": [0, -5], "radius": 150, "light": [0, 30, 500, 500]},
	{"id": "mailbox", "title": "mainres.Mailbox", "pos": [1000, 466], "res": "eff_UI_Main_Mailbox", "gap": [2, 4, 0, 0, 0], "touch": [0, 40], "radius": 60, "light": [8, 45, 200, 200]},
	{"id": "sshop", "title": "mainres.GoblinMerchant", "pos": [195, 336], "unlock": "sshop", "res": "eff_UI_Main_Shop2", "gap": [1.46, 1.46, 1.46, 1, 6], "touch": [0, 0], "radius": 68, "light": [0, 25, 317, 300]},
	{"id": "ssshop", "title": "mainres.Godfather", "pos": [10, 316], "unlock": "ssshop", "res": "eff_UI_Main_Shop3", "gap": [2, 4, 0, 0, 0], "touch": [0, 0], "radius": 40, "light": [0, 45, 307, 200]},
	{"id": "starshop", "title": "mainres.StarShop", "pos": [82, 296], "scale": 0.8, "res": "eff_UI_Main_Shop_Star", "gap": [1.4583, 1.4583, 2.04167, 3, 10], "touch": [0, 35], "radius": 60, "light": [-6, 30, 150, 180]},
	{"id": "excavate", "title": "mainres.Excavate", "pos": [1450, 346], "unlock": "Excavate", "res": "eff_UI_Main_Treasure", "touch": [0, -50], "radius": 100, "light": [0, 75, 600, 400]},
	{"id": "ranklist", "title": "mainres.Rank", "pos": [860, 386], "res": "eff_UI_Main_Rank", "touch": [0, 30], "radius": 50, "light": [0, 30, 150, 250]},
]

var _status_refs: Dictionary = {}   # MainStatusBar 节点引用（label/head/vip）
var _tutorial_view: TutorialGuideView = null   # 持引用供 EE/unlock/SU 跨阶段刷新
var _containers: Dictionary                    # MainMapBuilder 建的 4 容器（top/middle/bottom/verytop/sub）
var _parallax: MainParallax
var _drag_active: bool = false                 # 拖拽状态（照源 doDragMapTouch dragMode）
var _drag_last_x: float = 0.0
var _drag_last_time: int = 0
var _drag_velocity: float = 0.0

func _ready() -> void:
	_build_map()
	_build_status_bar()
	_build_shortcut()
	_refresh_status()
	setup(Events.bus)
	_maybe_start_tutorial()
	_maybe_resume_excavate()
	_maybe_resume_pvp()


func _maybe_start_tutorial() -> void:
	var pd: Variant = GameData.player
	if pd == null or pd.get("tutorial_manager") == null:
		return
	var tm: TutorialManager = pd.tutorial_manager
	if tm.is_done():
		return
	if tm.state == TutorialManager.State.NOT_STARTED:
		tm.start()
	_tutorial_view = TutorialGuideView.new("tutorial", {})
	_tutorial_view.setup_panel(tm)
	_tutorial_view.show_window(self)
	if _event_bus != null:
		if not _event_bus.tutorial_step.is_connected(tutorial_try_complete):
			_event_bus.tutorial_step.connect(tutorial_try_complete)
		if not _event_bus.tutorial_switch.is_connected(tutorial_switch_phase):
			_event_bus.tutorial_switch.connect(tutorial_switch_phase)


func _maybe_resume_excavate() -> void:
	if GameData.pending_excavate.is_empty():
		return
	var pe: Dictionary = GameData.pending_excavate
	GameData.pending_excavate.clear()
	var won: bool = bool(pe.get("won", false))
	var excavate_id: int = int(pe.get("id", 0))
	var panel := ExcavateMapPanel.new("excavate_map", {})
	panel.setup_panel(GameData.player, BattleRng.new(randi()))
	panel.show_window(self)
	panel.focus_excavate(excavate_id)
	Toast.show_message(EXCAVATE_WIN_TEXT if won else EXCAVATE_LOSE_TEXT)


# pvp 战斗结束回主菜单重弹 LadderPanel（PopWindow 跨场景丢失，battle_scene._finalize_pvp 存 pending_pvp）。
func _maybe_resume_pvp() -> void:
	if GameData.pending_pvp.is_empty():
		return
	var pp: Dictionary = GameData.pending_pvp
	GameData.pending_pvp.clear()
	var reply: Dictionary = pp.get("reply", {})
	var won: bool = bool(pp.get("won", false))
	Toast.show_message(("PVP 胜利！排名 %d 奖励 %d" % [int(reply.get("rank", 0)), int(reply.get("reward", 0))]) if won else "PVP 失败")
	_open_ladder()


## 天梯/PVP 入口（照源 ladder handler :3116 单机 NPC PVP，完整 ladder handler 非联机裁剪）。
func _open_ladder() -> void:
	var panel := LadderPanel.new("ladder", {})
	panel.setup_panel(GameData.player, GameData.player.cm, BattleRng.new(randi()))
	panel.show_window(self)


# EE/unlock/SU 跨阶段切换（条件触发调）：switch steps + 刷新 GuideView 显示新 phase 当前 step。
func tutorial_switch_phase(steps: Array) -> void:
	var pd: Variant = GameData.player
	if pd == null or pd.get("tutorial_manager") == null or _tutorial_view == null:
		return
	var sn_steps: Array[StringName] = []
	for s in steps:
		sn_steps.append(StringName(String(s)))
	pd.tutorial_manager.switch_steps(sn_steps)
	_tutorial_view._refresh()


# 事件驱动推进（EE/unlock/SU UI 动作调）：try_complete + 刷新 GuideView。
func tutorial_try_complete(step: StringName) -> void:
	var pd: Variant = GameData.player
	if pd == null or pd.get("tutorial_manager") == null or _tutorial_view == null:
		return
	if pd.tutorial_manager.try_complete(step):
		_tutorial_view._refresh()

# 4 层视差地图（照源 create:1048-1055 createBottom/Middle/Top/VeryTopMap + doDragMapTouch:116 自定义拖拽）。
# map = clip Control（960×MAP_H 区），4 容器由 MainMapBuilder 建，MainParallax 按系数横向位移。
# 拖拽：_gui_input 接空地点击（按钮 STOP 吞自己区域），改 top.x → parallax refresh 让 middle/bottom/verytop 跟。
func _build_map() -> void:
	var map := Control.new()
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	map.offset_top = BAR_H
	map.offset_bottom = -BAR_H
	map.clip_contents = true
	map.mouse_filter = Control.MOUSE_FILTER_STOP   # 接收空地拖拽（按钮 STOP 吞自己区域）
	add_child(map)
	_containers = MainMapBuilder.new().build(map)
	_parallax = MainParallax.new()
	_parallax.setup(_containers.top, _containers.middle, _containers.bottom, _containers.verytop)
	_parallax.scroll_to(0.0, 0.0)   # 源 setbgOffset(bgOffset=-300) → refreshMapPos clamp 到 0（初始左边界）
	for e in ENTRIES:
		_entry_host(int(e.get("parent", 1))).add_child(_make_entry(e))
	_add_lightning(_containers.top)   # 照源 createMainFca lightning 加 topContainer


# 按钮挂载容器（照源 main.lua:62-68 p_container = [top, middle, bottom, sub]，parent_index 1-4）。
func _entry_host(parent_index: int) -> Control:
	match parent_index:
		2:
			return _containers.middle
		3:
			return _containers.bottom
		4:
			return _containers.sub
		_:
			return _containers.top


# 拖拽输入（照源 doDragMapTouch:116-178）。press→begin+记速基准 / move→top.x+=delta+速度 / release→惯性 end。
func _gui_input(event: InputEvent) -> void:
	if _parallax == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_active = true
			_drag_last_x = event.position.x
			_drag_last_time = Time.get_ticks_usec()
			_drag_velocity = 0.0
			_parallax.on_drag_begin()
		elif _drag_active:
			_drag_active = false
			_parallax.on_drag_end(_drag_velocity)
	elif event is InputEventMouseMotion and _drag_active:
		var cur_x: float = event.position.x
		var now: int = Time.get_ticks_usec()
		var dt: float = (now - _drag_last_time) / 1000000.0
		var dx: float = cur_x - _drag_last_x
		if dt > 0.0:
			_drag_velocity = dx / dt   # 源 speed = mdx/dt（像素/秒）
		_parallax.on_drag_moved(dx)
		_drag_last_x = cur_x
		_drag_last_time = now


func _add_lightning(map: Control) -> void:
	var atlas := AtlasSprite.new()
	if not atlas.load_atlas_from_ani(FCA_LIGHTNING_ANI):
		return
	var fca := FcaAnimation.new()
	if not fca.load_from_ani(FCA_LIGHTNING_RES, atlas):
		return
	map.add_child(fca)
	fca.position = Vector2(float(LIGHTNING_POS[0]), float(LIGHTNING_POS[1]))
	fca.play(GapLoopAnimator.LOOP_ACTION, true)
	var anim := GapLoopAnimator.new()
	map.add_child(anim)
	anim.setup(fca, float(LIGHTNING_GAP[0]), float(LIGHTNING_GAP[1]), float(LIGHTNING_GAP[2]), int(LIGHTNING_GAP[3]), int(LIGHTNING_GAP[4]))

func _make_entry(e: Dictionary) -> Button:
	var is_locked: bool = e.has("unlock") and not _is_unlocked(StringName(e["unlock"]))
	var e_resolved: Dictionary = e.duplicate()
	if GameData.config != null:
		e_resolved["title"] = GameData.config.get_lstr(String(e["title"]))
	return MainButtonFactory.make_entry(e_resolved, _on_entry_pressed.bind(String(e["id"])), is_locked)


# 源 playerlimit.checkAreaUnlock：功能是否已解锁（team_level 达 PlayerLevel.Unlock 阈值）。
func _is_unlocked(key: StringName) -> bool:
	if GameData.config == null:
		return true   # 测试/未就绪默认解锁（避阻塞）
	var fl := FeatureLimit.new(GameData.config)
	return fl.check_area_unlock(key, GameData.player.team_level)


func _find_entry(entry_id: String) -> Dictionary:
	for e in ENTRIES:
		if String(e["id"]) == entry_id:
			return e
	return {}

## 顶部状态栏：等级/金币/钻石/体力（GameData 只读，data_changed 刷新）。
func _build_status_bar() -> void:
	var bar := Panel.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, BAR_H)
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bar)
	_status_refs = MainStatusBar.build(bar, _on_vitality_plus, func() -> void: ConfigurePanel.open(self))


## 右侧 shortcut 快捷栏抽屉（照源 ui/shortcut.lua + framework.lua scCreateBoard/scCreateButtons）。
## 常驻 UI：5 按钮（heroPackage/package/fragment/task/todoList）竖排 + 切换按钮 + 展开收起动画。
func _build_shortcut() -> void:
	var shortcut := ShortcutPanel.new()
	shortcut.setup_panel(true)   # 照源 isShortcutOpen = identity=="main"（主界面默认展开）
	shortcut.open_requested.connect(_on_shortcut_open)
	add_child(shortcut)


## shortcut 按钮路由（照源 framework.lua:556-658 getSCButtonTouchHandler）。
## package/fragment→PackagePanel / heroPackage→hero_scene / task·todoList 桩（源场景未复刻）。
func _on_shortcut_open(key: String) -> void:
	match key:
		"package":
			_open_package("package")
		"fragment":
			_open_package("fragment")
		"heroPackage":
			_open_hero()
		"task":
			_open_task()
		"todoList":
			Toast.show_message("「每日任务」待实现（源 dailyjob）")
		_:
			pass


## 从 GameData 刷新状态栏（委托 MainStatusBar，金币归 HeroManager）。
func _refresh_status() -> void:
	var p: PlayerData = GameData.player
	MainStatusBar.refresh(_status_refs, p.team_level, p.hero_manager.gold, p.diamond, p.vitality, p.vitality_max, p.player_name, p.vip_level, p.avatar)


## 体力加号（照源 statusbar.lua:59-68 vitality_add_icon→showHandyDialog("buyVitality")）。
## 源弹 HandyDialog 确认框，单机化降级为直接买 + Toast（同项目 showHandyDialog→Toast 先例）。
## 先 can_buy_vitality 查 VIP 当日上限（源 dialog.lua:498 canBuyVitality→needHighervip 分支），
## 再 buy_vitality 扣 50 钻 +120 体力（源 handler :1794，钻石不足返 false）。
func _on_vitality_plus() -> void:
	var p: PlayerData = GameData.player
	if not p.can_buy_vitality():
		Toast.show_message("今日购买体力次数已达上限")
		return
	if p.buy_vitality():
		Toast.show_message("购买体力 +120")
		_refresh_status()
	else:
		Toast.show_message("钻石不足")

func _open_hero() -> void:
	SceneManager.change_scene("res://scenes/hero/hero_scene.tscn")


## 头像设置入口（照源 set_avatar handler :1837-1845 配套 UI）。
func _open_avatar() -> void:
	var panel := AvatarPanel.new("avatar", {})
	panel.setup_panel(GameData.player, GameData.config)
	panel.show_window(self)


## 改名入口（照源 set_name handler :1819-1833 配套 UI）。
func _open_name() -> void:
	var panel := NameInputPanel.new("name_input", {})
	panel.setup_panel(GameData.player)
	panel.show_window(self)


## 点石成金入口（照源 statusbar 金币+按钮 doClickMidas → midas 面板）。
func _open_midas() -> void:
	var panel := MidasPanel.new("midas", {})
	panel.setup_panel(GameData.player)
	panel.show_window(self)


## 每日登录奖励入口（照源 ask_daily_login :2096 + login 后自动弹，本项目按钮入口）。
func _open_daily_login() -> void:
	var panel := DailyLoginPanel.new("daily_login", {})
	panel.setup_panel(GameData.player)
	panel.show_window(self)


## 图鉴入口（源 guild 联机裁剪 → 图鉴面板，handbook_manager 已挂 PlayerData）。
func _open_handbook() -> void:
	var panel := HandbookPanel.new("handbook", {})
	panel.setup_panel(GameData.player)
	panel.show_window(self)


## 日常任务入口（照源 job_rewards handler :4071-4110 配套 UI）。
func _open_task() -> void:
	var tm := TaskManager.new()
	var panel := TaskPanel.new("task", {})
	panel.setup_panel(GameData.player, GameData.config, tm)
	panel.show_window(self)


## 排行榜入口（照源 query_ranklist/top_arena :2227-2368 单机 NPC 假榜，P1-2 修正非联机裁剪）。
## ladder 完整 PVP 战斗（:3116-3666）留专项；当前展示 NPC 假榜 + 玩家 rank。
func _open_ranklist(rank_type: String) -> void:
	var rm := RanklistManager.new()
	var panel := RanklistPanel.new("ranklist", {})
	panel.setup_panel(GameData.player, rm, rank_type)
	panel.show_window(self)


## 背包入口（照源 framework shortcut package/fragment 按钮 → ed.ui.package.create(identity)）。
## 第 25 段起由 ShortcutPanel.open_requested 路由调用。
func _open_package(panel_identity: String) -> void:
	var panel := PackagePanel.new(panel_identity, {})
	panel.setup_panel(GameData.config, GameData.player)
	panel.show_window(self)

func _on_entry_pressed(entry_id: String) -> void:
	# 源 main.lua:1306 getAreaUnlockPrompt：未解锁入口点击提示文案，不进功能。
	var entry: Dictionary = _find_entry(entry_id)
	if entry.has("unlock") and not _is_unlocked(StringName(entry["unlock"])):
		var fl := FeatureLimit.new(GameData.config)
		var prompt: String = fl.get_area_unlock_prompt(StringName(entry["unlock"]), GameData.player.team_level)
		Toast.show_message(prompt if prompt != "" else "功能未解锁")
		return
	# 路由照源 getMainButtonHandler（main.lua:1328-1514）。联机玩法（pvp/handbook/volcano/ranklist）单机裁剪。
	match entry_id:
		"pve":
			_open_stage_select()              # 源 :1340 stageselect.create
		"tavern":
			_open_tavern()                    # 源 :1435 tavern.create
		"volcano":
			_open_crusade()                   # 源 :1469 tbc/crusade 联机 → 单机 CrusadePanel
		"shop":
			_open_shop(1)                     # 源 :1366 shop.create()
		"sshop":
			_open_shop(2)                     # 源 :1382 shop.create(2) 地精商人
		"ssshop":
			_open_shop(3)                     # 源 :1394 shop.create(3) 黑市商人
		"starshop":
			_open_star_shop()                 # 源 :1406 shop.create("starshop")
		"defence":
			_open_exercise_panel()            # 源 :1329 exercise.create("em") → 弹试炼入口选择
		"exercise":
			_open_exercise_panel()            # 源 :1447 exercise.create("equip") → 弹试炼入口选择
		"estren":
			Toast.show_message("「装备强化」请从英雄详情进入（需选择英雄）")  # 源 :1424 equipstrengthen.create
		"mailbox":
			_open_mailbox()                                # 源 :1458 mailbox.create
		"handbook":
			_open_handbook()                                # 源 :1413 guild 联机裁剪 → 图鉴面板
		"excavate":
			_open_excavate()                                # 源 :1483 excavate.initialize
		"pvp":
			_open_ladder()                        # 源 :1354 ladder → 单机 NPC PVP（完整 ladder handler）
		"ranklist":
			_open_ranklist("top_gs")              # 源 :1492 ranklist → 单机 NPC 假榜
		_:
			Toast.show_message("「%s」入口待补" % entry_id)


## 战役入口（照源 pve → stageselect.create）：选关 → battle_scene → 结算。
func _open_stage_select() -> void:
	var mgr := GameData.player.stage_manager
	var rng := BattleRng.new(randi())
	var panel := StageSelectPanel.new("stageselect", {})
	panel.setup_panel(mgr, GameData.player, rng)
	panel.show_window(self)


## 装备合成获取途径跳转（照源 doClickGetWay :77-89 → stageselect.createByStage(id)）。
## 由 HeroDetailPanel._on_equip_craft_jump 经 get_tree().current_scene 调用（跳转链避究长 signal 转发）。
func open_stage_select_by_stage(stage_id: int) -> void:
	var mgr := GameData.player.stage_manager
	var rng := BattleRng.new(randi())
	var panel := StageSelectPanel.new("stageselect", {})
	panel.setup_by_stage(mgr, GameData.player, rng, stage_id)
	panel.show_window(self)


## 酒馆入口（照源 tavern → tavern.create）：抽卡面板。
func _open_tavern() -> void:
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(GameData.player, BattleRng.new(randi()))
	panel.show_window(self)


## 远征入口（照源 volcano → crusade；单机化无 tbc 网络，CrusadeManager 程序生成数据）。
func _open_crusade() -> void:
	var panel := CrusadePanel.new("crusade", {})
	panel.setup_panel(GameData.player, BattleRng.new(randi()))
	panel.show_window(self)


## 商店入口（照源 main.lua:1366/1382 shop.create(id)；shop→id=1 普通商人 / goblin→id=2 地精商人）。
## ShopManager 持商品状态，ShopPanel 持 mgr 引用随面板生命周期存活。
func _open_shop(shop_id: int) -> void:
	var mgr := ShopManager.new(GameData.config)
	var panel := ShopPanel.new("shop", {})
	panel.setup_panel(shop_id, mgr, GameData.player, BattleRng.new(randi()))
	panel.show_window(self)


## 星际商店入口（照源 main.lua:1406 shop.create("starshop")；灵魂石货币 8/9/10 + box 产出 equip）。
func _open_star_shop() -> void:
	var mgr := ShopManager.new(GameData.config)
	var panel := StarShopPanel.new("starshop", {})
	panel.setup_panel(mgr, GameData.player, BattleRng.new(randi()))
	panel.show_window(self)


func _open_exercise_panel() -> void:  # 源 exercise.lua createExerciseButton 7 入口
	var panel := ExercisePanel.new()
	panel.set_entry_callback(_open_dungeon_groups)
	add_child(panel)

func _open_dungeon_groups(mode: String, groups: Array) -> void:
	var gi: Array[int] = []
	for g in groups: gi.append(int(g))
	var panel := DungeonMapPanel.new("dungeonMap", {})
	panel.setup_panel(GameData.player, GameData.player.stage_manager, BattleRng.new(randi()), mode, gi); panel.show_window(self)

## 信箱入口（照源 main.lua:1458 mailbox.create → MailPanel 列表）。
func _open_mailbox() -> void:
	var panel := MailPanel.new("mailbox", {})
	panel.setup_panel(GameData.player)
	panel.show_window(self)


## 藏宝地穴入口（照源 main.lua:1483 excavate.initialize + entry:284）。
## excavate_data 空 → ExcavateSearchPanel；非空 → ExcavateMapPanel。
func _open_excavate() -> void:
	if GameData.player.excavate.get_data_list().is_empty():
		var sp := ExcavateSearchPanel.new("excavate", {})
		sp.setup_panel(GameData.player, BattleRng.new(randi()))
		sp.show_window(self)
	else:
		var mp := ExcavateMapPanel.new("excavate_map", {})
		mp.setup_panel(GameData.player, BattleRng.new(randi()))
		mp.show_window(self)


func _on_data_changed(_scope: StringName) -> void:
	_refresh_status()
