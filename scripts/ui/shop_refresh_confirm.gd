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
# 2026-09-10 照源修正：源 dialog.lua:304-310 rightText 默认 T(LSTR("FASTSELL.GOOD"))="好的"
# （market/shop.lua doClickRefresh 未传 rightText），非 CHATCONFIG.CONFIRM"确定"。
const CONFIRM_LSTR: String = "FASTSELL.GOOD"
const CANCEL_FALLBACK: String = "取消"   # cm 未注入降级（源同样中文）
const CONFIRM_FALLBACK: String = "好的"

signal confirmed

var _msg_text: String = "花费钻石刷新？"
var _msg_label: Label = null
var _cm: Variant = null   # 由 set_message 注入，供按钮文字 LSTR 化


func _ready() -> void:
	# 2026-09-10 根修：set_anchors_and_offsets_preset 才真正拉满父 rect——
	# set_anchors_preset 在树内调用会调整 offsets 保持当前 rect(0×0) 不变 → 尺寸恒 0
	# （商店刷新确认框自 P1-8 起从未真正显示过，SummonConfirm 复用带进召唤链后暴露）。
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 拦截底层（模态）
	z_index = 50   # 绘制层盖宿主 content 内 relative z（ SummonConfirm.DIALOG_Z 同值同因）
	_build_content()


# p_cm 注入 ConfigManager 供按钮文字 LSTR 化（CHATCONFIG.CANCEL/CONFIRM）；null 则降级字面量。
func set_message(text: String, p_cm: Variant = null) -> void:
	_msg_text = text
	_cm = p_cm
	if _msg_label != null:
		_msg_label.text = text


# 建 UI 内容：静态节点（shade/bg/line/msg/cancel/ok）从 .tscn instantiate（位置/size .tscn 固化）。
# 2026-09-10 召唤按钮变形根修：content 照源 dialog.lua 直译重建（dialog_bg 贴图框 + 120x49
# 按钮 + line 分隔线，同构 stage_reset_confirm_content.tscn）；cancel/ok 样式走 theme
# variation DialogConfirmBtn（tscn 声明三态），此处只填文字。
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
