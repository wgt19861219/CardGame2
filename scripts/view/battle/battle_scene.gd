class_name BattleScene
extends Node2D

## 战斗场景主控（View 层）— 照源 battle_scene.lua 核心段翻译（Phase 4）。
## 4 层节点（bg/main/top/ui）+ reset + step（速度倍率 quantize + engine.update + syncActors
## + actor/effect/ui list 推进）+ play_effect_on_scene（FCA .abc 特效）+ actor 桥。

const BattleViewCoords = preload("res://scripts/view/battle/battle_view_coords.gd")
const BattleFloatingBar = preload("res://scripts/view/battle/battle_floating_bar.gd")
const BattleBigHpBar = preload("res://scripts/view/battle/battle_big_hp_bar.gd")
const BattleSpeedButton = preload("res://scripts/view/battle/battle_speed_button.gd")
const BattlePauseLayer = preload("res://scripts/view/battle/battle_pause_layer.gd")
const BattleTimer = preload("res://scripts/view/battle/battle_timer.gd")
const BattleNextButton = preload("res://scripts/view/battle/battle_next_button.gd")
const BattleResourceMarker = preload("res://scripts/view/battle/battle_resource_marker.gd")
const BattleHeroPanel = preload("res://scripts/view/battle/battle_hero_panel.gd")
const BattleAutoButton = preload("res://scripts/view/battle/battle_auto_button.gd")
const BattleActor = preload("res://scripts/view/battle/battle_actor.gd")
const NpcActor = preload("res://scripts/view/battle/npc_actor.gd")
const BattleCameraShake = preload("res://scripts/view/battle/battle_camera_shake.gd")
const BattleSceneFinalizer = preload("res://scripts/view/battle/battle_scene_finalizer.gd")
const BattleResourceAssembler = preload("res://scripts/view/battle/battle_resource_assembler.gd")
const BattleEffect = preload("res://scripts/view/battle/battle_effect.gd")
const BattleWaveAdvancer = preload("res://scripts/view/battle/battle_wave_advancer.gd")

# 源 speedMultiplier（battle_scene.lua:13）{[1]=1,[2]=2,[3]=3,[4]=4}
const SPEED_MULTIPLIERS: Array[int] = [1, 2, 3, 4]
const STAGE_DONE_PATH: String = "res://scenes/battle/stage_done_scene.tscn"      # 胜利结算场景
const STAGE_FAILED_PATH: String = "res://scenes/battle/stage_failed_scene.tscn"  # 失败结算场景
const MAIN_SCENE_PATH: String = "res://scenes/main_menu/main_scene.tscn"         # 主菜单（excavate 战斗结束回）
const ExcavateBattle = preload("res://scripts/systems/excavate_battle.gd")
const LadderBattle = preload("res://scripts/systems/ladder_battle.gd")
const MAX_TICKS: int = 6000  # 战斗最大帧数（防死循环；≥ time_limit(90s)×fps(60)=5400，覆盖 engine 自然 timeout）

signal battle_exited
signal next_wave_requested

