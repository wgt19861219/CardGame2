class_name MidasRenderer
extends RefCounted

## MidasPanel 渲染 helper（批次 1 第 3 拆分 2026-07-25）。
## 从 midas_panel.gd 外迁的 9 函数（4 历史渲染 + 5 渲染工具），全 static + 状态参数化
## （对齐 task_row_builder/hero_detail_equip_slots 范式）。
## 不含 panel 状态，依赖（host/history/lstr_resolver）全经参数传入；不反向引用 MidasPanel class_name
## （规避 AGENTS.md class_name 跨脚本反模式）。
## Label 字号走 Theme variation（MidasHistoryLabel/MidasConfirmLabel），
## rebuild_history 的 HBox separation 是 Container constant 例外保留（无 variation 概念）。

const OFFSET_X: float = 80.0
const OFFSET_Y: float = 80.0

const HISTORY_LINE_HEIGHT: float = 28.0
const HISTORY_START_Y: float = 2.0
const HISTORY_ROW_X: float = 4.0
const HISTORY_FONT: int = 14
const HISTORY_ICON_H: float = 22.0
const HISTORY_SEP: int = 5
const HISTORY_TOKEN_RES: String = "res://assets/ui/alpha/HVGA/shop_token_icon.png"
const HISTORY_GOLD_RES: String = "res://assets/ui/alpha/HVGA/goldicon_small.png"
const HISTORY_RATIO_RES: Dictionary = {
	2: "res://assets/ui/alpha/HVGA/midas/midas_crip2.png",
	3: "res://assets/ui/alpha/HVGA/midas/midas_crip3.png",
	4: "res://assets/ui/alpha/HVGA/midas/midas_crip10.png",
}
const HISTORY_USE_COLOR: Color = Color(1.0, 246.0 / 255.0, 143.0 / 255.0)
const HISTORY_COST_COLOR: Color = Color(50.0 / 255.0, 223.0 / 255.0, 253.0 / 255.0)
const HISTORY_GET_COLOR: Color = Color(1.0, 246.0 / 255.0, 143.0 / 255.0)
const HISTORY_ACQUIRE_COLOR: Color = Color(1.0, 175.0 / 255.0, 52.0 / 255.0)
const RATIO_TEXT: Dictionary = {1: "", 2: " ×2!", 3: " ×3!", 4: " ×10!!"}
const RATIO_COLOR: Dictionary = {
	1: Color.WHITE, 2: Color(1.0, 0.4, 0.7), 3: Color(1.0, 0.4, 0.7), 4: Color(1.0, 0.36, 0.27),
}
const LSTR_USE := "MIDAS.USE"


static func rebuild_history(host: Control, history: Array, lstr_resolver: Callable) -> void:
	for c in host.get_children():
		c.queue_free()
	if history.is_empty():
		return
	var y: float = HISTORY_START_Y
	for h in history:
		var ratio: int = int(h.get("ratio", 1))
		var row := HBoxContainer.new()
		row.position = Vector2(HISTORY_ROW_X, y)
		row.add_theme_constant_override("separation", HISTORY_SEP)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_history_label(row, lstr_resolver.call(LSTR_USE), HISTORY_USE_COLOR)
		add_history_label(row, str(int(h.get("cost", 0))), HISTORY_COST_COLOR)
		add_history_icon(row, HISTORY_TOKEN_RES)
		add_history_label(row, lstr_resolver.call("ADDEQUIP.GET"), HISTORY_GET_COLOR)
		add_history_icon(row, HISTORY_GOLD_RES)
		add_history_label(row, str(int(h.get("acquire", 0))), HISTORY_ACQUIRE_COLOR)
		if ratio >= 2:
			add_history_ratio(row, ratio)
		host.add_child(row)
		y += HISTORY_LINE_HEIGHT


static func add_history_label(parent: HBoxContainer, text: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = col
	lbl.theme_type_variation = &"MidasHistoryLabel"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)


static func add_history_icon(parent: HBoxContainer, res_path: String) -> void:
	if not ResourceLoader.exists(res_path):
		return
	var tex: Texture2D = load(res_path) as Texture2D
	if tex == null:
		return
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	var th: float = float(tex.get_height())
	var tw: float = float(tex.get_width())
	tr.custom_minimum_size = Vector2(tw * HISTORY_ICON_H / maxf(th, 1.0), HISTORY_ICON_H)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)


static func add_history_ratio(parent: HBoxContainer, ratio: int) -> void:
	var res_path: String = String(HISTORY_RATIO_RES.get(ratio, ""))
	if res_path != "" and ResourceLoader.exists(res_path):
		add_history_icon(parent, res_path)
		return
	var rtext: String = String(RATIO_TEXT.get(ratio, ""))
	if rtext == "":
		return
	add_history_label(parent, rtext, RATIO_COLOR.get(ratio, Color.WHITE))


static func to_godot(cocos: Vector2) -> Vector2:
	return Vector2(cocos.x + OFFSET_X, 560.0 - cocos.y)


static func center(cocos: Vector2, sz: Vector2) -> Vector2:
	return to_godot(cocos) - sz * 0.5


static func left_mid(cocos: Vector2, h: float) -> Vector2:
	var g: Vector2 = to_godot(cocos)
	return Vector2(g.x, g.y - h * 0.5)


static func make_texture(parent: Control, res_path: String, pos: Vector2, sz: Vector2) -> TextureRect:
	if not ResourceLoader.exists(res_path):
		return null
	var tr := TextureRect.new()
	tr.texture = load(res_path) as Texture2D
	tr.position = pos
	tr.size = sz
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr


static func make_label(parent: Control, text: String, col: Color, pos: Vector2) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.modulate = col
	lbl.theme_type_variation = &"MidasConfirmLabel"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	return lbl


static func add_nine_patch(parent: Control, res_path: String, pos: Vector2, sz: Vector2, cap: int) -> NinePatchRect:
	var np := NinePatchRect.new()
	if ResourceLoader.exists(res_path):
		np.texture = load(res_path) as Texture2D
	np.position = pos
	np.size = sz
	np.patch_margin_left = cap
	np.patch_margin_top = cap
	np.patch_margin_right = cap
	np.patch_margin_bottom = cap
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(np)
	return np
