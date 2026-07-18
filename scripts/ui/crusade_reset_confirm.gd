class_name CrusadeResetConfirm
extends Control

## 远征重置确认框 — 照源 crusade.lua:665-679 showConfirmDialog。
## spriteLabel + 取消/确认按钮，确认 → emit confirmed（调用方执行 reset）。
## 单机化：源 ed.showConfirmDialog 通用弹窗 → 独立 Control（Panel+Button 原生控件，无贴图依赖）。
## 通用确认框组件（后续 mail overfull 等可复用此范式）。
## P1（2026-07-16）：文字 cm.get_lstr 化（源 LSTR key，GameData.config 解析，fallback 中文兜底）。
## Phase A 静态化（2026-07-18）：shade/frame/msg/cancel/ok 从 procedural 改 instantiate
## crusade_reset_confirm_content.tscn（位置/size .tscn 固化，照 hero_detail 范式）。
## Control 非 PopWindow：content 挂 panel 自身（无 container 字段，参考 shortcut/battle_prepare 范式）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/crusade_reset_confirm_content.tscn")
# 源 :668 LSTR CRUSADE.END_THIS_EXPEDITION_AND_START_OVER
const LSTR_MSG_KEY: String = "CRUSADE.END_THIS_EXPEDITION_AND_START_OVER"
const MSG_TEXT_FALLBACK: String = "结束本次远征并重新开始？"
# 源 :669/670 LSTR CHATCONFIG.CANCEL/CONFIRM
const LSTR_CANCEL_KEY: String = "CHATCONFIG.CANCEL"
const LSTR_CONFIRM_KEY: String = "CHATCONFIG.CONFIRM"
const CANCEL_TEXT_FALLBACK: String = "取消"
const OK_TEXT_FALLBACK: String = "确认"
# 源 dialog.lua:273/292 showConfirmDialog（crusade.lua:679）herodetail-upgrade Scale9 capInsets 20,20,40,29。
const UPGRADE_RES: String = "res://assets/ui/alpha/HVGA/herodetail-upgrade.png"
const UPGRADE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-upgrade-mask.png"
const UPGRADE_CAP: Rect2 = Rect2(20.0, 20.0, 40.0, 29.0)

signal confirmed


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 拦截底层（模态）
	var content: Control = CONTENT_SCENE.instantiate() as Control
	add_child(content)   # Control 非 PopWindow：content 挂 panel 自身
	_fill_content(content)


# 源 LSTR 走 GameData.config（autoload）；未初始化（headless 测试）fallback 中文兜底。
func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = GameData.config
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


# Phase A：静态节点从 .tscn instantiate（位置/size .tscn 固化）+ fill 动态文案/Scale9 + 信号绑定。
func _fill_content(content: Control) -> void:
	var msg_lbl: Label = content.get_node("%Msg") as Label
	msg_lbl.text = _lstr(LSTR_MSG_KEY, MSG_TEXT_FALLBACK)
	var cancel_btn: Button = content.get_node("%CancelBtn") as Button
	UiScale9Button.apply_with_label(cancel_btn, UPGRADE_RES, UPGRADE_PRESS_RES, UPGRADE_CAP, _lstr(LSTR_CANCEL_KEY, CANCEL_TEXT_FALLBACK))
	cancel_btn.pressed.connect(_close)
	var ok_btn: Button = content.get_node("%OkBtn") as Button
	UiScale9Button.apply_with_label(ok_btn, UPGRADE_RES, UPGRADE_PRESS_RES, UPGRADE_CAP, _lstr(LSTR_CONFIRM_KEY, OK_TEXT_FALLBACK))
	ok_btn.pressed.connect(_on_ok)


func _close() -> void:
	queue_free()


# 源 :671-677 rightHandler → emit confirmed（调用方接信号执行 reset）。
func _on_ok() -> void:
	emit_signal("confirmed")
	queue_free()