var engine: Variant = null
var cm: Variant = null
var background_layer: Node2D = null
var main_layer: Node2D = null
var top_layer: Node2D = null
var ui_layer: CanvasLayer = null
var actor_list: Array = []        # BattleActor 实例（源 actor_list）
var effect_list: Array = []       # 源 effect_list（effect/popup/loot 后续）
var ui_list: Array = []           # 源 ui_list（hero_panel/hp_bar 后续）
var speed_state: int = 1          # 源 curSpeedState（1-4）
var pause_locks: Dictionary = {}  # P1-17：源 pause_locks 多 reason 字典
var is_paused: bool = false       # pause_locks.values().has(true) 缓存（调用点内联算，源 :777-780 any）
var last_sync_tick: int = -1      # 源 lastSync（syncActors tick 去重）
var speed_btn: Variant = null     # 源 speedBtn（battle_scene.lua:1239）
var return_btn: Variant = null    # 源 return_btn（:1189 pausebtn）
var pause_layer: Variant = null   # 源 pauseLayer（:219）
var timer: Variant = null         # 源 self.timer（:1349）
var next_btn: Variant = null      # 源 next_btn（:1199）
var battle_info: Dictionary = {}  # 源 battle_info（resetUI Wave ID 等装配依赖）
var wave_mark: Variant = null     # 源 wave_mark（:1292）
var gold_marker: Variant = null   # 源 goldmarker（:1310）
var loot_marker: Variant = null   # 源 lootmarker（:1326）
var heroes_panel: Control = null   # 源 heroes_panel（resetUI :1284）
var _hero_panels: Dictionary = {} # unit→HeroPanel（源 unit.heroPanel 波次复用，scene dict 避改 BattleUnit）
var auto_combat: bool = false     # 源 auto_combat（reset :118 ed.config.localMode，单机化默认 false）
var auto_btn: Variant = null      # 源 auto_btn（:1252）
var _camera: Camera2D = null       # 源 CCDirector 全局相机（CameraShake 震动用）
var _shake_tween_x: Tween = null
var _shake_tween_y: Tween = null
var frames: int = 0
var _battle_context: Dictionary = {}  # GameData.battle_context 快照（_ready 读 / _finalize 读）
var _finalized: bool = false          # 结算去重（防 _process 重复切场景）
var _ticks_left: int = MAX_TICKS      # 战斗 tick 上限（防死循环）


func setup(p_engine: Variant, p_cm: Variant, p_battle_info: Variant = null) -> void:
	engine = p_engine
	cm = p_cm
	if p_battle_info is Dictionary:
		battle_info = p_battle_info
	_create_layers()
	reset_state()
	# 源 nextBtnTapHandler → scene:nextBattle 闭环（scene 自接信号切波，照源 :431 ed.scene:nextBattle）
	if not next_wave_requested.is_connected(_on_next_wave_requested):
		next_wave_requested.connect(_on_next_wave_requested)


func _create_layers() -> void:
	for child in get_children():
		child.queue_free()
	background_layer = Node2D.new()
	background_layer.name = "Background"
	add_child(background_layer)
	main_layer = Node2D.new()
	main_layer.name = "Main"
	add_child(main_layer)
	top_layer = Node2D.new()
	top_layer.name = "Top"
	add_child(top_layer)
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)
	_camera = Camera2D.new()   # 源 CCDirector 全局相机（CameraShake 震动用）
	add_child(_camera)
	# Node2D 层（actor/背景）需 Camera2D current 才在 viewport 渲染；CanvasLayer(UI) 独立不需。
	# 仅运行时入树后激活（GUT 测试 scene 不入树，跳过）。
	if _camera.is_inside_tree():
		_camera.make_current()


# 源 reset（:47-178）核心状态清空（4 层节点 + UI 装配后续会话补）
func reset_state() -> void:
	for a in actor_list:
		if a is Node:
			a.queue_free()
	actor_list.clear()
	effect_list.clear()
	for u in ui_list:
		if u is Node:
			u.queue_free()
	ui_list.clear()
	frames = 0
	last_sync_tick = -1
	# 源 reset :148-164 — Boss hpLayer!=0 装 BigHpBar + viewCamp(player) isHero 装 hero_panel
	if engine != null:
		_create_heroes_panel()   # 源 resetUI :1283-1287 heroes_panel @70,5
		for unit in engine.unit_list:
			if int(unit.hp_layer) != 0:
				add_big_blood_panel(unit)
			# 源 :154-158 viewCamp(player) isHero → addHeroPanel
			if int(unit.camp) == BattleEngine.CAMP_PLAYER and bool(unit.is_hero()):
				add_hero_panel(unit)
	# 源 resetUI（:1184-1389）speedBtn 装配（:1235-1250）；其余按钮（return/next/auto/timer）后续里程碑补
	_create_speed_button()
	_create_return_button()   # 源 resetUI :1188-1192 returnBtn
	_create_timer()           # 源 resetUI :1341-1387 timer
	_create_next_button()     # 源 resetUI :1198-1206 nextBtn
	_create_auto_button()     # 源 resetUI :1207-1257 auto_btn（pve stars<3 默认隐藏）
	# 源 resetUI :1289-1339 wave_mark + goldmarker/lootmarker（需 battle_info，pve/act/guildInstance）
	if not battle_info.is_empty():
		_create_wave_mark()
		_create_resource_markers()
		_create_background()


