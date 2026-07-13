class_name HeroDetailBuilder
extends RefCounted

## HeroDetailPanel 视觉工厂（照源 herodetail/window.lua create :1955-2030 + createHeroStars :1341-1392 +
## createBottomButtons :1395）。背景 + 英雄立绘 + 星级 + 名字框 + close + 动作按钮（替原纯文字）。
## 源 cocos(800×480 左下) → Godot(960×640 左上)：(cx+80, 560-cy)，同 hero_package/handbook 范式。

const OFFSET_X: float = 80.0
const BASE_Y: float = 560.0
# 源 :1961-1970 bg herodetail-bg @ (400,240)
const BG_RES: String = "res://assets/ui/alpha/HVGA/herodetail-bg.png"
const BG_COCOS: Vector2 = Vector2(400.0, 240.0)
# 源 :1976-1998 close @ (398,425) + close_press
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png"
const CLOSE_COCOS: Vector2 = Vector2(398.0, 425.0)
# 源 :2000-2009 name_bg @ (228,202) + :2010-2021 type_icon @ (122,204) z=202
const NAME_BG_RES: String = "res://assets/ui/alpha/HVGA/herodetail_name_bg.png"
const NAME_BG_COCOS: Vector2 = Vector2(228.0, 202.0)
const TYPE_COCOS: Vector2 = Vector2(122.0, 204.0)
const NAME_LABEL_COCOS: Vector2 = Vector2(175.0, 202.0)   # name_bg 上居中（估算）
# 源 :1355-1374 星级 灰星底（hero_max_star）+ 黄星（_stars）@ (364+20*(i-1), 258)
const STAR_GREY_RES: String = "res://assets/ui/alpha/HVGA/herodetail_star_grey.png"
const STAR_YELLOW_RES: String = "res://assets/ui/alpha/HVGA/herodetail_star_yellow.png"
const STAR_BASE_COCOS: Vector2 = Vector2(364.0, 258.0)
const STAR_DX: float = 20.0
const HERO_MAX_STAR: int = 3   # 源 res.hero_max_star（满星数，待校准）
# 英雄立绘区（源 createHeroFca :11 FCA 动画；本项目 FCA 接入重，降级 Unit.Portrait 静态立绘）
const PORTRAIT_COCOS: Vector2 = Vector2(125.0, 320.0)
const PORTRAIT_MAX_SIZE: Vector2 = Vector2(200.0, 280.0)
const PORTRAIT_PREFIX: String = "UI/"
const PORTRAIT_REPLACE: String = "res://assets/ui/"
# 动作按钮图（源 window.lua:2091/2286/2334 upgrade/evolve/onekey 全 herodetail-detail-n Scale9Sprite capInsets 15,15,138,19；herodetail-upgrade 是注释旧码不用）
const DETAIL_N_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-n.png"
const DETAIL_N_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-pressed-n.png"
const DETAIL_N_CAP: Rect2 = Rect2(15.0, 15.0, 138.0, 19.0)  # 源 capInsets CCRectMake(15,15,138,19)
const ACTION_BTN_SIZE: Vector2 = Vector2(100.0, 42.0)  # 源 scaleSize CCSizeMake(100,42)


static func to_godot(cx: float, cy: float) -> Vector2:
	return Vector2(cx + OFFSET_X, BASE_Y - cy)


# 源 :1961-1970 bg（anchor 0.5,0.5 居中）。
static func create_background(parent: Control) -> void:
	_add_centered(parent, BG_RES, BG_COCOS, 0)


# 源 createHeroFca :11 英雄立绘（FCA 动画）。本项目降级用 Unit.Portrait 静态立绘（资源就绪）。
static func create_portrait(parent: Control, hero: HeroInstance, cm: Variant) -> void:
	if cm == null:
		return
	var portrait_res: Variant = cm.lookup("Unit", "Portrait", int(hero.tid))
	if portrait_res == null or not (portrait_res is String) or (portrait_res as String).is_empty():
		return
	var path: String = (portrait_res as String).replace(PORTRAIT_PREFIX, PORTRAIT_REPLACE)
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return
	var sp := TextureRect.new()
	sp.texture = tex
	sp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var scale: float = min(PORTRAIT_MAX_SIZE.x / tex.get_size().x, PORTRAIT_MAX_SIZE.y / tex.get_size().y)
	if scale < 1.0:
		sp.size = tex.get_size() * scale
	else:
		sp.size = tex.get_size()
	sp.position = to_godot(PORTRAIT_COCOS.x, PORTRAIT_COCOS.y) - sp.size * 0.5
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(sp)


