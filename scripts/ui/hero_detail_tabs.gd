class_name HeroDetailTabs
extends RefCounted

## HeroDetailPanel「图鉴 card」+「技能 skill」tab 内容工厂（task#9 拆分 2026-07-20 + builder P2 拆分）。
## 含 card 基础结构（frame/art/name，源 card.lua:127-140）+ card 图标/星数（readhero.lua:1069-1158）+
## skill 行绘制（图标+升级按钮，源 skillstren.lua:424-451）+ 技能描述弹板（skillstren.lua:14）。
## 不含 panel 状态，全 static + 参数化，panel 传 host + on_click Callable。
## 单向依赖：本类 → HeroDetailAttribs.get_lstr_fallback + HeroDetailFills.to_godot（避 class_name 循环）。

const CONTENT_SCALE: float = 1.28125
# 源止态定位链（2026-08-22 内容回源）：card.lua:150 card 弹层 container(-200,0)（= window.lua:513
# pop endPos）→ ui.container 中心 ccp(400,240)（card.lua:135）→ 卡片 container 中心全局 cocos (200,240)。
const CARD_CENTER_COCOS: Vector2 = Vector2(200.0, 240.0)   # container 中心（container 242×420 点，readhero.lua:1053）
# container 局部 (0,0)（左下角）基准，TabCardView 局部口径：全局 (79,450) + view 左缘 -200 = (279,450)。
# 动态子节点公式 = CONTAINER_ORIGIN + (局部x, -局部y)（cocos y 向上 → Godot 取负）。
# 源实机图 final_axmol_herodetail_800x480.png 实测卡框 (79,24.6)~(324.9,450) 逐边吻合。
const CONTAINER_ORIGIN: Vector2 = Vector2(279.0, 450.0)
const CONTAINER_LOGIC_H: float = 420.0   # 源 container 高（readhero.lua:1053 CCSizeMake(242,420)），Art 等比目标高
const CARD_FRAME_SIZE: Vector2 = Vector2(315.0 / CONTENT_SCALE, 545.0 / CONTENT_SCALE)   # CardFrame 显示尺寸（card_bg 纹理 ÷CS = 245.90×425.37）
# Art 中心 = 源 readhero.lua:1132 card:setPosition(ccp(123,215))（container 局部，clipping node 中心锚）
# → TabCardView 局部 (279+123, 450-215) = (402,235)。Art 显示 = 源 setScale(420/ArtH) 等比：高 420、宽随纹理比。
const ART_CENTER: Vector2 = Vector2(402.0, 235.0)
const ART_MODULATE: Color = Color(1.0, 1.0, 1.0)   # 原始不提亮（暗根因=层级：TabCardView z-1 被 BaseLayer Bg 盖，改 z 解决非提亮）
const ART_MASK_RES: String = "res://assets/ui/alpha/HVGA/art_mask.png"
# 源 readhero.lua:992 card_type_icon（big 版）：type → 类型图标资源。
const CARD_TYPE_ICON_RES: Dictionary = {
	"STR": "res://assets/ui/alpha/HVGA/card/card_att_str_big.png",
	"AGI": "res://assets/ui/alpha/HVGA/card/card_att_agi_big.png",
	"INT": "res://assets/ui/alpha/HVGA/card/card_att_int_big.png",
}
const CARD_STAR_RES: String = "res://assets/ui/alpha/HVGA/card/card_star_big.png"
# 源 readhero.lua:1152-1157 star setScale(0.5)：显示 = 纹理 46×48px ×0.5 ÷CS = 17.95×18.73 点
# （旧值 23×24 为 tex_px×0.5 直用，px 坐标系下视觉正确，坐标系迁显示口径后同步 ÷CS）。
const CARD_STAR_SIZE: Vector2 = Vector2(23.0 / CONTENT_SCALE, 24.0 / CONTENT_SCALE)
const EQUIP_FRAME_WHITE_PATH: String = "res://assets/ui/alpha/HVGA/equip_frame_white.png"
# 名字底纹条（源 readhero.lua:1141-1148）：name 像素宽 > NAME_BG_SHORT_THRESHOLD 用 short 版，否则 long 版。
const CARD_NAME_BG_SHORT_RES: String = "res://assets/ui/alpha/HVGA/card/card_name_bg_short.png"
const CARD_NAME_BG_LONG_RES: String = "res://assets/ui/alpha/HVGA/card/card_name_bg_long.png"
const CARD_NAME_BG_SHORT_THRESHOLD: float = 120.0   # 源 readhero.lua:1143 阈值
# short/long.png IHDR 71×151×11px，显示 = ÷CS（2026-08-22 溢出修复：旧值 IHDR px 直用）。
const CARD_NAME_BG_SHORT_W: float = 71.0 / CONTENT_SCALE
const CARD_NAME_BG_LONG_W: float = 151.0 / CONTENT_SCALE
const CARD_NAME_BG_H: float = 11.0 / CONTENT_SCALE
# skill icon equip_frame_white 白边框（源 readhero.lua:1011-1021 createSkillIcon：frame 挂 icon 内
# ccp(30,29) 随 icon setScale(22/iconW) 缩放。icon 纹理 78×78px÷CS=60.88 → scale 0.3615；
# frame 94×95px÷CS=73.4×74.2 ×0.3615 = 26.5×26.8，中心偏 icon 中心 (30-30.44,29-30.44)×0.3615≈居中）。
const SKILL_ICON_FRAME_SIZE: Vector2 = Vector2(26.5, 26.8)   # 白框显示尺寸（源比例 1.2× 盖 icon 22）
# CardArtName 称号 Label（源 readhero.lua:1102-1110）：max_width=180 size=14 暖白 ccc3(233,232,213)。
const CARD_ART_NAME_MAX_WIDTH: float = 180.0
const CARD_ART_NAME_COLOR: Color = Color(233.0 / 255.0, 232.0 / 255.0, 213.0 / 255.0, 1.0)
const SKILL_GRAY_MODULATE: Color = Color(0.4, 0.4, 0.4, 1.0)
const SKILL_ICON_BTN_SIZE: Vector2 = Vector2(40.0, 40.0)   # 技能图标可点击区
const SKILL_BTN_SIZE: Vector2 = Vector2(80.0, 28.0)
const SKILL_DESC_POS: Vector2 = Vector2(400.0, 100.0)      # 描述弹板位置
const SKILL_GROWTH_COLOR: Color = Color(1.0, 0.81, 0.07)
const SKILL_TIP_RES: String = "res://assets/ui/alpha/HVGA/herodetail-skill-tip.png"
const SKILL_UP_BTN_RES: String = "res://assets/ui/alpha/HVGA/herodetail_skill_upgrade_button_1.png"
const SKILL_UP_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail_skill_upgrade_button_2.png"
const SKILL_UP_BTN_SIZE: Vector2 = Vector2(40.0, 40.0)
const UI_PATH_PREFIX: String = "UI/"
const UI_PATH_REPLACE: String = "res://assets/ui/"


