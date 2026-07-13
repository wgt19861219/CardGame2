class_name EquipStrengthenMaterial
extends RefCounted

## equipstrengthen 材料列表/网格/add-delete/飘字（View helper）— 从 EquipStrengthenPanel 拆出控 ≤300。
## static 方法第一参 panel，照 battle_unit_combat.gd 静态拆分。
## 源 ui/equipstrengthen.lua createmt:110 + createmtListLayer:393 + addMaterial:276 + deleteMaterial:300
## + createMinusIcon:195 + removeMinusIcon:211 + playAddmtAnim:218 + playAddExpAnim:246。
## 主类 _add_material/_delete_material 转发本类（单测 panel._add_material 不变）。

# 材料网格（源 createmt:110 ox=140,oy=155 dx=80,dy=75；本项目坐标适配）
const MT_ORIGIN: Vector2 = Vector2(140.0, 485.0)   # 源 createmt:113 oy=155 cocos → Godot 640-155=485
const MT_DX: float = 80.0
const MT_DY: float = 75.0
const MT_PER_ROW: int = 6                          # 源 createmt:118 bi=6*(index-1)+1
const MT_AMOUNT_OFFSET: Vector2 = Vector2(36.0, 20.0)   # 源 :136 aLabel
const MT_MINUS_OFFSET: Vector2 = Vector2(40.0, 40.0)    # 源 createMinusIcon:204（68,65）
const MT_MINUS_SIZE: Vector2 = Vector2(30.0, 30.0)
# 过滤键（源 readequip.lua:346 getMaterialList + :357 checkValid；本项目 Equip.json 用 LSTR 键）
const CAT_SOUL_STONE: String = "EQUIP.SOUL_STONE"
const CAT_CONSUMABLES: String = "EQUIP.CONSUMABLES"
const CAT_FRAGMENT: String = "EQUIP.FRAGMENT"
const CT_ENCHANTING: String = "EQUIP.ENCHANTING"
const NAME_UNIVERSAL_DEBRIS: String = "EQUIP.UNIVERSAL_DEBRIS"
const TEXT_EXP_MAXED: String = "经验已满"           # 源 addMaterial:278
const TEXT_MATERIAL_USED_UP: String = "该材料已用完" # 源 addMaterial:285
const PANEL_HEIGHT: float = 640.0
# 材料层滑入（源 createmtListLayer:407 runLayerAction 0.2s fade+move EaseSineOut）
const MT_LAYER_SLIDE_OFFSET: float = 20.0
const MT_LAYER_FADE_DUR: float = 0.2
# 材料添加飘字（源 :218 playAddmtAnim + :246 playAddExpAnim）
const ADDMT_END: Vector2 = Vector2(400.0, 212.0)           # 源 :227 epos 飞行终点
const ADDMT_DURATION: float = 0.2                          # 源 :229/231/233 0.2
const ADDMT_SCALE: float = 0.5                             # 源 :231 CCScaleTo 0.5
const ADDEXP_POS: Vector2 = Vector2(380.0, 235.0)          # 源 :248 bpos
const ADDEXP_RISE: float = 50.0                            # 源 :259 ccp(0,50)


# 源 readequip.lua:346 getMaterialList + :357 checkValid：遍历 items 过滤排序。
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
			continue   # 源 :358 魂石
		var ct: String = String(row.get("Consume Type", ""))
		if category == CAT_CONSUMABLES and ct != CT_ENCHANTING:
			continue   # 源 :361 非附魔消耗品
		var name_key: String = String(row.get("Name", ""))
		if category == CAT_FRAGMENT and name_key == NAME_UNIVERSAL_DEBRIS:
			continue   # 源 :364 万能碎
		if bool(row.get("Invisible", false)):
			continue   # 源 :367 不可见
		result.append({
			"id": int(item_id),
			"amount": count,
			"ehc": int(row.get("Enhance Value", 0)),
			"category": category,
			"ct": ct,
		})
	result.sort_custom(cmp_material)
	return result


