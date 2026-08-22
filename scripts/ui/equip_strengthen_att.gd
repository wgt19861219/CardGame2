class_name EquipStrengthenAtt
extends RefCounted

## equipstrengthen 装备槽 fill/属性 fill/经验条 fill/费用 fill + 查询（View helper）。
## 两件套范式（批 1 Task 5，2026-08-15）：静态结构（槽 host/名条底板/经验条六件/
## 金币钻石区/材料区背景）在 equip_strengthen_content.tscn；本类纯 fill 动态数据 +
## 数据查询，禁建静态节点/禁样式 override（金币不足红字为动态状态色，eatexp 先例）。
## static 方法第一参 panel（EquipStrengthenPanel 实例，鸭子类型避循环引用）。
## + 源对照：createEquip:1576 + createEquipAtt:1416 + createAttList:1366 +
## createExpBar:1109 + refreshExpBar:1061 + refreshStrenCost:504 + getUnitMoney:1289 + checkMaxLevel:1306。

const SLOT_COUNT: int = 6
const SLOT_DIM_ALPHA: float = 75.0 / 255.0
# 属性动态行（源 createAttList :1366-1414 + refreshAttListPos :1334-1364）：
# 首行左端 x=347（源 ox=347 直译），行距=att label 内容高（源 :1362 y -= att.height）。
const ATT_LIST_LEFT: float = 347.0
const ATT_LIST_TOP: float = 125.0   # 源 oy=355 → 480-355
const ATT_PRE_GAP: float = 5.0      # 源 :1352 pre→att 间隔 5
# 经验条（源 createExpBar :1109-1223）：progress_1/2 原始 842x24，显示=÷CS；
# bar 左中 (72,213)→(152,347) 高 18（源 textureRect 高 18），满宽=底条显示宽。
const BAR_TEX_SIZE: Vector2 = Vector2(842.0, 24.0)
const BAR_DISP_W: float = 657.17   # 842/CS，与 BarBg 同宽
const EXP_BAR_SPEED: float = 60.0
const EXP_BAR_MIN_DUR: float = 0.1
# 材料区背景两态（源 doShowmbPrompt :1959-1982）：宽 bottom_bg 660x154@(400,120)
# cap(10,10,640,146)（858x216 贴图 → margin right=208/top=216-156=60）；窄 material_bg
# 520x154@(335,120) cap(10,10,480,144)（650x214 → right=160/top=214-154=60）。
# cap 换算（批 1 终审必修 1）：top=H-y-h / bottom=y，两态 bottom 恒=10。
# MARGIN 语义=(right, top)，fill 处 left/bottom 恒 10。
const MATERIAL_BG_WIDE_RES: String = "res://assets/ui/alpha/HVGA/equipupgrade/equipupgrade_bottom_bg.png"
const MATERIAL_BG_NARROW_RES: String = "res://assets/ui/alpha/HVGA/equipupgrade/equipupgrade_material_bg.png"
const MATERIAL_BG_WIDE_RECT: Rect2 = Rect2(150.0, 363.0, 660.0, 154.0)
const MATERIAL_BG_NARROW_RECT: Rect2 = Rect2(155.0, 363.0, 520.0, 154.0)
const MATERIAL_BG_WIDE_MARGIN: Vector2i = Vector2i(208, 60)
const MATERIAL_BG_NARROW_MARGIN: Vector2i = Vector2i(160, 60)
# 费用区动态色（源 refreshStrenCost :526-529 红/白切换）
const COST_COLOR_SHORT: Color = Color(1.0, 0.0, 0.0)
const COST_COLOR_OK: Color = Color(1.0, 1.0, 1.0)
# 提示文案 LSTR key（源 T(LSTR(...))，panel.cm.get_lstr 解析）。
const TEXT_UNENCHANTED_KEY: String = "EQUIPINFO.UNENCHANTED"
const TEXT_MAX_LEVEL_KEY: String = "EQUIPSTRENGTHEN.YOUR_ENCHANTING_LEVEL_HAS_BEEN_MAXED_OUT"
const TEXT_ADD_MATERIAL_KEY: String = "EQUIPSTRENGTHEN.NO_MATERIAL_ADDED"
const TEXT_MONEY_SHORT_KEY: String = "EQUIPSTRENGTHEN.YOUR_MONEY_IS_NOT_ENOUGH"
const TEXT_MATERIAL_HINT_KEY: String = "EQUIPSTRENGTHEN.CLICK_HERE_TO_OPEN_THE_PACK\\N_YOU_CAN_USE_ANY_EQUIPMENT_TO_ENCHANT"
const ATT_FADE_DUR: float = 0.2


