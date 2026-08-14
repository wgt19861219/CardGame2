extends Control

## 主界面（View 层 Step 4.2）：游戏入口。拖拽地图 + 入口按钮 + 状态栏。
## View 纯 UI：建 UI + 按钮→SceneManager + 状态栏（HudOverlay 手动 refresh，GameData 只读）。
## 业务逻辑在 Logic/Data 层。布局坐标复用旧版 mainres.lua（800x480→960x640）。

const MAP_H: float = 640.0   # grass + 按钮 + mountain/cloud/side/lightning 整体下移 104（grass 放屏底 56~536→160~640，图标 godot_y=MAP_H-cocos_y 跟着下移）
const BG_INIT_OFFSET: float = -300.0   # 初始视角偏移
const TutorialGuideView = preload("res://scripts/ui/tutorial_guide_view.gd")
const MainButtonFactory = preload("res://scripts/ui/main_button_factory.gd")
const FcaAnimation = preload("res://scripts/view/battle/fca_animation.gd")
const AtlasSprite = preload("res://scripts/view/battle/atlas_sprite.gd")
const GapLoopAnimator = preload("res://scripts/ui/gap_loop_animator.gd")
const MainMapBuilder = preload("res://scripts/ui/main_map_builder.gd")
const MainParallax = preload("res://scripts/ui/main_parallax.gd")
const ExcavateMapPanel = preload("res://scripts/ui/excavate_map_panel.gd")
# P1-2026-07-10：补全未 preload 的 class_name 类（消除跨脚本强引用）
const BattleRng = preload("res://scripts/systems/battle/battle_rng.gd")
const FeatureLimit = preload("res://scripts/systems/feature_limit.gd")
const PlayerData = preload("res://scripts/data/player_data.gd")
const StageSelectPanel = preload("res://scripts/ui/stage_select_panel.gd")
const ConfigurePanel = preload("res://scripts/ui/configure_panel.gd")
const TutorialManager = preload("res://scripts/systems/tutorial_manager.gd")
# lightning 背景装饰 FCA（非按钮纯装饰；挂 topContainer）
const FCA_LIGHTNING_RES: String = "effect/eff_UI_Main_Lightning"
const FCA_LIGHTNING_ANI: String = "res://assets/anim_frames/effect/eff_UI_Main_Lightning.ani"
const LIGHTNING_POS: Array = [205, 310]       # Godot(205, MAP_H-330=310)
const LIGHTNING_GAP: Array = [1.71, 1.71, 1.71, 3, 10]  # gap/loop 序列
const EXCAVATE_WIN_TEXT: String = "占领成功！矿点开始产出资源"     # excavate 战斗胜利 Toast（_maybe_resume_excavate）
const EXCAVATE_LOSE_TEXT: String = "战斗失败，再接再厉"          # excavate 战斗失败 Toast
# 每日签到入口按钮（dailylogin_pos，head→项目 HEAD_POS(70,52)，delta(150,42)→项目(220,94)）。
const DAILY_BTN_RES: String = "res://assets/ui/alpha/HVGA/main_dailyreward_1.png"
const DAILY_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/main_dailyreward_2.png"
const DAILY_BTN_CENTER: Vector2 = Vector2(220.0, 94.0)
# 15 入口按钮数据外移 main_scene_entries.gd（控 LINT005 ≤400，第九轮 P1-B 入口接线）。
const MainSceneEntries = preload("res://scripts/ui/main_scene_entries.gd")

