class_name BattleLootView
extends Node2D

## 战斗掉落物（View 层）— 照源 loot.lua(128) 翻译（Phase 4 子件，2026-07-02）。
## chest1/chestopen1/shine/chest_holo 资源已就位。物理弹射（重力 + 边界反弹 + life）+ chest 显示
## + 拾取（on_tapped/on_auto_collect emit 信号，scene 端 showMonsterLoots/addLootMarker + createIcon 装备图标后续补）。
## 挂 ui_layer。源 ed.toViewPosition → BattleViewCoords。源 ed.readequip.createIcon → 信号回调（桩）。

const BattleViewCoords = preload("res://scripts/ui/battle_view_coords.gd")

const BOUNCE_X: float = 785.0
const GRAVITY: float = -1000.0
const LIFE_DEFAULT: float = 0.6
const VEL_Y: float = -100.0
const VEL_Z_INIT: float = 300.0
const VEL_X_BASE: float = 100.0
const BOUNCE_MULT: float = -1.5
const MARKER_POS: Vector2 = Vector2(157.0, 445.0)
const CHEST_PATH: String = "res://assets/ui/alpha/HVGA/chest1.png"
const CHEST_OPEN_PATH: String = "res://assets/ui/alpha/HVGA/chestopen1.png"
const SHINE_PATH: String = "res://assets/ui/alpha/HVGA/shine.png"
const HOLO_PATH: String = "res://assets/ui/alpha/HVGA/chest_holo.png"
const SHINE_ROTATE_RATE: float = 60.0
const SHINE_INIT_ROT: float = 30.0

signal loot_tapped(loot_id: int)
# P2-GUT-2：飞抵 marker + add_loot_marker 完成（测试信号等待替代固定时长 await）
signal flew_to_marker

var loot_id: int = 0
var loot_type: Variant = null
var icon: Variant = null
var _logic_pos: Vector2 = Vector2.ZERO
var _height: float = 0.0
var _vel_x: float = 0.0
var _vel_z: float = VEL_Z_INIT
var _life: float = LIFE_DEFAULT
var _terminated: bool = false
var _bound: float = 0.0
var _chest: Sprite2D = null
var scene: Variant = null


static func create(p_icon: Variant, p_type: Variant, monster: Variant, idx: int, p_loot_id: int, ui_layer: Node) -> BattleLootView:
	var loot := BattleLootView.new()
	loot._setup(p_icon, p_type, monster, idx, p_loot_id, ui_layer)
	return loot


func _setup(p_icon: Variant, p_type: Variant, monster: Variant, idx: int, p_loot_id: int, ui_layer: Node) -> void:
	icon = p_icon
	loot_type = p_type
	loot_id = p_loot_id
	_logic_pos = Vector2(float(monster.position.x), float(monster.position.y))
	_vel_x = VEL_X_BASE * float(idx)
	ui_layer.add_child(self)
	_create_visuals()
	_update_physics_and_sync(0.0)


func _create_visuals() -> void:
	# shine/holo（源 :43-59，装饰背景层 z=-1）
	var shine: Sprite2D = _load_sprite(SHINE_PATH)
	if shine:
		shine.z_index = -1
		shine.modulate.a = 96.0 / 255.0
		shine.rotation = deg_to_rad(SHINE_INIT_ROT)
		add_child(shine)
		_play_shine_anim(shine)
	var holo: Sprite2D = _load_sprite(HOLO_PATH)
	if holo:
		holo.z_index = -1
		holo.modulate.a = 96.0 / 255.0
		add_child(holo)
		_play_holo_anim(holo)
	# chest（源 :14 btn CCMenuItemImage chest1）— 点击拾取（Area2D，贴源按钮可点+吞事件）
	_chest = _load_sprite(CHEST_PATH)
	if _chest:
		add_child(_chest)
		_attach_tap_area(_chest)


func _play_shine_anim(shine: Sprite2D) -> void:
	var blink := create_tween().set_loops()
	blink.tween_property(shine, "modulate:a", 1.0, LIFE_DEFAULT * 0.5)
	blink.tween_property(shine, "modulate:a", 0.0, LIFE_DEFAULT * 0.5)
	var rot := create_tween().set_loops()
	rot.tween_property(shine, "rotation", shine.rotation + SHINE_ROTATE_RATE, 1.0)


func _play_holo_anim(holo: Sprite2D) -> void:
	var blink := create_tween().set_loops()
	blink.tween_property(holo, "modulate:a", 1.0, LIFE_DEFAULT * 0.5)
	blink.tween_property(holo, "modulate:a", 96.0 / 255.0, LIFE_DEFAULT * 0.5)


func update(dt: float) -> void:
	if _life <= 0.0 or _terminated:
		return
	_life -= dt
	if _logic_pos.x > BOUNCE_X - _bound and _vel_x > 0.0:
		_vel_x = _vel_x * BOUNCE_MULT
	_update_physics_and_sync(dt)


func _update_physics_and_sync(dt: float) -> void:
	_logic_pos.x += _vel_x * dt
	_logic_pos.y += VEL_Y * dt
	_height += _vel_z * dt
	_vel_z += GRAVITY * dt
	position = BattleViewCoords.to_view_position(_logic_pos.x, _logic_pos.y, _height)


func is_terminated() -> bool:
	return _terminated


# scene 引用注入（源 loot 经 ed.scene 全局调 addLootMarker，本项目 scene 显式注入）。
func set_scene(p_scene: Variant) -> void:
	scene = p_scene


func on_tapped() -> void:
	if _terminated:
		return
	AudioPlayer.play_sfx("battle_loot")
	loot_tapped.emit(loot_id)
	_show_chest_open()
	_fly_to_marker_and_cleanup()


func on_auto_collect() -> void:
	if _terminated:
		return
	loot_tapped.emit(loot_id)
	_fly_to_marker_and_cleanup()


func _show_chest_open() -> void:
	var chest_open: Sprite2D = _load_sprite(CHEST_OPEN_PATH)
	if chest_open == null:
		return
	chest_open.position = position
	var parent: Node = get_parent()
	if parent:
		parent.add_child(chest_open)
	var t := create_tween()
	t.tween_property(chest_open, "modulate:a", 0.0, 0.3)
	t.tween_callback(chest_open.queue_free)


func _fly_to_marker_and_cleanup() -> void:
	_terminated = true
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "position", BattleViewCoords.to_godot(MARKER_POS.x, MARKER_POS.y), 0.3)
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_property(self, "scale", Vector2(0.5, 0.5), 0.3)
	t.chain().tween_callback(func() -> void:
		if scene != null and scene.has_method("add_loot_marker"):
			scene.add_loot_marker(1)
		flew_to_marker.emit()
		queue_free())


func _load_sprite(path: String) -> Sprite2D:
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return null
	var s := Sprite2D.new()
	s.texture = tex
	# Sprite2D（CanvasItem）无 mouse_filter，默认不处理点击；拾取由 scene/逻辑触发 on_tapped
	return s


# 宝箱点击区（源 :17-24 CCMenuItemImage registerScriptTapHandler → onTapped）。
func _attach_tap_area(chest: Sprite2D) -> void:
	var area := Area2D.new()
	area.input_pickable = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	if chest.texture != null:
		rect.size = chest.texture.get_size()
	shape.shape = rect
	area.add_child(shape)
	chest.add_child(area)
	# Area2D.input_event 签名=3 参（viewport, event, shape_idx），勿多声明（Godot 4 运行时才炸）
	area.input_event.connect(func(viewport: Node, event: InputEvent, _idx: int) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			viewport.accept_event()
			on_tapped())
