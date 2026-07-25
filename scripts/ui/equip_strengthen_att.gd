class_name EquipStrengthenAtt
extends RefCounted

## equipstrengthen 装备槽/属性/经验条/cost 显示（View helper）— 从 EquipStrengthenPanel 拆出控 ≤300。
## static 方法第一参 panel（EquipStrengthenPanel 实例，鸭子类型避循环引用），照 battle_unit_combat.gd 静态拆分。
## + createExpBar:1109 + refreshExpBar:1061 + refreshStrenCost:504 + getUnitMoney:1289 + checkMaxLevel:1306。

const SLOT_COUNT: int = 6
const EQUIP_OX: float = 235.0
const EQUIP_OY_COCOS: float = 405.0
const EQUIP_DX: float = 72.0
const EQUIP_DY: float = 72.0
const HALF: float = 0.5              # 中心定位偏移（icon.size*0.5，源 cocos 锚点 0.5/0.5 等价）
const EMPTY_SLOT_SIZE: Vector2 = Vector2(70.0, 70.0)
const SLOT_DIM_ALPHA: float = 75.0 / 255.0
const ATT_TOP: float = 380.0
const ATT_LINE: float = 26.0
const ATT_LEFT: float = 340.0
const EXP_BAR_POS: Vector2 = Vector2(340.0, 415.0)
const EXP_BAR_SIZE: Vector2 = Vector2(280.0, 22.0)
const COST_LABEL_POS: Vector2 = Vector2(340.0, 350.0)
const EXP_BAR_SPEED: float = 60.0
const EXP_BAR_MIN_DUR: float = 0.1
# 提示文案 LSTR key（源 T(LSTR(...))，panel.cm.get_lstr 解析）。
const TEXT_UNENCHANTED_KEY: String = "EQUIPINFO.UNENCHANTED"
const TEXT_MAX_LEVEL_KEY: String = "EQUIPSTRENGTHEN.YOUR_ENCHANTING_LEVEL_HAS_BEEN_MAXED_OUT"
const TEXT_ADD_MATERIAL_KEY: String = "EQUIPSTRENGTHEN.NO_MATERIAL_ADDED"
const TEXT_MONEY_SHORT_KEY: String = "EQUIPSTRENGTHEN.YOUR_MONEY_IS_NOT_ENOUGH"
const TEXT_MATERIAL_HINT_KEY: String = "EQUIPSTRENGTHEN.CLICK_HERE_TO_OPEN_THE_PACK\\N_YOU_CAN_USE_ANY_EQUIPMENT_TO_ENCHANT"
const ATT_FADE_DUR: float = 0.2
# 材料区背景宽窄切换（源 doShowmbPrompt:1959-1982）
const MATERIAL_BG_WIDE_RES: String = "res://assets/ui/alpha/HVGA/equipupgrade/equipupgrade_bottom_bg.png"
const MATERIAL_BG_NARROW_RES: String = "res://assets/ui/alpha/HVGA/equipupgrade/equipupgrade_material_bg.png"
const MATERIAL_BG_WIDE_SIZE: Vector2 = Vector2(660.0, 154.0)
const MATERIAL_BG_NARROW_SIZE: Vector2 = Vector2(520.0, 154.0)
const MATERIAL_BG_WIDE_COCOS: Vector2 = Vector2(400.0, 120.0)
const MATERIAL_BG_NARROW_COCOS: Vector2 = Vector2(335.0, 120.0)
const MATERIAL_BG_CAP: int = 10
const ATT_LIST_LEFT: float = 427.0
const ATT_LIST_TOP: float = 205.0
const ATT_PRE_W: float = 70.0          # pre 列宽（源 content size 累加，估）
const ATT_ATT_W: float = 50.0
const ATT_ADD_W: float = 50.0
const ATT_FONT_SIZE: int = 18
const NAME_BG_RES: String = "res://assets/ui/alpha/HVGA/equipupgrade/equipupgrade_item_name_bg.png"
const NAME_BG_COCOS: Vector2 = Vector2(345.0, 415.0)
const NAME_BG_SIZE: Vector2 = Vector2(200.0, 30.0)    # 估


# i 是 0-based（本项目），源 1-based → ix=i%2, iy=i/2 等价源 (i-1)%2/floor((i-1)/2)。
static func get_equip_pos(i: int) -> Vector2:
	var ix: int = i % 2
	var iy: int = int(i / 2)
	var cocos_x: float = EQUIP_OX + EQUIP_DX * ix
	var cocos_y: float = EQUIP_OY_COCOS - EQUIP_DY * iy
	return Vector2(cocos_x + 80.0, 560.0 - cocos_y)


