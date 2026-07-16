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
# 源 createBottomButtons（window.lua:1395-1663）：detail/card/skill 三 tab Scale9Sprite。
# 源 detail-n（normal）+ detail-a（select active）双态切 visible（:1429/:1444）。
# 本项目单 Button swap normal stylebox 近似（n=未选 / a=选中）。
const TAB_N_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-n.png"
const TAB_A_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-a.png"
const TAB_CAP: Rect2 = Rect2(15.0, 15.0, 138.0, 19.0)   # 源 capInsets 同动作按钮
const TAB_SIZE: Vector2 = Vector2(120.0, 49.0)          # 源 scaleSize CCSizeMake(120,49)
const TAB_DETAIL_COCOS: Vector2 = Vector2(75.0, 42.0)   # 源 :1409 detail ccp(75,42)
const TAB_CARD_COCOS: Vector2 = Vector2(200.0, 42.0)    # 源 :1486 card ccp(200,42)
const TAB_SKILL_COCOS: Vector2 = Vector2(326.0, 42.0)   # 源 :1563 skill ccp(326,42)
# 源 card.lua getInformation + readhero.getHeroCard：rank 色边框（card_frame）+ Art 立绘 + 名字。
const CARD_CENTER_COCOS: Vector2 = Vector2(400.0, 240.0)   # 源 card.lua:135 ccp(400,240)
const CARD_ART_MAX_SIZE: Vector2 = Vector2(240.0, 240.0)   # Art 缩放上限（frame 内贴图区）
const CARD_NAME_COCOS: Vector2 = Vector2(400.0, 90.0)      # 名字（frame 底部 name 区估算）


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
		btn.text = label_text   # Button.text 自描述（可测）+ theme override 等价子 Label 视觉（BLACK 字 WHITE 描边）
		btn.add_theme_color_override("font_color", Color.BLACK)
		btn.add_theme_color_override("font_outline_color", Color.WHITE)
		btn.add_theme_constant_override("outline_size", 2)
	return btn


static func _tex_size(res_path: String) -> Vector2:
	var tex: Texture2D = load(res_path) as Texture2D
	if tex != null:
		return tex.get_size()
	return Vector2(100.0, 40.0)


# 源 skillstren.lua:345-364 技能升级按钮 = Sprite herodetail_skill_upgrade_button_1.png（无文字，纯图标）+
# button_press herodetail_skill_upgrade_button_2.png。
# 本项目 TextureButton（normal/pressed 双态）居中于 pos。
const SKILL_UP_BTN_RES: String = "res://assets/ui/alpha/HVGA/herodetail_skill_upgrade_button_1.png"
const SKILL_UP_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail_skill_upgrade_button_2.png"
const SKILL_UP_BTN_SIZE: Vector2 = Vector2(40.0, 40.0)   # 源按钮触控区近似（纹理 ~32×32）


static func create_skill_upgrade_button(parent: Control, godot_center_pos: Vector2) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = load(SKILL_UP_BTN_RES) as Texture2D
	btn.texture_pressed = load(SKILL_UP_BTN_PRESS_RES) as Texture2D
	btn.ignore_texture_size = true
	btn.size = SKILL_UP_BTN_SIZE
	btn.position = godot_center_pos - SKILL_UP_BTN_SIZE * 0.5
	parent.add_child(btn)
	return btn


# ---- 底栏三 tab（源 createBottomButtons window.lua:1395-1663）----

# 建 detail/card/skill 三 Scale9 tab 按钮（normal=detail-n，选中 swap detail-a）。
# labels: {key: 显示文本}。返回 {key: Button}。selected_key 对应的按钮初始选中态。
static func create_tab_bar(parent: Control, labels: Dictionary, selected_key: String) -> Dictionary:
	var buttons: Dictionary = {}
	var positions: Dictionary = {
		"detail": TAB_DETAIL_COCOS,
		"card": TAB_CARD_COCOS,
		"skill": TAB_SKILL_COCOS,
	}
	for key in positions:
		var cocos_p: Vector2 = positions[key]
		var center: Vector2 = to_godot(cocos_p.x, cocos_p.y)
		var btn: Button = UiScale9Button.make(TAB_N_RES, TAB_N_RES, center - TAB_SIZE * 0.5, TAB_SIZE, TAB_CAP, String(labels.get(key, key)))
		btn.set_meta(&"tab_button", key)
		parent.add_child(btn)
		buttons[key] = btn
	set_tab_selected(buttons, selected_key)
	return buttons


