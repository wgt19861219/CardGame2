class_name ShopRefreshConfirm
extends Control

## 商店刷新确认框（View 层）— 照源 shop.lua:302-313 doClickRefresh showConfirmDialog。
## "花费 X 钻石刷新（剩余 Y 次）" + 取消/确认，确认 → emit confirmed（调用方执行 refresh）。
## 单机化：源 ed.showConfirmDialog 通用弹窗 → 独立 Control（CrusadeResetConfirm 范式，无贴图依赖）。
## P1-8（2026-07-11）：替 shop_panel _on_refresh 的 Toast 降级（源 :311 showConfirmDialog 消耗预览）。
## 重构（2026-07-18，hero_detail 范式）：shade/frame/msg/cancel/ok 静态化进
## scenes/ui/shop_refresh_confirm_content.tscn（位置/size 编辑器可视化调）。Control 非 PopWindow，
## content 挂 panel 自身（同 shortcut_panel 范式）。cancel/ok 普通 Button 运行时套 Scale9 样式。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/shop_refresh_confirm_content.tscn")
const CANCEL_LSTR: String = "CHATCONFIG.CANCEL"
const CONFIRM_LSTR: String = "CHATCONFIG.CONFIRM"
const CANCEL_FALLBACK: String = "取消"   # cm 未注入降级（源同样中文）
const CONFIRM_FALLBACK: String = "确定"

signal confirmed

var _msg_text: String = "花费钻石刷新？"
var _msg_label: Label = null
var _cm: Variant = null   # 由 set_message 注入，供按钮文字 LSTR 化


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 拦截底层（模态）
	_build_content()


# p_cm 注入 ConfigManager 供按钮文字 LSTR 化（CHATCONFIG.CANCEL/CONFIRM）；null 则降级字面量。
func set_message(text: String, p_cm: Variant = null) -> void:
	_msg_text = text
	_cm = p_cm
	if _msg_label != null:
		_msg_label.text = text


# 建 UI 内容：静态节点（shade/frame/msg/cancel/ok）从 .tscn instantiate（位置/size .tscn 固化）。
# cancel/ok 按钮样式走 theme variation ShopConfirmBtn（tscn 声明三态，2026-08-22 巡检迁移
# 旧运行时 UiScale9Button.apply_with_label，照 MailOverfullBtn 先例），此处只填文字。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	add_child(content)
	_msg_label = content.get_node("%MsgLabel") as Label
	_msg_label.text = _msg_text
	var cancel: Button = content.get_node("%CancelBtn") as Button
	cancel.text = _lstr(CANCEL_LSTR, CANCEL_FALLBACK)
	cancel.pressed.connect(queue_free)
	var ok: Button = content.get_node("%OkBtn") as Button
	ok.text = _lstr(CONFIRM_LSTR, CONFIRM_FALLBACK)
	ok.pressed.connect(_on_ok)


func _lstr(key: String, fallback: String) -> String:
	if _cm != null and _cm.has_method("get_lstr"):
		var s: String = String(_cm.get_lstr(key))
		return s if s != key else fallback
	return fallback


func _on_ok() -> void:
	confirmed.emit()
	queue_free()
