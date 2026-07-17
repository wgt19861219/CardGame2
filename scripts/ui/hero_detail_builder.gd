class_name HeroDetailBuilder
extends RefCounted

## HeroDetailPanel 视觉工厂（Phase A+B 重构 2026-07-17）。
## base 层 + tab view（card/detail/skill）位置+size 静态化进 hero_detail_content.tscn（编辑器可视化调）。
## 本类只往 .tscn 节点填动态数据（fill_*）+ 给 .tscn 普通 Button 套 Scale9 样式（apply_*）。
## tab 内容（属性/技能行/Art）fill 到各 tab view 的 host（visible 切换，不再 free+重建）。
## 源 cocos(800×480 左下) → Godot(960×640 左上)：(cx+80, 560-cy)，同 hero_package/handbook 范式。

const OFFSET_X: float = 80.0
const BASE_Y: float = 560.0

# ---- base 按钮 Scale9 样式（.tscn 普通 Button 套用，源 detail-n capInsets 15,15,138,19）----
# 源 window.lua:2091/2286/2334 升星/进阶/分解 全 herodetail-detail-n Scale9Sprite + capInsets 15,15,138,19。
const DETAIL_N_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-n.png"
const DETAIL_N_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-pressed-n.png"
const DETAIL_N_CAP: Rect2 = Rect2(15.0, 15.0, 138.0, 19.0)
# 源 createBottomButtons（window.lua:1395-1663）detail-n（normal）+ detail-a（select active）双态切。
const TAB_N_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-n.png"
const TAB_A_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-a.png"
const TAB_CAP: Rect2 = Rect2(15.0, 15.0, 138.0, 19.0)

# ---- portrait FCA（源 createHeroFca window.lua:11-18）----
const HERO_FCA_COCOS: Vector2 = Vector2(400.0, 265.0)   # 源 window.lua:14 ccp(400,265)
const HERO_FCA_SCALE: float = 1.5   # 源 readhero.lua:1254 createAnimation(Resource,1.5,AniType) 外层 scale（FcaAnimation 自带 _coord_scale 0.09，总=0.135）
const PORTRAIT_COCOS: Vector2 = Vector2(125.0, 320.0)   # 降级静态立绘中心
const PORTRAIT_MAX_SIZE: Vector2 = Vector2(200.0, 280.0)
const PORTRAIT_PREFIX: String = "UI/"
const PORTRAIT_REPLACE: String = "res://assets/ui/"
# 源 parameter.lua:24 hero_max_star=5（.tscn 建 %StarYellow1-5 / %StarGrey1-5）。
const STAR_COUNT: int = 5

# ---- card 图鉴视图（源 card.lua，Phase B 静态化进 .tscn %TabCardView）----
# 源 card.lua:135 ui.container ccp(400,240) 相对 cardLayer；cardLayer 挂 container，pop endPos(-200,0)（window.lua:513）。
# 世界 cocos = 400-200 = 200（已含 pop -200 偏移）。card_frame size .tscn 固化（编辑器拖），fill 只设 texture。
const CARD_CENTER_COCOS: Vector2 = Vector2(200.0, 240.0)
const CARD_ART_MAX_SIZE: Vector2 = Vector2(240.0, 240.0)   # Art 缩放上限（frame 内贴图区）

# ---- skill 升级按钮（源 skillstren.lua:345-364）----
const SKILL_UP_BTN_RES: String = "res://assets/ui/alpha/HVGA/herodetail_skill_upgrade_button_1.png"
const SKILL_UP_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail_skill_upgrade_button_2.png"
const SKILL_UP_BTN_SIZE: Vector2 = Vector2(40.0, 40.0)


static func to_godot(cx: float, cy: float) -> Vector2:
	return Vector2(cx + OFFSET_X, BASE_Y - cy)


# ==================== base 层 fill（Phase A：.tscn 已建节点，填动态数据 + 样式）====================

