class_name HandbookBuilder
extends RefCounted

## handbook 图鉴 View 工厂（照源 handbook.lua create :600-719 + createIcon :423-452 +
## getTagPosition :298-350 + getIconPosition :412-421 + 常量 :13-22）。
## 背景层（book_bg/page_shade/page）+ back 按钮 + 12 tag（左右各 6）+ 装备单元（图标/锁定态+名字）+ 翻页箭头。
## 源 tag 用触摸区机制（getTagPosition 12 区 + 单精灵切换），Godot 适配为 12 TextureButton（引擎适配，铁律允许）。
## 坐标源 cocos(800×480 左下) → Godot(960×640 左上)：(cx+80, 560-cy)（同 hero_package/StageDetailBuilder 范式）。

const OFFSET_X: float = 80.0
const BASE_Y: float = 560.0
# 源 :13-22 常量
const BOOK_CENTER_COCOS: Vector2 = Vector2(400.0, 240.0)   # 源 bg/book_bg/page 中心
const BACK_COCOS: Vector2 = Vector2(70.0, 428.0)            # 源 back btn :668
const LEFT_FIRST: Vector2 = Vector2(196.0, 356.0)           # 源 leftFirstX,Y :13
const RIGHT_FIRST: Vector2 = Vector2(476.0, 356.0)          # 源 rightFirstX,Y :14
const GAP: Vector2 = Vector2(130.0, 115.0)                  # 源 gapX,gapY :15
const EQUIP_ICON_POS: Vector2 = Vector2(57.0, 64.0)         # 源 equipIconPosX,Y :17（handbook_equip_bg 内）
const EQUIP_NAME_POS: Vector2 = Vector2(57.0, 17.0)         # 源 :20
const LEFT_ARROW_COCOS: Vector2 = Vector2(295.0, 50.0)      # 源 :21
const RIGHT_ARROW_COCOS: Vector2 = Vector2(515.0, 50.0)     # 源 :22
# 源 :23-24 tag 文字色
const TAG_NORMAL_COLOR: Color = Color(178.0 / 255.0, 150.0 / 255.0, 146.0 / 255.0)
const TAG_SELECT_COLOR: Color = Color(1.0, 1.0, 1.0)
const EQUIP_NAME_COLOR: Color = Color(182.0 / 255.0, 65.0 / 255.0, 21.0 / 255.0)   # 源 :19
const EQUIP_NAME_FONT: int = 18                              # 源 :18
const NAME_MAX_W: float = 114.0                             # 源 createIcon :445 宽度上限缩放
# 资源路径
const BG_BOOK: String = "res://assets/ui/alpha/HVGA/handbook_bg.png"
const BG_SHADE: String = "res://assets/ui/alpha/HVGA/handbook_bg_2.png"
const BG_PAGE: String = "res://assets/ui/alpha/HVGA/handbook_bg_1.png"
const BACK_RES: String = "res://assets/ui/alpha/HVGA/backbtn.png"
const TAG_LEFT: String = "res://assets/ui/alpha/HVGA/handbook_left.png"
const TAG_LEFT_SEL: String = "res://assets/ui/alpha/HVGA/handbook_left_select.png"
const TAG_RIGHT: String = "res://assets/ui/alpha/HVGA/handbook_right.png"
const TAG_RIGHT_SEL: String = "res://assets/ui/alpha/HVGA/handbook_right_select.png"
const EQUIP_BG_RES: String = "res://assets/ui/alpha/HVGA/handbook_equip_bg.png"
const ICON_BG_RES: String = "res://assets/ui/alpha/HVGA/handbook_icon_bg.png"
const ICON_LOCK_RES: String = "res://assets/ui/alpha/HVGA/handbook_icon_lock.png"
const ARROW_L_RES: String = "res://assets/ui/alpha/HVGA/handbook_left_arrow.png"
const ARROW_R_RES: String = "res://assets/ui/alpha/HVGA/handbook_right_arrow.png"
# 12 tag LSTR key（源 tagText :41-52，tagTextIndex :26-39 顺序）。1-6 左 / 7-12 右。
const TAG_LSTR: Array[String] = [
	"BATTLEPREPARE.WHOLE", "HERO_EQUIP.STRENGTH", "HERO_EQUIP.AGILITY", "HERO_EQUIP.INTELLIGENCE",
	"HANDBOOK.HEALTH", "HANDBOOK.PHYSICAL_ATTACK", "HANDBOOK.MAGIC_ATTACK", "HANDBOOK.ARMOR",
	"HANDBOOK.CRIT", "HANDBOOK.HEALTH_SUPPLY", "HANDBOOK.MAGIC_SUPPLY", "SKILL.HEAL",
]