# ==================== card 图鉴视图 fill（Phase B：.tscn %TabCardView 已建节点）====================

# 统一 fill card view（panel._fill_card_view 入口）：frame/art/name 基础（源 card.lua:127-140）+
# 类型图标/技能图标/星数（readhero.lua:1069-1158）+ 标记 Art 子（测试识别 card 内容渲染）。
static func fill_card_view(view: Control, hero: HeroInstance, cm: Variant) -> void:
	if cm == null:
		return
	_fill_card_frame(view.get_node("%CardFrame") as TextureRect, hero.rank)
	_fill_card_art(view.get_node("%CardArtHost") as Control, hero, cm)
	_fill_card_name(view.get_node("%CardNameLabel") as Label, view.get_node("%CardArtName") as Label, view.get_node("%CardNameBgLine") as TextureRect, hero, cm)
	_fill_card_type_icon(view, hero, cm)
	_fill_card_skill_icons(view, hero, cm)
	_fill_card_stars(view, hero)
	var art_host: Control = view.get_node("%CardArtHost") as Control
	for c in art_host.get_children():
		c.set_meta(&"tab_content", true)   # Art 标记


# fill %CardFrame texture（源 card_frame rank 色，herodetailres.lua:27-51）。
static func _fill_card_frame(frame: TextureRect, rank: int) -> void:
	frame.texture = load(_card_frame_res(rank)) as Texture2D


# fill %CardArtHost（源 card.lua:111 Art = row.Art，居中缩放进 frame + 圆角 shader 近似源 art_mask 裁剪）。
static func _fill_card_art(host: Control, hero: HeroInstance, cm: Variant) -> void:
	var art_res: String = String(cm.lookup("Unit", "Art", int(hero.tid)))
	var art: TextureRect = _make_card_art(art_res, hero.rank)
	if art != null:
		host.add_child(art)