# 源 readequip.lua:385 排序：ENCHANTING 优先（ap=1），同 ap 按 ehc 升序。
static func cmp_material(a: Dictionary, b: Dictionary) -> bool:
	var ap: int = 1 if String(a["ct"]) == CT_ENCHANTING else 0
	var bp: int = 1 if String(b["ct"]) == CT_ENCHANTING else 0
	if ap != bp:
		return ap > bp
	return int(a["ehc"]) < int(b["ehc"])


# 源 createmt:110 + createmtList:184：6 列网格 + 材料层滑入动画（源 createmtListLayer:407）。
static func show_materials(panel) -> void:
	panel._clear_meta_children("mt")
	panel._mt_nodes.clear()
	var slide_targets: Array = []   # 滑入动画目标（源 createmtListLayer:407）
	for i in panel._materials.size():
		var info: Dictionary = panel._materials[i]
		var icon: Control = ReadequipIcon.create_icon(int(info["id"]), 1, panel.cm)
		var col: int = i % MT_PER_ROW
		var row_idx: int = i / MT_PER_ROW
		var target_y: float = MT_ORIGIN.y + MT_DY * row_idx
		icon.position = Vector2(MT_ORIGIN.x + MT_DX * col, target_y)
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.set_meta("mt", true)
		var amount_label := Label.new()
		amount_label.text = str(int(info["amount"]))   # 源 :135 初始 amount
		amount_label.position = MT_AMOUNT_OFFSET
		icon.add_child(amount_label)
		icon.gui_input.connect(make_mt_handler(panel, i, false))
		panel.container.add_child(icon)
		panel._mt_nodes.append({
			"icon": icon,
			"amount_label": amount_label,
			"info": info,
			"add": 0,
			"minus": null,
		})
		slide_targets.append({"icon": icon, "target_y": target_y})
	_play_layer_slide(panel, slide_targets)


# 源 createmtListLayer:407 runLayerAction：材料层从下方滑入 + 淡入 0.2s（补源视觉细节）。
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


# 源 doClickInList:352：id>0 点图标 add，id<0 点减号 delete。
static func make_mt_handler(panel, idx: int, is_minus: bool) -> Callable:
	return func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			if is_minus:
				EquipStrengthenMaterial.delete_material(panel, idx)
			else:
				EquipStrengthenMaterial.add_material(panel, idx)


# 源 addMaterial:276：满级/用完守卫 + add+1 + addmtInfo[id]+1 + 标签 + 减号 + addExp(ehc) + 飘字。
static func add_material(panel, idx: int) -> void:
	if idx < 0 or idx >= panel._mt_nodes.size():
		return
	if EquipStrengthenAtt.is_max_level_target(panel):
		EquipStrengthenAnim.do_speak(panel, TEXT_EXP_MAXED)   # 源 :278
		return
	var node: Dictionary = panel._mt_nodes[idx]
	var info: Dictionary = node["info"]
	var add: int = int(node["add"])
	var amount: int = int(info["amount"])
	if add >= amount:
		EquipStrengthenAnim.do_speak(panel, TEXT_MATERIAL_USED_UP)   # 源 :285
		return
	Events.bus.emit_tutorial_step(&"EEclickMaterial")   # 源 doClickInList:356（点材料添加）
	add += 1
	node["add"] = add
	var mat_id: int = int(info["id"])
	panel._addmt_info[mat_id] = int(panel._addmt_info.get(mat_id, 0)) + 1
	(node["amount_label"] as Label).text = "%d/%d" % [add, amount]   # 源 :292
	ensure_minus_icon(panel, idx)
	play_addmt_anim(panel, idx)    # 源 :294 playAddmtAnim
	play_add_exp_anim(panel, idx)  # 源 :295 playAddExpAnim
	panel._add_exp(int(info["ehc"]))   # 源 :296