# 源 reset :101-111 background（battle_info["Background Pic"] → Sprite2D add background_layer）。
func _create_background() -> void:
	for child in background_layer.get_children():
		child.queue_free()
	var bg_name := String(battle_info.get("Background Pic", ""))
	if bg_name.is_empty():
		return
	var bg_path := "res://assets/ui/alpha/HVGA/" + bg_name
	if not ResourceLoader.exists(bg_path):
		push_warning("[BattleScene] 背景图缺失: " + bg_path)
		return
	var bg_tex := load(bg_path) as Texture2D
	var bg_sprite := Sprite2D.new()
	bg_sprite.texture = bg_tex
	bg_sprite.centered = false   # 源 setAnchorPoint(ccpZero) → 左上锚点
	bg_sprite.position = Vector2.ZERO   # 源 setPosition(ccpZero)
	bg_sprite.flip_h = bool(battle_info.get("H Flip", false))   # 源 :105-108
	background_layer.add_child(bg_sprite)


func set_speed_state(s: int) -> void:
	speed_state = clampi(s, 1, SPEED_MULTIPLIERS.size())


# 源 update（:765-861）核心循环。名 step 避与 CanvasItem.update 混淆；_process 运行时自动调。
func step(dt: float) -> void:
	# 源 :767-775 速度倍率 quantize（>1x 时对齐 tick 整数倍，避免 4x 抖动）
	if speed_state > 1:
		var speed: int = SPEED_MULTIPLIERS[speed_state - 1]
		var raw_speed_dt: float = minf(dt, 0.1) * float(speed)
		var num_ticks: int = int(round(raw_speed_dt / BattleEngine.TICK_INTERVAL))
		if num_ticks < 1:
			num_ticks = 1
		dt = float(num_ticks) * BattleEngine.TICK_INTERVAL
	if is_paused or engine == null:
		return
	engine.update(dt)
	frames += 1
	_sync_actors()
	_advance_actor_list(dt)
	_advance_effect_list(dt)
	_advance_ui_list(dt)
	_update_timer()


func _ready() -> void:
	# View 接入：从 GameData.battle_context 自动装配（stage_select_panel 选关后存入）。
	# setup 后 _process 驱动 engine.update，结束时 _finalize_battle 切结算。
	if engine == null and not GameData.battle_context.is_empty():
		_battle_context = GameData.battle_context
		var eng: BattleEngine = _battle_context["engine"]
		var info: Dictionary = _battle_context["battle_info"]
		setup(eng, GameData.config, info)


func _process(delta: float) -> void:
	if engine == null or _finalized:
		return
	step(delta)
	_ticks_left -= 1
	# 源 battle 结束条件：engine.running=false / stage_ended；加 _ticks_left 防死循环。
	if (not bool(engine.running) or bool(engine.stage_ended)) or _ticks_left <= 0:
		_finalize_battle()


## 战斗结束结算（View 接入闭环）：mode 分流委托 BattleSceneFinalizer。
func _finalize_battle() -> void:
	_finalized = true
	if _battle_context.is_empty():
		SceneManager.change_scene(STAGE_FAILED_PATH)
		return
	var mode: String = String(_battle_context.get("mode", "stage"))
	if mode == "excavate":
		BattleSceneFinalizer.finalize_excavate(self)
		return
	if mode == "pvp":
		BattleSceneFinalizer.finalize_pvp(self)
		return
	BattleSceneFinalizer.finalize_stage(self)


