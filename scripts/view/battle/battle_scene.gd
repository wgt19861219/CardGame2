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
var effect_list: Array = []
var ui_list: Array = []
var speed_state: int = 1
var pause_locks: Dictionary = {}  # P1-17：源 pause_locks 多 reason 字典
var is_paused: bool = false       # pause_locks.values().has(true) 缓存（调用点内联算，源 :777-780 any）
var last_sync_tick: int = -1
var speed_btn: Variant = null
var return_btn: Variant = null
var pause_layer: Variant = null
var timer: Variant = null
var next_btn: Variant = null
var battle_info: Dictionary = {}
var wave_mark: Variant = null
var gold_marker: Variant = null
var loot_marker: Variant = null
var heroes_panel: Control = null
var _hero_panels: Dictionary = {} # unit→HeroPanel（源 unit.heroPanel 波次复用，scene dict 避改 BattleUnit）
var auto_combat: bool = false
var auto_btn: Variant = null
var _camera: Camera2D = null
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
	_camera = Camera2D.new()
	add_child(_camera)
	# Node2D 层（actor/背景）需 Camera2D current 才在 viewport 渲染；CanvasLayer(UI) 独立不需。
	# 仅运行时入树后激活（GUT 测试 scene 不入树，跳过）。
	if _camera.is_inside_tree():
		_camera.make_current()


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
	if engine != null:
		_create_heroes_panel()
		for unit in engine.unit_list:
			if int(unit.hp_layer) != 0:
				add_big_blood_panel(unit)
			if int(unit.camp) == BattleEngine.CAMP_PLAYER and bool(unit.is_hero()):
				add_hero_panel(unit)
	_create_speed_button()
	_create_return_button()
	_create_timer()
	_create_next_button()
	_create_auto_button()
	if not battle_info.is_empty():
		_create_wave_mark()
		_create_resource_markers()
		_create_background()


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
	bg_sprite.centered = false
	bg_sprite.position = Vector2.ZERO
	bg_sprite.flip_h = bool(battle_info.get("H Flip", false))
	background_layer.add_child(bg_sprite)


func set_speed_state(s: int) -> void:
	speed_state = clampi(s, 1, SPEED_MULTIPLIERS.size())


func step(dt: float) -> void:
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
	if (not bool(engine.running) or bool(engine.stage_ended)) or _ticks_left <= 0:
		_finalize_battle()


# 场景销毁 kill 残留 tween（leak P1：_shake_tween_x/y 持已释放 _camera，Tween 不随 Node 销毁）。
func _exit_tree() -> void:
	BattleCameraShake.kill_all(self)


## 战斗结束结算（View 接入闭环）：mode 分流委托 BattleSceneFinalizer。
func _finalize_battle() -> void:
	_finalized = true
	if _battle_context.is_empty():
		SceneManager.change_scene(STAGE_FAILED_PATH); return
	var m := String(_battle_context.get("mode", "stage"))
	if m == "excavate":
		BattleSceneFinalizer.finalize_excavate(self)
	elif m == "pvp":
		BattleSceneFinalizer.finalize_pvp(self)
	else:
		BattleSceneFinalizer.finalize_stage(self)


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
	NpcActor.sync_actors(self)


func _create_actor(unit: Variant) -> BattleActor:
	var actor := BattleActor.new()
	actor.setup(unit, cm, ui_layer)
	return actor


func _add_actor(actor: BattleActor) -> void:
	actor_list.append(actor)
	main_layer.add_child(actor)


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


func play_effect_on_scene(effect_name: String, origin: Vector2, scale: float = 1.0, height: float = 0.0, zorder: int = 0) -> void:
	var effect: Variant = null
	var battle_effect := BattleEffect.create(effect_name)
	if battle_effect != null:
		battle_effect.play()
		effect = battle_effect
	else:
		effect = BattleEffect.FallbackEffect.new(Node2D.new(), 1.0)  # 降级
	var n: Node2D = effect.get_node()
	n.position = BattleViewCoords.to_view_position(origin.x, origin.y, height); n.scale = Vector2(scale, scale)
	n.z_index = -int(origin.y)
	(background_layer if zorder < 0 else (main_layer if zorder == 0 else top_layer)).add_child(n)
	effect_list.append(effect)


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


func add_big_blood_panel(unit: Variant) -> void:
	var panel: BattleBigHpBar = BattleBigHpBar.create(unit, _calculate_big_hp_length())
	ui_layer.add_child(panel)
	panel.position = BattleViewCoords.to_godot(375.0, 440.0)
	ui_list.append(panel)


# 初始档同步当前 speed_state（源从 CCUserDefault 持久化，单机化默认 1）。
func _create_speed_button() -> void:
	if speed_btn != null:
		speed_btn.queue_free()
	var btn := BattleSpeedButton.new()
	btn.setup(speed_state)
	btn.speed_changed.connect(_on_speed_changed)
	ui_layer.add_child(btn)
	speed_btn = btn


func _on_speed_changed(state: int) -> void:
	set_speed_state(state)
	var spd: float = float(SPEED_MULTIPLIERS[state - 1])
	for actor in actor_list:
		if actor.puppet != null and actor.puppet.has_method("set_speed"):
			actor.puppet.set_speed(spd)


