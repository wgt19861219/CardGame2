class_name HandbookBuilder
extends RefCounted

## handbook 图鉴 View 工厂(照源 handbook.lua create :600-719 + createIcon :423-452 +
## getTagPosition :298-350 + getIconPosition :412-421 + 常量 :13-22)。
## 重构(2026-07-17):静态节点(背景三层/12 tag 按钮+label/箭头/back/pageLabel)进 handbook_content.tscn,
## 本类只 collect .tscn 已建 tag + fill LSTR text + 动态建装备 cell(翻页/切 tag 重建)。
## 坐标源 cocos(800×480 左下) → Godot(960×640 左上):(cx+80, 560-cy)(同 hero_package/HeroDetailBuilder 范式)。

# (源 pushScene),不用 popup 居中(cx+80),改全屏缩放铺满. SC=640/480,OFFSET_X=400×SC-480(横向居中).
const SCREEN_SCALE: float = 1.3333
const OFFSET_X: float = -53.33
const BASE_Y: float = 640.0
# TextureRect 默认 size=纹理原始(偏大 1.28),照源无 fix_size 的纯 Sprite 统一 /CS。
const CONTENT_SCALE: float = 1.28125
const LEFT_FIRST: Vector2 = Vector2(196.0, 356.0)
const RIGHT_FIRST: Vector2 = Vector2(476.0, 356.0)
const GAP: Vector2 = Vector2(130.0, 115.0)
const EQUIP_ICON_POS: Vector2 = Vector2(57.0, 64.0)
const EQUIP_NAME_POS: Vector2 = Vector2(57.0, 17.0)
const TAG_NORMAL_COLOR: Color = Color(178.0 / 255.0, 150.0 / 255.0, 146.0 / 255.0)
const TAG_SELECT_COLOR: Color = Color(1.0, 1.0, 1.0)
const EQUIP_NAME_COLOR: Color = Color(182.0 / 255.0, 65.0 / 255.0, 21.0 / 255.0)
const EQUIP_NAME_FONT: int = 18
# tag 资源路径(_update_tag_visual 切选中态 texture 用,.tscn 已设 normal/pressed,选中需切 normal)
const TAG_LEFT: String = "res://assets/ui/alpha/HVGA/handbook_left.png"
const TAG_LEFT_SEL: String = "res://assets/ui/alpha/HVGA/handbook_left_select.png"
const TAG_RIGHT: String = "res://assets/ui/alpha/HVGA/handbook_right.png"
const TAG_RIGHT_SEL: String = "res://assets/ui/alpha/HVGA/handbook_right_select.png"
# 装备 cell 资源(动态建)
const EQUIP_BG_RES: String = "res://assets/ui/alpha/HVGA/handbook_equip_bg.png"
const ICON_BG_RES: String = "res://assets/ui/alpha/HVGA/handbook_icon_bg.png"
const ICON_LOCK_RES: String = "res://assets/ui/alpha/HVGA/handbook_icon_lock.png"
# 12 tag LSTR key(源 tagText :41-52,tagTextIndex :26-39 顺序)。1-6 左 / 7-12 右。
const TAG_LSTR: Array[String] = [
	"BATTLEPREPARE.WHOLE", "HERO_EQUIP.STRENGTH", "HERO_EQUIP.AGILITY", "HERO_EQUIP.INTELLIGENCE",
	"HANDBOOK.HEALTH", "HANDBOOK.PHYSICAL_ATTACK", "HANDBOOK.MAGIC_ATTACK", "HANDBOOK.ARMOR",
	"HANDBOOK.CRIT", "HANDBOOK.HEALTH_SUPPLY", "HANDBOOK.MAGIC_SUPPLY", "SKILL.HEAL",
]
# 12 tag 分类标题 LSTR(源 tagText.title1-12 :53-64,切 tag 时 pageTitle 显示)。与 TAG_LSTR 同序。
const TITLE_LSTR: Array[String] = [
	"HANDBOOK.WHOLE", "HANDBOOK.POWER", "HANDBOOK.AGILITY", "HANDBOOK.INTELLIGENCE",
	"BASERES.MAXIMUM_HP", "BASERES.PHYSICAL_ATTACK", "BASERES.MAGIC_STRENGTH", "BASERES.PHYSICAL_ARMOR",
	"HANDBOOK.PHYSICAL_CRIT_MAGIC_CRIT", "BASERES.RECOVER_HP_AFTER_EACH_BATTLE",
	"BASERES.REPLENISH_ENERGY_AFTER_EACH_BATTLE", "BASERES.IMPROVE_THERAPEUTIC_SKILL_EFFECT",
]
const TAG_COUNT: int = 12


