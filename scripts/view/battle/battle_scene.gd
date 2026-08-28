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
const BattleTimeoutBanner = preload("res://scripts/view/battle/battle_timeout_banner.gd")
const BattleHud = preload("res://scripts/view/battle/battle_hud.gd")
const BattleSpeedSync = preload("res://scripts/view/battle/battle_speed_sync.gd")
const BattleHudAssembler = preload("res://scripts/view/battle/battle_hud_assembler.gd")
const ProjectileSync = preload("res://scripts/view/battle/projectile_sync.gd")
const HUD_SCENE: PackedScene = preload("res://scenes/battle/battle_hud.tscn")

const SPEED_MULTIPLIERS: Array[int] = [1, 2, 3, 4]
const STAGE_DONE_PATH: String = "res://scenes/battle/stage_done_scene.tscn"      # 胜利结算场景
const STAGE_FAILED_PATH: String = "res://scenes/battle/stage_failed_scene.tscn"  # 失败结算场景
const MAIN_SCENE_PATH: String = "res://scenes/main_menu/main_scene.tscn"         # 主菜单（excavate 战斗结束回）
const ExcavateBattle = preload("res://scripts/systems/excavate_battle.gd")
const LadderBattle = preload("res://scripts/systems/ladder_battle.gd")
const MAX_TICKS: int = 6000  # 防死循环（≥ time_limit 90s×fps 60=5400，覆盖 engine 自然 timeout）
const BIG_HP_LENGTH: float = 397.0  # 大血条长度（源 _calculate_big_hp_length 常量内联）
const BIG_HP_POS: Vector2 = Vector2(375.0, 40.0)  # to_godot(375,440)=(375,480-440)，Boss 血条 HUD 原生坐标（800×480 直译）
# 暂停键源直译：createButtonWithMask÷CS 显示 54.6×53.9，中心(757,440)→Godot 左上；旧(710,20)偏位+未÷CS（2026-08-28 战斗域批次修）。
const RETURN_BTN_POS: Vector2 = Vector2(729.7, 13.1)

signal next_wave_requested

var engine: Variant = null
var cm: Variant = null
var background_layer: Node2D = null
var main_layer: Node2D = null
var top_layer: Node2D = null
var ui_layer: CanvasLayer = null
var actor_list: Array = []        # BattleActor 实例（源 actor_list）
var _actors_by_unit: Dictionary = {}  # T4-B7：unit/projectile/npc→actor 映射（Logic actor 黑板退役）
var effect_list: Array = []
var ui_list: Array = []
var speed_state: int = 1
var pause_locks: Dictionary = {}  # P1-17：源 pause_locks 多 reason 字典
var is_paused: bool = false       # pause_locks.values().has(true) 缓存（调用点内联算，源 :777-780 any）
var last_sync_tick: int = -1
var _entering: bool = false           # 入场走路进行中（冻结 engine，仅驱动 actor 离线走）
var _pending_enter_count: int = 0     # 待入场就位 actor 计数
var _enter_walk_enabled: bool = false # 入场走路开关（真实战斗 _ready 从 battle_context 装配时开启）
var _wave_clear_handled: bool = false  # 本波清完已显示 next_btn（防重复触发）
var _walking_to_next: bool = false    # 切波走路中（玩家 gotoNextBattle，冻结 engine 驱动走路）
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
var hud: BattleHud = null          # 战斗 HUD 容器（常驻，分区编排 HUD 元素）
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
var _timeout_banner_pending: bool = false   # 超时横幅显示中（finalize 延迟到横幅 Tween 结束）


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
	# 四层 + hud + camera 已固化进 battle_scene.tscn（编辑器可视化），此处只取节点引用。
	# 兼容旧空壳场景：节点不存在时回退 new()（GUT 测试可能用旧实例）。
	background_layer = (get_node_or_null("Background") as Node2D)
	if background_layer == null:
		background_layer = _ensure_layer("Background")
	main_layer = (get_node_or_null("Main") as Node2D)
	if main_layer == null:
		main_layer = _ensure_layer("Main")
	top_layer = (get_node_or_null("Top") as Node2D)
	if top_layer == null:
		top_layer = _ensure_layer("Top")
	ui_layer = (get_node_or_null("UI") as CanvasLayer)
	if ui_layer == null:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UI"
		add_child(ui_layer)
	# HUD：优先取 .tscn 实例化的实例，否则回退 instantiate（波次重置只清子节点不重建）。
	hud = (ui_layer.get_node_or_null("BattleHud") as BattleHud)
	if hud == null:
		hud = HUD_SCENE.instantiate() as BattleHud
		ui_layer.add_child(hud)
	_camera = (get_node_or_null("Camera2D") as Camera2D)
	if _camera == null:
		_camera = Camera2D.new()
		add_child(_camera)
	# FIXED_TOP_LEFT：世界坐标直接映射屏幕坐标（无 DRAG_CENTER 的 +480,+320 偏移）。
	# to_view_position 输出已是目标屏幕坐标（地面 y=295≈屏幕中部），不应再被相机偏移到底部。
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	# Node2D 层（actor/背景）需 Camera2D current 才在 viewport 渲染；CanvasLayer(UI) 独立不需。
	# 仅运行时入树后激活（GUT 测试 scene 不入树，跳过）。
	if _camera.is_inside_tree():
		_camera.make_current()


