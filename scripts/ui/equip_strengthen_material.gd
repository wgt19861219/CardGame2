class_name EquipStrengthenMaterial
extends RefCounted

## equipstrengthen 材料网格 fill/add-delete/飘字（View helper）。
## 两件套范式（批 1 Task 5，2026-08-15）：滚动层 %MtClip(ScrollContainer) + 内容层
## %MtListHost 静态在 content.tscn（源 draglist canDragY 连续滚动 + cliprect 裁剪，
## 审查修复补滚动能力），材料格为动态数据行 fill 挂内容层下；
## 本批补漏译：ehcBg 数量底（源 createmt :127-132）+ minus 贴图按钮
#（源 createMinusIcon :195-209 skill_material_delete 双态）+ 材料格中心锚修正。
## static 方法第一参 panel，照 battle_unit_combat.gd 静态拆分。
## + 源对照：createmt:110 + createMinusIcon:195 + removeMinusIcon:211 + playAddmtAnim:218 + playAddExpAnim:246。

# 材料网格（源 createmt:110-113 ox=140,oy=155 dx=80,dy=75 中心锚）：
# 源第一格中心 cocos(140,155) → 全屏 (220,405)；裁剪层 rect (178,363) → 局部中心 (42,42)。
const MT_CLIP_ORIGIN: Vector2 = Vector2(42.0, 42.0)
const MT_DX: float = 80.0
const MT_DY: float = 75.0
const MT_PER_ROW: int = 6
# 滚动视口/内容高（源 draglist cliprect 宽 500 + createmtList:188 initListHeight(75*plies)）：
# 内容高 = 首行中心 42 + 行距×(plies-1) + 半格 36 + 底余量 6（末行底缘可滚入视口，源 maxy 等价）
const MT_CLIP_W: float = 500.0
const MT_LIST_H_TAIL: float = 84.0
# 数量底/数量字（源 :127-137：ehcBg @(36,18) z=-1 + aLabel @(36,20) 中心锚（相对 icon 中心
# (72,72) 基准 → Godot 局部 (72, 72-18=54) / (72, 72-20=52)；数量字 18 号白）
const EHC_BG_ATT_RES: String = "res://assets/ui/alpha/HVGA/skill_material_att_bg.png"
const EHC_BG_FRAG_RES: String = "res://assets/ui/alpha/HVGA/equipupgrade/equipupgrade_fragment_bg.png"
const EHC_BG_SIZE: Vector2 = Vector2(60.88, 21.85)   # skill_material_att_bg 78x28 ÷CS
const EHC_BG_FRAG_SIZE: Vector2 = Vector2(60.88, 22.63)   # fragment_bg 78x29 ÷CS
const EHC_BG_CENTER: Vector2 = Vector2(72.0, 54.0)
const AMOUNT_CENTER: Vector2 = Vector2(72.0, 52.0)
# 减号按钮（源 createMinusIcon :195-209 skill_material_delete(+_down) @(68,65) 中心锚
# → icon 局部中心 (72+... 即 (36+68, 36-65)=(104,-29) 右上角外）
const MINUS_NORMAL_RES: String = "res://assets/ui/alpha/HVGA/equipupgrade/skill_material_delete.png"
const MINUS_PRESS_RES: String = "res://assets/ui/alpha/HVGA/equipupgrade/skill_material_delete_down.png"
const MINUS_SIZE: Vector2 = Vector2(27.32, 29.66)   # 35x38 ÷CS
const MINUS_CENTER: Vector2 = Vector2(104.0, -29.0)
# 过滤键（源 readequip.lua:346 getMaterialList + :357 checkValid；本项目 Equip.json 用 LSTR 键）
const CAT_SOUL_STONE: String = "EQUIP.SOUL_STONE"
const CAT_CONSUMABLES: String = "EQUIP.CONSUMABLES"
const CAT_FRAGMENT: String = "EQUIP.FRAGMENT"
const CT_ENCHANTING: String = "EQUIP.ENCHANTING"
const NAME_UNIVERSAL_DEBRIS: String = "EQUIP.UNIVERSAL_DEBRIS"
# 提示文案 LSTR key（源 T(LSTR(...))，panel.cm.get_lstr 解析）。
const TEXT_EXP_MAXED_KEY: String = "EQUIPSTRENGTHEN.EXPERIENCE_MAXED_OUT"
const TEXT_MATERIAL_USED_UP_KEY: String = "EQUIPSTRENGTHEN.THIS_MATERIAL_HAS_BEEN_USED_UP"
# 材料层滑入（源 createmtListLayer:407 runLayerAction 0.2s fade+move EaseSineOut）
const MT_LAYER_SLIDE_OFFSET: float = 20.0
const MT_LAYER_FADE_DUR: float = 0.2
# 材料添加飘字（源 :218 playAddmtAnim + :246 playAddExpAnim）：终点全屏坐标（挂 %FxHost）
const ADDMT_END: Vector2 = Vector2(480.0, 348.0)   # 源 epos (400,212) → _g
const ADDMT_DURATION: float = 0.2
const ADDMT_SCALE: float = 0.5
const ADDEXP_POS: Vector2 = Vector2(460.0, 325.0)   # 源 (380,235) → _g
const ADDEXP_RISE: float = 50.0
const ADDEXP_FONT_SIZE: int = 24
const ADDEXP_COLOR: Color = Color("65cfff")
# 材料格显示尺寸（ReadequipIcon.ICON_SIZE）
const MT_ICON_SIZE: Vector2 = Vector2(72.0, 72.0)


