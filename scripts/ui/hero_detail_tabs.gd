class_name HeroDetailTabs
extends RefCounted

## HeroDetailPanel「图鉴 card」+「技能 skill」tab 内容工厂（task#9 拆分 2026-07-20 + builder P2 拆分）。
## 含 card 基础结构（frame/art/name，源 card.lua:127-140）+ card 图标/星数（readhero.lua:1069-1158）+
## skill 行绘制（图标+升级按钮，源 skillstren.lua:424-451）+ 技能描述弹板（skillstren.lua:14）。
## 不含 panel 状态，全 static + 参数化，panel 传 host + on_click Callable。
## 单向依赖：本类 → HeroDetailAttribs.get_lstr_fallback + HeroDetailBuilder.to_godot（避 class_name 循环）。

# 世界 cocos = 400-200 = 200（已含 pop 偏移）。card_frame size .tscn 固化，fill 只设 texture。
const CARD_CENTER_COCOS: Vector2 = Vector2(200.0, 190.0)   # Art center 世界 cocos（container center = frame center）
# Art setScale(420/ArtH) 显示高=container 高 420（readhero.lua:1134）。frame 镂空区 PIL 实测 294×372 居中偏上 77px。
# 项目 CardFrame .tscn offset (122.5,47.5)→(437.5,592.5) size 315×545 照源原尺寸（不放大，旧 369×570 偏大用户反馈）。
const CONTAINER_ORIGIN: Vector2 = Vector2(138.5, 539.5)   # container 左下角 Godot（保留兼容旧调用，Art fill 不再用）
const CONTAINER_SIZE: Vector2 = Vector2(335.0, 417.0)   # 旧镂空区估算（保留兼容，Art fill 不再用）
const CONTAINER_LOGIC_HEIGHT: float = 282.0   # 保留兼容（旧 Art fill 用），新 Art 公式改用 CARD_HOLE_SIZE
const CARD_FRAME_SIZE: Vector2 = Vector2(315.0, 545.0)   # CardFrame 阶级框 size 照源 PNG IHDR（offset 122.5,47.5→437.5,592.5）
# Art 内缩量（像素）：Art size = CardFrame size - INSET*2，让 Art 4 角落在 frame 圆角装饰内圈不超出。
# PIL 实测 CardFrame 4 角圆角半径约 8px，Art 之前 = frame size 时 4 角凸出 frame 圆角外 5px（38px² 面积），
# 内缩 8px 后 Art 4 角在 frame 圆角装饰内圈，0 凸出（牺牲少量边缘 Art 内容换边角整齐）。
const CARD_FRAME_INSET: float = 8.0
# card_bg 镂空区 PIL alpha<128 flood fill 实测 bbox (10,10)~(303,476) center png (156.5, 243.0)。
# Art 纹理实测 card_bg_big_*.jpg 536×928 ratio 0.5776，CardFrame 315×545 ratio 0.5780，**两者几乎同比例**。
# 用户要"按比例铺满框"= Art 铺满整个 CardFrame 315×545（不是镂空 294×467），Art 315×545 完全覆盖 frame，
# frame 边框装饰 + name 条从 Art 之上盖下来（源效果）。
const CARD_HOLE_SIZE: Vector2 = Vector2(294.0, 467.0)   # 保留（PIL alpha<128 实测，作参考）
const COORD_SX: float = 1.0
const COORD_SY: float = 1.0
# Art center 对齐 CardFrame center (280,320)，让 Art 相对 frame 上下对称铺满。
# （先前对齐镂空 center (279, 290.5) 致 Art 偏上：顶超出 frame 11px + 底距 frame 47px，用户反馈"顶超出底留白"）
const ART_CENTER: Vector2 = Vector2(280.0, 320.0)   # Art 显示中心 = CardFrame center
const ART_MODULATE: Color = Color(1.0, 1.0, 1.0)   # 原始不提亮（暗根因=层级：TabCardView z-1 被 BaseLayer Bg 盖，改 z 解决非提亮）
const ART_MASK_RES: String = "res://assets/ui/alpha/HVGA/art_mask.png"
# 源 readhero.lua:992 card_type_icon（big 版）：type → 类型图标资源。
const CARD_TYPE_ICON_RES: Dictionary = {
	"STR": "res://assets/ui/alpha/HVGA/card/card_att_str_big.png",
	"AGI": "res://assets/ui/alpha/HVGA/card/card_att_agi_big.png",
	"INT": "res://assets/ui/alpha/HVGA/card/card_att_int_big.png",
}
const CARD_STAR_RES: String = "res://assets/ui/alpha/HVGA/card/card_star_big.png"
const CARD_STAR_SIZE: Vector2 = Vector2(23.0, 24.0)
const EQUIP_FRAME_WHITE_PATH: String = "res://assets/ui/alpha/HVGA/equip_frame_white.png"
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
	_fill_card_name(view.get_node("%CardNameLabel") as Label, hero, cm)
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