func _ensure_layer(layer_name: String) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	add_child(layer)
	return layer


func reset_state() -> void:
	for a in actor_list:
		if a is Node:
			a.queue_free()
	actor_list.clear(); _actors_by_unit.clear()
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


# 战斗入场走路编排（转发 BattleEnterWalk helper）：冻结 engine，预创建 actor 放场外，走到位后解冻。
func _start_enter_walk() -> void:
	BattleEnterWalk.start(self)


# 单个 actor 入场就位回调（转发 helper）；全部就位后解冻 engine。
func _on_actor_enter_done() -> void:
	BattleEnterWalk.on_actor_done(self)


func _create_background() -> void:
	BattleResourceAssembler.create_background(self)


func set_speed_state(s: int) -> void:
	speed_state = clampi(s, 1, SPEED_MULTIPLIERS.size())


# 当前战斗加速倍率（View 层）——FCA 特效创建/切速时补偿到 set_speed
# （FcaAnimation _process 真实 delta 自驱，不补偿则特效恒 1x 与人物动作脱节）。
func current_speed() -> float:
	return float(SPEED_MULTIPLIERS[speed_state - 1])


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
	BattleEventRenderer.render(engine, _actors_by_unit); frames += 1   # T4：同帧 drain 事件分发（近等价旧同步直调）
	_sync_actors()
	ProjectileSync.sync(self)
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
		AudioPlayer.play_battle_bgm(eng.stage_info)
		_enter_walk_enabled = true   # 真实战斗入口（经 battle_context 装配）启用入场走路
	# 战斗场景无全局 HUD（货币栏/快捷栏）— 声明 identity 让 HudOverlay 整体隐藏。
	HudOverlay.apply_identity("battle")
	# 入场走路（engine 已 setup 就位时触发；测试可调 skip_enter_walk 跳过）。
	if engine != null and _enter_walk_enabled:
		_start_enter_walk()


func _process(delta: float) -> void:
	if engine == null or _finalized:
		return
	if _entering or _walking_to_next:
		# 入场/切波走路期间冻结 engine（不 step），仅驱动 actor 离线走路推进。
		_advance_actor_list(delta)
		return
	step(delta)
	_ticks_left -= 1
	# 波次清完待切波：显示"下一波"按钮，不 finalize（源 :1608 showNextButton）。
	if bool(engine.wave_clear) and not _wave_clear_handled:
		_wave_clear_handled = true
		_on_wave_clear()
		return
	if (not bool(engine.wave_clear) and not bool(engine.running)) or bool(engine.stage_ended) or _ticks_left <= 0:
		# 超时分支（源 battle_scene.lua:1429-1438 addTimeOutUI）：stage 模式 + RESULT_TIMEOUT 先显示横幅，延迟 finalize。
		if not _timeout_banner_pending and BattleTimeoutBanner.is_timeout_end(engine, _battle_context):
			_timeout_banner_pending = true
			BattleTimeoutBanner.show(self, _finalize_battle)
		else:
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
		var actor: Variant = _actors_by_unit.get(unit)
		if actor == null:
			var new_actor: BattleActor = _create_actor(unit)
			if new_actor:
				_actors_by_unit[unit] = new_actor
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
		battle_effect.set_speed(current_speed())
		effect = battle_effect
	else:
		effect = BattleEffect.FallbackEffect.new(Node2D.new(), 1.0)  # 降级
	var n: Node2D = effect.get_node()
	n.position = BattleViewCoords.to_view_position(origin.x, origin.y, height)
	# scale 作额外倍率乘进去（照源 :897-898 setScaleX(getScaleX()*scale)），不覆盖 FCA 自带缩放（0.09）。
	n.scale = Vector2(n.scale.x * scale, n.scale.y * scale)
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
	BattleHudAssembler.add_big_blood_panel(self, unit)