static func build_material_list(panel) -> Array:
	var result: Array = []
	if panel.pd == null:
		return result
	var equip_table: Dictionary = panel.cm.get_raw_table(&"Equip")
	for item_id in panel.pd.items:
		var count: int = int(panel.pd.items[item_id])
		if count <= 0:
			continue
		var row: Dictionary = equip_table.get(str(item_id), {})
		if row.is_empty():
			continue
		var category: String = String(row.get("Category", ""))
		if category == CAT_SOUL_STONE:
			continue
		var ct: String = String(row.get("Consume Type", ""))
		if category == CAT_CONSUMABLES and ct != CT_ENCHANTING:
			continue
		var name_key: String = String(row.get("Name", ""))
		if category == CAT_FRAGMENT and name_key == NAME_UNIVERSAL_DEBRIS:
			continue
		if bool(row.get("Invisible", false)):
			continue
		result.append({
			"id": int(item_id),
			"amount": count,
			"ehc": int(row.get("Enhance Value", 0)),
			"category": category,
			"ct": ct,
		})
	result.sort_custom(cmp_material)
	return result


static func cmp_material(a: Dictionary, b: Dictionary) -> bool:
	var ap: int = 1 if String(a["ct"]) == CT_ENCHANTING else 0
	var bp: int = 1 if String(b["ct"]) == CT_ENCHANTING else 0
	if ap != bp:
		return ap > bp
	return int(a["ehc"]) < int(b["ehc"])


# 材料网格 fill（源 createmt :110-149）：挂 %MtListHost 内容层（源 draglist addItem 挂 listLayer，
# 视口 %MtClip 为 ScrollContainer，审查修复补滚动能力），每格 = ReadequipIcon 工厂 +
# ehcBg 数量底（z 底）+ 数量字；中心锚定位（源 setPosition 中心语义）。
static func show_materials(panel) -> void:
	var clip: ScrollContainer = panel._content.get_node("%MtClip") as ScrollContainer
	var host: Control = panel._content.get_node("%MtListHost") as Control
	panel._clear_meta_children("mt")
	panel._mt_nodes.clear()
	# 内容高照源 initListHeight(75*plies) 语义（:188）→ ScrollContainer 滚动范围自管
	var plies: int = int(ceil(float(panel._materials.size()) / float(MT_PER_ROW)))
	host.custom_minimum_size = Vector2(MT_CLIP_W, MT_LIST_H_TAIL + MT_DY * float(plies - 1))
	clip.scroll_vertical = 0.0   # 重建回顶（源 refreshmtList 重建网格同语义）
	var slide_targets: Array = []   # 滑入动画目标（源 createmtListLayer:407）
	for i in panel._materials.size():
		var info: Dictionary = panel._materials[i]
		var icon: Control = ReadequipIcon.create_icon(int(info["id"]), 1, panel.cm)
		var col: int = i % MT_PER_ROW
		var row_idx: int = i / MT_PER_ROW
		var center: Vector2 = Vector2(MT_CLIP_ORIGIN.x + MT_DX * col, MT_CLIP_ORIGIN.y + MT_DY * row_idx)
		icon.position = center - icon.size * 0.5   # 源 icon 中心锚 → 内容层局部居中
		icon.set_meta("mt", true)
		_add_ehc_bg(icon, String(info["category"]))
		var amount_label := Label.new()
		amount_label.text = str(int(info["amount"]))
		amount_label.theme_type_variation = &"EquipStrenLabel18"
		amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.add_child(amount_label)
		_center_on(amount_label, AMOUNT_CENTER)
		icon.gui_input.connect(make_mt_handler(panel, i, false))
		host.add_child(icon)
		panel._mt_nodes.append({
			"icon": icon,
			"amount_label": amount_label,
			"info": info,
			"add": 0,
			"minus": null,
		})
		slide_targets.append({"icon": icon, "target_y": icon.position.y})
	_play_layer_slide(panel, slide_targets)


