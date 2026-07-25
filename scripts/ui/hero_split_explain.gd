class_name HeroSplitExplain
extends Control

## 分解规则说明弹窗（View 层）— 照源 ui/herosplit/explain.lua createContent（4 行 LSTR explain.1.10.1.001-004）。
## 文字照源（含「选碎片转化灵魂石」说明）；实际单机化行为简化（hero_manager.split 固定返还专属碎片，不选碎片）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/hero_split_explain_content.tscn")
const EXPLAIN_KEYS: Array[String] = [
	"explain.1.10.1.001",
	"explain.1.10.1.002",
	"explain.1.10.1.003",
	"explain.1.10.1.004",
]
const FONT_COLOR: Color = Color(238.0 / 255.0, 204.0 / 255.0, 119.0 / 255.0)
const FALLBACK_TEXT: String = "1.分解英雄会将英雄重置为初始状态，同时返还培养过程中消耗的所有材料。\n2.分解英雄时，玩家可以选择另一个想要获得的英雄。\n3.只能在规定的时间内分解特定英雄。\n4.英雄一旦分解，无法撤销，请慎重操作。"

var cm: Variant = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 拦截底层（模态）
	_build_content()


func setup(p_cm: Variant = null) -> void:
	cm = p_cm


func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	add_child(content)
	var lbl: Label = content.get_node("%ExplainLabel") as Label
	lbl.text = _explain_text()
	lbl.add_theme_color_override("font_color", FONT_COLOR)
	(content.get_node("%CloseBtn") as TextureButton).pressed.connect(_close)


func _explain_text() -> String:
	if cm == null:
		return FALLBACK_TEXT
	var lines: Array[String] = []
	for key in EXPLAIN_KEYS:
		lines.append(str(cm.get_lstr(key)))
	return "\n".join(lines)


func _close() -> void:
	queue_free()