static func to_godot(cx: float, cy: float) -> Vector2:
	return Vector2(cx * SCREEN_SCALE + OFFSET_X, BASE_Y - cy * SCREEN_SCALE)


static func icon_position(slot: int) -> Vector2:
	if slot < 1 or slot > 12:
		return Vector2.ZERO
	if slot <= 6:
		var s: int = slot - 1
		return to_godot(LEFT_FIRST.x + GAP.x * float(s % 2), LEFT_FIRST.y - GAP.y * float(int(s / 2)))
	var r: int = slot - 7
	return to_godot(RIGHT_FIRST.x + GAP.x * float(r % 2), LEFT_FIRST.y - GAP.y * float(int(r / 2)))


# collect .tscn 已建 12 tag button + label → {index(1-12): {button, label}}。
static func collect_tags(content: Control) -> Dictionary:
	var tabs: Dictionary = {}
	for i in range(1, TAG_COUNT + 1):
		var btn: TextureButton = content.get_node("%Tag" + str(i) + "Btn") as TextureButton
		var lbl: Label = content.get_node("%Tag" + str(i) + "Label") as Label
		tabs[i] = {"button": btn, "label": lbl}
	return tabs


# fill 12 tag label LSTR text(源 tagText :41-52)。
static func fill_tag_labels(tags: Dictionary, cm: Variant) -> void:
	for i in range(1, TAG_COUNT + 1):
		var lbl: Label = tags[i]["label"]
		lbl.text = _lstr(cm, TAG_LSTR[i - 1])


# lr > player_level 锁定(源 :428 ed.player:getLevel() >= info.lr 才开)。
static func create_equip_cell(info: Dictionary, player_level: int, cm: Variant) -> Control:
	var cell := Control.new()
	var bg_tex: Texture2D = load(EQUIP_BG_RES) as Texture2D
	var bg_size: Vector2 = TexDisplaySize.display_size(EQUIP_BG_RES) if bg_tex != null else Vector2(114, 114) / CONTENT_SCALE
	cell.custom_minimum_size = bg_size
	cell.size = bg_size
	cell.pivot_offset = bg_size * 0.5   # 中心缩放(began setScale 0.95 围绕中心,源 anchor 0.5,0.5)
	cell.scale = Vector2(SCREEN_SCALE, SCREEN_SCALE)   # 全屏放大(跟 book_bg ×SC,cell 内部源坐标自动放大)
	var bg := TextureRect.new()
	bg.texture = bg_tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.size = bg_size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(bg)
	var lr: int = int(info.get("lr", 1))
	var name_text: String = _lstr(cm, String(info.get("name", "")))
	var is_open: bool = player_level >= lr
	if is_open:
		var icon: Control = ReadequipIcon.create_icon(int(info["id"]), 0, cm)
		icon.position = Vector2(EQUIP_ICON_POS.x, bg_size.y - EQUIP_ICON_POS.y)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon)
	else:
		var icon_bg := TextureRect.new()
		icon_bg.texture = load(ICON_BG_RES) as Texture2D
		icon_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_bg.size = TexDisplaySize.display_size(ICON_BG_RES) if icon_bg.texture != null else Vector2(66, 66) / CONTENT_SCALE
		icon_bg.position = Vector2(EQUIP_ICON_POS.x, bg_size.y - EQUIP_ICON_POS.y)
		icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon_bg)
		var lock := TextureRect.new()
		lock.texture = load(ICON_LOCK_RES) as Texture2D
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var lock_sz: Vector2 = TexDisplaySize.display_size(ICON_LOCK_RES) if lock.texture != null else Vector2.ZERO
		lock.size = lock_sz
		lock.position = (icon_bg.size - lock_sz) * 0.5
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_bg.add_child(lock)
		name_text = _lstr(cm, "HANDBOOK.LV_D_ACTIVATED") % lr
	_add_name_label(cell, name_text, Vector2(EQUIP_NAME_POS.x, bg_size.y - EQUIP_NAME_POS.y))
	cell.set_meta(&"is_open", is_open)
	cell.set_meta(&"id", int(info["id"]))
	return cell


static func _add_name_label(parent: Control, text: String, pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", EQUIP_NAME_FONT)
	lbl.add_theme_color_override("font_color", EQUIP_NAME_COLOR)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.position = pos
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)


static func title_text(index: int, cm: Variant) -> String:
	if index < 1 or index > TAG_COUNT:
		return ""
	return _lstr(cm, TITLE_LSTR[index - 1])


static func _lstr(cm: Variant, key: String) -> String:
	if cm != null and cm.has_method("get_lstr"):
		return String(cm.get_lstr(key))
	return key
