class_name LadderBuyConfirm
extends Control

## 竞技场购买次数确认框 — 照源 pvp.lua:1867-1887 buyPvpTime → dialog.lua
## confirmDialog 家族 createWithSprite 分支（info.sprite 空 CCSprite 存在，
## 同 crusade_reset_confirm 口径：spriteLabel 中心 bg 局部 (172,135)）。
## bg/line/正文/左右 Scale9 按钮全静态进 ladder_buy_confirm_content.tscn。
## 单机化：源 rightHandler 发 ladder _buy_battle_chance → confirmed 信号
## （调用方 ladder_panel._do_buy 执行购买）；源钻石不足 toRecharge 弹窗在
## 调用方预检（Toast「钻石不足」，同 stage_detail_panel 2026-09-17 去充值引导口径）。
## 受控裁剪（同 Task 1 口径）：bg 开/关 scale 动画、openWindow/closeWindow 音效。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/ladder_buy_confirm_content.tscn")
const LSTR_CANCEL_KEY: String = "CHATCONFIG.CANCEL"
const LSTR_OK_KEY: String = "CHATCONFIG.CONFIRM"
const CANCEL_TEXT_FALLBACK: String = "取消"
const OK_TEXT_FALLBACK: String = "确定"

signal confirmed

var _cm: Variant = null
var _content: Control = null


func _ready() -> void:
	# set_anchors_and_offsets_preset（非 set_anchors_preset）：进树后调用时后者按
	# keep_offsets 语义保持当前 0×0 rect → 算出负 offset，确认框不可见（2026-10-09
	# bridge 实测 @Control@293 size=(0,0) 复现；PopWindow 系进树前 setup 无此坑）。
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 拦截底层（模态，源 layer touchEnabled）
	z_index = 100   # 宿主面板（LadderPanel z_index=100）之上（同挂 MainScene，默认 0 会被面板盖住）
	_content = CONTENT_SCENE.instantiate() as Control
	add_child(_content)
	_wire_buttons()


# 调用方（ladder_panel._do_buy）注入 msg 文案（已含 buy 次数/cost 参数）+ cm 查 LSTR。
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
	(_content.get_node("%CancelBtn") as Button).pressed.connect(queue_free)
	(_content.get_node("%OkBtn") as Button).pressed.connect(_on_ok)


func _refresh_button_texts() -> void:
	if _cm == null:
		return
	(_content.get_node("%CancelBtn") as Button).text = _lstr(LSTR_CANCEL_KEY, CANCEL_TEXT_FALLBACK)
	(_content.get_node("%OkBtn") as Button).text = _lstr(LSTR_OK_KEY, OK_TEXT_FALLBACK)


func _lstr(key: String, fallback: String) -> String:
	if _cm != null:
		var v: String = _cm.get_lstr(key)
		return v if v != key else fallback
	return fallback


func _on_ok() -> void:
	emit_signal("confirmed")
	queue_free()