# fill %CardNameLabel text（源 card.lua:112 name = Display Name）+ %CardArtName 称号（源 readhero.lua:1102-1110
# Unit "Art Name" LSTR key）+ %CardNameBgLine 底纹条（源 readhero.lua:1141-1148 按 name 像素宽选 short/long）。
# name_label = 主名 Label；art_label = 称号小字 Label；bg_line = 名字底纹 TextureRect。
static func _fill_card_name(name_label: Label, art_label: Label, bg_line: TextureRect, hero: HeroInstance, cm: Variant) -> void:
	var display_name: String = HeroDetailFills.get_display_name(hero, cm)
	name_label.text = display_name
	# 称号（Art Name 字段，LSTR key → 本地化）。可能为空（部分英雄无称号），art_label.text 留空。
	var art_key: String = String(cm.lookup("Unit", "Art Name", int(hero.tid)))
	art_label.text = cm.get_lstr(art_key) if not art_key.is_empty() else ""
	# 底纹条按 name 像素宽选贴图（源 readhero.lua:1143 name:getSize().width > 120 判定）。
	# 用 name_label 当前 font 量宽，无 font 时回退 display_name.length() 近似。
	var name_width: float = _measure_label_text_width(name_label, display_name)
	var use_short: bool = name_width > CARD_NAME_BG_SHORT_THRESHOLD
	var bg_res: String = CARD_NAME_BG_SHORT_RES if use_short else CARD_NAME_BG_LONG_RES
	var bg_tex: Texture2D = _load_texture(bg_res)
	bg_line.texture = bg_tex
	# 重设 offset_left/right 让 bg 右对齐 anchor(1,0.5)（源 readhero.lua:1146-1147 ccp(242,60) 右锚定）。
	# container 右缘 = TabCardView 局部 x 279+242 = 521.0（2026-08-22 内容回源；旧值 399.05 系
	# 1.28 时代 CardFrame left 157.05 + 242 口径）；bg 宽按选贴图。
	var bg_w: float = CARD_NAME_BG_SHORT_W if use_short else CARD_NAME_BG_LONG_W
	bg_line.offset_right = 521.0
	bg_line.offset_left = 521.0 - bg_w


# 用 Label 当前 font 量字符串像素宽（font 未就绪时回退 char 数 ×8 近似，保证有底纹）。
static func _measure_label_text_width(label: Label, text_str: String) -> float:
	if text_str.is_empty():
		return 0.0
	var font: Font = label.get_theme_default_font()
	var size: int = label.get_theme_font_size(&"font_size")
	if font == null:
		return float(text_str.length()) * 8.0
	return font.get_string_size(text_str, HORIZONTAL_ALIGNMENT_LEFT, -1.0, max(size, 1)).x


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


# Art 立绘 TextureRect（源 readhero.lua:1131-1135 createClippingNode(cardres, art_mask, nil, (-20,-8))
# + card:setPosition(ccp(123,215)) + setScale(420/ArtH)）。
# 2026-08-22 内容回源：照源公式 = 等比缩放至高 420（container 高，readhero.lua:1053），中心局部 (123,215)
# → ART_CENTER (402,235)。典型 card_bg_big_*.jpg 536×928px → 显示 242.6×420（≈container 242×420 铺满逻辑区，
# frame 245.9×425.4 四周多出 ~1.7/2.7 的边框装饰）。圆角裁剪沿用 art_mask shader 近似源 ClippingNode。
static func _make_card_art(art_res: String, rank: int) -> TextureRect:
	if art_res.is_empty():
		return null
	var path: String = art_res.replace(UI_PATH_PREFIX, UI_PATH_REPLACE)
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return null
	var sp := TextureRect.new()
	sp.texture = tex
	sp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# 源 setScale(420/ArtH)：等比目标高 = container 高 420，宽随纹理比例。
	var tex_w: float = float(tex.get_width())
	var tex_h: float = float(tex.get_height())
	var scale: float = CONTAINER_LOGIC_H / tex_h
	var disp_w: float = tex_w * scale
	sp.size = Vector2(disp_w, CONTAINER_LOGIC_H)
	sp.stretch_mode = TextureRect.STRETCH_SCALE
	sp.modulate = ART_MODULATE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/art_mask.gdshader")
	mat.set_shader_parameter("mask_tex", load(ART_MASK_RES) as Texture2D)
	sp.material = mat
	sp.position = ART_CENTER - sp.size * 0.5   # Art 中心 = 源 ccp(123,215)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sp


