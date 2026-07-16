class_name ShopRefreshConfirm
extends Control

## 商店刷新确认框（View 层）— 照源 shop.lua:302-313 doClickRefresh showConfirmDialog。
## "花费 X 钻石刷新（剩余 Y 次）" + 取消/确认，确认 → emit confirmed（调用方执行 refresh）。
## 单机化：源 ed.showConfirmDialog 通用弹窗 → 独立 Control（CrusadeResetConfirm 范式，无贴图依赖）。
## P1-8（2026-07-11）：替 shop_panel _on_refresh 的 Toast 降级（源 :311 showConfirmDialog 消耗预览）。

const FRAME_POS: Vector2 = Vector2(330.0, 230.0)
const FRAME_SIZE: Vector2 = Vector2(300.0, 150.0)
const MSG_POS: Vector2 = Vector2(0.0, 20.0)
const MSG_SIZE: Vector2 = Vector2(300.0, 55.0)   # 容纳 SPEND_XXX_TO_REFRESH 两行（含\n）
const BTN_SIZE: Vector2 = Vector2(90.0, 35.0)
const CANCEL_POS: Vector2 = Vector2(40.0, 90.0)
const OK_POS: Vector2 = Vector2(170.0, 90.0)
const SHADE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.5)
# 源 dialog.lua:273/292 showConfirmDialog（shop.lua:311）herodetail-upgrade Scale9 capInsets 20,20,40,29。
const UPGRADE_RES: String = "res://assets/ui/alpha/HVGA/herodetail-upgrade.png"
const UPGRADE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-upgrade-mask.png"
const UPGRADE_CAP: Rect2 = Rect2(20.0, 20.0, 40.0, 29.0)
# 源 dialog 按钮 leftText/rightText 默认（pvp.lua:1875-1876）= CHATCONFIG.CANCEL/CONFIRM。
const CANCEL_LSTR: String = "CHATCONFIG.CANCEL"
const CONFIRM_LSTR: String = "CHATCONFIG.CONFIRM"
const CANCEL_FALLBACK: String = "取消"   # cm 未注入降级（源同样中文）
const CONFIRM_FALLBACK: String = "确定"   # 源 CHATCONFIG.CONFIRM = "确定"

signal confirmed

var _msg_text: String = "花费钻石刷新？"
var _msg_label: Label = null
var _cm: Variant = null   # 由 set_message 注入，供按钮文字 LSTR 化


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 拦截底层（模态）
	_build()


# 源 :308 LSTR SHOP.SPEND_XXX_TO_REFRESH（cost/coinname/times）→ 调用方设消息。
# p_cm 注入 ConfigManager 供按钮文字 LSTR 化（CHATCONFIG.CANCEL/CONFIRM）；null 则降级字面量。
func set_message(text: String, p_cm: Variant = null) -> void:
	_msg_text = text
	_cm = p_cm
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
	_msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	frame.add_child(_msg_label)
	var cancel_text: String = _lstr(CANCEL_LSTR, CANCEL_FALLBACK)
	var cancel: Button = UiScale9Button.make(UPGRADE_RES, UPGRADE_PRESS_RES, CANCEL_POS, BTN_SIZE, UPGRADE_CAP, cancel_text)
	cancel.pressed.connect(queue_free)
	frame.add_child(cancel)
	var ok_text: String = _lstr(CONFIRM_LSTR, CONFIRM_FALLBACK)
	var ok: Button = UiScale9Button.make(UPGRADE_RES, UPGRADE_PRESS_RES, OK_POS, BTN_SIZE, UPGRADE_CAP, ok_text)
	ok.pressed.connect(_on_ok)
	frame.add_child(ok)


func _lstr(key: String, fallback: String) -> String:
	if _cm != null and _cm.has_method("get_lstr"):
		var s: String = String(_cm.get_lstr(key))
		return s if s != key else fallback
	return fallback


# 源 :309 rightHandler → emit confirmed（调用方接信号执行 refresh）。
func _on_ok() -> void:
	confirmed.emit()
	queue_free()
