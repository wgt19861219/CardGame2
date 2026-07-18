class_name HeroSplitConfirm
extends Control

## 分解确认框 — 照源 herosplit/window.lua:88-103 firstConfirm ed.popConfirmDialog。
## "确认分解 {name}？" + 取消/确认，确认 → emit confirmed（调用方执行 split）。
## popConfirmDialog sell_number_button capInsets 15.63,15.63,19.53,15.63 + 浅金 ccc3(234,225,205)（confirmdialog.lua）。
## 重构（2026-07-18）：静态节点（shade/frame/msg/cancel/ok）固化进
## scenes/ui/hero_split_confirm_content.tscn（位置/size 编辑器可视化调，照 hero_detail 范式）。
## Control 非 PopWindow，无 container → content 直接挂自身（同 shortcut/battle_prepare 范式）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/hero_split_confirm_content.tscn")
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
	_build_content()


func set_message(text: String) -> void:
	_msg_text = text
	if _msg_label != null:
		_msg_label.text = text


# 建 UI 内容：静态节点从 .tscn instantiate（位置/size .tscn 固化）+ fill 动态数据/样式 + 信号绑定。
# Control 非 PopWindow，无 container → content 直接挂自身（同 shortcut/battle_prepare 范式）。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	add_child(content)
	_msg_label = content.get_node("%MsgLabel") as Label
	_msg_label.text = _msg_text
	var cancel: Button = content.get_node("%CancelBtn") as Button
	UiScale9Button.apply_with_label(cancel, BTN_RES, BTN_PRESS_RES, BTN_CAP, CANCEL_TEXT, BTN_LABEL_COLOR)
	cancel.pressed.connect(_close)
	var ok: Button = content.get_node("%OkBtn") as Button
	UiScale9Button.apply_with_label(ok, BTN_RES, BTN_PRESS_RES, BTN_CAP, OK_TEXT, BTN_LABEL_COLOR)
	ok.pressed.connect(_on_ok)


func _close() -> void:
	queue_free()


# 源 :100-102 rightHandler → emit confirmed（调用方接信号执行 secondConfirm split）。
func _on_ok() -> void:
	emit_signal("confirmed")
	queue_free()