# 6 槽 fill（源 createEquip :1576-1638）：host 常驻 tscn，fill 塞装备 icon 或显示 gocha 空位。
# _equip_icons 存 icon（有装备，供星动画 refresh_stars）或 EmptyRect（空槽照源参与淡入淡出）。
static func show_equips(panel) -> void:
	if panel.hero == null:
		return
	panel._equip_icons.clear()
	for i in SLOT_COUNT:
		var host: Control = panel._content.get_node("%EquipSlot" + str(i)) as Control
		var empty: TextureRect = host.get_node("EmptyRect") as TextureRect
		for c in host.get_children():
			if c != empty and c.has_meta("equip_icon"):
				c.queue_free()
		var item_id: int = int(panel.hero.equip_slots[i])
		var icon: Control = empty
		if item_id > 0:
			var lvl: int = int(ReadequipData.get_equip_level(item_id, float(panel.hero.equip_exp[i]), panel.cm).get("level", 0))
			icon = ReadequipIcon.create_icon(item_id, 1, panel.cm, lvl, true)
			icon.position = (host.size - icon.size) * 0.5   # 源 icon 中心锚 → host 居中
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 点击由 host gui_input 接管
			icon.set_meta("slot", i)
			icon.set_meta("equip_icon", true)
			empty.visible = false
			host.add_child(icon)
		else:
			empty.visible = true   # 源 :1595/1615 gocha 空位
		panel._equip_icons.append(icon)


# 装备属性 fill（源 createEquipAtt:1416 + getEquipName:1260 + getEquipLevel:1278 + getLevelText:1325）。
# 名条底板/名/等级 label 静态在 tscn；att list 动态行（数量随装备属性变化）fill 挂 AttHost。
static func show_equip_att(panel, slot: int) -> void:
	panel._clear_meta_children("att")
	var item_id: int = int(panel.hero.equip_slots[slot])
	if item_id <= 0:
		return
	var equip_row: Dictionary = panel.cm.get_raw_table(&"Equip").get(str(item_id), {})
	var lvl_info: Dictionary = ReadequipData.get_equip_level(item_id, float(panel.hero.equip_exp[slot]), panel.cm)
	var level: int = int(lvl_info["level"])
	var is_max: bool = level >= int(lvl_info["max_level"]) and int(lvl_info["exp_in_level"]) >= int(lvl_info["level_total"])
	var att_host: Control = panel._content.get_node("AttHost") as Control
	(att_host.get_node("%AttNameLabel") as Label).text = String(panel.cm.get_lstr(String(equip_row.get("Name", "equip"))))
	var level_label: Label = att_host.get_node("%AttLevelLabel") as Label
	if is_max:
		level_label.text = _L(panel, TEXT_MAX_LEVEL_KEY)
	else:
		var lvl_text: String = _L(panel, TEXT_UNENCHANTED_KEY) if level == 0 else BaseresData.get_enhance_level_text(level, panel.cm)
		level_label.text = lvl_text + "  " + str(int(lvl_info["exp_in_level"])) + "/" + str(int(lvl_info["level_total"]))
	create_att_list(panel, slot)
	_fade_in_att(panel)


static func _fade_in_att(panel) -> void:
	if not panel.is_inside_tree():
		return
	for child in panel._content.get_node("AttHost").get_children():
		if child.has_meta("att"):
			child.modulate.a = 0.0
			var tw: Tween = panel.create_tween()
			tw.tween_property(child, "modulate:a", 1.0, ATT_FADE_DUR)


