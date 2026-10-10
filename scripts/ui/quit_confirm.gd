class_name QuitConfirm
extends Control

## 退出游戏确认框（View 层）— 受控增强（2026-10-09 用户需求：返回键/关窗防误退）。
## 文案 tools.exitgame="确定退出游戏?"（源语言包自带，8 语言齐）；复用
## shop_refresh_confirm_content.tscn 通用结构（Bg/Line/MsgLabel/CancelBtn/OkBtn），
## 不新建 tscn。挂 HudOverlay（CanvasLayer 150）→ 任何界面触发都恒在全部弹窗之上。

signal confirmed

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/shop_refresh_confirm_content.tscn")
const MSG_LSTR: String = "tools.exitgame"
const CANCEL_LSTR: String = "CHATCONFIG.CANCEL"
const CONFIRM_LSTR: String = "CHATCONFIG.CONFIRM"
const MSG_FALLBACK: String = "确定退出游戏?"
const CANCEL_FALLBACK: String = "取消"
const CONFIRM_FALLBACK: String = "确定"

var _cm: Variant = null   # setup 注入 ConfigManager；null 降级中文（源同样中文先例）


func _ready() -> void:
	# set_anchors_and_offsets_preset 才真正拉满父 rect（set_anchors_preset 保持
	# 0×0 当前 rect 不变 → 尺寸恒 0，2026-09-10 召唤确认框根修判例同因）。
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 模态拦截底层
	_build_content()


func setup(p_cm: Variant = null) -> void:
	_cm = p_cm


func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	add_child(content)
	var msg: Label = content.get_node("%MsgLabel") as Label
	msg.text = _lstr(MSG_LSTR, MSG_FALLBACK)
	# 共享 content 的 MsgLabel 左对齐（源 dialog 长文案样式）；本弹窗文案短
	# （7 字），左对齐视觉偏左 91 逻辑 px（2026-10-09 像素实测），改居中。
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	(content.get_node("%CancelBtn") as Button).text = _lstr(CANCEL_LSTR, CANCEL_FALLBACK)
	(content.get_node("%CancelBtn") as Button).pressed.connect(queue_free)
	(content.get_node("%OkBtn") as Button).text = _lstr(CONFIRM_LSTR, CONFIRM_FALLBACK)
	(content.get_node("%OkBtn") as Button).pressed.connect(_on_ok)


func _lstr(key: String, fallback: String) -> String:
	if _cm != null and _cm.has_method("get_lstr"):
		var s: String = String(_cm.get_lstr(key))
		return s if s != key else fallback
	return fallback


func _on_ok() -> void:
	confirmed.emit()
	queue_free()
