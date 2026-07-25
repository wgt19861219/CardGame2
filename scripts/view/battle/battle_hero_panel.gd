class_name BattleHeroPanel
extends Control

## 英雄头像面板（HUD）— 照源 hero_panel.lua:8-78 HeroPanelCreate + :93-150 update 翻译（Phase 4）。
## hp_bar/mp_bar（FloatingBar）+ portrait（ReadheroIcon，createIcon isHideFrame）+ frame_btn（点放大招
## castHandler，hero_panel 自加 frame 边框）+ container herobucket + redmask hp_low 红闪。
## update 每 tick 检查 can_cast_manual/current_skill:can_trigger → state cast/trigger/switch +
## FCA skill_ready 降级 stub（.abc 缺）+ 死亡变灰 setColor(100,100,100) + auto_combat 自动放。
##
## 重构（2026-07-18，hero_detail 范式）：静态节点（FrameBtn/Redmask/Container + 3 Host 位置）从
## battle_hero_panel_content.tscn instantiate（位置/size 可视化）；动态 portrait/hp_bar/mp_bar 挂 %Host。

const CONTENT_SCENE: PackedScene = preload("res://scenes/battle/battle_hero_panel_content.tscn")
const ReadheroIcon: Script = preload("res://scripts/view/battle/readhero_icon.gd")
const BattleFloatingBar: Script = preload("res://scripts/view/battle/battle_floating_bar.gd")
const BattleEffect: Script = preload("res://scripts/view/battle/battle_effect.gd")

# frame_btn texture_normal 按 rank 动态 fill（FRAME_PATH_FMT % frame_id）。位置/size 在 .tscn。
const FRAME_PATH_FMT: String = "res://assets/ui/alpha/HVGA/hero_icon_frame_%d.png"

# redmask FadeTo 闪烁 loop（源 :75-76）。位置/texture/初始 visible 在 .tscn。
const REDMASK_FADE_LOW: float = 64.0 / 255.0
const DEAD_COLOR: Color = Color(100.0 / 255.0, 100.0 / 255.0, 100.0 / 255.0)
const AUTO_CAST_INTERVAL: float = 0.5
const MP_CAST_THRESHOLD: int = 1000
const TICK_INTERVAL: float = 0.033

const STATE_NONE: String = ""
const STATE_CAST: String = "cast"
const STATE_TRIGGER: String = "trigger"
const STATE_SWITCH: String = "switch"

# 源 hero_panel.lua:30-33 FCA 光圈资源名
const FCA_SWITCH: String = "effect/eff_UI_battle_skill_can_switch"
const FCA_READY: String = "effect/eff_UI_battle_skill_will_ready"
const FCA_CAST: String = "effect/eff_UI_battle_skill_cast"
const FCA_TRIGGER: String = "effect/eff_UI_battle_skill_activate"

var unit: Variant = null
var cm: Variant = null
var scene: Variant = null
var portrait: ReadheroIcon = null
var hp_bar: BattleFloatingBar = null
var mp_bar: BattleFloatingBar = null
var frame_btn: TextureButton = null
var redmask: Sprite2D = null
var _state: String = STATE_NONE
var _ticks: int = -1
var _skill_ready_timer: float = 0.0
var _skill_ready_effect: Variant = null


# 动态 portrait/hp_bar/mp_bar 挂 %Host（位置在 .tscn，子组件局部坐标系不变）。
func setup(p_unit: Variant, p_cm: Variant, p_scene: Variant = null) -> void:
	unit = p_unit
	cm = p_cm
	scene = p_scene
	var content := CONTENT_SCENE.instantiate()
	add_child(content)   # Control 组件，content 挂 panel 自身（坑 7）
	frame_btn = content.get_node("%FrameBtn") as TextureButton
	redmask = content.get_node("%Redmask") as Sprite2D
	var portrait_host: Control = content.get_node("%PortraitHost") as Control
	var hp_bar_host: Control = content.get_node("%HpBarHost") as Control
	var mp_bar_host: Control = content.get_node("%MpBarHost") as Control
	var rank: int = int(unit.rank)
	var frame_id: int = ReadheroIcon._frame_id_by_rank(rank)
	frame_btn.texture_normal = _load_tex(FRAME_PATH_FMT % frame_id)
	frame_btn.pressed.connect(_on_frame_pressed)
	portrait = ReadheroIcon.new()
	portrait.setup({"id": int(unit.tid), "stars": int(unit.stars), "isHideFrame": true}, cm)
	portrait_host.add_child(portrait)
	portrait_host.move_child(portrait, 0)   # 让 portrait 在 FrameBtn 之下（视觉等价源 add 顺序）
	hp_bar = BattleFloatingBar.create(unit, "HP")
	hp_bar.auto_hide = false
	hp_bar_host.add_child(hp_bar)
	var mp_type: String = str(unit.info.get("MP Type", "MP"))
	mp_bar = BattleFloatingBar.create(unit, mp_type)
	mp_bar.auto_hide = false
	mp_bar_host.add_child(mp_bar)
	_start_redmask_flicker()
	frame_btn.disabled = true


