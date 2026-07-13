class_name CrusadeResetConfirm
extends Control

## 远征重置确认框 — 照源 crusade.lua:665-679 showConfirmDialog。
## spriteLabel"结束本次远征并重新开始" + 取消/确认按钮，确认 → emit confirmed（调用方执行 reset）。
## 单机化：源 ed.showConfirmDialog 通用弹窗 → 独立 Control（Panel+Button 原生控件，无贴图依赖）。
## 通用确认框组件（后续 mail overfull 等可复用此范式）。

const FRAME_POS: Vector2 = Vector2(330.0, 250.0)
const FRAME_SIZE: Vector2 = Vector2(300.0, 130.0)
const MSG_POS: Vector2 = Vector2(0.0, 25.0)
const MSG_SIZE: Vector2 = Vector2(300.0, 30.0)
const BTN_SIZE: Vector2 = Vector2(90.0, 35.0)
const CANCEL_POS: Vector2 = Vector2(40.0, 75.0)
const OK_POS: Vector2 = Vector2(170.0, 75.0)
const SHADE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.5)
# 源 :668 LSTR CRUSADE.END_THIS_EXPEDITION_AND_START_OVER
const MSG_TEXT: String = "结束本次远征并重新开始？"
# 源 :669/670 LSTR CHATCONFIG.CANCEL/CONFIRM
const CANCEL_TEXT: String = "取消"
const OK_TEXT: String = "确认"
# 源 dialog.lua:273/292 showConfirmDialog（crusade.lua:679）herodetail-upgrade Scale9 capInsets 20,20,40,29。
const UPGRADE_RES: String = "res://assets/ui/alpha/HVGA/herodetail-upgrade.png"
const UPGRADE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-upgrade-mask.png"
const UPGRADE_CAP: Rect2 = Rect2(20.0, 20.0, 40.0, 29.0)

signal confirmed


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 拦截底层（模态）
	_build()


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = SHADE_COLOR
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var frame := Panel.new()
	frame.position = FRAME_POS
	frame.size = FRAME_SIZE
	add_child(frame)
	var lbl := Label.new()
	lbl.text = MSG_TEXT
	lbl.position = MSG_POS
	lbl.size = MSG_SIZE
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(lbl)
	var cancel: Button = UiScale9Button.make(UPGRADE_RES, UPGRADE_PRESS_RES, CANCEL_POS, BTN_SIZE, UPGRADE_CAP, CANCEL_TEXT)
	cancel.pressed.connect(_close)
	frame.add_child(cancel)
	var ok: Button = UiScale9Button.make(UPGRADE_RES, UPGRADE_PRESS_RES, OK_POS, BTN_SIZE, UPGRADE_CAP, OK_TEXT)
	ok.pressed.connect(_on_ok)
	frame.add_child(ok)


func _close() -> void:
	queue_free()


# 源 :671-677 rightHandler → emit confirmed（调用方接信号执行 reset）。
func _on_ok() -> void:
	emit_signal("confirmed")
	queue_free()
