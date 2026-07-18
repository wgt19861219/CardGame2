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
const BUTTON_POS: Vector2 = Vector2(670.0, 260.0)   # 源 :1202 ccp(670,260)
const BUTTON_SCALE: float = 1.25                    # 源 :1200 nextScale
const SWING_DIST: float = 30.0                      # 源 :1400 ccp(30,0)
const SWING_DURATION: float = 0.65                  # 源 :1400 CCMoveBy(0.65)

signal pressed

var _btn: TextureButton = null
var _swing_tween: Tween = null
var _godot_pos: Vector2 = Vector2.ZERO   # BUTTON_POS 经 to_godot 转换（源 800×480→Godot 960×640）


func setup() -> void:
	_godot_pos = BattleViewCoords.to_godot(BUTTON_POS.x, BUTTON_POS.y)
	position = _godot_pos
	scale = Vector2(BUTTON_SCALE, BUTTON_SCALE)
	var content := CONTENT_SCENE.instantiate()
	add_child(content)   # Control 组件 content 挂 panel 自身（坑 7，坐标原点 = btn 原点）
	_btn = content.get_node("%NextBtn") as TextureButton
	_btn.pressed.connect(_on_pressed)


# 源 showNextButton（:1392-1404）：setVisible+setEnabled + 摆动动画。
func show_button() -> void:
	_btn.visible = true
	_btn.disabled = false
	if _swing_tween:
		_swing_tween.kill()
	# 源 :1400-1402 CCRepeatForever(MoveBy(30,0)+MoveBy(-30,0))
	_swing_tween = create_tween().set_loops()
	_swing_tween.tween_property(self, "position:x", _godot_pos.x + SWING_DIST, SWING_DURATION)
	_swing_tween.tween_property(self, "position:x", _godot_pos.x, SWING_DURATION)


func hide_button() -> void:
	_btn.visible = false
	_btn.disabled = true
	if _swing_tween:
		_swing_tween.kill()
		_swing_tween = null
	position.x = _godot_pos.x


func _on_pressed() -> void:
	pressed.emit()


func is_button_visible() -> bool:
	return _btn.visible