# 源 syncActors（:559-591）：每 tick 为无 actor 的存活单位创建 actor + 入场标记。
func _sync_actors() -> void:
	if last_sync_tick == int(engine.ticks):
		return
	last_sync_tick = int(engine.ticks)
	for unit in engine.foreach_alive_unit(BattleEngine.CAMP_BOTH):
		var actor: Variant = unit.actor
		if actor == null:
			var new_actor: BattleActor = _create_actor(unit)
			if new_actor:
				unit.actor = new_actor
				new_actor.in_scene = true
				_add_actor(new_actor)
		elif not actor.in_scene:
			# 波次切换 reparent（源 :570-580，interp 重置后续补）
			_add_actor(actor)
			actor.in_scene = true
	NpcActor.sync_actors(self)   # 源 :582-589 foreachNpc → NpcActorCreate（A-npc Phase 4 装配）


func _create_actor(unit: Variant) -> BattleActor:
	var actor := BattleActor.new()
	actor.setup(unit, cm, ui_layer)
	return actor


# 源 addActor（:509-519）：actor 入 actor_list + 节点挂 main_layer + 速度倍率同步 puppet。
func _add_actor(actor: BattleActor) -> void:
	actor_list.append(actor)
	main_layer.add_child(actor)
	# 源 :513-517 curSpeedState>1 时 puppet.setActionSpeeder（puppet 速度器后续会话补）


# 源 actor_list 推进（:791-812）：存活 actor update_view + terminated 移除（双指针压缩）。
func _advance_actor_list(dt: float) -> void:
	var n: int = 0
	for i in range(actor_list.size()):
		var actor: Variant = actor_list[i]   # Variant：actor_list 混装 BattleActor+NpcActor（源 :791 统一推进）
		if actor.model != null and not bool(actor.model.terminated):
			actor.update_view(dt)
			actor_list[n] = actor
			n += 1
		else:
			actor.queue_free()
	actor_list.resize(n)


# 源 effect_list 推进（:813-832）：effect.update + terminated 移除。
func _advance_effect_list(dt: float) -> void:
	var n: int = 0
	for i in range(effect_list.size()):
		var effect: Variant = effect_list[i]
		if effect.has_method("update"):
			effect.update(dt)
		if not bool(effect.is_terminated()):
			effect_list[n] = effect
			n += 1
		else:
			if effect is Node:
				effect.queue_free()
	effect_list.resize(n)


# 源 battle_scene.lua:889-903 playEffectOnScene — 创建 FCA 特效节点并挂到场景层。
# 源 battle_scene.lua:889-903 playEffectOnScene — 创建 FCA 特效节点并挂到场景层。
func play_effect_on_scene(effect_name: String, origin: Vector2, scale: float = 1.0, height: float = 0.0, zorder: int = 0) -> void:
	var effect: Variant = null
	var battle_effect := BattleEffect.create(effect_name)  # 照源 createFcaNode
	if battle_effect != null:
		battle_effect.play()
		effect = battle_effect
	else:
		effect = BattleEffect.FallbackEffect.new(Node2D.new(), 1.0)  # 降级
	var n: Node2D = effect.get_node()
	n.position = BattleViewCoords.to_view_position(origin.x, origin.y, height); n.scale = Vector2(scale, scale)
	n.z_index = -int(origin.y)  # 源 :899 setZOrder(-origin[2])
	(background_layer if zorder < 0 else (main_layer if zorder == 0 else top_layer)).add_child(n)  # 源 :728-741
	effect_list.append(effect)