func _start_redmask_flicker() -> void:
	if redmask == null:
		return
	var t := create_tween().set_loops()
	t.tween_property(redmask, "modulate:a", REDMASK_FADE_LOW, 0.8)
	t.tween_property(redmask, "modulate:a", 1.0, 0.2)


func _on_frame_pressed() -> void:
	if unit == null or unit.engine == null:
		return
	if not bool(unit.engine.running):
		return
	unit.cast_manual_skill()
	frame_btn.disabled = true
	_play_skill_cast_effect()


func update(dt: float) -> void:
	if unit == null or unit.engine == null:
		return
	var eng: Variant = unit.engine
	if _ticks != int(eng.ticks) and not bool(eng.arena_mode) and not bool(eng.replay_mode):
		_ticks = int(eng.ticks)
		var new_state: String = STATE_NONE
		if bool(unit.can_cast_manual) and bool(eng.running):
			new_state = STATE_CAST
		var cs: Variant = unit.current_skill
		if cs != null and cs.has_method("can_trigger") and bool(cs.can_trigger()):
			new_state = STATE_TRIGGER
		if new_state == STATE_CAST and int(unit.mp) < MP_CAST_THRESHOLD:
			new_state = STATE_SWITCH
		frame_btn.disabled = (new_state == STATE_NONE)
		if _state != new_state:
			_play_skill_ready(new_state)
			_state = new_state
		redmask.visible = bool(unit.hp_low)
		if not bool(unit.is_alive()):
			redmask.visible = false
			_set_portrait_gray()
		if (new_state == STATE_CAST or new_state == STATE_SWITCH) and _is_auto_combat():
			_skill_ready_timer += TICK_INTERVAL
			var ms: Variant = unit.manual_skill
			if _skill_ready_timer > AUTO_CAST_INTERVAL and ms != null and bool(ms.will_cast()):
				_on_frame_pressed()
				_skill_ready_timer = 0.0
	hp_bar.update(dt)
	mp_bar.update(dt)


func _play_skill_ready(state: String) -> void:
	_skill_ready_timer = 0.0
	if state == STATE_NONE:
		return
	if state == STATE_CAST:
		AudioPlayer.play_sfx("battle_fury_full")
	if _skill_ready_effect != null and is_instance_valid(_skill_ready_effect):
		_skill_ready_effect.queue_free()
	var res: String = FCA_READY if state == STATE_CAST else (FCA_TRIGGER if state == STATE_TRIGGER else FCA_SWITCH)
	var eff: Variant = BattleEffect.create(res)
	if eff != null:
		eff.play()
		_skill_ready_effect = eff.get_node()
		add_child(_skill_ready_effect)


func _play_skill_cast_effect() -> void:
	var eff: Variant = BattleEffect.create(FCA_CAST)
	if eff != null:
		eff.play()
		var n: Node2D = eff.get_node()
		add_child(n)
		# cast 特效不持久，1s 后清（hero_panel 不在 effect_list，手动回收）
		if is_inside_tree():
			get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(n): n.queue_free())


func _set_portrait_gray() -> void:
	if portrait != null and portrait.ori_icon != null:
		portrait.ori_icon.modulate = DEAD_COLOR


func _is_auto_combat() -> bool:
	if scene != null and scene.get("auto_combat") != null:
		return bool(scene.auto_combat)
	return false


func _load_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