# 源 cocos(cx,cy) → Godot(cx+80, 560-cy)。
static func to_godot(cx: float, cy: float) -> Vector2:
	return Vector2(cx + OFFSET_X, BASE_Y - cy)


# 源 getIconPosition :412-421。slot 1-12（页内序），左列 1-6 / 右列 7-12。
static func icon_position(slot: int) -> Vector2:
	if slot < 1 or slot > 12:
		return Vector2.ZERO
	if slot <= 6:
		var s: int = slot - 1
		return to_godot(LEFT_FIRST.x + GAP.x * float(s % 2), LEFT_FIRST.y - GAP.y * float(int(s / 2)))
	var r: int = slot - 7
	return to_godot(RIGHT_FIRST.x + GAP.x * float(r % 2), LEFT_FIRST.y - GAP.y * float(int(r / 2)))


# 源 getTagPosition :298-348 type=1（button 中心）。index 1-12。
static func tag_center(index: int) -> Vector2:
	if index <= 6:
		var x: float = 93.0 - 2.0 * float(index - 1)   # 源 :305
		var y: float = 360.0 - 60.0 * float(index - 1)   # 源 :321
		return to_godot(x, y)
	var x2: float = 710.0 + 2.0 * float(index - 7)   # 源 :327
	var y2: float = 360.0 - 60.0 * float(index - 7)   # 源 :343
	return to_godot(x2, y2)


# 源 create :613-709 背景层（bg.jpg 由 framework/hero_scene 提供，这里只加 book 三层）。
static func create_background(parent: Control) -> void:
	_add_centered_sprite(parent, BG_BOOK, BOOK_CENTER_COCOS, 0)
	_add_centered_sprite(parent, BG_SHADE, BOOK_CENTER_COCOS, 5)   # 源 z=5
	_add_centered_sprite(parent, BG_PAGE, BOOK_CENTER_COCOS, 10)   # 源 z=10


static func _add_centered_sprite(parent: Control, res_path: String, cocos_center: Vector2, z: int) -> void:
	var tex: Texture2D = load(res_path) as Texture2D
	if tex == null:
		return
	var s := TextureRect.new()
	s.texture = tex
	s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.size = tex.get_size()
	s.position = to_godot(cocos_center.x, cocos_center.y) - tex.get_size() * 0.5
	s.z_index = z
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(s)


# 源 back :660-684。TextureButton 适配（源 Sprite + backPress 双层切 visible）。
static func create_back_button(parent: Control) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = load(BACK_RES) as Texture2D
	btn.texture_pressed = load("res://assets/ui/alpha/HVGA/backbtn-disabled.png") as Texture2D
	btn.ignore_texture_size = true
	btn.position = to_godot(BACK_COCOS.x, BACK_COCOS.y) - _tex_size(BACK_RES) * 0.5
	parent.add_child(btn)
	return btn