# 源 ui_list 推进（:847-858）：ui.update + terminated 移除。本轮空（hero_panel/hp_bar 后续）。
func _advance_ui_list(dt: float) -> void:
	var n: int = 0
	for i in range(ui_list.size()):
		var ui: Variant = ui_list[i]
		if ui.has_method("update"):
			ui.update(dt)
		var _term: Variant = ui.get("terminated")
		if _term == null or not bool(_term):
			ui_list[n] = ui
			n += 1
		else:
			if ui is Node:
				ui.queue_free()
	ui_list.resize(n)


# 源 addBigBloodPanel（:541-546）：Boss 多血段血条挂 ui_layer 固定 (375,440) + 入 ui_list。
func add_big_blood_panel(unit: Variant) -> void:
	var panel: BattleBigHpBar = BattleBigHpBar.create(unit, _calculate_big_hp_length())
	ui_layer.add_child(panel)
	panel.position = Vector2(375.0, 440.0)   # 源 :544
	ui_list.append(panel)


# 源 resetUI（:1235-1250）speedBtn 装配：setPosition(735,120) + registerScriptTapHandler。
# 初始档同步当前 speed_state（源从 CCUserDefault 持久化，单机化默认 1）。
func _create_speed_button() -> void:
	if speed_btn != null:
		speed_btn.queue_free()
	var btn := BattleSpeedButton.new()
	btn.setup(speed_state)
	btn.speed_changed.connect(_on_speed_changed)
	ui_layer.add_child(btn)
	speed_btn = btn


# 源 speedBtnHandler（:1052-1060）：setSpeedState + 同步所有 actor puppet 动画速度。
func _on_speed_changed(state: int) -> void:
	set_speed_state(state)
	var spd: float = float(SPEED_MULTIPLIERS[state - 1])
	for actor in actor_list:
		if actor.puppet != null and actor.puppet.has_method("set_speed"):
			actor.puppet.set_speed(spd)


# 源 resetUI（:1188-1192）returnBtn 装配：setPosition(757,440) + registerScriptTapHandler(returnBtnTapHandler)。
func _create_return_button() -> void:
	if return_btn != null:
		return_btn.queue_free()
	var btn := TextureButton.new()
	btn.texture_normal = load("res://assets/ui/alpha/HVGA/pausebtn.png") as Texture2D
	btn.position = Vector2(757.0, 440.0)   # 源 :1190 ccp(757-ox, header_y)，ox/oy=0→440
	btn.pressed.connect(_on_return_pressed)
	ui_layer.add_child(btn)
	return_btn = btn


# 源 returnBtnTapHandler（:395-398）→ createPauseLayer。
func _on_return_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")   # 源 battle.clickReturn（battle_scene.lua:396，点暂停按钮）
	create_pause_layer()


# 源 createPauseLayer（:206-330）：pauseBattle + 黑半透层 + 三按钮 + 进场动画（BattlePauseLayer 组件）。
func create_pause_layer() -> void:
	if pause_layer != null:
		return   # 源 :207-209 已存在则返
	pause_locks["pauseButton"] = true; is_paused = pause_locks.values().has(true)   # 源 :210 pauseBattle + any :777-780
	AudioPlayer.set_bgm_volume(0.25)   # 源 :215 setMusicVolume(0.25) 暂停时降音
	var layer := BattlePauseLayer.new()
	layer.setup(ui_layer, true)
	layer.exit_requested.connect(_on_pause_exit)
	layer.resume_requested.connect(_on_pause_resume)
	pause_layer = layer


# 源 :240-245 exit / :296-313 resume → 清层（单机化：exit emit battle_exited）。
func _on_pause_exit() -> void:
	_clear_pause_layer(); pause_locks["pauseButton"] = false; is_paused = pause_locks.values().has(true); battle_exited.emit()


func _on_pause_resume() -> void:
	_clear_pause_layer(); pause_locks["pauseButton"] = false; is_paused = pause_locks.values().has(true)


func _clear_pause_layer() -> void:
	if pause_layer != null:
		pause_layer.queue_free()
		pause_layer = null
	AudioPlayer.restore_bgm_volume()   # 源 :298 resetMusicVolume 恢复音乐音量（exit/resume 共用）


