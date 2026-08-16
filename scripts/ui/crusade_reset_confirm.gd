class_name CrusadeResetConfirm
extends Control

## 远征重置确认框 — 照源 crusade.lua:660-680 resetBattle → dialog.lua
## confirmDialog 家族 showDialog（info.sprite 空 CCSprite 存在 → createWithSprite
## 分支 :339-363：spriteLabel 中心 ccp(172,135)，非 createWithText 的 180）。
## bg/line/正文/左右 Scale9 按钮全静态进 crusade_reset_confirm_content.tscn；
## 按钮三态走 theme DialogConfirmBtn（Task 1 同款，cap(20,20,40,29) 直译）。
## 单机化：源 rightHandler 发 reset 消息 → confirmed 信号（调用方
## crusade_panel._on_reset_confirmed 执行 reset）。
## 受控裁剪：空 sprite(:346) 无贴图零视觉不建节点（分支布局后果 x=172 已保留）、
## bg 开/关 scale 动画、openWindow/closeWindow 音效（Task 1 同口径）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/crusade_reset_confirm_content.tscn")
const LSTR_MSG_KEY: String = "CRUSADE.END_THIS_EXPEDITION_AND_START_OVER"
const MSG_TEXT_FALLBACK: String = "是否结束本次远征并重新开始？"
const LSTR_CANCEL_KEY: String = "CHATCONFIG.CANCEL"
const LSTR_OK_KEY: String = "CHATCONFIG.CONFIRM"
const CANCEL_TEXT_FALLBACK: String = "取消"
const OK_TEXT_FALLBACK: String = "确定"

signal confirmed


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 拦截底层（模态，源 layer touchEnabled）
	var content: Control = CONTENT_SCENE.instantiate() as Control
	add_child(content)   # Control 非 PopWindow：content 挂 panel 自身
	_fill_content(content)


# fill：msg/按钮文案 LSTR（GameData.config，缺失回 fallback）+ 信号接线。
# 文案键照源 crusade.lua:668-670：CANCEL / msg；right 显式传 CHATCONFIG.CONFIRM
# （"确定"，confirmDialog.create 默认 FASTSELL.GOOD 是未传 rightText 的路径）。
func _fill_content(content: Control) -> void:
	var msg_lbl: Label = content.get_node("%Msg") as Label
	msg_lbl.text = _lstr(LSTR_MSG_KEY, MSG_TEXT_FALLBACK)
	var cancel_btn: Button = content.get_node("%CancelBtn") as Button
	cancel_btn.text = _lstr(LSTR_CANCEL_KEY, CANCEL_TEXT_FALLBACK)
	cancel_btn.pressed.connect(_close)
	var ok_btn: Button = content.get_node("%OkBtn") as Button
	ok_btn.text = _lstr(LSTR_OK_KEY, OK_TEXT_FALLBACK)
	ok_btn.pressed.connect(_on_ok)


func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = GameData.config
	if cfg != null:
		var v: String = cfg.get_lstr(key)
		return v if v != key else fallback
	return fallback


func _close() -> void:
	queue_free()


func _on_ok() -> void:
	emit_signal("confirmed")
	queue_free()