# fill %CardNameLabel text（源 card.lua:112 name = Display Name）。get_display_name 在 builder（共用）。
static func _fill_card_name(label: Label, hero: HeroInstance, cm: Variant) -> void:
	label.text = HeroDetailBuilder.get_display_name(hero, cm)


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


# Art 立绘 TextureRect（源 readhero.lua:1131-1134 createClippingNode(cardres, art_mask) + setScale(420/ArtH)）。
# 用户需求（2026-07-20）：立绘"按比例铺满框中"= cover CardFrame 315×545（Art ratio 0.5776 ≈ frame ratio 0.5780，
# 显示 ≈315×545 完全覆盖 frame，frame 边框装饰 + name 条从 Art 之上盖下来）。
# 用户反馈"Art 4 个边角凸出 frame 圆角外"，根因：源 art_mask.png 圆角半径 3px < CardFrame 圆角 8px，且 Art size = frame size
# 致 Art 方角从 frame 圆角透明区露出。修法：Art size 内缩 CARD_FRAME_INSET（8px）让 Art 方角落在 frame 圆角装饰内圈，
# 不超出 frame 边界（牺牲少量边缘 Art 内容换边角整齐）。
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
	# Art size = CardFrame size - 内缩 ×2（上下/左右各内缩 CARD_FRAME_INSET）。
	# Art ratio ≈ frame ratio，内缩后仍铺满 frame 内圈（圆角装饰内），4 角不超出 frame 圆角。
	# Art center 保持 = CardFrame center (280, 320)，Art 上下/左右对称内缩。
	var tex_w: float = float(tex.get_width())
	var tex_h: float = float(tex.get_height())
	var target_w: float = CARD_FRAME_SIZE.x - CARD_FRAME_INSET * 2.0
	var target_h: float = CARD_FRAME_SIZE.y - CARD_FRAME_INSET * 2.0
	var cover_scale: float = max(target_w / tex_w, target_h / tex_h)
	var disp_w: float = tex_w * cover_scale
	var disp_h: float = tex_h * cover_scale
	sp.size = Vector2(disp_w, disp_h)
	sp.stretch_mode = TextureRect.STRETCH_SCALE
	sp.modulate = ART_MODULATE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/art_mask.gdshader")
	mat.set_shader_parameter("mask_tex", load(ART_MASK_RES) as Texture2D)
	sp.material = mat
	sp.position = ART_CENTER - sp.size * 0.5   # Art center 居中到镂空 center
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
	icon.position = CONTAINER_ORIGIN + Vector2(32.0 * COORD_SX, -67.0 * COORD_SY) - icon.size * 0.5
	icon.z_index = 3   # 在 Art(z=2) 之上
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(icon)
	icon.set_meta(&"tab_content", true)


static func _fill_card_skill_icons(view: Control, hero: HeroInstance, cm: Variant) -> void:
	if cm == null or hero == null:
		return
	var sg: Dictionary = cm.get_raw_table(&"SkillGroup").get(str(hero.tid), {})
	for i in range(4):
		var slot_info: Dictionary = sg.get(str(i + 1), {})
		var icon_res: String = String(slot_info.get("Icon", ""))
		if icon_res.is_empty():
			continue
		var tex: Texture2D = _load_ui_texture(icon_res)
		if tex == null:
			continue
		var icon := TextureRect.new()
		icon.texture = tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size = Vector2(22.0, 22.0)
		icon.position = CONTAINER_ORIGIN + Vector2((130.5 + 27.2 * float(i)) * COORD_SX, -28.0 * COORD_SY) - icon.size * 0.5
		icon.z_index = 3   # 在 Art(z=2) 之上
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
		star.position = CONTAINER_ORIGIN + Vector2((25.0 + 14.0 * float(i)) * COORD_SX, -27.0 * COORD_SY) - star.size * 0.5
		star.z_index = 3   # 在 CardFrame(z=1) / CardNameLabel(z=2) 上
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
	bg.patch_margin_left = 20
	bg.patch_margin_top = 52
	bg.patch_margin_right = 200
	bg.patch_margin_bottom = 5
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