# 统一准备 base 层动态数据 + 按钮样式。base = .tscn instantiate 后的 %BaseLayer。
# 返 {gs_label, tab_buttons}（panel 持有：gs_label 供 refresh_gs_after_wear，tab_buttons 供 tab 切换）。
# 静态节点（%Bg/%NameBg/%StarGrey×5/%CloseBtn + 坐标）.tscn 已固化，此处不碰。
static func setup_base(base: Control, hero: HeroInstance, cm: Variant) -> Dictionary:
	fill_portrait(base.get_node("%PortraitHost"), hero, cm)
	fill_name_board(base.get_node("%TypeIcon"), base.get_node("%NameLabel"), hero, cm)
	fill_stars(_collect_yellow_stars(base), hero.stars)
	var gs_label: Label = fill_info_board(base, hero, cm)
	fill_action_buttons(base, cm)
	var tab_buttons: Dictionary = collect_tab_buttons(base)
	fill_tab_labels(tab_buttons, cm)
	for key in tab_buttons:
		(tab_buttons[key] as Button).set_meta(&"tab_button", key)   # 测试扫描 tab 按钮
	return {"gs_label": gs_label, "tab_buttons": tab_buttons}


# 源 createHeroFca :11 英雄立绘（FCA 动画）。本项目降级用 Unit.Portrait 静态立绘（资源就绪）。
static func fill_portrait(host: Control, hero: HeroInstance, cm: Variant) -> void:
	if cm == null:
		return
	if _try_add_hero_fca(host, hero, cm):
		return
	_add_portrait_fallback(host, hero, cm)


# 源 createHeroFca（window.lua:11-18）：Puppet.Resource → assets/anim_frames/<res>/sheet.plist + <res>.ani
# → FcaAnimation play("Idle")。资源就绪（assets/anim_frames/ 101 .ani）。FCA/atlas 缺返 false 走降级。
static func _try_add_hero_fca(parent: Control, hero: HeroInstance, cm: Variant) -> bool:
	var puppet_name: String = String(cm.lookup("Unit", "Puppet", int(hero.tid)))
	if puppet_name.is_empty():
		return false
	var puppet_cfg: Dictionary = cm.get_raw_table(&"Puppet").get(puppet_name, {})
	var resource: String = String(puppet_cfg.get("Resource", ""))
	if resource.is_empty():
		return false
	var atlas := AtlasSprite.new()
	if not atlas.load_atlas("res://assets/anim_frames/" + resource + "/sheet.plist"):
		return false
	var fca := FcaAnimation.new()
	if not fca.load_from_ani(resource, atlas):
		fca.queue_free()
		return false
	# 照 unit_sprite 范式：外层 _parts_node（scale=HERO_FCA_SCALE）+ FcaAnimation 加其下（_create_sprites
	# 自设 scale=_coord_scale 0.09）。勿覆盖 fca.scale，否则丢 cha_scale 致 sprite cocos 大坐标×1.5 巨大。
	var parts := Node2D.new()
	parts.position = to_godot(HERO_FCA_COCOS.x, HERO_FCA_COCOS.y)
	parts.scale = Vector2(HERO_FCA_SCALE, HERO_FCA_SCALE)
	parts.add_child(fca)
	parent.add_child(parts)
	fca.play("Idle")
	return true


# 降级静态立绘（FCA/atlas 缺时用 Unit.Portrait）。
static func _add_portrait_fallback(parent: Control, hero: HeroInstance, cm: Variant) -> void:
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


# fill %TypeIcon texture（源 hero_mark_res STR/AGI/INT，item.lua:1-5）+ %NameLabel text（Display Name）。
# 源 :2000-2021 name_bg + type_icon + name Label（位置 .tscn 已固化，此处只填动态 texture/text）。
static func fill_name_board(type_icon: TextureRect, name_label: Label, hero: HeroInstance, cm: Variant) -> void:
	var attrib: String = String(cm.lookup("Unit", "Main Attrib", int(hero.tid))) if cm != null else ""
	var type_res: String = _type_icon_res(attrib)
	if not type_res.is_empty() and ResourceLoader.exists(type_res):
		type_icon.texture = load(type_res) as Texture2D
	name_label.text = get_display_name(hero, cm)


static func _type_icon_res(attrib: String) -> String:
	match attrib:
		"HERO_EQUIP.STRENGTH":
			return "res://assets/ui/alpha/HVGA/icon_str.png"
		"HERO_EQUIP.AGILITY":
			return "res://assets/ui/alpha/HVGA/icon_agi.png"
		"HERO_EQUIP.INTELLIGENCE":
			return "res://assets/ui/alpha/HVGA/icon_int.png"
	return ""


# fill %StarYellow1-5 visible（stars 个数；灰星底 %StarGrey1-5 恒显，源 createHeroStars :1341-1392）。
static func fill_stars(yellow_stars: Array, stars: int) -> void:
	for i in range(yellow_stars.size()):
		(yellow_stars[i] as CanvasItem).visible = i < stars


