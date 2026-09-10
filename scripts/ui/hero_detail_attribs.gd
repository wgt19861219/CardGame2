class_name HeroDetailAttribs
extends RefCounted

## HeroDetailPanel「详细属性」tab 内容工厂（task#9 拆分 2026-07-20）。
## 从 hero_detail_panel.gd 外迁的纯绘制函数：属性列表 fill（简介标题+Description+Narrative+
## 属性标题+成长值+21 属性）。照源 attributes.lua createAttList（:455-563）draglist 竖排，
## 本项目 ScrollContainer+%AttribVBox 替代 draglist（cliprect 249×415 照源）。
## 不含 panel 状态，全 static + 参数化（hero/cm/vbox）。Logic 层不依赖 Control 子类可 headless 单测。

const DISPLAY_ATTRIBS: Array[String] = ["STR", "INT", "AGI", "HP", "AD", "AP", "ARM", "MR", "CRIT", "MCRIT", "HPS", "MPS", "DODG", "ARMP", "MRI", "LFS", "CDR", "HEAL", "HIT", "SKL", "SILR"]
const ATTR_PRE_LSTR: Dictionary = {
	"STR": "BASERES.STRENGTH_", "INT": "BASERES.INTELLIGENCE_", "AGI": "BASERES.AGILITY_",
	"HP": "BASERES.MAXIMUM_HP_", "AD": "BASERES.PHYSICAL_ATTACK_", "AP": "BASERES.MAGIC_STRENGTH_",
	"ARM": "BASERES.PHYSICAL_ARMOR_", "MR": "BASERES.MAGIC_RESISTANCE_",
	"CRIT": "BASERES.PHYSICAL_CRIT_", "MCRIT": "BASERES.MAGIC_CRIT_",
	"HPS": "BASERES.HP_REPLIES_", "MPS": "BASERES.ENERGY_RECOVERY_", "DODG": "BASERES.DODGE_",
	"ARMP": "BASERES.PHYSICAL_ARMOR_PENETRATION", "MRI": "BASERES.IGNORE_MAGIC_RESISTANCE",
	"LFS": "BASERES.VAMPIRE_LEVEL_", "CDR": "BASERES.REDUCE_ENERGY_CONSUMPTION",
	"HEAL": "BASERES.IMPROVE_THERAPEUTIC_SKILL_EFFECT",
	"HIT": "baseres.1.10.1.004", "SKL": "baseres.1.10.1.005",
}
const ATTR_SUFFIX: Dictionary = {"CDR": "%", "HEAL": "%", "SKL": " "}
const ATT_PRE_COLOR: Color = Color(0.945, 0.757, 0.443)
const ATT_BASE_COLOR: Color = Color(1.0, 0.918, 0.776)
const ATT_ADD_COLOR: Color = Color(0.627, 0.882, 0.102)
const ATT_TITLE_COLOR: Color = Color(0.984, 0.808, 0.063)
const ATT_GROWTH_NAME_COLOR: Color = Color(1.0, 0.302, 0.0)
const ATT_DESC_COLOR: Color = Color.WHITE
const ATT_TEXT_WIDTH: float = 235.0
const ATT_TITLE_MARK_RES: String = "res://assets/ui/alpha/HVGA/herodetail-title-mark.png"


# 属性标题+成长值（createGrowth）+ 21 属性（createAttDetail）。本项目 ScrollContainer+%AttribVBox 替代 draglist。
static func fill_attributes(vbox: VBoxContainer, hero: HeroInstance, cm: Variant) -> void:
	if hero == null or cm == null:
		return
	for c in vbox.get_children():
		c.free()
	_add_section_title(vbox, &"HERODETAILATT.HERO_INTROUDUCEMENT", "英雄简介", cm)
	# Unit 表 Description/Narrative 字段值是 LSTR key（如 UNIT.FRONT_TANKS_...），
	# 直接 lookup 拿到的是 key 本身（用户看到的英文 key），需过 get_lstr 翻译。
	# lookup_str（2026-09-10 根修）：9 个真英雄（tid 18..45）无 Narrative 字段，lookup 返
	# null → String(null) 构造器崩（Godot 4 实测），null 安全读取返 ""。
	var desc_raw: String = cm.lookup_str(&"Unit", &"Description", int(hero.tid))
	var desc: String = cm.get_lstr(desc_raw) if cm != null and not desc_raw.is_empty() else desc_raw
	if not desc.is_empty():
		_add_text(vbox, desc, 18, ATT_DESC_COLOR)
	var narrative_raw: String = cm.lookup_str(&"Unit", &"Narrative", int(hero.tid))
	var narrative: String = cm.get_lstr(narrative_raw) if cm != null and not narrative_raw.is_empty() else narrative_raw
	if not narrative.is_empty():
		_add_text(vbox, narrative, 16, ATT_PRE_COLOR)
	_add_section_title(vbox, &"HERODETAILATT.HERO_ATTRIBUTES", "英雄属性", cm)
	_add_growth(vbox, hero, cm)
	var att: Dictionary = ReadheroAttribs.get_hero_att_by_hero(hero, cm)
	for key in DISPLAY_ATTRIBS:
		if not att.has(key):
			continue
		var row: Dictionary = att[key]
		var pre: String = get_lstr_fallback(String(ATTR_PRE_LSTR.get(key, "")), key, cm)
		var suffix: String = String(ATTR_SUFFIX.get(key, ""))
		var row_box := HBoxContainer.new()
		row_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_box.add_theme_constant_override("separation", 1)
		var name_lbl := Label.new()
		name_lbl.text = pre + ":"
		name_lbl.modulate = ATT_PRE_COLOR
		row_box.add_child(name_lbl)
		# suffix 始终显示在 base 后（源 attributes.lua:165-167 独立 label，visible 切换不含 suffix）。
		# 之前 suffix 绑死在 add>0 分支，致 CDR/HEAL/SKL 满级属性丢 %/单位后缀。
		var base_lbl := Label.new()
		base_lbl.text = str(int(row["all"])) + suffix
		base_lbl.modulate = ATT_BASE_COLOR
		row_box.add_child(base_lbl)
		if int(row["add"]) > 0:
			var add_lbl := Label.new()
			add_lbl.text = "+" + str(int(row["add"]))
			add_lbl.modulate = ATT_ADD_COLOR
			row_box.add_child(add_lbl)
		vbox.add_child(row_box)