static func _fill_card_type_icon(view: Control, hero: HeroInstance, cm: Variant) -> void:
	if cm == null or hero == null:
		return
	var type_str: String = String(cm.lookup("Unit", "Main Attrib", int(hero.tid)))
	var res: String = String(CARD_TYPE_ICON_RES.get(type_str, ""))
	if res.is_empty():
		return
	var tex: Texture2D = _load_texture(res)
	if tex == null:
		return
	var icon := TextureRect.new()
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = Vector2(47.0, 42.0)
	# 源 readhero.lua:1074-1081 type icon fix_size(47,42) 中心锚 @ccp(32,67)（container 局部）。
	icon.position = CONTAINER_ORIGIN + Vector2(32.0, -67.0) - icon.size * 0.5
	icon.z_index = 3   # 源 z=1 同 frame 层后 add（在 frame 之上）
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(icon)
	icon.set_meta(&"tab_content", true)


static func _fill_card_skill_icons(view: Control, hero: HeroInstance, cm: Variant) -> void:
	if cm == null or hero == null:
		return
	var sg: Dictionary = cm.get_raw_table(&"SkillGroup").get(str(hero.tid), {})
	# frame 白边框纹理预加载（4 icon 共用，源 readhero.lua:1014-1018 每个 skill icon addChild equip_frame_white）。
	var frame_tex: Texture2D = _load_texture(EQUIP_FRAME_WHITE_PATH)
	for i in range(4):
		var slot_info: Dictionary = sg.get(str(i + 1), {})
		var icon_res: String = String(slot_info.get("Icon", ""))
		if icon_res.is_empty():
			continue
		var tex: Texture2D = _load_ui_texture(icon_res)
		if tex == null:
			continue
		# icon 中心（源 readhero.lua:1125 ccp(130.5+27.2*(i-1), 28) container 局部，i 从 1 → 此处 i 从 0）。
		var icon_center: Vector2 = CONTAINER_ORIGIN + Vector2(130.5 + 27.2 * float(i), -28.0)
		# frame 白边框（先 add → 在 view 子序下层，icon 后 add 盖其上）。源 frame 随 icon 缩放居中盖 icon
		# （readhero.lua:1016-1017 bg @ccp(30,29) 挂 icon，icon 60.88 点方 → 中心偏 (-0.44,-1.44)×0.3615≈居中）。
		if frame_tex != null:
			var frame := TextureRect.new()
			frame.texture = frame_tex
			frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			frame.size = SKILL_ICON_FRAME_SIZE
			frame.position = icon_center - frame.size * 0.5
			frame.z_index = 3   # 与 icon 同层（先 add 子序在下，icon 盖 frame 中心透明区）
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			view.add_child(frame)
			frame.set_meta(&"tab_content", true)
		var icon := TextureRect.new()
		icon.texture = tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size = Vector2(22.0, 22.0)
		icon.position = icon_center - icon.size * 0.5
		icon.z_index = 3   # 源 setScale(22/iconW)（readhero.lua:1127），z=1 同层后 add 在 frame 上
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.add_child(icon)
		icon.set_meta(&"tab_content", true)


static func _fill_card_stars(view: Control, hero: HeroInstance) -> void:
	if hero == null:
		return
	var tex: Texture2D = _load_texture(CARD_STAR_RES)
	if tex == null:
		return
	for i in range(hero.stars):
		var star := TextureRect.new()
		star.texture = tex
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.size = CARD_STAR_SIZE
		# 源 readhero.lua:1150-1157 star 中心 ccp(25+14*(i-1), 27)（container 局部，i 从 1 → 此处从 0）。
		star.position = CONTAINER_ORIGIN + Vector2(25.0 + 14.0 * float(i), -27.0) - star.size * 0.5
		star.z_index = 5 - i   # 源 z=6-i（readhero.lua:1155）：左星压右星
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.add_child(star)
		star.set_meta(&"tab_content", true)


# ==================== skill 行绘制（图标 + 升级按钮）====================

# skill_tab 静态化后 panel fill 用：加载技能图标纹理（动态，每技能不同）。
# create_skill_icon/create_skill_upgrade_button 保留兼容（DescHost 等），skill_tab 改 .tscn + 本函数 fill。
static func load_skill_icon(icon_res: String) -> Texture2D:
	return _load_ui_texture(icon_res)