# 源 createHeroStars :1341-1392：灰星底（max）+ 黄星（stars）。
static func create_stars(parent: Control, stars: int) -> void:
	for i in range(1, HERO_MAX_STAR + 1):
		_add_star(parent, STAR_GREY_RES, i)
	for i in range(1, min(stars, HERO_MAX_STAR) + 1):
		_add_star(parent, STAR_YELLOW_RES, i)


static func _add_star(parent: Control, res_path: String, i: int) -> void:
	var tex: Texture2D = load(res_path) as Texture2D
	if tex == null:
		return
	var s := TextureRect.new()
	s.texture = tex
	s.position = to_godot(STAR_BASE_COCOS.x + STAR_DX * float(i - 1), STAR_BASE_COCOS.y) - tex.get_size() * 0.5
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(s)


# 源 :2000-2021 name_bg + type_icon + name Label。
static func create_name_board(parent: Control, hero: HeroInstance, cm: Variant) -> void:
	_add_centered(parent, NAME_BG_RES, NAME_BG_COCOS, 0)
	var attrib: String = String(cm.lookup("Unit", "Main Attrib", int(hero.tid))) if cm != null else ""
	var type_res: String = _type_icon_res(attrib)
	if not type_res.is_empty() and ResourceLoader.exists(type_res):
		_add_centered(parent, type_res, TYPE_COCOS, 202)
	var name_key: String = String(cm.lookup("Unit", "Display Name", int(hero.tid))) if cm != null else ""
	var name_str: String = String(cm.get_lstr(name_key)) if cm != null else ""
	var lbl := Label.new()
	lbl.text = name_str
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.position = to_godot(NAME_LABEL_COCOS.x, NAME_LABEL_COCOS.y) - lbl.get_minimum_size() * 0.5
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)


# 源 hero_mark_res STR/AGI/INT 图标（item.lua:1-5）。
static func _type_icon_res(attrib: String) -> String:
	match attrib:
		"HERO_EQUIP.STRENGTH":
			return "res://assets/ui/alpha/HVGA/icon_str.png"
		"HERO_EQUIP.AGILITY":
			return "res://assets/ui/alpha/HVGA/icon_agi.png"
		"HERO_EQUIP.INTELLIGENCE":
			return "res://assets/ui/alpha/HVGA/icon_int.png"
	return ""


static func _add_centered(parent: Control, res_path: String, cocos_center: Vector2, z: int) -> void:
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


# 源 close :1976-1998（detail-close + close_press 双层切 visible → TextureButton normal/pressed）。
static func create_close_button(parent: Control) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = load(CLOSE_RES) as Texture2D
	btn.texture_pressed = load(CLOSE_PRESS_RES) as Texture2D
	btn.ignore_texture_size = true
	btn.position = to_godot(CLOSE_COCOS.x, CLOSE_COCOS.y) - _tex_size(CLOSE_RES) * 0.5
	parent.add_child(btn)
	return btn


# 源动作按钮（window.lua:2091/2286/2334 upgrade/evolve/onekey 全 herodetail-detail-n Scale9Sprite capInsets 15,15,138,19 + 100×42）。
# use_upgrade_res 保留签名兼容调用点（历史参数，源全 detail-n 统一，内部分支已去）。
static func create_action_button(parent: Control, label_text: String, godot_pos: Vector2, use_upgrade_res: bool) -> Button:
	var btn: Button = UiScale9Button.make(DETAIL_N_RES, DETAIL_N_PRESS_RES, godot_pos - ACTION_BTN_SIZE * 0.5, ACTION_BTN_SIZE, DETAIL_N_CAP)
	parent.add_child(btn)
	if not label_text.is_empty():
		var lbl := Label.new()
		lbl.text = label_text
		lbl.set_anchors_preset(Control.PRESET_CENTER)
		lbl.add_theme_color_override("font_color", Color.BLACK)
		lbl.add_theme_color_override("font_outline_color", Color.WHITE)
		lbl.add_theme_constant_override("outline_size", 2)
		btn.add_child(lbl)
	return btn


static func _tex_size(res_path: String) -> Vector2:
	var tex: Texture2D = load(res_path) as Texture2D
	if tex != null:
		return tex.get_size()
	return Vector2(100.0, 40.0)