# 切 tab 选中态：选中 → detail-a stylebox，未选 → detail-n stylebox（源 :321-323 切 _select visible）。
static func set_tab_selected(buttons: Dictionary, selected_key: String) -> void:
	for key in buttons:
		var btn: Button = buttons[key]
		var res_path: String = TAB_A_RES if key == selected_key else TAB_N_RES
		var sb: StyleBoxTexture = _make_tab_stylebox(res_path)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)


static func _make_tab_stylebox(res_path: String) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	var tex: Texture2D = load(res_path) as Texture2D
	sb.texture = tex
	sb.texture_margin_left = TAB_CAP.position.x
	sb.texture_margin_top = TAB_CAP.position.y
	if tex != null:
		sb.texture_margin_right = tex.get_width() - TAB_CAP.position.x - TAB_CAP.size.x
		sb.texture_margin_bottom = tex.get_height() - TAB_CAP.position.y - TAB_CAP.size.y
	return sb


# ---- card 图鉴视图（源 card.lua getInformation + readhero.getHeroCard）----

# 源 card.lua:127-140 createCard：rank 色边框（card_frame）+ Art 立绘 + 名字。
# 缺图降级：card_att_*（职业图标）缺失省略；Art 缺 → frame 占位。所有子节点 mouse_filter=IGNORE。
# 每个子节点打 tab_content 标记（HeroDetailPanel 切 tab 时 free）。
static func create_card_view(parent: Control, hero: HeroInstance, cm: Variant) -> void:
	if cm == null:
		return
	# 源 card_frame（herodetailres.lua:27-51）：rank → 颜色边框。
	var frame_res: String = _card_frame_res(hero.rank)
	var frame: TextureRect = _make_centered_rect(frame_res, CARD_CENTER_COCOS, 0)
	_tag_tab(frame, parent)
	# 源 :111 cardres = row.Art（立绘大图）。
	var art_res: String = String(cm.lookup("Unit", "Art", int(hero.tid)))
	var art: TextureRect = _make_card_art(art_res)
	if art != null:
		_tag_tab(art, parent)
	# 源 :112 name = Display Name。
	var name_key: String = String(cm.lookup("Unit", "Display Name", int(hero.tid)))
	var name_str: String = String(cm.get_lstr(name_key))
	var lbl := Label.new()
	lbl.text = name_str
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.position = to_godot(CARD_NAME_COCOS.x, CARD_NAME_COCOS.y) - lbl.get_minimum_size() * 0.5
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag_tab(lbl, parent)


static func _tag_tab(node: Control, parent: Control) -> void:
	node.set_meta(&"tab_content", true)
	parent.add_child(node)


# rank → card_bg_{color}.png（源 card_frame 索引）。red 缺图 → orange 降级。
static func _card_frame_res(rank: int) -> String:
	var color: String = "white"
	if rank >= 12:
		color = "orange"
	elif rank >= 7:
		color = "purple"
	elif rank >= 4:
		color = "blue"
	elif rank >= 2:
		color = "green"
	return "res://assets/ui/alpha/HVGA/card/card_bg_%s.png" % color


# 居中 TextureRect（不 add 到 parent，由调用方打标 + add）。
static func _make_centered_rect(res_path: String, cocos_center: Vector2, z: int) -> TextureRect:
	var tex: Texture2D = load(res_path) as Texture2D
	var s := TextureRect.new()
	if tex == null:
		return s
	s.texture = tex
	s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.size = tex.get_size()
	s.position = to_godot(cocos_center.x, cocos_center.y) - tex.get_size() * 0.5
	s.z_index = z
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


# Art 立绘（源 :134 ed.readhero.getHeroCard）：UI/art/card_bg_big_X.jpg 居中缩放进 frame。
static func _make_card_art(art_res: String) -> TextureRect:
	if art_res.is_empty():
		return null
	var path: String = art_res.replace(PORTRAIT_PREFIX, PORTRAIT_REPLACE)
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return null
	var sp := TextureRect.new()
	sp.texture = tex
	sp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var sc: float = min(CARD_ART_MAX_SIZE.x / tex.get_size().x, CARD_ART_MAX_SIZE.y / tex.get_size().y)
	sp.size = tex.get_size() * sc
	sp.position = to_godot(CARD_CENTER_COCOS.x, CARD_CENTER_COCOS.y + 50.0) - sp.size * 0.5   # 略上偏让出底部 name 区
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sp