# 属性动态行（源 createAttList :1366-1414 四列 label + refreshAttListPos :1334-1364 内容宽拼接）：
# pre 左端 427 → pre 右端+5 → att → add → suf（列间按文字实际宽累加，源 :1339-1361 等价左端拼接）。
# 行距 = att label 内容高（源 :1362）。headless 未入树 variation 回落 16 号宽（AGENTS 沉淀），入树后准确。
static func create_att_list(panel, slot: int) -> void:
	var item_id: int = int(panel.hero.equip_slots[slot])
	var att: Dictionary = ReadequipData.get_att_list(item_id, panel.cm)
	var add: Dictionary = ReadequipData.get_add_att_list(item_id, get_slot_level(panel, slot), panel.cm)
	var host: Control = panel._content.get_node("AttHost") as Control
	var y: float = ATT_LIST_TOP
	for key in BaseresData.ATT_NAME:
		if not att.has(key):
			continue
		var x: float = ATT_LIST_LEFT
		var pre: Label = _make_att_label(panel, host, BaseresData.get_att_pre(key, panel.cm), x, y, &"EquipStrenAttPreLabel")
		x += pre.get_combined_minimum_size().x + ATT_PRE_GAP
		var val: Label = _make_att_label(panel, host, str(int(att[key])), x, y, &"EquipStrenAttValLabel")
		x += val.get_combined_minimum_size().x
		var add_val: int = int(add.get(key, 0))
		var add_lbl: Label = _make_att_label(panel, host, ("+" + str(add_val)) if add_val > 0 else "", x, y, &"EquipStrenAttAddLabel")
		x += add_lbl.get_combined_minimum_size().x
		_make_att_label(panel, host, BaseresData.get_att_suffix(key), x, y, &"EquipStrenAttSufLabel")
		y += val.get_combined_minimum_size().y


# 动态属性行 label（variation 承载色/字号/阴影，meta "att" 供清理）。
static func _make_att_label(panel, host: Control, text: String, x: float, y: float, variation: StringName) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2(x, y)
	lbl.theme_type_variation = variation
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.set_meta("att", true)
	host.add_child(lbl)
	return lbl


# 材料区背景两态 fill（源 doShowmbPrompt :1959-1982）：未选槽=宽背景+提示隐；
# 选槽=窄背景+提示显（满级文案或 CLICK_HERE）。
static func show_material_bg(panel, slot: int) -> void:
	var narrow: bool = slot >= 0
	var bg: NinePatchRect = panel._content.get_node("%MaterialBg") as NinePatchRect
	var rect: Rect2 = MATERIAL_BG_NARROW_RECT if narrow else MATERIAL_BG_WIDE_RECT
	var margin: Vector2i = MATERIAL_BG_NARROW_MARGIN if narrow else MATERIAL_BG_WIDE_MARGIN
	var tex: Texture2D = load(MATERIAL_BG_NARROW_RES if narrow else MATERIAL_BG_WIDE_RES) as Texture2D
	if tex != null:
		bg.texture = tex
	bg.patch_margin_left = 10
	bg.patch_margin_top = margin.y
	bg.patch_margin_right = margin.x
	bg.patch_margin_bottom = 10
	bg.offset_left = rect.position.x
	bg.offset_top = rect.position.y
	bg.offset_right = rect.position.x + rect.size.x
	bg.offset_bottom = rect.position.y + rect.size.y
	panel._material_label.visible = narrow
	if narrow:
		panel._material_label.text = _L(panel, TEXT_MAX_LEVEL_KEY) if is_max_level_current(panel) else _L(panel, TEXT_MATERIAL_HINT_KEY)


# LSTR 解析包装（源 T(LSTR(key))；panel.cm 缺失时返空串）。
static func _L(panel, key: String) -> String:
	if panel.cm == null:
		return ""
	return String(panel.cm.get_lstr(key))


