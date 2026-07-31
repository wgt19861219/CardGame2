class_name BattleNextButton
extends Control

## 下一关按钮（View 层）— 照源 battle_scene.lua:1198-1206（resetUI 装配）/1392-1404（showNextButton）。
## nextbtn @ (670,260) scale 1.25，初始不可见。show_button() 显示 + 左右摆动（源 CCRepeatForever MoveBy±30）。
## 挂 ui_layer（scene 装配）。发 pressed 信号；nextBattle 波次切换 Logic 留待 engine.next_battle（Phase 2.1续）。
##
## 重构（2026-07-18，hero_detail 范式）：TextureButton（texture_normal + 初始 visible/disabled）静态化进
## scenes/battle/battle_next_button_content.tscn；setup instantiate + add_child + get_node("%NextBtn") as + connect。
## show/hide_button 摆动动画保留 procedural（position.x tween）。Control 组件 content 挂 panel 自身（坑 7）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/battle/battle_next_button_content.tscn")
const GODOT_POS: Vector2 = Vector2(750.0, 300.0)  # 原 to_godot(670,260)=(670+80,560-260)，HUD 原生坐标
const BUTTON_SCALE: float = 1.25
const SWING_DIST: float = 30.0
const SWING_DURATION: float = 0.65

signal pressed

var _btn: TextureButton = null
var _swing_tween: Tween = null


func setup() -> void:
	position = GODOT_POS
	scale = Vector2(BUTTON_SCALE, BUTTON_SCALE)
	var content := CONTENT_SCENE.instantiate()
	add_child(content)   # Control 组件 content 挂 panel 自身（坑 7，坐标原点 = btn 原点）
	_btn = content.get_node("%NextBtn") as TextureButton
	_btn.pressed.connect(_on_pressed)


func show_button() -> void:
	_btn.visible = true
	_btn.disabled = false
	if _swing_tween:
		_swing_tween.kill()
	_swing_tween = create_tween().set_loops()
	_swing_tween.tween_property(self, "position:x", GODOT_POS.x + SWING_DIST, SWING_DURATION)
	_swing_tween.tween_property(self, "position:x", GODOT_POS.x, SWING_DURATION)


func hide_button() -> void:
	_btn.visible = false
	_btn.disabled = true
	if _swing_tween:
		_swing_tween.kill()
		_swing_tween = null
	position.x = GODOT_POS.x


func _on_pressed() -> void:
	pressed.emit()


func is_button_visible() -> bool:
	return _btn.visible