func _create_return_button() -> void:
	if return_btn != null:
		return_btn.queue_free()
	var btn := TextureButton.new()
	btn.texture_normal = load("res://assets/ui/alpha/HVGA/pausebtn.png") as Texture2D
	btn.position = BattleViewCoords.to_godot(757.0, 440.0)
	btn.pressed.connect(_on_return_pressed)
	ui_layer.add_child(btn)
	return_btn = btn


func _on_return_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	create_pause_layer()


func create_pause_layer() -> void:
	if pause_layer != null:
		return
	pause_locks["pauseButton"] = true; is_paused = pause_locks.values().has(true)
	AudioPlayer.set_bgm_volume(0.25)
	var layer := BattlePauseLayer.new()
	layer.setup(ui_layer, true)
	layer.exit_requested.connect(_on_pause_exit)
	layer.resume_requested.connect(_on_pause_resume)
	pause_layer = layer


func _on_pause_exit() -> void:
	_clear_pause_layer(); pause_locks["pauseButton"] = false; is_paused = pause_locks.values().has(true); battle_exited.emit()


func _on_pause_resume() -> void:
	_clear_pause_layer(); pause_locks["pauseButton"] = false; is_paused = pause_locks.values().has(true)


func _clear_pause_layer() -> void:
	if pause_layer != null:
		pause_layer.queue_free()
		pause_layer = null
	AudioPlayer.restore_bgm_volume()


# reason：pauseButton/5v5skill·5v5ending（教学）/story（剧情）。单机化裁剪教学/剧情，仅 pauseButton 实接。
# _on_pause_exit/_on_pause_resume 调用点（pause_locks[reason]= + is_paused=pause_locks.values().has(true)）。
# resume 设 false 非 erase（源 :174）。has(true) = 源 :777-780 any(v)。


func _create_timer() -> void:
	if timer != null:
		timer.queue_free()
	var t := BattleTimer.new()
	t.setup()
	ui_layer.add_child(t)
	timer = t


func _update_timer() -> void:
	if timer != null and engine != null:
		timer.update(float(engine.time_limit), bool(engine.running))


func _create_next_button() -> void:
	if next_btn != null:
		next_btn.queue_free()
	var btn := BattleNextButton.new()
	btn.setup()
	btn.pressed.connect(_on_next_pressed)
	ui_layer.add_child(btn)
	next_btn = btn


func _on_next_pressed() -> void:
	AudioPlayer.play_sfx("battle_next_wave")
	if engine != null:
		engine.battle_supply()
	if next_btn != null:
		next_btn.hide_button()
	var maxtime: float = _start_player_walk_to_next_battle()
	_auto_collect_loots()
	await get_tree().create_timer(maxtime).timeout
	next_wave_requested.emit()


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


func _auto_collect_loots() -> void:
	var delay: float = 0.0
	for ui in ui_list:
		if ui.has_method("on_auto_collect"):
			await get_tree().create_timer(delay).timeout
			ui.on_auto_collect()
			delay += 0.16666666666666666


func show_next_button() -> void:
	if next_btn != null:
		next_btn.show_button()


func _on_next_wave_requested() -> void:
	BattleWaveAdvancer.advance_wave(self)


func _create_auto_button() -> void:
	if auto_btn != null:
		auto_btn.queue_free()
	var btn := BattleAutoButton.new()
	btn.setup(false, false)   # 默认 off + 隐藏（pve stars<3，源 :1224-1226）
	btn.toggled.connect(_on_auto_toggled)
	ui_layer.add_child(btn)
	auto_btn = btn


func _on_auto_toggled(on: bool) -> void:
	AudioPlayer.play_sfx("common_switch_on" if on else "common_switch_off")
	auto_combat = on


func start_camera_shake_animation_y(max_height: float, shake_time: float, shake_num: int) -> void:
	BattleCameraShake.shake_y(self, max_height, shake_time, shake_num)


func stop_camera_shake_animation_y() -> void:
	BattleCameraShake.stop_y(self)


func start_camera_shake_animation_x(max_height: float, shake_time: float, shake_num: int) -> void:
	BattleCameraShake.shake_x(self, max_height, shake_time, shake_num)


func stop_camera_shake_animation_x() -> void:
	BattleCameraShake.stop_x(self)


func _create_wave_mark() -> void:
	BattleResourceAssembler.create_wave_mark(self)


func _create_resource_markers() -> void:
	BattleResourceAssembler.create_resource_markers(self)


func add_gold(num: int) -> void:
	BattleResourceAssembler.add_gold(self, num)


func add_loot_marker(num: int) -> void:
	BattleResourceAssembler.add_loot_marker(self, num)


func _create_heroes_panel() -> void:
	if heroes_panel != null:
		heroes_panel.queue_free()
	_hero_panels.clear()
	heroes_panel = Control.new()
	heroes_panel.position = BattleViewCoords.to_godot(70.0, 5.0)
	ui_layer.add_child(heroes_panel)


func add_hero_panel(unit: Variant) -> void:
	if heroes_panel == null:
		return
	var panel := BattleHeroPanel.new()
	panel.setup(unit, cm, self)
	heroes_panel.add_child(panel)
	ui_list.append(panel)
	_hero_panels[unit] = panel


func _calculate_big_hp_length() -> float:
	return 397.0