# 数量底（源 createmt :127-132：fragment 类 equipupgrade_fragment_bg / 其他 skill_material_att_bg
# @(36,18) z=-1）；迁移期漏译，本批补全。置 icon 子序最底（z=-1 等价）。
static func _add_ehc_bg(icon: Control, category: String) -> void:
	var is_frag: bool = category == CAT_FRAGMENT
	var res_path: String = EHC_BG_FRAG_RES if is_frag else EHC_BG_ATT_RES
	var size: Vector2 = EHC_BG_FRAG_SIZE if is_frag else EHC_BG_SIZE
	var bg := TextureRect.new()
	bg.name = "EhcBg"
	bg.texture = load(res_path) as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.size = size
	bg.position = EHC_BG_CENTER - size * 0.5
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_child(bg)
	icon.move_child(bg, 0)   # 源 z=-1 置底


# 子节点中心锚定位（源 cocos 子元素默认 anchor(0.5,0.5)，position=中心点）。
# Label 未入树 size=0，须先 reset_size 取 minimum size（headless 16 号回落宽度，入树后略偏，可接受）。
static func _center_on(child: Control, center: Vector2) -> void:
	child.reset_size()
	child.size = child.get_combined_minimum_size()
	child.position = center - child.size * 0.5


static func _play_layer_slide(panel, targets: Array) -> void:
	if not panel.is_inside_tree():
		return
	for t in targets:
		var icon: Control = t["icon"]
		var target_y: float = float(t["target_y"])
		icon.position.y = target_y + MT_LAYER_SLIDE_OFFSET
		icon.modulate.a = 0.0
		var tw: Tween = panel.create_tween()
		tw.tween_property(icon, "position:y", target_y, MT_LAYER_FADE_DUR).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(icon, "modulate:a", 1.0, MT_LAYER_FADE_DUR)


static func make_mt_handler(panel, idx: int, is_minus: bool) -> Callable:
	return func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			if is_minus:
				EquipStrengthenMaterial.delete_material(panel, idx)
			else:
				EquipStrengthenMaterial.add_material(panel, idx)


static func add_material(panel, idx: int) -> void:
	if idx < 0 or idx >= panel._mt_nodes.size():
		return
	if EquipStrengthenAtt.is_max_level_target(panel):
		EquipStrengthenAnim.do_speak(panel, _L(panel, TEXT_EXP_MAXED_KEY))
		return
	var node: Dictionary = panel._mt_nodes[idx]
	var info: Dictionary = node["info"]
	var add: int = int(node["add"])
	var amount: int = int(info["amount"])
	if add >= amount:
		EquipStrengthenAnim.do_speak(panel, _L(panel, TEXT_MATERIAL_USED_UP_KEY))
		return
	Events.bus.emit_tutorial_step(&"EEclickMaterial")
	add += 1
	node["add"] = add
	var mat_id: int = int(info["id"])
	panel._addmt_info[mat_id] = int(panel._addmt_info.get(mat_id, 0)) + 1
	(node["amount_label"] as Label).text = "%d/%d" % [add, amount]
	ensure_minus_icon(panel, idx)
	play_addmt_anim(panel, idx)
	play_add_exp_anim(panel, idx)
	panel._add_exp(int(info["ehc"]))


static func delete_material(panel, idx: int) -> void:
	if idx < 0 or idx >= panel._mt_nodes.size():
		return
	var node: Dictionary = panel._mt_nodes[idx]
	var add: int = int(node["add"])
	if add <= 0:
		return
	add -= 1
	var info: Dictionary = node["info"]
	var mat_id: int = int(info["id"])
	panel._addmt_info[mat_id] = int(panel._addmt_info.get(mat_id, 0)) - 1
	node["add"] = add
	var amount: int = int(info["amount"])
	(node["amount_label"] as Label).text = "%d/%d" % [add, amount] if add > 0 else str(amount)
	panel._add_exp(-int(info["ehc"]))
	if add == 0:
		remove_minus_icon(panel, idx)