# 初始档同步当前 speed_state（源从 CCUserDefault 持久化，单机化默认 1）。
func _create_speed_button() -> void:
	BattleHudAssembler.create_speed_button(self)


func _on_speed_changed(state: int) -> void:
	set_speed_state(state)
	BattleSpeedSync.broadcast(self, state)


func _create_return_button() -> void:
	BattleHudAssembler.create_return_button(self)


func _on_return_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	create_pause_layer()


func create_pause_layer() -> void:
	if pause_layer != null:
		return
	pause_locks["pauseButton"] = true; is_paused = pause_locks.values().has(true)
	AudioPlayer.set_bgm_volume(0.25)
	var layer := BattlePauseLayer.new()
	# 第 4 参 exit 回调=放弃战斗（源 :230-245 exit→:331-344 popScene；2026-08-22 巡检：
	# 旧与 resume 同效致玩家无法中途放弃）。多行 lambda 避免新增成员函数（代码行贴线）。
	layer.setup(ui_layer, AudioPlayer.sound_switch, _on_pause_dismissed, func() -> void:
		_clear_pause_layer()
		BattleSceneFinalizer.abort_battle(self))
	pause_layer = layer


# pause 恢复（清层 + 解锁；exit 走 abort_battle 见 create_pause_layer 第 4 参）。
# 单机化仅 pauseButton 一种 reason；resume 设 false 非 erase（源 :174）。has(true) = 源 :777-780 any(v)。
func _on_pause_dismissed() -> void:
	_clear_pause_layer(); pause_locks["pauseButton"] = false; is_paused = pause_locks.values().has(true)


func _clear_pause_layer() -> void:
	if pause_layer != null:
		pause_layer.queue_free()
		pause_layer = null
	AudioPlayer.restore_bgm_volume()


# reason：pauseButton/5v5skill·5v5ending（教学）/story（剧情）。单机化裁剪教学/剧情，仅 pauseButton 实接。


func _create_timer() -> void:
	BattleHudAssembler.create_timer(self)


func _update_timer() -> void:
	if timer != null and engine != null:
		timer.update(float(engine.time_limit), bool(engine.running))


func _create_next_button() -> void:
	BattleHudAssembler.create_next_button(self)


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
	# 出屏目标 x（>屏宽 800 对应 logic x>800，取 WAVE_WALK_OFFSCREEN_X=1050 确保出屏；
	# 停在屏缘附近会半露右边缘，切波瞬移到站位时被看见）。
	var target_x: float = BattleActor.WAVE_WALK_OFFSCREEN_X
	for unit in engine.foreach_alive_unit(BattleEngine.CAMP_PLAYER):
		var wa: Variant = _actors_by_unit.get(unit)
		if wa != null and wa.has_method("goto_next_battle"):
			# 传 target_x 作停止点（双保险：到位回调 + await maxtime 任一先到都能停）。
			wa.goto_next_battle(float(unit.info.get("Walk Speed", 0.0)), target_x)
		var walk_speed: float = float(unit.info.get("Walk Speed", 0.0)) * BattleActor.NEXT_BATTLE_WALK_SPEEDER
		if walk_speed > 0.0:
			maxtime = maxf(maxtime, (target_x - float(unit.position.x)) / walk_speed)
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


# 本波敌人清完（engine.wave_clear）：玩家向右走到下一波 + 切波 + 新敌人入场。
func _on_wave_clear() -> void:
	if next_btn != null:
		next_btn.hide_button()
	await get_tree().create_timer(0.5).timeout   # 让死亡动画播完
	if _finalized or engine == null or engine.stage_ended:
		return
	# 玩家向右走（gotoNextBattle），_walking_to_next 冻结 engine 驱动走路。
	_walking_to_next = true
	var maxtime: float = _start_player_walk_to_next_battle()
	await get_tree().create_timer(maxtime).timeout
	_walking_to_next = false
	if _finalized or engine == null:
		return
	BattleWaveAdvancer.advance_wave(self)


func _on_next_wave_requested() -> void:
	BattleWaveAdvancer.advance_wave(self)


func _create_auto_button() -> void:
	BattleHudAssembler.create_auto_button(self)


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
	BattleHudAssembler.create_heroes_panel(self)


func add_hero_panel(unit: Variant) -> void:
	BattleHudAssembler.add_hero_panel(self, unit)