# 源 createTagButton :351-411。12 tag（左 handbook_left / 右 handbook_right + select 版 + Label）。
# 返 {index -> {button: TextureButton, label: Label}}。
static func create_tag_buttons(parent: Control, cm: Variant) -> Dictionary:
	var tabs: Dictionary = {}
	for i in range(1, 13):
		var is_right: bool = i > 6   # 源 :358 i>6 用 right 纹理
		var normal: String = TAG_RIGHT if is_right else TAG_LEFT
		var selected: String = TAG_RIGHT_SEL if is_right else TAG_LEFT_SEL
		var btn := TextureButton.new()
		btn.texture_normal = load(normal) as Texture2D
		btn.texture_pressed = load(selected) as Texture2D
		btn.ignore_texture_size = true
		btn.position = tag_center(i) - _tex_size(normal) * 0.5
		btn.z_index = 4   # 源 :360
		parent.add_child(btn)
		var lbl := Label.new()
		lbl.text = _lstr(cm, TAG_LSTR[i - 1])
		lbl.add_theme_font_size_override("font_size", 16)   # 源 :391 size 16
		lbl.position = tag_center(i) - lbl.get_minimum_size() * 0.5
		lbl.z_index = 9 if i == 1 else 4   # 源 :393 i==1 z=9 else 4
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(lbl)
		tabs[i] = {"button": btn, "label": lbl}
	return tabs


# 源 createIcon :423-452。装备单元：handbook_equip_bg + 图标（已解锁 readequip.createIcon / 锁定 icon_lock）+ 名字。
# lr > player_level 锁定（源 :428 ed.player:getLevel() >= info.lr 才开）。
static func create_equip_cell(info: Dictionary, player_level: int, cm: Variant) -> Control:
	var cell := Control.new()
	var bg_tex: Texture2D = load(EQUIP_BG_RES) as Texture2D
	cell.custom_minimum_size = bg_tex.get_size() if bg_tex != null else Vector2(114, 114)
	cell.size = cell.custom_minimum_size
	var bg := TextureRect.new()
	bg.texture = bg_tex
	bg.size = cell.custom_minimum_size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(bg)
	var lr: int = int(info.get("lr", 1))
	var name_text: String = _lstr(cm, String(info.get("name", "")))
	var is_open: bool = player_level >= lr   # 源 :428
	if is_open:
		var icon: Control = ReadequipIcon.create_icon(int(info["id"]), 0, cm)
		icon.position = EQUIP_ICON_POS
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon)
	else:
		var icon_bg := TextureRect.new()   # 源 :434-440 handbook_icon_bg + lock
		icon_bg.texture = load(ICON_BG_RES) as Texture2D
		icon_bg.size = Vector2(66, 66)
		icon_bg.position = EQUIP_ICON_POS
		icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon_bg)
		var lock := TextureRect.new()
		lock.texture = load(ICON_LOCK_RES) as Texture2D
		lock.position = Vector2(33, 33) - _tex_size_centered(ICON_LOCK_RES)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_bg.add_child(lock)
		name_text = "Lv%d 解锁" % lr   # 源 :441 T(LSTR("HANDBOOK.LV_D_ACTIVATED"), lr)
	_add_name_label(cell, name_text)
	cell.set_meta(&"is_open", is_open)
	cell.set_meta(&"id", int(info["id"]))
	return cell


static func _add_name_label(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", EQUIP_NAME_FONT)
	lbl.add_theme_color_override("font_color", EQUIP_NAME_COLOR)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 2)   # 源 :444 shadow 近似
	lbl.position = EQUIP_NAME_POS
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)


# 源 left_arrow/right_arrow :685-708。
static func create_arrow(parent: Control, is_left: bool) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = load(ARROW_L_RES if is_left else ARROW_R_RES) as Texture2D
	btn.ignore_texture_size = true
	var cocos: Vector2 = LEFT_ARROW_COCOS if is_left else RIGHT_ARROW_COCOS
	btn.position = to_godot(cocos.x, cocos.y) - _tex_size(btn.texture_normal.resource_path) * 0.5
	btn.z_index = 20   # 源 :690
	parent.add_child(btn)
	return btn


static func _tex_size(res_path: String) -> Vector2:
	var tex: Texture2D = load(res_path) as Texture2D
	if tex != null:
		return tex.get_size()
	return Vector2(80, 50)


static func _tex_size_centered(res_path: String) -> Vector2:
	return _tex_size(res_path) * 0.5


static func _lstr(cm: Variant, key: String) -> String:
	if cm != null and cm.has_method("get_lstr"):
		return String(cm.get_lstr(key))
	return key