static func _collect_yellow_stars(base: Control) -> Array:
	var stars: Array = []
	for i in range(1, STAR_COUNT + 1):
		stars.append(base.get_node("%StarYellow" + str(i)))
	return stars


# fill info 标题 LSTR（%LevelTitle/GsTitle/ExpTitle）+ 数字（%LevelNum/GsNum/ExpNum）。
# 源 createInfoBoard（window.lua:1210-1314）+ base 标题（:2022-2066）。颜色/字号 .tscn 已设。
# 返 %GsNum Label（供 panel refresh_gs_after_wear 更新）。
static func fill_info_board(base: Control, hero: HeroInstance, cm: Variant) -> Label:
	(base.get_node("%LevelTitle") as Label).text = String(cm.get_lstr(&"HERODETAIL.LEVEL_")) if cm != null else "等级:"
	(base.get_node("%LevelNum") as Label).text = str(hero.level)
	(base.get_node("%GsTitle") as Label).text = String(cm.get_lstr(&"HERODETAIL.POWER_")) if cm != null else "战力:"
	var gs_lbl: Label = base.get_node("%GsNum")
	gs_lbl.text = str(hero.gs)
	(base.get_node("%ExpTitle") as Label).text = String(cm.get_lstr(&"HERODETAIL.EXPERIENCE_")) if cm != null else "经验:"
	var max_exp: int = int(cm.lookup("Levels", "Exp", hero.level)) if cm != null else 0
	(base.get_node("%ExpNum") as Label).text = str(hero.exp) + "/" + str(max_exp)
	return gs_lbl


# fill 4 action button（%EvolveBtn/%UpgradeRankBtn/%SplitBtn/%EnhanceBtn）Scale9 样式 + LSTR text。
# 源 window.lua:2158/2322 evolve/upgrade label = T(LSTR("HERODETAIL.EVOLUTION_"/"ADVANCE_"))。
# 分解/强化源独立面板（split_button 缺图降级），本项目硬编码中文。
static func fill_action_buttons(base: Control, cm: Variant) -> void:
	var labels: Dictionary = {
		"EvolveBtn": String(cm.get_lstr(&"HERODETAIL.EVOLUTION_")) if cm != null else "升星",
		"UpgradeRankBtn": String(cm.get_lstr(&"HERODETAIL.ADVANCE_")) if cm != null else "进阶",
		"SplitBtn": "分解",
		"EnhanceBtn": "强化",
	}
	for btn_name in labels:
		var btn: Button = base.get_node("%" + btn_name)
		_apply_detail_style(btn)
		btn.text = labels[btn_name]


# .tscn 普通 Button 套 Scale9 StyleBoxTexture（normal/hover=detail-n，pressed=detail-pressed-n），
# 视觉等价原 UiScale9Button。源 action button 文字 BLACK + WHITE 描边 outline_size 2。
static func _apply_detail_style(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_stylebox(DETAIL_N_RES))
	btn.add_theme_stylebox_override("hover", _make_stylebox(DETAIL_N_RES))
	btn.add_theme_stylebox_override("pressed", _make_stylebox(DETAIL_N_PRESS_RES))
	btn.add_theme_color_override("font_color", Color.BLACK)
	btn.add_theme_color_override("font_outline_color", Color.WHITE)
	btn.add_theme_constant_override("outline_size", 2)


static func _make_stylebox(res_path: String) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	var tex: Texture2D = load(res_path) as Texture2D
	sb.texture = tex
	sb.texture_margin_left = DETAIL_N_CAP.position.x
	sb.texture_margin_top = DETAIL_N_CAP.position.y
	if tex != null:
		sb.texture_margin_right = tex.get_width() - DETAIL_N_CAP.position.x - DETAIL_N_CAP.size.x
		sb.texture_margin_bottom = tex.get_height() - DETAIL_N_CAP.position.y - DETAIL_N_CAP.size.y
	return sb


# 收集 3 tab 按钮（%TabDetailBtn/%TabCardBtn/%TabSkillBtn）→ {key: Button}。
static func collect_tab_buttons(base: Control) -> Dictionary:
	return {
		"detail": base.get_node("%TabDetailBtn"),
		"card": base.get_node("%TabCardBtn"),
		"skill": base.get_node("%TabSkillBtn"),
	}