# 源 attributes.lua:29-44 addListNode：des_title_bg(mark) 无 addHeight 游标不推进，des_title
# 与 bg 同 height 基准定位且同 list_center=142 水平中心 → mark 横条（两端装饰、中间约 65~153pt
# 透明）叠在标题文字身后、两者同中心（label offsetY=6 后中线与 mark 中线重合），非上下两行。
# mark 显示尺寸走 TexDisplaySize ÷CS（289×15px → 225.6×11.7pt，源 config 无 scale 直译）。
static func _add_section_title(vbox: VBoxContainer, lstr_key: StringName, fallback: String, cm: Variant) -> void:
	var lbl := Label.new()
	lbl.text = String(cm.get_lstr(lstr_key)) if cm != null else fallback
	lbl.modulate = ATT_TITLE_COLOR
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = _load_texture(ATT_TITLE_MARK_RES)
	if tex == null:
		lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(lbl)
		return
	var mark := TextureRect.new()
	mark.texture = tex
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_SCALE
	mark.custom_minimum_size = TexDisplaySize.display_size(ATT_TITLE_MARK_RES)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := CenterContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# CenterContainer 将每个子节点各自排到自身中心 → mark（先加，居下层）与 lbl 同中心叠放。
	row.add_child(mark)
	row.add_child(lbl)
	vbox.add_child(row)


static func _add_text(vbox: VBoxContainer, text: String, size: int, color: Color) -> void:
	if text.is_empty():
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = color
	lbl.add_theme_font_size_override("font_size", size)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(ATT_TEXT_WIDTH, 0.0)
	lbl.size_flags_horizontal = Control.SIZE_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl)


static func _add_growth(vbox: VBoxContainer, hero: HeroInstance, cm: Variant) -> void:
	if hero == null or cm == null:
		return
	var growth: Dictionary = ReadheroData.get_growth(int(hero.tid), hero.stars, cm)
	if growth.is_empty():
		return
	var names: Dictionary = {
		"STR": get_lstr_fallback("HERODETAILATT.STRENGTH_GROWTH_", "力量成长", cm),
		"INT": get_lstr_fallback("HERODETAILATT.INTELLIGENCE_GROWTH_", "智力成长", cm),
		"AGI": get_lstr_fallback("HERODETAILATT.AGILITY_GROWTH_", "敏捷成长", cm),
	}
	for k in ["STR", "INT", "AGI"]:
		if not growth.has(k):
			continue
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_lbl := Label.new()
		name_lbl.text = String(names[k])
		name_lbl.modulate = ATT_GROWTH_NAME_COLOR
		name_lbl.add_theme_font_size_override("font_size", 16)
		row.add_child(name_lbl)
		var val_lbl := Label.new()
		val_lbl.text = str(int(growth[k]))
		val_lbl.modulate = ATT_BASE_COLOR
		val_lbl.add_theme_font_size_override("font_size", 16)
		row.add_child(val_lbl)
		vbox.add_child(row)


# cm 可能为 null（测试降级）的 LSTR fallback：key 空或 cm null → 返 fallback（源英文 key）。
# panel/tabs 共用（单向：tabs → HeroDetailAttribs.get_lstr_fallback，避免 class_name 循环）。
static func get_lstr_fallback(lstr_key: String, fallback: String, cm: Variant) -> String:
	if lstr_key.is_empty() or cm == null:
		return fallback
	return String(cm.get_lstr(lstr_key))


static func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