# 边框 Sprite2D（equip_frame_white centered）+ 图标 TextureButton（可点击 → 描述弹板）。
# locked=true 灰显（源 skillstren.lua:434 setSpriteGray）。icon_pos/on_click 由 panel 传入。
static func create_skill_icon(skill_host: Control, icon_res: String, icon_pos: Vector2, locked: bool, slot: int, on_click: Callable) -> void:
	var tex: Texture2D = _load_ui_texture(icon_res)
	if tex == null:
		return
	var frame := Sprite2D.new()
	frame.texture = _load_texture(EQUIP_FRAME_WHITE_PATH)
	if frame.texture != null:
		frame.position = icon_pos
		if locked:
			frame.modulate = SKILL_GRAY_MODULATE
		skill_host.add_child(frame)
		frame.set_meta(&"tab_content", true)
	var btn := TextureButton.new()
	btn.texture_normal = tex
	btn.texture_hover = tex
	btn.ignore_texture_size = true
	btn.size = SKILL_ICON_BTN_SIZE
	btn.position = icon_pos - SKILL_ICON_BTN_SIZE * 0.5   # TextureButton 左上 = 中心 - size/2
	if locked:
		btn.modulate = SKILL_GRAY_MODULATE
	btn.pressed.connect(on_click)
	btn.set_meta(&"skill_icon", true)   # 标记技能图标（测试区分 vs close/action 按钮图）
	skill_host.add_child(btn)


# pos = 按钮 godot 左上基准（panel 算好传入，center = pos + SKILL_BTN_SIZE/2）。
# on_click = 升级回调（panel 传 Callable(self,"_on_skill_upgrade_clicked").bind(idx)）。
static func create_skill_upgrade_button(skill_host: Control, pos: Vector2, on_click: Callable) -> void:
	var btn := TextureButton.new()
	btn.texture_normal = load(SKILL_UP_BTN_RES) as Texture2D
	btn.texture_pressed = load(SKILL_UP_BTN_PRESS_RES) as Texture2D
	btn.ignore_texture_size = true
	btn.size = SKILL_UP_BTN_SIZE
	btn.position = pos + SKILL_BTN_SIZE * 0.5 - SKILL_UP_BTN_SIZE * 0.5
	skill_host.add_child(btn)
	btn.set_meta(&"tab_content", true)   # 标记 tab 内容（测试识别）
	btn.set_meta(&"skill_upgrade", true)   # 标记技能升级按钮（测试识别）
	btn.pressed.connect(on_click)


# ==================== 技能描述弹板（源 skillstren.lua:14 createDescBoard）====================

# 建 desc board（NinePatchRect bg herodetail-skill-tip.png cap 20,52,200,5 + description label ox=27）。
# 描述 = Skill.Description（get_skill_description）+ 成长值（get_skill_desc，黄色）。
# 返 bg（含 meta slot，panel 接 _add_tab_content + _desc_label = bg）。
static func build_skill_desc(hero: HeroInstance, slot: int, cm: Variant) -> Control:
	var desc: String = ReadheroSkill.get_skill_description(hero, slot + 1, cm)
	var growth: String = ReadheroSkill.get_skill_desc(hero, slot + 1, cm)
	var bg := NinePatchRect.new()
	bg.texture = _load_texture(SKILL_TIP_RES)
	# 源 skillstren.lua:20 capInsets = CCRectMake(20, 52, 200, 5)（左下原点中间拉伸区），
	# 贴图 345x101 纹理px：L=20 / T=44 / R=125 / B=52；patch 须 ÷CS 取整 → 16/34/98/41。
	bg.patch_margin_left = 16
	bg.patch_margin_top = 34
	bg.patch_margin_right = 98
	bg.patch_margin_bottom = 41
	bg.position = SKILL_DESC_POS
	bg.size = Vector2(280.0, 100.0)
	var lbl := Label.new()
	lbl.text = desc + ("\n" + growth if not growth.is_empty() else "")
	lbl.position = Vector2(27.0, 15.0)
	lbl.add_theme_font_size_override("font_size", 13)
	if not growth.is_empty():
		lbl.modulate = SKILL_GROWTH_COLOR
	bg.add_child(lbl)
	bg.set_meta("slot", slot)
	return bg


# ==================== load 工具（readhero 范式）====================

static func _load_ui_texture(ui_path: String) -> Texture2D:
	if ui_path.is_empty():
		return null
	var path: String = ui_path.replace(UI_PATH_PREFIX, UI_PATH_REPLACE) if ui_path.begins_with(UI_PATH_PREFIX) else ui_path
	return _load_texture(path)


static func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