# 源 deleteMaterial:300：add==0 守卫 + add-1 + addmtInfo[id]-1 + 标签 + addExp(-ehc) + 减号隐藏。
static func delete_material(panel, idx: int) -> void:
	if idx < 0 or idx >= panel._mt_nodes.size():
		return
	var node: Dictionary = panel._mt_nodes[idx]
	var add: int = int(node["add"])
	if add <= 0:
		return   # 源 :303
	add -= 1
	var info: Dictionary = node["info"]
	var mat_id: int = int(info["id"])
	panel._addmt_info[mat_id] = int(panel._addmt_info.get(mat_id, 0)) - 1
	node["add"] = add
	var amount: int = int(info["amount"])
	(node["amount_label"] as Label).text = "%d/%d" % [add, amount] if add > 0 else str(amount)
	panel._add_exp(-int(info["ehc"]))   # 源 :311
	if add == 0:
		remove_minus_icon(panel, idx)   # 源 :312-314


# 源 createMinusIcon:195 + removeMinusIcon:211。减号用 Button.pressed（避 gui_input 双触发）。
static func ensure_minus_icon(panel, idx: int) -> void:
	var node: Dictionary = panel._mt_nodes[idx]
	var cur = node["minus"]
	if cur != null and is_instance_valid(cur):
		return
	var minus := Button.new()
	minus.text = "−"
	minus.position = MT_MINUS_OFFSET
	minus.size = MT_MINUS_SIZE
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


# 源 initMaterialData:414 + initMaterialLayer:433：addmtInfo 清零 + mt.add=0 + amount 标签/减号复位。
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


# 源 playAddmtAnim :218-244：材料图标副本飞向终点 (400,212) + 缩放 0.5 + 淡出。
static func play_addmt_anim(panel, idx: int) -> void:
	if idx < 0 or idx >= panel._mt_nodes.size():
		return
	var node: Dictionary = panel._mt_nodes[idx]
	var icon: Control = node["icon"]
	var info: Dictionary = node["info"]
	var ti: Control = ReadequipIcon.create_icon(int(info["id"]), 1, panel.cm)
	ti.position = icon.position
	ti.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.container.add_child(ti)
	var end_pos: Vector2 = Vector2(ADDMT_END.x, PANEL_HEIGHT - ADDMT_END.y)
	var tw: Tween = panel.create_tween()
	tw.tween_property(ti, "position", end_pos, ADDMT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(ti, "scale", Vector2(ADDMT_SCALE, ADDMT_SCALE), ADDMT_DURATION)
	tw.tween_property(ti, "modulate:a", 0.0, ADDMT_DURATION)
	tw.tween_callback(ti.queue_free)


# 源 playAddExpAnim :246-274："+ehc" 飘字 (380,235) 蓝(101,207,255) + 上浮 50 + 淡出。
static func play_add_exp_anim(panel, idx: int) -> void:
	if idx < 0 or idx >= panel._mt_nodes.size():
		return
	var node: Dictionary = panel._mt_nodes[idx]
	var info: Dictionary = node["info"]
	var ehc: int = int(info["ehc"])
	var label := Label.new()
	label.text = "+" + str(ehc)
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = Color("65cfff")
	label.position = Vector2(ADDEXP_POS.x, PANEL_HEIGHT - ADDEXP_POS.y)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.container.add_child(label)
	label.modulate.a = 0.0
	var tw: Tween = panel.create_tween()
	tw.tween_property(label, "modulate:a", 1.0, ADDMT_DURATION)   # 源 FadeIn 0.2
	tw.tween_interval(ADDMT_DURATION)                             # 源 Delay 0.2
	tw.tween_property(label, "position:y", label.position.y - ADDEXP_RISE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.5)   # 源 FadeOut 0.5 与上浮并行
	tw.tween_callback(label.queue_free)