# 源 pauseBattle :168-170 / resumeBattle :173-175 + any 检查 :777-780：pause_locks 多 reason 字典（任一 true → 暂停）。
# reason：pauseButton/5v5skill·5v5ending（教学）/story（剧情）。单机化裁剪教学/剧情，仅 pauseButton 实接。
# 源是 pauseBattle/resumeBattle 方法；本项目 battle_scene View ≤400 行限，内联到 create_pause_layer/
# _on_pause_exit/_on_pause_resume 调用点（pause_locks[reason]= + is_paused=pause_locks.values().has(true)）。
# resume 设 false 非 erase（源 :174）。has(true) = 源 :777-780 any(v)。


# 源 resetUI（:1341-1387）timer 装配：bg+mask+hourglass+text。
func _create_timer() -> void:
	if timer != null:
		timer.queue_free()
	var t := BattleTimer.new()
	t.setup()
	ui_layer.add_child(t)
	timer = t


# 源 updateTimer（:1406-1427）每帧调用（step 末尾）。
func _update_timer() -> void:
	if timer != null and engine != null:
		timer.update(float(engine.time_limit), bool(engine.running))


# 源 resetUI（:1198-1206）nextBtn 装配：setPosition(670,260) scale 1.25 初始不可见。
func _create_next_button() -> void:
	if next_btn != null:
		next_btn.queue_free()
	var btn := BattleNextButton.new()
	btn.setup()
	btn.pressed.connect(_on_next_pressed)
	ui_layer.add_child(btn)
	next_btn = btn


# 源 nextBtnTapHandler（:408-444）：sfx + battleSupply + next_btn 隐藏 + 玩家走路 + 延迟切波 + autoCollectLoots。
func _on_next_pressed() -> void:
	AudioPlayer.play_sfx("battle_next_wave")   # 源 battle.goNextBattle（battle_scene.lua:410）
	if engine != null:
		engine.battle_supply()
	if next_btn != null:
		next_btn.hide_button()
	var maxtime: float = _start_player_walk_to_next_battle()   # 源 :418-428
	_auto_collect_loots()   # 源 :442
	await get_tree().create_timer(maxtime).timeout   # 源 :438 CCDelayTime(maxtime)
	next_wave_requested.emit()   # 源 :431 nextBattle()


# 源 nextBtnTapHandler :418-428：foreachAliveUnit Player → actor.gotoNextBattle（走路）+ maxtime（最慢单位）。
func _start_player_walk_to_next_battle() -> float:
	var maxtime: float = 0.0
	if engine == null:
		return maxtime
	var max_x: float = float(engine.stage_rect.get("maxX", 0.0))
	for unit in engine.foreach_alive_unit(BattleEngine.CAMP_PLAYER):
		if unit.actor != null and unit.actor.has_method("goto_next_battle"):
			unit.actor.goto_next_battle(float(unit.info.get("Walk Speed", 0.0)))
		var distance: float = max_x - float(unit.position.x)
		var walk_speed: float = float(unit.info.get("Walk Speed", 0.0)) * BattleActor.NEXT_BATTLE_WALK_SPEEDER
		if walk_speed > 0.0:
			maxtime = maxf(maxtime, distance / walk_speed)
	return maxtime


# 源 autoCollectLoots :447-461：ui_list 中 Loot 依次 onAutoCollect（delay 1/60 递增）。
func _auto_collect_loots() -> void:
	var delay: float = 0.0
	for ui in ui_list:
		if ui.has_method("on_auto_collect"):
			await get_tree().create_timer(delay).timeout
			ui.on_auto_collect()
			delay += 0.16666666666666666


# 源 showNextButton（:1392-1404）— 暴露给上层（victory 多波流程）调显示下一关按钮。
func show_next_button() -> void:
	if next_btn != null:
		next_btn.show_button()


