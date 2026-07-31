class_name BattleAutoButton
extends Control

## 自动战斗按钮 — 照源 battle_scene.lua resetUI :1207-1257（auto_btn @734,60 CCMenuItemToggle
## autocombat_on/off）+ autoCombatHandler :1016-1029 翻译（Phase 4）。
## ⚠️ 资源 autocombat_on/off.png 硬缺（源项目 + HC/Client 均未导出，同 .abc 阻塞）→ 降级 Button
## text toggle（"自动战斗 开/关"，复刻铁律允许资源缺降级，同 popup/timer Label）。
##
## 重构（2026-07-18，hero_detail 范式）：Button 静态节点搬进
## scenes/battle/battle_auto_button_content.tscn（位置/size 编辑器可视化调），
## Control 组件 content 挂 panel 自身（坑 7，坐标原点 = button 原点）。
## setup instantiate + get_node("%AutoButton") as Button 取节点 + _apply_label fill on/off 文案。

const CONTENT_SCENE: PackedScene = preload("res://scenes/battle/battle_auto_button_content.tscn")
const GODOT_POS: Vector2 = Vector2(814.0, 500.0)  # 原 to_godot(734,60)=(734+80,560-60)，HUD 原生坐标
const LABEL_ON: String = "自动战斗 开"
const LABEL_OFF: String = "自动战斗 关"

signal toggled(on: bool)

var _on: bool = false
var _button: Button = null


func setup(initial_on: bool = false, visible_default: bool = true) -> void:
	_on = initial_on
	position = GODOT_POS
	var content := CONTENT_SCENE.instantiate()
	add_child(content)   # Control 组件 content 挂 panel 自身（坑 7）
	_button = content.get_node("%AutoButton") as Button
	_apply_label()
	_button.pressed.connect(_on_pressed)
	visible = visible_default


func _apply_label() -> void:
	if _button != null:
		_button.text = LABEL_ON if _on else LABEL_OFF


func _on_pressed() -> void:
	_on = not _on
	_apply_label()
	toggled.emit(_on)


func set_on(on: bool) -> void:
	_on = on
	_apply_label()


func is_on() -> bool:
	return _on


func show_button() -> void:
	visible = true


func hide_button() -> void:
	visible = false
