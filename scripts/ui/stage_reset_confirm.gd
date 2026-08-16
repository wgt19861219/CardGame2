class_name StageResetConfirm
extends Control

## 精英关次数重置确认框 — 照源 stagedetail.lua:514-535 doPayReset →
## dialog.lua confirmDialog（ed.showConfirmDialog=createWithText :180-382）。
## bg/line/正文/左右 Scale9 按钮全静态进 stage_reset_confirm_content.tscn；
## 按钮三态走 theme DialogConfirmBtn（cap(20,20,40,29) 直译，批 3 两件套）。
## 单机化：源通用 ed.showConfirmDialog → 独立 Control；确认 → emit confirmed
## （调用方 stage_detail_panel._do_reset_elite 执行 reset）。
## 受控裁剪（通用 dialog 框架行为，未实现）：bg 开/关 scale 动画（0.2s
## EaseBackOut/In）、openWindow/closeWindow/clickConfirm* 音效、right 0.5s 防抖。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/stage_reset_confirm_content.tscn")
const LSTR_CANCEL_KEY: String = "CHATCONFIG.CANCEL"
const LSTR_OK_KEY: String = "FASTSELL.GOOD"
const CANCEL_TEXT_FALLBACK: String = "取消"
const OK_TEXT_FALLBACK: String = "好的"

signal confirmed

var _cm: Variant = null
var _content: Control = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 拦截底层（模态，源 layer touchEnabled）
	_content = CONTENT_SCENE.instantiate() as Control
	add_child(_content)
	_wire_buttons()


# 调用方（stage_detail_panel._on_reset_pressed）注入 msg 文案（已含 cost/times）+ cm 查 LSTR。
# _ready 先于 setup_msg 执行：按钮文字先落 fallback，cm 注入后 _apply_msg 刷新。
func setup_msg(msg: String, p_cm: Variant) -> void:
	_cm = p_cm
	call_deferred("_apply_msg", msg)


func _apply_msg(msg: String) -> void:
	if _content == null:
		return
	var msg_lbl: Label = _content.get_node_or_null("%Msg") as Label
	if msg_lbl != null:
		msg_lbl.text = msg
	_refresh_button_texts()


func _wire_buttons() -> void:
	var cancel_btn: Button = _content.get_node("%CancelBtn") as Button
	cancel_btn.pressed.connect(_close)
	var ok_btn: Button = _content.get_node("%OkBtn") as Button
	ok_btn.pressed.connect(_on_ok)
	_refresh_button_texts()


# 按钮文案：left 默认 T(LSTR("CHATCONFIG.CANCEL"))，right 默认 T(LSTR("FASTSELL.GOOD"))
# （源 dialog.lua:291-296/:312-317，right 非 CHATCONFIG.CONFIRM）。
func _refresh_button_texts() -> void:
	(_content.get_node("%CancelBtn") as Button).text = _lstr(LSTR_CANCEL_KEY, CANCEL_TEXT_FALLBACK)
	(_content.get_node("%OkBtn") as Button).text = _lstr(LSTR_OK_KEY, OK_TEXT_FALLBACK)


func _lstr(key: String, fallback: String) -> String:
	if _cm != null and _cm.has_method("get_lstr"):
		var v: String = _cm.get_lstr(key)
		return v if v != key else fallback
	return fallback


func _close() -> void:
	queue_free()


func _on_ok() -> void:
	emit_signal("confirmed")
	queue_free()