# 经验条 fill（源 createExpBar :1109-1223 + initBar :1043-1059）：
# Bar 显示已确认值（equip_exp），AnimBar 预览值（refreshExpBar 隐 bar 显 anim_bar）。
static func show_exp_bar(panel, slot: int) -> void:
	var item_id: int = int(panel.hero.equip_slots[slot])
	var bar_host: Control = panel._content.get_node("BarHost") as Control
	if item_id <= 0:
		bar_host.visible = false   # 源 :1114-1116 空槽移除容器
		return
	bar_host.visible = true
	var lvl_info: Dictionary = ReadequipData.get_equip_level(item_id, float(panel.hero.equip_exp[slot]), panel.cm)
	var level: int = int(lvl_info["level"])
	var max_level: int = int(lvl_info["max_level"])
	var anim: TextureRect = bar_host.get_node("%AnimBar") as TextureRect
	anim.visible = false   # 源 :1055 anim_bar 隐
	# 源 :1198 anim_bar 初始纹理即当前 exp（textureRect(0,0,655*exp/mexp,18)）：
	# 同步重置预览起点，首次预览从当前值涨、切槽不残留上次比例（审查修复）
	_apply_bar_ratio(panel, anim, _bar_ratio(lvl_info))
	_apply_bar_ratio(panel, bar_host.get_node("%Bar") as TextureRect, _bar_ratio(lvl_info))
	(bar_host.get_node("%BarLevelLabel") as Label).text = BaseresData.get_enhance_level_text(level, panel.cm)
	(bar_host.get_node("%NextLevelLabel") as Label).text = BaseresData.get_enhance_level_text(mini(level + 1, max_level), panel.cm)
	_fill_ehc_label(panel, lvl_info)


static func _bar_ratio(lvl_info: Dictionary) -> float:
	var total: int = int(lvl_info["level_total"])
	if total <= 0:
		return 0.0
	return clampf(float(int(lvl_info["exp_in_level"])) / float(total), 0.0, 1.0)


# 条填充：AtlasTexture.region 裁剪宽随 ratio（源 setTextureRect(0,0,655*e/m,18) 裁剪语义，非拉伸；
# 本引擎 TextureRect 无 region 属性，AtlasTexture 等价——.tscn 两条独立实例）。
static func _apply_bar_ratio(panel, bar: TextureRect, ratio: float) -> void:
	var atlas: AtlasTexture = bar.texture as AtlasTexture
	if atlas != null:
		atlas.region = Rect2(0.0, 0.0, BAR_TEX_SIZE.x * ratio, BAR_TEX_SIZE.y)
	bar.offset_right = bar.offset_left + BAR_DISP_W * ratio


static func _bar_ratio_of(bar: TextureRect) -> float:
	var atlas: AtlasTexture = bar.texture as AtlasTexture
	if atlas == null or BAR_TEX_SIZE.x <= 0.0:
		return 0.0
	return atlas.region.size.x / BAR_TEX_SIZE.x


static func _fill_ehc_label(panel, lvl_info: Dictionary) -> void:
	var bar_host: Control = panel._content.get_node("BarHost") as Control
	(bar_host.get_node("%EhcLabel") as Label).text = "%d/%d" % [int(lvl_info["exp_in_level"]), int(lvl_info["level_total"])]


# 预览动画（源 refreshExpBar :1061-1101）：bar 隐 anim_bar 显，值向 targetExp 平滑（速度 60/s），
# 回落到实际值时切回 bar（源 :1081-1084）；等级/数字文字随预览终态更新（源 :1089-1094 逐帧的终值等价）。
static func refresh_exp_bar_preview(panel) -> void:
	if panel.hero == null or panel._selected_slot < 0:
		return
	var item_id: int = int(panel.hero.equip_slots[panel._selected_slot])
	if item_id <= 0:
		return
	var bar_host: Control = panel._content.get_node("BarHost") as Control
	var bar: TextureRect = bar_host.get_node("%Bar") as TextureRect
	var anim: TextureRect = bar_host.get_node("%AnimBar") as TextureRect
	bar.visible = false
	anim.visible = true
	var lvl_info: Dictionary = ReadequipData.get_equip_level(item_id, panel._target_exp, panel.cm)
	var target_ratio: float = _bar_ratio(lvl_info)
	var cur_ratio: float = _bar_ratio_of(anim)
	_fill_ehc_label(panel, lvl_info)
	# 等级文字随预览（源 :1089-1093 l 变化时更新 b_lv/n_lv）
	var preview_level: int = int(lvl_info["level"])
	(bar_host.get_node("%BarLevelLabel") as Label).text = BaseresData.get_enhance_level_text(preview_level, panel.cm)
	(bar_host.get_node("%NextLevelLabel") as Label).text = BaseresData.get_enhance_level_text(mini(preview_level + 1, int(lvl_info["max_level"])), panel.cm)
	if not panel.is_inside_tree():   # 面板未入树时直接设值（同 select_slot 守护）
		_apply_bar_ratio(panel, anim, target_ratio)
		return
	if panel._exp_bar_tween != null and panel._exp_bar_tween.is_valid():
		panel._exp_bar_tween.kill()
	var dur: float = max(EXP_BAR_MIN_DUR, abs(target_ratio - cur_ratio) * BAR_DISP_W / EXP_BAR_SPEED)
	panel._exp_bar_tween = panel.create_tween()
	var anim_ref: TextureRect = anim
	panel._exp_bar_tween.tween_method(
		func(r: float) -> void:
			if is_instance_valid(anim_ref):   # 面板提前销毁时 tween 已失效，防御 freed 访问
				_apply_bar_ratio(panel, anim_ref, r),
		cur_ratio, target_ratio, dur)
	if panel._target_exp == float(panel.hero.equip_exp[panel._selected_slot]):
		# 预览回落到实际值 → 动画结束切回 bar（源 :1081-1084 exp==getItemExp）
		var bar_ref: TextureRect = bar
		panel._exp_bar_tween.tween_callback(func() -> void:
			if not is_instance_valid(anim_ref) or not is_instance_valid(bar_ref):
				return
			anim_ref.visible = false
			bar_ref.visible = true
			_apply_bar_ratio(panel, bar_ref, target_ratio))


