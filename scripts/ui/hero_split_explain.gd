class_name HeroSplitExplain
extends Control

## 分解规则说明弹窗（View 层）— 两件套范式（批 1 Task 8，2026-08-15）。
## 静态树在 hero_split_explain_content.tscn（照源 uieditor/explainwindow.lua 通用
## 说明窗直译：main_vit_tips 九宫格框 + pvp 标题条 + 滚动区；标题复用通用窗的
## PVP.RULE_DESCRIPTION"规则说明"——herosplit/explain.lua 只 override 文本）。
## 本文件只做 fill：4 行 LSTR 规则文本逐行进 VBox（源 createContent text_list
## 逐行 label + dy=3 堆叠 + 612x0 自动换行 → 宽 478.13 autowrap）。
## 文字照源（含「选碎片转化灵魂石」说明）；实际单机化行为简化（split 固定返还
## 专属碎片，不选碎片）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/hero_split_explain_content.tscn")
const TITLE_KEY: String = "PVP.RULE_DESCRIPTION"
const EXPLAIN_KEYS: Array[String] = [
	"explain.1.10.1.001",
	"explain.1.10.1.002",
	"explain.1.10.1.003",
	"explain.1.10.1.004",
]
const TITLE_FALLBACK: String = "规则说明"
const EXPLAIN_FALLBACKS: Array[String] = [
	"1.分解英雄会将英雄重置为初始状态，同时返还培养过程中消耗的所有材料。",
	"2.分解英雄时，玩家可以选择另一个想要获得的英雄。",
	"3.只能在规定的时间内分解特定英雄。",
	"4.英雄一旦分解，无法撤销，请慎重操作。",
]

var cm: Variant = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 拦截底层（模态）
	_build_content()


func setup(p_cm: Variant = null) -> void:
	cm = p_cm


# 静态树 instantiate + fill 标题/4 行 LSTR 文本 + 关闭信号。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	add_child(content)
	(content.get_node("%TitleLabel") as Label).text = _lstr(TITLE_KEY, TITLE_FALLBACK)
	var vbox: VBoxContainer = content.get_node("%ScrollHost/ListHost") as VBoxContainer
	for i in EXPLAIN_KEYS.size():
		(vbox.get_child(i) as Label).text = _lstr(EXPLAIN_KEYS[i], EXPLAIN_FALLBACKS[i])
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(_close)


func _close() -> void:
	queue_free()


func _lstr(key: String, fallback: String) -> String:
	if cm == null:
		return fallback
	var text: String = str(cm.get_lstr(key))
	return text if text != "" and text != key else fallback
