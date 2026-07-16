class_name CrusadeResetConfirm
extends Control

## 远征重置确认框 — 照源 crusade.lua:665-679 showConfirmDialog。
## spriteLabel + 取消/确认按钮，确认 → emit confirmed（调用方执行 reset）。
## 单机化：源 ed.showConfirmDialog 通用弹窗 → 独立 Control（Panel+Button 原生控件，无贴图依赖）。
## 通用确认框组件（后续 mail overfull 等可复用此范式）。
## P1（2026-07-16）：文字 cm.get_lstr 化（源 LSTR key，GameData.config 解析，fallback 中文兜底）。

const FRAME_POS: Vector2 = Vector2(330.0, 250.0)
const FRAME_SIZE: Vector2 = Vector2(300.0, 130.0)
const MSG_POS: Vector2 = Vector2(0.0, 25.0)
const MSG_SIZE: Vector2 = Vector2(300.0, 30.0)
const BTN_SIZE: Vector2 = Vector2(90.0, 35.0)
const CANCEL_POS: Vector2 = Vector2(40.0, 75.0)
const OK_POS: Vector2 = Vector2(170.0, 75.0)
const SHADE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.5)
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
	_build()


# 源 LSTR 走 GameData.config（autoload）；未初始化（headless 测试）fallback 中文兜底。
func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = GameData.config
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


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
	var lbl := Label.new()
	lbl.text = _lstr(LSTR_MSG_KEY, MSG_TEXT_FALLBACK)
	lbl.position = MSG_POS
	lbl.size = MSG_SIZE
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(lbl)
	var cancel: Button = UiScale9Button.make(UPGRADE_RES, UPGRADE_PRESS_RES, CANCEL_POS, BTN_SIZE, UPGRADE_CAP, _lstr(LSTR_CANCEL_KEY, CANCEL_TEXT_FALLBACK))
	cancel.pressed.connect(_close)
	frame.add_child(cancel)
	var ok: Button = UiScale9Button.make(UPGRADE_RES, UPGRADE_PRESS_RES, OK_POS, BTN_SIZE, UPGRADE_CAP, _lstr(LSTR_CONFIRM_KEY, OK_TEXT_FALLBACK))
	ok.pressed.connect(_on_ok)
	frame.add_child(ok)


func _close() -> void:
	queue_free()


# 源 :671-677 rightHandler → emit confirmed（调用方接信号执行 reset）。
func _on_ok() -> void:
	emit_signal("confirmed")
	queue_free()