# 金币区 fill（源 refreshStrenCost :504-533）：无材料 no_cost 显/icon+money 隐；
# 有材料反转 + money 纯数字（源 :515）+ 不足红字/充足白字（:526-529）。
static func refresh_stren_cost(panel) -> void:
	var no_cost: Label = panel._content.get_node("%NoCostLabel") as Label
	var icon: TextureRect = panel._content.get_node("%MoneyIcon") as TextureRect
	var money: Label = panel._content.get_node("%MoneyLabel") as Label
	var has_mt: bool = false
	for k in panel._addmt_info:
		if int(panel._addmt_info[k]) > 0:
			has_mt = true
			break
	if not has_mt:
		no_cost.visible = true
		icon.visible = false
		money.visible = false
		return
	no_cost.visible = false
	icon.visible = true
	money.visible = true
	var total_exp: float = get_total_exp(panel, panel._selected_slot)
	var target: float = max(min(panel._target_exp, total_exp), 0.0)
	var cost: int = int(get_unit_money(panel, panel._selected_slot) * (target - panel._ori_exp))
	money.text = str(cost)   # 源 :515 纯数字（goldicon_small 表意，迁移期"金币"前缀已删）
	if panel.pd != null and cost > panel.pd.hero_manager.gold:
		money.add_theme_color_override("font_color", COST_COLOR_SHORT)
		EquipStrengthenAnim.do_speak(panel, _L(panel, TEXT_MONEY_SHORT_KEY))
	else:
		money.add_theme_color_override("font_color", COST_COLOR_OK)


# 钻石区 fill（源 initStrenButton :476-478 + doShowMaxLevel :1924-1927）：
# cost>0 → icon+rmb 数字显；满级 cost=0 → 隐 + no_fastcost 提示。
static func refresh_fast_stren_cost(panel) -> void:
	if panel.hero == null or panel._selected_slot < 0:
		return
	var rmb: Label = panel._content.get_node("%RmbLabel") as Label
	var icon: TextureRect = panel._content.get_node("%RmbIcon") as TextureRect
	var no_fast: Label = panel._content.get_node("%NoFastCostLabel") as Label
	var item_id: int = int(panel.hero.equip_slots[panel._selected_slot])
	if item_id <= 0:
		rmb.text = ""
		icon.visible = false
		return
	var cost: int = ReadequipData.get_fast_stren_cost(item_id, panel._ori_exp, panel.cm)
	if cost > 0:
		rmb.text = str(cost)
		rmb.visible = true
		icon.visible = true
		no_fast.text = ""
	else:
		rmb.visible = false
		icon.visible = false
		no_fast.text = _L(panel, TEXT_MAX_LEVEL_KEY) if is_max_level_current(panel) else ""


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
