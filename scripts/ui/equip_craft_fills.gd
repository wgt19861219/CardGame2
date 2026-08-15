class_name EquipCraftFills
extends RefCounted

## EquipCraftPanel 纯数据填充（两件套范式，批 1 Task 10）。
## 只做动态 fill：装备详情（icon/名/拥有量/属性行）+ 合成历史栏动态行构建。
## 静态结构与样式归 equip_craft_content.tscn + default_theme（禁建静态节点、禁样式 override，
## 对齐 hero_detail_fills 范式）。panel 只留业务/信号/流程。

# 源 board.lua:320 icon@frame(50,328)；本项目 IconHost 相对 EquipLayer 左上（equipboard 范式实测）
const ICON_POS: Vector2 = Vector2(14.0, 21.0)
# 源 equipcraft.lua:1031 readequip.createIcon(id, 60)（72px 基底 × 60/72）
const ROOT_ICON_SCALE: float = 60.0 / 72.0
# 源 board.lua:60 拥有量 "EQUIPINFO.HAVE %d EQUIPINFO.ITEM"
const LSTR_HAVE: String = "EQUIPINFO.HAVE"
const LSTR_ITEM: String = "EQUIPINFO.ITEM"
# 历史栏（源 equipcraft.lua:843-872：ori=(55,350) + arrow 分隔；icon 40px）
const HISTORY_ICON_SCALE: float = 40.0 / 72.0
const HISTORY_ARROW_PATH: String = "res://assets/ui/alpha/HVGA/view_history_arrow.png"
# history layer 挂 %HistoryClip（源 draglist cliprect 原点 bg 局部 (12,300)），origin 相对 clip
# = 源 (55-12, 380-350) = (43, 30)（Godot 顶起 y 向下）。
const HISTORY_CLIP_ORIGIN: Vector2 = Vector2(43.0, 30.0)


# 装备详情 fill（源 board.lua refreshAmount:22-42 + initTitle:322-341 + initAtt:106-259）：
# icon 挂 %IconHost + %NameLabel/%AmountLabel 文本 + %AttHost 属性多行动态行。
static func fill_equip_layer(panel) -> void:
	if panel._equip_layer == null:
		return
	for c in panel._icon_host.get_children():
		c.free()
	if panel._target_id > 0:
		var icon: Control = ReadequipIcon.create_icon(panel._target_id, panel._get_amount(panel._target_id), panel.cm)
		icon.scale = Vector2(ROOT_ICON_SCALE, ROOT_ICON_SCALE)
		icon.position = ICON_POS
		panel._icon_host.add_child(icon)
	panel._name_label.text = panel._equip_name(panel._target_id)
	var amt: int = panel._get_amount(panel._target_id)
	panel._amount_label.text = "%s %d %s" % [String(panel.cm.get_lstr(LSTR_HAVE)), amt, String(panel.cm.get_lstr(LSTR_ITEM))]
	for c in panel._att_host.get_children():
		c.free()
	var rows: Array = ReadequipData.get_description(panel._target_id, 0, panel.cm)
	for row in rows:
		var r: Dictionary = row as Dictionary
		var lbl := Label.new()
		lbl.text = String(r.get("att", "")) + String(r.get("add", ""))
		lbl.theme_type_variation = &"EquipCraftAttLabel"
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel._att_host.add_child(lbl)


# 历史栏容器（源 createHistoryLayer :799-816 draglist.listLayer → HBox 挂 %HistoryClip 裁剪域）。
# separation 走全局 HBoxContainer/separation=8（default_theme，源 icon 间距 58 由 icon+arrow 尺寸合成）。
static func create_history_layer(panel) -> Control:
	if panel._history_layer != null and is_instance_valid(panel._history_layer):
		return panel._history_layer
	var layer := HBoxContainer.new()
	layer.position = HISTORY_CLIP_ORIGIN
	var clip: Control = panel._content.get_node("%HistoryClip") as Control
	clip.add_child(layer)
	panel._history_layer = layer
	return layer


# 追加一个历史节点（源 setHistory :848-872：len>0 时先加 view_history_arrow，再加 icon）。
# 返 icon_bg（panel 连 gui_input handler 并存 _history）。
static func append_history_node(panel, layer: Control, id: int) -> Control:
	var len_: int = panel._history.size()
	var icon_bg: Control = ReadequipIcon.create_icon(id, 0, panel.cm)
	icon_bg.scale = Vector2(HISTORY_ICON_SCALE, HISTORY_ICON_SCALE)
	if len_ > 0:
		# HBoxContainer 管子节点 layout，须用 custom_minimum_size（非 size）分配空间 + EXPAND_IGNORE_SIZE 让纹理 stretch 入框。
		var arrow := TextureRect.new()
		arrow.texture = load(HISTORY_ARROW_PATH)
		arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arrow.custom_minimum_size = TexDisplaySize.display_size(HISTORY_ARROW_PATH)
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(arrow)
	layer.add_child(icon_bg)
	return icon_bg
