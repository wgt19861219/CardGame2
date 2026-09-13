extends Control

## 主界面（View 层 Step 4.2）：游戏入口。拖拽地图 + 入口按钮 + 状态栏。
## View 纯 UI：建 UI + 按钮→SceneManager + 状态栏（HudOverlay 手动 refresh，GameData 只读）。
## 业务逻辑在 Logic/Data 层。布局坐标用 mainres.lua 直译（viewport 800x480 = 设计分辨率，
## godot_y = 480 - cocos_y，Task2 迁移贴底基准，无 960x640 补差）。

const MAP_H: float = 480.0   # 设计高 480：grass/mountain 铺满 0~480（Task2 自 640 迁回，图标 godot_y=480-cocos_y）
const BG_INIT_OFFSET: float = -300.0   # 初始视角偏移
const TutorialGuideView = preload("res://scripts/ui/tutorial_guide_view.gd")
const MainButtonFactory = preload("res://scripts/ui/main_button_factory.gd")
const FcaAnimation = preload("res://scripts/ui/fca_animation.gd")
const AtlasSprite = preload("res://scripts/ui/atlas_sprite.gd")
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
const LIGHTNING_POS: Array = [205, 150]       # Godot(205, MAP_H-330=150)；源 mainres.lua:58 lightning ccp(205,330)
const LIGHTNING_GAP: Array = [1.71, 1.71, 1.71, 3, 10]  # gap/loop 序列
const EXCAVATE_WIN_TEXT: String = "占领成功！矿点开始产出资源"     # excavate 战斗胜利 Toast（_maybe_resume_excavate）
const EXCAVATE_LOSE_TEXT: String = "战斗失败，再接再厉"          # excavate 战斗失败 Toast
# 每日签到入口按钮（源 uires.lua:53 dailylogin_pos=ori_pos=ccp(220,392)；statusbar.lua:383 createTitleButton
# t="Sprite" 无 anchor 覆盖 → readnode 用 CCSprite 默认锚(0.5,0.5) 即中心点）。Task2 迁移改源绝对定位：
# godot 中心 = (220, 480-392=88)（800x480 直译）。旧值 (300,108) 是"头像(150,66)+源 delta(150,42)"的
# 相对头像布局；cf2c48f 头像改贴左上角后该相对基准失效，且源本就是绝对坐标，故回归源口径。
const DAILY_BTN_RES: String = "res://assets/ui/alpha/HVGA/main_dailyreward_1.png"
const DAILY_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/main_dailyreward_2.png"
const DAILY_BTN_CENTER: Vector2 = Vector2(220.0, 88.0)
const DAILY_BTN_CONTENT_SCALE: float = 1.28125   # 散图显示=纹理÷CS（main_dailyreward 无 TextureConfig 条目，同 main_status_bar 口径）
const CHAT_BTN_RES: String = "res://assets/ui/alpha/HVGA/chat/chat_entrance_1.png"
const CHAT_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/chat/chat_entrance_2.png"
const CHAT_BTN_CENTER: Vector2 = Vector2(44.0, 334.0)   # 原版实机截图量取(105,681)@1600 反推逻辑系并经实机复测校正
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
	AudioPlayer.play_bgm("map")   # 地图 BGM（源 soundres music.map；战斗进出闭环锚点——设计 2.3）
	var bg := ColorRect.new()
	bg.color = Color(40.0 / 255.0, 100.0 / 255.0, 180.0 / 255.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_build_map()
	_build_hud()
	_refresh_status()
	# _maybe_start_tutorial()   # 2026-08-20 用户指示：一进游戏的新手引导暂不弹（与剧情/解锁公告一并禁用）；恢复取消本行注释即可
	_maybe_resume_excavate()
	_maybe_resume_stage_result()


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
	var pe: Dictionary = GameData.pending_excavate.duplicate()   # Dictionary 引用型：先拷贝再清，否则读值恒默认
	GameData.pending_excavate.clear()
	var won: bool = bool(pe.get("won", false))
	var excavate_id: int = int(pe.get("id", 0))
	var panel := ExcavateMapPanel.new("excavate_map", {})
	panel.setup_panel(GameData.player, BattleRng.new(randi()))
	panel.show_window(self)
	panel.focus_excavate(excavate_id)
	Toast.show_message(EXCAVATE_WIN_TEXT if won else EXCAVATE_LOSE_TEXT)


# pvp 战斗结束改切结算场景（stageDone/stageFailed，2026-09-13 PVP 结算补全，行为对齐源
# stageaccount 调度）；旧 _maybe_resume_pvp（回主菜单 Toast+重开 LadderPanel）退役，pending_pvp 字段已删。


# stage 结算页重试/下一关按钮跨场景重弹（源 doClickReplay/doClickBack → stagedetail、doClickNext →
# WinBackToSelect 选关；PopWindow 跨场景丢失，结算按钮经 settlement_common 存 pending_stage_result）。
func _maybe_resume_stage_result() -> void:
	if GameData.pending_stage_result.is_empty():
		return
	var pr: Dictionary = GameData.pending_stage_result.duplicate()   # 同 excavate/pvp：先拷贝再清
	GameData.pending_stage_result.clear()
	if String(pr.get("target", "")) == "stagedetail":
		var detail := StageDetailPanel.new("stagedetail", {})
		detail.setup_panel(int(pr.get("stage_id", 0)), GameData.player.stage_manager, GameData.player, BattleRng.new(randi()))
		detail.show_window(self)
	else:
		MainSceneEntryRouter.open_stage_select(self)


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
# map = clip Control（800×MAP_H 区），4 容器由 MainMapBuilder 建，MainParallax 按系数横向位移。
# 拖拽：_gui_input 接空地点击（按钮 STOP 吞自己区域），改 top.x → parallax refresh 让 middle/bottom/verytop 跟。
func _build_map() -> void:
	var map := Control.new()
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	map.offset_top = 0.0   # map 延伸到顶（statusbar 透明叠加，露 mountain 天；满 design statusbar 叠加，非独立占区）
	map.offset_bottom = 0.0   # map 满高 480（statusbar 透明叠加，grass 0~480 铺满不被裁）
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
	e_resolved["pos"] = [float(e["pos"][0]), float(e["pos"][1])]   # pos 已是 godot 中心（480-cocos_y 直译，Task2 迁移去掉旧 640 基准 +104 补差）
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
	# 显示尺寸 ÷CS 散图口径（AGENTS.md 2026-08-15）：main_dailyreward 无 TextureConfig 条目；
	# UiButton.make 内 tex_display_size 2026-08-21 Task5 已修正 ÷CS 同口径，此处手算保留
	# （修正前 base×cs 对散图偏大 1.28×，曾手算覆盖）。
	var dl_size: Vector2 = (load(DAILY_BTN_RES) as Texture2D).get_size() / DAILY_BTN_CONTENT_SCALE
	var dl_btn := UiButton.make(DAILY_BTN_RES, DAILY_BTN_PRESS_RES, DAILY_BTN_CENTER)
	dl_btn.size = dl_size
	dl_btn.position = DAILY_BTN_CENTER - dl_size / 2.0
	dl_btn.pressed.connect(func() -> void: MainSceneEntryRouter.open_daily_login(self))
	add_child(dl_btn)
	# 聊天气泡入口（源 statusbar.lua:673-699 createHead chatTurnUp chat_entrance_1/2.png）。
	# 中心照原版实机截图量取 @800 系 (52.5,340)（源 ccp(40,-327) 挂 head 容器的等价落点）；
	# 单机化受控裁剪：源点击开联机聊天面板 getChatPanel，本项目仅保留入口视觉，不接 handler。
	var chat_size: Vector2 = (load(CHAT_BTN_RES) as Texture2D).get_size() / DAILY_BTN_CONTENT_SCALE
	var chat_btn := UiButton.make(CHAT_BTN_RES, CHAT_BTN_PRESS_RES, CHAT_BTN_CENTER)
	chat_btn.size = chat_size
	chat_btn.position = CHAT_BTN_CENTER - chat_size / 2.0
	add_child(chat_btn)


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
	if not VitalityManager.can_buy(p):
		Toast.show_message("今日购买体力次数已达上限")
		return
	if VitalityManager.buy(p):
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
	# 入口路由（联机玩法 pvp/guild/volcano/ranklist 单机裁剪）。
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
			# 时光之穴建筑 → 英雄试炼地图 50005-7，直连无中间弹窗（溯源见 router）。
			MainSceneEntryRouter.open_dungeon_groups(self, "em", [50005, 50006, 50007])
		"exercise":
			# 英雄试炼建筑 → 装备副本地图 50001-4，直连无中间弹窗（溯源见 router）。
			MainSceneEntryRouter.open_dungeon_groups(self, "equip", [50001, 50002, 50003, 50004])
		"estren":
			MainSceneEntryRouter.open_equip_strengthen(self)
		"mailbox":
			MainSceneEntryRouter.open_mailbox(self)
		"guild":
			MainSceneEntryRouter.open_guild(self)   # 公会：联机裁剪，点击 Toast（图鉴走背包专属入口）
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
# 2026-09-12 二轮：占位聚合弹窗退役后此快跳直开 em 地图（FarmChapter 语义，溯源见 router）。
func _open_exercise_panel() -> void:
		MainSceneEntryRouter.open_dungeon_groups(self, "em", [50005, 50006, 50007])