var _status_refs: Dictionary = {}   # 已废弃，保留兼容（HudOverlay autoload 接管 HUD）
var _tutorial_view: TutorialGuideView = null   # 持引用供 EE/unlock/SU 跨阶段刷新
var _containers: Dictionary                    # MainMapBuilder 建的 4 容器（top/middle/bottom/verytop/sub）
var _parallax: MainParallax
var _drag_active: bool = false                 # 拖拽状态
var _drag_last_x: float = 0.0
var _drag_last_time: int = 0
var _drag_velocity: float = 0.0

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(40.0 / 255.0, 100.0 / 255.0, 180.0 / 255.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_build_map()
	_build_hud()
	_refresh_status()
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
	# 教程信号直连 Events.bus（BaseUI 拆除后无 _event_bus 字段；main_scene 释放时 Godot 自动断连）。
	if not Events.bus.tutorial_step.is_connected(tutorial_try_complete):
		Events.bus.tutorial_step.connect(tutorial_try_complete)
	if not Events.bus.tutorial_switch.is_connected(tutorial_switch_phase):
		Events.bus.tutorial_switch.connect(tutorial_switch_phase)


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


# 薄包装：保 task_query.FAST_ROUTE 反射链（task_panel.has_method + call）不断。
func _open_ladder() -> void:
	MainSceneEntryRouter.open_ladder(self)


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

# 4 层视差地图（createBottom/Middle/Top/VeryTopMap + 自定义拖拽）。
# map = clip Control（960×MAP_H 区），4 容器由 MainMapBuilder 建，MainParallax 按系数横向位移。
# 拖拽：_gui_input 接空地点击（按钮 STOP 吞自己区域），改 top.x → parallax refresh 让 middle/bottom/verytop 跟。
func _build_map() -> void:
	var map := Control.new()
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	map.offset_top = 0.0   # map 延伸到顶（statusbar 透明叠加，露 mountain 天；满 design statusbar 叠加，非独立占区）
	map.offset_bottom = 0.0   # map 满高 640（statusbar 透明叠加，grass 放屏底不被裁）
	map.clip_contents = true
	map.mouse_filter = Control.MOUSE_FILTER_STOP   # 接收空地拖拽（按钮 STOP 吞自己区域）
	map.gui_input.connect(_on_map_gui_input)   # 拖拽连 map（_gui_input 虚函数挂根 Control，map STOP 吞输入致根永不触发）
	add_child(map)
	_containers = MainMapBuilder.new().build(map)
	_parallax = MainParallax.new()
	_parallax.setup(_containers.top, _containers.middle, _containers.bottom, _containers.verytop, float(_containers.get("map_width", 0.0)))
	_parallax.scroll_to(BG_INIT_OFFSET, 0.0)   # refreshMapPos clamp 到 [_map_min_x, 212]
	for e in MainSceneEntries.ENTRIES:
		_entry_host(int(e.get("parent", 1))).add_child(_make_entry(e))
	_add_lightning(_containers.top)   # lightning 装饰加 topContainer


# 按钮挂载容器（p_container = [top, middle, bottom, sub]，parent_index 1-4）。
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


# 拖拽输入（doDragMapTouch）。press→begin+记速基准 / move→top.x+=delta+速度 / release→惯性 end。
func _on_map_gui_input(event: InputEvent) -> void:
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
			_drag_velocity = dx / dt   # 像素/秒
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
	e_resolved["pos"] = [float(e["pos"][0]), float(e["pos"][1]) + 104.0]   # 按钮 godot_y 下移 104 跟随 grass（grass 放屏底 MAP_H=640，ENTRIES pos 旧 536 基准补差 640-536）
	return MainButtonFactory.make_entry(e_resolved, _on_entry_pressed.bind(String(e["id"])), is_locked)


# 功能是否已解锁（team_level 达 PlayerLevel.Unlock 阈值）。
func _is_unlocked(key: StringName) -> bool:
	if GameData.config == null:
		return true   # 测试/未就绪默认解锁（避阻塞）
	var fl := FeatureLimit.new(GameData.config)
	return fl.check_area_unlock(key, GameData.player.team_level)


func _find_entry(entry_id: String) -> Dictionary:
	for e in MainSceneEntries.ENTRIES:
		if String(e["id"]) == entry_id:
			return e
	return {}

## Framework HUD 注入（顶部货币栏 + 右侧快捷栏）— 委托 HudOverlay autoload（全局 CanvasLayer）。
## main 场景 identity=main（含头像 + shortcut 默认展开）。
func _build_hud() -> void:
	HudOverlay.apply_identity("main")
	# 每日签到入口按钮（dailylogin 按钮 clickHandler→showDailyLogin，仅 main 建）。
	var dl_btn := UiButton.make(DAILY_BTN_RES, DAILY_BTN_PRESS_RES, DAILY_BTN_CENTER)
	dl_btn.pressed.connect(func() -> void: MainSceneEntryRouter.open_daily_login(self))
	add_child(dl_btn)


## shortcut 按钮路由（getSCButtonTouchHandler）— HudOverlay 已托管，本方法保留兼容。
func _on_shortcut_open(key: String) -> void:
	pass


## 从 GameData 刷新状态栏（委托 HudOverlay autoload → MainStatusBar）。
func _refresh_status() -> void:
	HudOverlay.refresh()


## 体力加号（vitality_add_icon→showHandyDialog("buyVitality")）。
## 单机化降级为直接买 + Toast（同项目 showHandyDialog→Toast 先例）。
## 先 can_buy_vitality 查 VIP 当日上限，再 buy_vitality 扣 50 钻 +120 体力（钻石不足返 false）。
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

# 薄包装：保 task_query.FAST_ROUTE 反射链（task_panel.has_method + call）不断。
func _open_hero() -> void:
	MainSceneEntryRouter.open_hero(self)


# 薄包装：保 task_query.FAST_ROUTE 反射链 + MainStatusBar.build Callable 不断。
func _open_midas() -> void:
	MainSceneEntryRouter.open_midas(self)

func _on_entry_pressed(entry_id: String) -> void:
	# 未解锁入口点击提示文案，不进功能。
	var entry: Dictionary = _find_entry(entry_id)
	if entry.has("unlock") and not _is_unlocked(StringName(entry["unlock"])):
		var fl := FeatureLimit.new(GameData.config)
		var prompt: String = fl.get_area_unlock_prompt(StringName(entry["unlock"]), GameData.player.team_level)
		Toast.show_message(prompt if prompt != "" else "功能未解锁")
		return
	# 入口路由（联机玩法 pvp/handbook/volcano/ranklist 单机裁剪）。
	match entry_id:
		"pve":
			_open_stage_select()
		"tavern":
			_open_tavern()
		"volcano":
			_open_crusade()
		"shop":
			MainSceneEntryRouter.open_shop(self, 1)
		"sshop":
			MainSceneEntryRouter.open_shop(self, 2)
		"ssshop":
			MainSceneEntryRouter.open_shop(self, 3)
		"starshop":
			MainSceneEntryRouter.open_star_shop(self)
		"defence":
			_open_exercise_panel()
		"exercise":
			_open_exercise_panel()
		"estren":
			MainSceneEntryRouter.open_equip_strengthen(self)
		"mailbox":
			MainSceneEntryRouter.open_mailbox(self)
		"handbook":
			MainSceneEntryRouter.open_handbook(self)   # 第九轮 P1-B2：图鉴入口（自建图鉴面板）
		"excavate":
			MainSceneEntryRouter.open_excavate(self)
		"pvp":
			_open_ladder()
		"ranklist":
			MainSceneEntryRouter.open_ranklist(self, "top_gs")
		_:
			Toast.show_message("「%s」入口待补" % entry_id)


# 薄包装：保 task_query.FAST_ROUTE 反射链（task_panel.has_method + call）不断。
func _open_stage_select() -> void:
	MainSceneEntryRouter.open_stage_select(self)


# 装备合成获取途径跳转：由 HeroDetailEquipSlots.on_equip_craft_jump 经 get_tree().current_scene 反射调（名字不可改）。
func open_stage_select_by_stage(stage_id: int) -> void:
	var mgr := GameData.player.stage_manager
	var rng := BattleRng.new(randi())
	var panel := StageSelectPanel.new("stageselect", {})
	panel.setup_by_stage(mgr, GameData.player, rng, stage_id)
	panel.show_window(self)


# 薄包装：保 task_query.FAST_ROUTE 反射链（task_panel.has_method + call）不断。
func _open_tavern() -> void:
	MainSceneEntryRouter.open_tavern(self)


# 薄包装：保 task_query.FAST_ROUTE 反射链（task_panel.has_method + call）不断。
func _open_crusade() -> void:
	MainSceneEntryRouter.open_crusade(self)


# 薄包装：保 task_query.FAST_ROUTE 反射链（task_panel.has_method + call）不断。
# _open_dungeon_groups 由 ExercisePanel entry_callback 反射调，转给 helper。
func _open_exercise_panel() -> void:
		MainSceneEntryRouter.open_exercise_panel(self, func(m: String, g: Array) -> void:
			MainSceneEntryRouter.open_dungeon_groups(self, m, g))