static func show_equips(panel) -> void:
	if panel.hero == null:
		return
	for i in SLOT_COUNT:
		var item_id: int = int(panel.hero.equip_slots[i])
		var icon: Control
		if item_id > 0:
			var lvl: int = int(ReadequipData.get_equip_level(item_id, float(panel.hero.equip_exp[i]), panel.cm).get("level", 0))
			icon = ReadequipIcon.create_icon(item_id, 1, panel.cm, lvl, true)
		else:
			icon = create_empty_slot()
		icon.position = get_equip_pos(i) - icon.size * HALF
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.set_meta("slot", i)
		icon.gui_input.connect(panel._make_slot_handler(i))
		panel.container.add_child(icon)
		panel._equip_icons.append(icon)


static func create_empty_slot() -> Control:
	var p := Panel.new()
	p.size = EMPTY_SLOT_SIZE
	return p


# 装备属性（源 initEquipAtt:1225 + getEquipName:1260 + getEquipLevel:1278 + getLevelText:1325）。
static func show_equip_att(panel, slot: int) -> void:
	panel._clear_meta_children("att")
	var item_id: int = int(panel.hero.equip_slots[slot])
	if item_id <= 0:
		return
	var equip_row: Dictionary = panel.cm.get_raw_table(&"Equip").get(str(item_id), {})
	var lvl_info: Dictionary = ReadequipData.get_equip_level(item_id, float(panel.hero.equip_exp[slot]), panel.cm)
	var level: int = int(lvl_info["level"])
	var is_max: bool = level >= int(lvl_info["max_level"]) and int(lvl_info["exp_in_level"]) >= int(lvl_info["level_total"])
	_add_att_texture(panel, NAME_BG_RES, NAME_BG_COCOS, NAME_BG_SIZE)
	add_att_label(panel, panel.cm.get_lstr(String(equip_row.get("Name", "equip"))), ATT_TOP)
	if is_max:
		add_att_label(panel, _L(panel, TEXT_MAX_LEVEL_KEY), ATT_TOP - ATT_LINE)
	else:
		var lvl_text: String = _L(panel, TEXT_UNENCHANTED_KEY) if level == 0 else BaseresData.get_enhance_level_text(level, panel.cm)
		add_att_label(panel, lvl_text + "  " + str(int(lvl_info["exp_in_level"])) + "/" + str(int(lvl_info["level_total"])), ATT_TOP - ATT_LINE)
	create_att_list(panel, slot)
	_fade_in_att(panel)


static func _fade_in_att(panel) -> void:
	if not panel.is_inside_tree():
		return
	for child in panel.container.get_children():
		if child.has_meta("att"):
			child.modulate.a = 0.0
			var tw: Tween = panel.create_tween()
			tw.tween_property(child, "modulate:a", 1.0, ATT_FADE_DUR)


static func add_att_label(panel, text: String, y: float) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2(ATT_LEFT, y)
	lbl.set_meta("att", true)
	panel.container.add_child(lbl)


# 未选(slot<0)→宽背景 660×154 + label 隐。setup_panel 初次调建背景(z 底)，select_slot 调更新属性。
# 列宽固定（源 refreshAttListPos 用 content size 累加，本项目估列宽近似）。
static func create_att_list(panel, slot: int) -> void:
	var item_id: int = int(panel.hero.equip_slots[slot])
	var att: Dictionary = ReadequipData.get_att_list(item_id, panel.cm)
	var add: Dictionary = ReadequipData.get_add_att_list(item_id, get_slot_level(panel, slot), panel.cm)
	var y: float = ATT_LIST_TOP
	for key in BaseresData.ATT_NAME:
		if not att.has(key):
			continue
		var x: float = ATT_LIST_LEFT
		_make_att_label(panel, BaseresData.get_att_pre(key, panel.cm), x, y, Color.WHITE)
		x += ATT_PRE_W
		_make_att_label(panel, str(int(att[key])), x, y, Color(1.0, 0.0, 0.0))
		x += ATT_ATT_W
		var add_val: int = int(add.get(key, 0))
		_make_att_label(panel, ("+" + str(add_val)) if add_val > 0 else "", x, y, Color(0.0, 1.0, 0.0))
		x += ATT_ADD_W
		_make_att_label(panel, BaseresData.get_att_suffix(key), x, y, Color.BLACK)
		y += ATT_LINE