# 源 nextBattle :463-502 scene 侧切波 — 委托 BattleWaveAdvancer 控 ≤400。
func _on_next_wave_requested() -> void:
	BattleWaveAdvancer.advance_wave(self)


# 源 resetUI :1207-1257 auto_btn 装配（@734,60；pve stars<3 隐藏，单机化默认隐藏）。
func _create_auto_button() -> void:
	if auto_btn != null:
		auto_btn.queue_free()
	var btn := BattleAutoButton.new()
	btn.setup(false, false)   # 默认 off + 隐藏（pve stars<3，源 :1224-1226）
	btn.toggled.connect(_on_auto_toggled)
	ui_layer.add_child(btn)
	auto_btn = btn


# 源 autoCombatHandler :1021 — toggle auto_combat（hero_panel._is_auto_combat 消费）。
func _on_auto_toggled(on: bool) -> void:
	AudioPlayer.play_sfx("common_switch_on" if on else "common_switch_off")  # 源 enableAuto(:1023)/disenableAuto(:1025)
	auto_combat = on


# 源 startCameraShakeAnimationY :1440 — 委托 BattleCameraShake 控 ≤400。
func start_camera_shake_animation_y(max_height: float, shake_time: float, shake_num: int) -> void:
	BattleCameraShake.shake_y(self, max_height, shake_time, shake_num)


# 源 stopCameraShakeAnimationY :1447 — 委托 BattleCameraShake。
func stop_camera_shake_animation_y() -> void:
	BattleCameraShake.stop_y(self)


# 源 startCameraShakeAnimationX :1454 — 委托 BattleCameraShake。
func start_camera_shake_animation_x(max_height: float, shake_time: float, shake_num: int) -> void:
	BattleCameraShake.shake_x(self, max_height, shake_time, shake_num)


# 源 stopCameraShakeAnimationX :1461 — 委托 BattleCameraShake。
func stop_camera_shake_animation_x() -> void:
	BattleCameraShake.stop_x(self)


# 源 resetUI :1289-1297 wave_mark — 委托 BattleResourceAssembler 控 ≤400。
func _create_wave_mark() -> void:
	BattleResourceAssembler.create_wave_mark(self)


# 源 resetUI :1309-1339 goldmarker/lootmarker — 委托 BattleResourceAssembler。
func _create_resource_markers() -> void:
	BattleResourceAssembler.create_resource_markers(self)


# 源 addGold :990-1014 — 委托 BattleResourceAssembler（公开 API，被 BattleActor 调用）。
func add_gold(num: int) -> void:
	BattleResourceAssembler.add_gold(self, num)


# 源 addLootMarker :957-988 — 委托 BattleResourceAssembler（公开 API）。
func add_loot_marker(num: int) -> void:
	BattleResourceAssembler.add_loot_marker(self, num)


# 源 resetUI :1283-1287 heroes_panel @70,5（hero_panel 容器层）。
func _create_heroes_panel() -> void:
	if heroes_panel != null:
		heroes_panel.queue_free()
	_hero_panels.clear()
	heroes_panel = Control.new()
	heroes_panel.position = Vector2(70.0, 5.0)   # 源 :1285 ccp(70,5)
	ui_layer.add_child(heroes_panel)


# 源 addHeroPanel（reset :148-158 调）：装 HeroPanel 挂 heroes_panel + 入 ui_list。
func add_hero_panel(unit: Variant) -> void:
	if heroes_panel == null:
		return
	var panel := BattleHeroPanel.new()
	panel.setup(unit, cm, self)
	heroes_panel.add_child(panel)
	ui_list.append(panel)
	_hero_panels[unit] = panel   # 源 unit.heroPanel（波次复用，scene dict 避改 BattleUnit 临界行数）


# 源 calculateBigHpLength（:532-539）：HVGA visibleOrigin=0 → rightX-leftX = 587-(84+106) = 397。
func _calculate_big_hp_length() -> float:
	return 397.0
