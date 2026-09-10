class_name SummonConfirm
extends Control

## 召唤确认框（View 层）— 照源 heropackage.lua:160-172 clickMissHero showConfirmDialog
##（「召唤英雄需要花费 N 金币，是否召唤?」+ 取消/确认 → doSummon）。
## 视觉复用 shop_refresh_confirm_content.tscn（shade/frame/msg/cancel/ok 通用确认框静态树，
## ShopRefreshConfirm 范式）；2026-09-09 召唤动画链补全（此前点击直接召唤无确认无动画）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/shop_refresh_confirm_content.tscn")
const CANCEL_LSTR: String = "CHATCONFIG.CANCEL"
const CONFIRM_LSTR: String = "CHATCONFIG.CONFIRM"
const CANCEL_FALLBACK: String = "取消"
const CONFIRM_FALLBACK: String = "确定"
# 绘制层置顶：盖宿主 content 内 relative z（hero_package tab label 15 最大）；恒低于
# PopWindow 栈步进 100——并存弹窗栈序不受扰。输入命中走树序（dlg 恒最后 add）无需 z。
const DIALOG_Z: int = 50

signal confirmed

var _msg_text: String = ""
var _cm: Variant = null


func _ready() -> void:
	# 2026-09-10 根修：set_anchors_and_offsets_preset 才真正拉满父 rect——
	# set_anchors_preset 在树内调用会调整 offsets 保持当前 rect(0×0) 不变 →
	# 尺寸恒 0（不可见+无命中+模态失效，用户实机「点击可召唤英雄无反应」根因）。
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 拦截底层（模态）
	z_index = DIALOG_Z   # 绘制盖宿主 content 内 z 10~15 的列表/tab（z 只管绘制；命中走树序）
	_build_content()


# p_cm 注入 ConfigManager 供按钮文字 LSTR 化；msg 由调用方 get_lstr(key) % cost 格式化后传入。
func set_message(text: String, p_cm: Variant = null) -> void:
	_msg_text = text
	_cm = p_cm
	var lbl: Label = _find_msg_label()
	if lbl != null:
		lbl.text = text


func get_message() -> String:
	return _msg_text


func _find_msg_label() -> Label:
	if get_child_count() == 0:
		return null
	return (get_child(0) as Node).get_node_or_null("%MsgLabel") as Label


func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	add_child(content)
	var msg: Label = content.get_node("%MsgLabel") as Label
	msg.text = _msg_text
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
