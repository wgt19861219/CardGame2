class_name BattleAutoButton
extends Control

## 自动战斗按钮 — 照源 battle_scene.lua resetUI :1207-1257（auto_btn @734,60 CCMenuItemToggle
## autocombat_on/off）+ autoCombatHandler :1016-1029 翻译（Phase 4）。
## ⚠️ 资源 autocombat_on/off.png 硬缺（源项目 + HC/Client 均未导出，同 .abc 阻塞）→ 降级 Button
## text toggle（"自动战斗 开/关"，复刻铁律允许资源缺降级，同 popup/timer Label）。
## 源 pve stars<3 隐藏（:1224-1226），单机化默认隐藏（visible_default=false），上层 stars>=3 调 show。

const BUTTON_POS: Vector2 = Vector2(734.0, 60.0)   # 源 :1253 ccp(734,60)
const LABEL_ON: String = "自动战斗 开"
const LABEL_OFF: String = "自动战斗 关"

signal toggled(on: bool)

var _on: bool = false
var _button: Button = null


# 源 resetUI auto_btn 装配 + autoCombatHandler。visible_default 源 pve stars<3 → false。
func setup(initial_on: bool = false, visible_default: bool = true) -> void:
	_on = initial_on
	position = BattleViewCoords.to_godot(BUTTON_POS.x, BUTTON_POS.y)
	_button = Button.new()
	_button.text = LABEL_ON if _on else LABEL_OFF
	_button.pressed.connect(_on_pressed)
	add_child(_button)
	visible = visible_default


# 源 autoCombatHandler :1021 — toggle auto_combat（单机化无 pvp alert 分支）。
func _on_pressed() -> void:
	_on = not _on
	_button.text = LABEL_ON if _on else LABEL_OFF
	toggled.emit(_on)


func set_on(on: bool) -> void:
	_on = on
	if _button != null:
		_button.text = LABEL_ON if _on else LABEL_OFF


func is_on() -> bool:
	return _on


# 源 :1224-1229 pve stars>=3 显示（单机化上层调）。
func show_button() -> void:
	visible = true


func hide_button() -> void:
	visible = false