# fill 3 tab LSTR text（源 :1468/:1545/:1622 HERODETAIL.DETAILED_PROPERTIES / ILLUSTRATIONS / TODOLIST.SKILLS_UPGRADING）。
static func fill_tab_labels(tab_buttons: Dictionary, cm: Variant) -> void:
	var labels: Dictionary = {
		"detail": String(cm.get_lstr(&"HERODETAIL.DETAILED_PROPERTIES")) if cm != null else "详细属性",
		"card": String(cm.get_lstr(&"HERODETAIL.ILLUSTRATIONS")) if cm != null else "图鉴",
		"skill": String(cm.get_lstr(&"TODOLIST.SKILLS_UPGRADING")) if cm != null else "技能升级",
	}
	for key in tab_buttons:
		(tab_buttons[key] as Button).text = labels[key]


# 切 tab 选中态：选中 → detail-a stylebox，未选 → detail-n（源 :321-323 切 _select visible）。
static func set_tab_selected(buttons: Dictionary, selected_key: String) -> void:
	for key in buttons:
		var res_path: String = TAB_A_RES if key == selected_key else TAB_N_RES
		var sb: StyleBoxTexture = _make_tab_stylebox(res_path)
		var btn: Button = buttons[key]
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


# ==================== card 图鉴视图 fill（Phase B：.tscn %TabCardView 已建节点）====================

# 统一 fill card view（%CardFrame texture + %CardArtHost Art + %CardNameLabel 名字）。
# 源 card.lua:127-140 createCard：rank 色边框（card_frame）+ Art 立绘 + 名字。
static func setup_card_view(view: Control, hero: HeroInstance, cm: Variant) -> void:
	if cm == null:
		return
	fill_card_frame(view.get_node("%CardFrame"), hero.rank)
	fill_card_art(view.get_node("%CardArtHost"), hero, cm)
	fill_card_name(view.get_node("%CardNameLabel"), hero, cm)


# fill %CardFrame texture（源 card_frame rank 色，herodetailres.lua:27-51）。
# size .tscn 固化（编辑器拖 offset 调），expand_mode=EXPAND_IGNORE_SIZE 纹理缩进 size。
static func fill_card_frame(frame: TextureRect, rank: int) -> void:
	frame.texture = load(_card_frame_res(rank)) as Texture2D


# fill %CardArtHost（源 card.lua:111 Art = row.Art，UI/art/card_bg_big_X.jpg 居中缩放进 frame）。
static func fill_card_art(host: Control, hero: HeroInstance, cm: Variant) -> void:
	var art_res: String = String(cm.lookup("Unit", "Art", int(hero.tid)))
	var art: TextureRect = _make_card_art(art_res)
	if art != null:
		host.add_child(art)


# fill %CardNameLabel text（源 card.lua:112 name = Display Name）。
static func fill_card_name(label: Label, hero: HeroInstance, cm: Variant) -> void:
	label.text = get_display_name(hero, cm)


# Unit Display Name（源 card/name 共用，LSTR key → 本地化名）。
static func get_display_name(hero: HeroInstance, cm: Variant) -> String:
	if cm == null:
		return ""
	var name_key: String = String(cm.lookup("Unit", "Display Name", int(hero.tid)))
	return String(cm.get_lstr(name_key))


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


# Art 立绘 TextureRect（源 :134 ed.readhero.getHeroCard）：居中缩放进 frame，略上偏让出底部 name 区。
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
	sp.position = to_godot(CARD_CENTER_COCOS.x, CARD_CENTER_COCOS.y + 50.0) - sp.size * 0.5
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sp


# ==================== skill 升级按钮（tab 内容动态挂 host，源 skillstren.lua:345-364）====================

# 源 skillstren.lua 技能升级按钮 = Sprite herodetail_skill_upgrade_button_1.png（无文字，纯图标）
# + button_press herodetail_skill_upgrade_button_2.png。本项目 TextureButton（normal/pressed 双态）居中于 pos。
static func create_skill_upgrade_button(parent: Control, godot_center_pos: Vector2) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = load(SKILL_UP_BTN_RES) as Texture2D
	btn.texture_pressed = load(SKILL_UP_BTN_PRESS_RES) as Texture2D
	btn.ignore_texture_size = true
	btn.size = SKILL_UP_BTN_SIZE
	btn.position = godot_center_pos - SKILL_UP_BTN_SIZE * 0.5
	parent.add_child(btn)
	return btn
