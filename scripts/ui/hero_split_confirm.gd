class_name HeroSplitConfirm
extends Control

## 分解确认框 — 照源 herosplit/window.lua:88-103 firstConfirm ed.popConfirmDialog。
## "确认分解 {name}？" + 取消/确认，确认 → emit confirmed（调用方执行 split）。
## popConfirmDialog sell_number_button capInsets 15.63,15.63,19.53,15.63 + 浅金 ccc3(234,225,205)（confirmdialog.lua）。

const FRAME_POS: Vector2 = Vector2(330.0, 250.0)
const FRAME_SIZE: Vector2 = Vector2(300.0, 130.0)
const MSG_POS: Vector2 = Vector2(0.0, 25.0)
const MSG_SIZE: Vector2 = Vector2(300.0, 30.0)
const BTN_SIZE: Vector2 = Vector2(90.0, 35.0)
const CANCEL_POS: Vector2 = Vector2(40.0, 75.0)
const OK_POS: Vector2 = Vector2(170.0, 75.0)
const SHADE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.5)
# 源 confirmdialog.lua popConfirmDialog（herosplit:98 调）sell_number_button capInsets 15.63,15.63,19.53,15.63 + 浅金。
const BTN_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button.png"
const BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button_down.png"
const BTN_CAP: Rect2 = Rect2(15.63, 15.63, 19.53, 15.63)
const BTN_LABEL_COLOR: Color = Color(234.0 / 255.0, 225.0 / 255.0, 205.0 / 255.0)
const CANCEL_TEXT: String = "取消"
const OK_TEXT: String = "确认"
const DEFAULT_MSG: String = "确认分解该英雄？"   # 源 :99 window.1.10.1.003 含 name（下轮补 Unit Display Name）

signal confirmed

var _msg_text: String = DEFAULT_MSG
var _msg_label: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 拦截底层（模态）
	_build()


func set_message(text: String) -> void:
	_msg_text = text
	if _msg_label != null:
		_msg_label.text = text


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
	_msg_label = Label.new()
	_msg_label.text = _msg_text
	_msg_label.position = MSG_POS
	_msg_label.size = MSG_SIZE
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(_msg_label)
	var cancel: Button = UiScale9Button.make(BTN_RES, BTN_PRESS_RES, CANCEL_POS, BTN_SIZE, BTN_CAP, CANCEL_TEXT, BTN_LABEL_COLOR)
	cancel.pressed.connect(_close)
	frame.add_child(cancel)
	var ok: Button = UiScale9Button.make(BTN_RES, BTN_PRESS_RES, OK_POS, BTN_SIZE, BTN_CAP, OK_TEXT, BTN_LABEL_COLOR)
	ok.pressed.connect(_on_ok)
	frame.add_child(ok)


func _close() -> void:
	queue_free()


# 源 :100-102 rightHandler → emit confirmed（调用方接信号执行 secondConfirm split）。
func _on_ok() -> void:
	emit_signal("confirmed")
	queue_free()