# 减号按钮（源 createMinusIcon :195-209：skill_material_delete + minusPress 双态贴图
# @(68,65) 右上角外；迁移期 Button 文字降级本批改贴图双态照源）。
static func ensure_minus_icon(panel, idx: int) -> void:
	var node: Dictionary = panel._mt_nodes[idx]
	var cur = node["minus"]
	if cur != null and is_instance_valid(cur):
		return
	var minus := TextureButton.new()
	minus.name = "Minus"
	minus.texture_normal = load(MINUS_NORMAL_RES) as Texture2D
	minus.texture_pressed = load(MINUS_PRESS_RES) as Texture2D
	minus.ignore_texture_size = true
	minus.size = MINUS_SIZE
	minus.position = MINUS_CENTER - MINUS_SIZE * 0.5
	minus.set_meta("mt", true)
	minus.pressed.connect(EquipStrengthenMaterial.delete_material.bind(panel, idx))
	(node["icon"] as Control).add_child(minus)
	node["minus"] = minus


static func remove_minus_icon(panel, idx: int) -> void:
	if idx < 0 or idx >= panel._mt_nodes.size():
		return
	var node: Dictionary = panel._mt_nodes[idx]
	var minus = node["minus"]
	if minus != null and is_instance_valid(minus):
		minus.queue_free()
	node["minus"] = null


static func reset_material_selection(panel) -> void:
	panel._addmt_info.clear()
	for node in panel._mt_nodes:
		node["add"] = 0
		var info: Dictionary = node["info"]
		var lbl = node["amount_label"]
		if lbl != null and is_instance_valid(lbl):
			(lbl as Label).text = str(int(info["amount"]))
		var minus = node["minus"]
		if minus != null and is_instance_valid(minus):
			minus.queue_free()
		node["minus"] = null


# 材料拖影（源 playAddmtAnim :218-244：icon 拖到经验条 (400,212)→(480,348) 缩小淡出）；
# 挂 %FxHost（content 局部坐标 = 裁剪层 offset + 内容层 position（含滚动偏移，ScrollContainer
# 滚动时移动子层 position）+ icon 局部）。
static func play_addmt_anim(panel, idx: int) -> void:
	if idx < 0 or idx >= panel._mt_nodes.size():
		return
	var clip: Control = panel._content.get_node("%MtClip") as Control
	var host: Control = panel._content.get_node("%MtListHost") as Control
	var fx_host: Control = panel._content.get_node("%FxHost") as Control
	var node: Dictionary = panel._mt_nodes[idx]
	var icon: Control = node["icon"]
	var info: Dictionary = node["info"]
	var ti: Control = ReadequipIcon.create_icon(int(info["id"]), 1, panel.cm)
	ti.position = Vector2(
		clip.offset_left + host.position.x + icon.position.x,
		clip.offset_top + host.position.y + icon.position.y)
	ti.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_host.add_child(ti)
	var tw: Tween = panel.create_tween()
	tw.tween_property(ti, "position", ADDMT_END, ADDMT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(ti, "scale", Vector2(ADDMT_SCALE, ADDMT_SCALE), ADDMT_DURATION)
	tw.tween_property(ti, "modulate:a", 0.0, ADDMT_DURATION)
	tw.tween_callback(ti.queue_free)


# 加经验飘字（源 playAddExpAnim :246-274："+ehc" 24 号 (101,207,255) 描边黑 1 @(380,235)→(460,325)）。
static func play_add_exp_anim(panel, idx: int) -> void:
	if idx < 0 or idx >= panel._mt_nodes.size():
		return
	var fx_host: Control = panel._content.get_node("%FxHost") as Control
	var node: Dictionary = panel._mt_nodes[idx]
	var info: Dictionary = node["info"]
	var ehc: int = int(info["ehc"])
	var label := Label.new()
	label.text = "+" + str(ehc)
	label.add_theme_font_size_override("font_size", ADDEXP_FONT_SIZE)
	label.modulate = ADDEXP_COLOR
	label.position = ADDEXP_POS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_host.add_child(label)
	label.modulate.a = 0.0
	var tw: Tween = panel.create_tween()
	tw.tween_property(label, "modulate:a", 1.0, ADDMT_DURATION)
	tw.tween_interval(ADDMT_DURATION)
	tw.tween_property(label, "position:y", label.position.y - ADDEXP_RISE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(label.queue_free)


# LSTR 解析包装（源 T(LSTR(key))；panel.cm 缺失时返空串）。
static func _L(panel, key: String) -> String:
	if panel.cm == null:
		return ""
	return String(panel.cm.get_lstr(key))
