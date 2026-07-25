class_name StageResetConfirm
extends Control

## 精英关次数重置确认框 — 照源 stagedetail.lua:514-535 doPayReset showConfirmDialog。
## spriteLabel + 取消/确认按钮，确认 → emit confirmed（调用方执行 reset）。
## 单机化：源通用 showConfirmDialog → 独立 Control（Panel+Button 原生控件，无贴图依赖）。
## 范式同 CrusadeResetConfirm（msg 动态传入，stage_detail 调用方填 cost/times）。
## Phase A 静态化：shade/frame/msg/cancel/ok 从 stage_reset_confirm_content.tscn instantiate。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/stage_reset_confirm_content.tscn")
const LSTR_CANCEL_KEY: String = "CHATCONFIG.CANCEL"
const LSTR_CONFIRM_KEY: String = "CHATCONFIG.CONFIRM"
const CANCEL_TEXT_FALLBACK: String = "取消"
const OK_TEXT_FALLBACK: String = "确认"
const UPGRADE_RES: String = "res://assets/ui/alpha/HVGA/herodetail-upgrade.png"
const UPGRADE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-upgrade-mask.png"
const UPGRADE_CAP: Rect2 = Rect2(20.0, 20.0, 40.0, 29.0)

signal confirmed

var _cm: Variant = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 拦截底层（模态）
	var content: Control = CONTENT_SCENE.instantiate() as Control
	add_child(content)
	_fill_content(content)


# 调用方（stage_detail_panel._on_reset_pressed）注入 msg 文案（已含 cost/times）+ cm 查 LSTR。
func setup_msg(msg: String, p_cm: Variant) -> void:
	_cm = p_cm
	# _ready 后调用需手动 fill（_ready 先于 setup_msg 执行，content 已 instantiate）。
	# 改用 call_deferred 保证 _ready 已跑完（content 子节点已挂载）。
	call_deferred("_apply_msg", msg)


func _apply_msg(msg: String) -> void:
	var content: Node = get_child(0) if get_child_count() > 0 else null
	if content == null:
		return
	var msg_lbl: Label = content.get_node_or_null("%Msg") as Label
	if msg_lbl != null:
		msg_lbl.text = msg


func _fill_content(content: Control) -> void:
	var cancel_btn: Button = content.get_node("%CancelBtn") as Button
	UiScale9Button.apply_with_label(cancel_btn, UPGRADE_RES, UPGRADE_PRESS_RES, UPGRADE_CAP,
		_lstr(LSTR_CANCEL_KEY, CANCEL_TEXT_FALLBACK))
	cancel_btn.pressed.connect(_close)
	var ok_btn: Button = content.get_node("%OkBtn") as Button
	UiScale9Button.apply_with_label(ok_btn, UPGRADE_RES, UPGRADE_PRESS_RES, UPGRADE_CAP,
		_lstr(LSTR_CONFIRM_KEY, OK_TEXT_FALLBACK))
	ok_btn.pressed.connect(_on_ok)


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
