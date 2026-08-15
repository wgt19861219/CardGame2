class_name HeroSplitConfirm
extends Control

## 分解确认弹窗（View 层）— 两件套范式（批 1 Task 8，2026-08-15）。
## 静态树在 hero_split_confirm_content.tscn（照源 uieditor/herosplitconfirm.lua
## splitconfirm 二次确认窗直译：alert 框 + 标题"分解提醒" + 转化箭头 + 左右英雄
## icon + 警示两行 + 确认/关闭），本文件只做 fill。
## 单机化：源 firstConfirm 的 popConfirmDialog（"是否确认分解英雄%s？"通用确认）与
## secondConfirm 的 splitconfirm 两段确认合并为本窗一次确认（既有 2026-07-19 决策），
## 文字行用源 splitconfirm ChaosNode 的 confirm.1.10.1.001/002 文案。
## icon：左=当前态（rank/stars/level 照实），右=分解后初始态（rank1/Initial Stars/级1，
## 源 confirm.lua initWindow 两 icon）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/hero_split_confirm_content.tscn")
# ReadheroIcon CONTAINER_SIZE 半宽（挂零尺寸点 icon 中心对齐，fragment_compose 同款）
const ICON_HALF: float = 52.0
const TITLE_KEY: String = "herosplitconfirm.1.10.1.001"
const WARN_KEY: String = "confirm.1.10.1.001"
const ASK_KEY: String = "confirm.1.10.1.002"
const OK_KEY: String = "CHATCONFIG.CONFIRM"
const TITLE_FALLBACK: String = "分解提醒"
const WARN_FALLBACK: String = "分解英雄后无法撤消！！"
const ASK_FALLBACK: String = "是否确认分解英雄"
const OK_FALLBACK: String = "确认"

signal confirmed

var cm: Variant = null
var _hero: HeroInstance = null
var _content: Control = null


func setup(p_hero: HeroInstance, p_cm: Variant = null) -> void:
	_hero = p_hero
	cm = p_cm


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 拦截底层（模态）
	_build_content()


# 建 UI 内容：静态节点从 .tscn instantiate + fill 动态数据 + 信号绑定。
# Control 非 PopWindow，无 container → content 直接挂自身（同 shortcut/battle_prepare 范式）。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	add_child(_content)
	(_content.get_node("Frame/%TitleLabel") as Label).text = _lstr(TITLE_KEY, TITLE_FALLBACK)
	(_content.get_node("Frame/%WarnLabel") as Label).text = _lstr(WARN_KEY, WARN_FALLBACK)
	(_content.get_node("Frame/%AskLabel") as Label).text = "%s%s？" % [_lstr(ASK_KEY, ASK_FALLBACK), _hero_display_name()]
	(_content.get_node("Frame/%OkBtn") as Button).text = _lstr(OK_KEY, OK_FALLBACK)
	_fill_icons()
	(_content.get_node("Frame/%OkBtn") as BaseButton).pressed.connect(_on_ok)
	(_content.get_node("Frame/%CloseBtn") as BaseButton).pressed.connect(_close)


# 左右英雄 icon（源 initWindow：左 createIconByID 当前态、右 createIcon 初始态）。
func _fill_icons() -> void:
	var frame: Control = _content.get_node("Frame") as Control
	var hero_icon := ReadheroIcon.new()
	hero_icon.setup({
		"id": int(_hero.tid),
		"rank": int(_hero.rank),
		"stars": int(_hero.stars),
		"level": int(_hero.level),
	}, cm)
	hero_icon.position = Vector2(-ICON_HALF, -ICON_HALF)
	(frame.get_node("%IconHostL") as Control).add_child(hero_icon)
	var reset_icon := ReadheroIcon.new()
	reset_icon.setup({
		"id": int(_hero.tid),
		"rank": 1,
		"stars": _initial_stars(),
		"level": 1,
	}, cm)
	reset_icon.position = Vector2(-ICON_HALF, -ICON_HALF)
	(frame.get_node("%IconHostR") as Control).add_child(reset_icon)


# 分解后初始星（源 confirm.lua initWindow row["Initial Stars"]）。
func _initial_stars() -> int:
	if cm == null:
		return 0
	return int(cm.get_raw_table(&"Unit").get(str(_hero.tid), {}).get(&"Initial Stars", 0))


func _hero_display_name() -> String:
	if cm == null or _hero == null:
		return ""
	var unit: Dictionary = cm.get_raw_table(&"Unit").get(str(_hero.tid), {})
	var name_key: String = String(unit.get(&"Display Name", ""))
	if name_key == "":
		return ""
	return str(cm.get_lstr(name_key))


func _close() -> void:
	queue_free()


func _lstr(key: String, fallback: String) -> String:
	if cm == null:
		return fallback
	var text: String = str(cm.get_lstr(key))
	return text if text != "" and text != key else fallback


func _on_ok() -> void:
	confirmed.emit()
	queue_free()