static func _make_att_label(panel, text: String, x: float, y: float, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2(x, y)
	lbl.modulate = col
	lbl.add_theme_font_size_override("font_size", ATT_FONT_SIZE)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.set_meta("att", true)
	panel.container.add_child(lbl)
	return lbl


static func _add_att_texture(panel, path: String, cocos_pos: Vector2, sz: Vector2) -> void:
	if not ResourceLoader.exists(path):
		return
	var tr := TextureRect.new()
	tr.texture = load(path)
	tr.size = sz
	tr.position = Vector2(cocos_pos.x + 80.0, 560.0 - cocos_pos.y - sz.y * 0.5)   # Cocos→Godot：X+80，Y 翻 560（源 anchor 0,0.5）
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.set_meta("att", true)
	panel.container.add_child(tr)


static func show_material_bg(panel, slot: int) -> void:
	var narrow: bool = slot >= 0
	var res_path: String = MATERIAL_BG_NARROW_RES if narrow else MATERIAL_BG_WIDE_RES
	var size: Vector2 = MATERIAL_BG_NARROW_SIZE if narrow else MATERIAL_BG_WIDE_SIZE
	var cocos_pos: Vector2 = MATERIAL_BG_NARROW_COCOS if narrow else MATERIAL_BG_WIDE_COCOS
	if panel._material_bg == null or not is_instance_valid(panel._material_bg):
		panel._material_bg = NinePatchRect.new()
		panel._material_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel._material_bg.patch_margin_left = MATERIAL_BG_CAP
		panel._material_bg.patch_margin_top = MATERIAL_BG_CAP
		panel._material_bg.patch_margin_right = MATERIAL_BG_CAP
		panel._material_bg.patch_margin_bottom = MATERIAL_BG_CAP
		panel._material_bg.set_meta("mbg", true)
		panel.container.add_child(panel._material_bg)
	var tex := load(res_path)
	if tex != null:
		panel._material_bg.texture = tex
	panel._material_bg.size = size
	panel._material_bg.position = Vector2(cocos_pos.x + 80.0, 560.0 - cocos_pos.y - size.y)
	if panel._material_label == null or not is_instance_valid(panel._material_label):
		panel._material_label = Label.new()
		panel._material_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel._material_label.add_theme_font_size_override("font_size", 16)
		panel._material_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel._material_label.set_meta("mbg", true)
		panel.container.add_child(panel._material_label)
	panel._material_label.visible = narrow
	if narrow:
		panel._material_label.text = _L(panel, TEXT_MAX_LEVEL_KEY) if is_max_level_current(panel) else _L(panel, TEXT_MATERIAL_HINT_KEY)
		panel._material_label.size = Vector2(size.x, 30.0)
		panel._material_label.position = Vector2(cocos_pos.x + 80.0, 560.0 - cocos_pos.y - size.y * 0.5 - 15.0)


# LSTR 解析包装（源 T(LSTR(key))；panel.cm 缺失时返空串）。
static func _L(panel, key: String) -> String:
	if panel.cm == null:
		return ""
	return String(panel.cm.get_lstr(key))


# 经验条（源 createExpBar:1109 精灵图，本项目 ProgressBar 适配）。
static func show_exp_bar(panel, slot: int) -> void:
	panel._clear_meta_children("bar")
	var item_id: int = int(panel.hero.equip_slots[slot])
	if item_id <= 0:
		return
	var lvl_info: Dictionary = ReadequipData.get_equip_level(item_id, float(panel.hero.equip_exp[slot]), panel.cm)
	var bar := ProgressBar.new()
	bar.position = EXP_BAR_POS
	bar.size = EXP_BAR_SIZE
	bar.set_meta("bar", true)
	var total: int = int(lvl_info["level_total"])
	bar.max_value = total if total > 0 else 1
	bar.value = int(lvl_info["exp_in_level"])
	panel.container.add_child(bar)


# Tween 模拟：时长 = |target-cur|/60，min 0.1，kill 旧避叠加；is_inside_tree 守护。
static func refresh_exp_bar_preview(panel) -> void:
	if panel.hero == null or panel._selected_slot < 0:
		return
	var item_id: int = int(panel.hero.equip_slots[panel._selected_slot])
	if item_id <= 0:
		return
	for child in panel.container.get_children():
		if child.has_meta("bar"):
			var bar: ProgressBar = child as ProgressBar
			var lvl_info: Dictionary = ReadequipData.get_equip_level(item_id, panel._target_exp, panel.cm)
			var total: int = int(lvl_info["level_total"])
			bar.max_value = total if total > 0 else 1
			var target_val: float = float(lvl_info["exp_in_level"])
			var cur_val: float = bar.value
			if panel.is_inside_tree():   # 面板未入树时直接设值（同 select_slot 守护）
				if panel._exp_bar_tween != null and panel._exp_bar_tween.is_valid():
					panel._exp_bar_tween.kill()
				var dur: float = max(EXP_BAR_MIN_DUR, abs(target_val - cur_val) / EXP_BAR_SPEED)
				panel._exp_bar_tween = panel.create_tween()
				panel._exp_bar_tween.tween_property(bar, "value", target_val, dur)
			else:
				bar.value = target_val
			return


static func refresh_stren_cost(panel) -> void:
	if panel._cost_label == null:
		panel._cost_label = Label.new()
		panel._cost_label.position = COST_LABEL_POS
		panel._cost_label.set_meta("cost", true)
		panel.container.add_child(panel._cost_label)
	var has_mt: bool = false
	for k in panel._addmt_info:
		if int(panel._addmt_info[k]) > 0:
			has_mt = true
			break
	if not has_mt:
		panel._cost_label.text = _L(panel, TEXT_ADD_MATERIAL_KEY)
		panel._cost_label.modulate = Color.WHITE
		return
	var total_exp: float = get_total_exp(panel, panel._selected_slot)
	var target: float = max(min(panel._target_exp, total_exp), 0.0)
	var cost: int = int(get_unit_money(panel, panel._selected_slot) * (target - panel._ori_exp))
	panel._cost_label.text = "金币 " + str(cost)
	if panel.pd != null and cost > panel.pd.hero_manager.gold:
		panel._cost_label.modulate = Color.RED
		EquipStrengthenAnim.do_speak(panel, _L(panel, TEXT_MONEY_SHORT_KEY))
	else:
		panel._cost_label.modulate = Color.WHITE


static func refresh_fast_stren_cost(panel) -> void:
	if panel._diamond_cost_label == null or panel.hero == null or panel._selected_slot < 0:
		return
	var item_id: int = int(panel.hero.equip_slots[panel._selected_slot])
	if item_id <= 0:
		panel._diamond_cost_label.text = ""
		return
	var cost: int = ReadequipData.get_fast_stren_cost(item_id, panel._ori_exp, panel.cm)
	panel._diamond_cost_label.text = "钻石 " + str(cost) if cost > 0 else ""   # 满级 cost=0 隐


static func get_total_exp(panel, slot: int) -> float:
	if panel.hero == null or slot < 0 or slot >= SLOT_COUNT:
		return 0.0
	var item_id: int = int(panel.hero.equip_slots[slot])
	if item_id <= 0:
		return 0.0
	var le: Array = ReadequipData.get_equip_level_exp(item_id, panel.cm)["le"]
	var total: float = 0.0
	for v in le:
		total += float(v)
	return total


static func get_unit_money(panel, slot: int) -> float:
	if panel.hero == null or slot < 0 or slot >= SLOT_COUNT:
		return 0.0
	var item_id: int = int(panel.hero.equip_slots[slot])
	var quality: int = int(panel.cm.get_raw_table(&"Equip").get(str(item_id), {}).get("Quality", 0))
	return float(panel.cm.get_raw_table(&"Enhancement").get(str(quality), {}).get("Unit Price", 0))


static func is_max_level_target(panel) -> bool:
	if panel.hero == null or panel._selected_slot < 0:
		return false
	var total_exp: float = get_total_exp(panel, panel._selected_slot)
	if total_exp <= 0.0:
		return false
	return panel._target_exp >= total_exp


static func is_max_level_current(panel) -> bool:
	if panel.hero == null or panel._selected_slot < 0:
		return false
	var total_exp: float = get_total_exp(panel, panel._selected_slot)
	if total_exp <= 0.0:
		return false
	return float(panel.hero.equip_exp[panel._selected_slot]) >= total_exp


static func get_current_fast_cost(panel) -> int:
	if panel.hero == null or panel._selected_slot < 0:
		return 0
	var item_id: int = int(panel.hero.equip_slots[panel._selected_slot])
	if item_id <= 0:
		return 0
	return ReadequipData.get_fast_stren_cost(item_id, float(panel.hero.equip_exp[panel._selected_slot]), panel.cm)


static func get_slot_level(panel, slot: int) -> int:
	if panel.hero == null or slot < 0 or slot >= SLOT_COUNT:
		return 0
	var item_id: int = int(panel.hero.equip_slots[slot])
	if item_id <= 0:
		return 0
	return int(ReadequipData.get_equip_level(item_id, float(panel.hero.equip_exp[slot]), panel.cm).get("level", 0))
