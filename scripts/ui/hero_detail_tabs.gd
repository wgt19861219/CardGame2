class_name HeroDetailTabs
extends RefCounted

## HeroDetailPanel「图鉴 card」+「技能 skill」tab 内容工厂（task#9 拆分 2026-07-20）。
## 从 hero_detail_panel.gd 外迁的纯绘制函数：card 视图 fill（类型图标/技能图标/星数）+
## skill 行绘制（图标 TextureButton+边框 / 升级按钮）+ 技能描述弹板建。
## 照源 readhero.lua:1069-1158 card / skillstren.lua:424-451 skill / skillstren.lua:14 desc。
## 不含 panel 状态（_desc_label/_skill_host 等），全 static + 参数化，panel 传 host + on_click Callable。
## 单向依赖：本类 → HeroDetailAttribs.get_lstr_fallback（避免 class_name 循环引用）。

# 源 readhero.lua:992 card_type_icon（big 版）：type → 类型图标资源。
const CARD_TYPE_ICON_RES: Dictionary = {
	"STR": "res://assets/ui/alpha/HVGA/card/card_att_str_big.png",
	"AGI": "res://assets/ui/alpha/HVGA/card/card_att_agi_big.png",
	"INT": "res://assets/ui/alpha/HVGA/card/card_att_int_big.png",
}
const CARD_STAR_RES: String = "res://assets/ui/alpha/HVGA/card/card_star_big.png"
const CARD_STAR_SIZE: Vector2 = Vector2(23.0, 24.0)   # 源 46×48 scale 0.5（readhero.lua:1153-1156）
# 源 skillstren.lua 技能图标边框 + 灰显 + 可点击区。
const EQUIP_FRAME_WHITE_PATH: String = "res://assets/ui/alpha/HVGA/equip_frame_white.png"
const SKILL_GRAY_MODULATE: Color = Color(0.4, 0.4, 0.4, 1.0)   # 源 setSpriteGray 灰显近似
const SKILL_ICON_BTN_SIZE: Vector2 = Vector2(40.0, 40.0)   # 技能图标可点击区
const SKILL_BTN_SIZE: Vector2 = Vector2(80.0, 28.0)
const SKILL_DESC_POS: Vector2 = Vector2(400.0, 100.0)      # 描述弹板位置
const SKILL_GROWTH_COLOR: Color = Color(1.0, 0.81, 0.07)   # 源 ccc3(231,206,19) 成长值黄
const SKILL_TIP_RES: String = "res://assets/ui/alpha/HVGA/herodetail-skill-tip.png"
# 源 UI 路径前缀映射（仿 readhero_icon.gd:81 Portrait）。
const UI_PATH_PREFIX: String = "UI/"
const UI_PATH_REPLACE: String = "res://assets/ui/"


# ==================== card 图鉴视图 fill ====================

# fill card view 入口：%CardFrame/%CardArtHost/%CardNameLabel 由 builder.setup_card_view 填，
# 本函数补类型图标 + 技能图标 + 星数（源 getHeroCard readhero.lua:1069-1158）+ 标记 Art 子。
static func fill_card_view(view: Control, hero: HeroInstance, cm: Variant) -> void:
	if cm == null:
		return
	_fill_card_type_icon(view, hero, cm)
	_fill_card_skill_icons(view, hero, cm)
	_fill_card_stars(view, hero)
	var art_host: Control = view.get_node("%CardArtHost") as Control
	for c in art_host.get_children():
		c.set_meta(&"tab_content", true)   # Art 标记（测试识别 card 内容渲染）


# 源 getHeroCard type icon（readhero.lua:1069-1082）：card_att_X_big at ccp(32,67) fix_size 47×42。
# 相对 Art ccp(123,215)：dx=32-123=-91, dy=67-215=-148（cocos）→ godot dx=-91, dy=+148。
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
	var art_center: Vector2 = HeroDetailBuilder.to_godot(HeroDetailBuilder.CARD_CENTER_COCOS.x, HeroDetailBuilder.CARD_CENTER_COCOS.y + 50.0)
	icon.position = art_center + Vector2(-91.0, 148.0) - icon.size * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(icon)
	icon.set_meta(&"tab_content", true)


# 源 getHeroCard skillIcon（readhero.lua:1122-1130）：4 个 SkillGroup.Icon at ccp(130.5+27.2*(i-1),28) scale 22。
static func _fill_card_skill_icons(view: Control, hero: HeroInstance, cm: Variant) -> void:
	if cm == null or hero == null:
		return
	var sg: Dictionary = cm.get_raw_table(&"SkillGroup").get(str(hero.tid), {})
	var art_center: Vector2 = HeroDetailBuilder.to_godot(HeroDetailBuilder.CARD_CENTER_COCOS.x, HeroDetailBuilder.CARD_CENTER_COCOS.y + 50.0)
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
		# 源相对 Art：dx=130.5+27.2*i-123=7.5+27.2*i, dy=28-215=-187 → godot dx, dy=+187
		icon.position = art_center + Vector2(7.5 + 27.2 * float(i), 187.0) - icon.size * 0.5
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.add_child(icon)
		icon.set_meta(&"tab_content", true)


# 源 getHeroCard stars（readhero.lua:1149-1158）：card_star_big at ccp(25+14*(i-1),27) scale 0.5 z=6-i。
# 相对 Art ccp(123,215)：dx=-98+14*i，dy=+188（cocos y 翻转 godot）。
static func _fill_card_stars(view: Control, hero: HeroInstance) -> void:
	if hero == null:
		return
	var tex: Texture2D = _load_texture(CARD_STAR_RES)
	if tex == null:
		return
	var art_center: Vector2 = HeroDetailBuilder.to_godot(HeroDetailBuilder.CARD_CENTER_COCOS.x, HeroDetailBuilder.CARD_CENTER_COCOS.y + 50.0)
	for i in range(hero.stars):
		var star := TextureRect.new()
		star.texture = tex
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.size = CARD_STAR_SIZE
		star.position = art_center + Vector2(-98.0 + 14.0 * float(i), 188.0) - star.size * 0.5
		star.z_index = 3   # 在 CardFrame(z=1) / CardNameLabel(z=2) 上
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.add_child(star)
		star.set_meta(&"tab_content", true)


# ==================== skill 行绘制（图标 + 升级按钮）====================

# 源 readhero.lua:1011 createSkillIcon + skillstren.lua:758 board_i pressHandler。
# 边框 Sprite2D（equip_frame_white centered 居中）+ 图标 TextureButton（可点击 → 描述弹板）。
# locked=true 灰显（源 skillstren.lua:434 setSpriteGray，modulate 降亮近似）。
# icon_pos = 中心 godot 坐标（panel _fill_skills 用 SKILL_ICON_COCOS_X + TAB_POP_OFFSET_X 算好传入）。
# on_click = 图标点击回调（panel 传 Callable(self,"_toggle_skill_desc").bind(slot)）。
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


# 源 skillstren.lua:345 createSkillLevelBoard 升级按钮（herodetail_skill_upgrade_button_1.png 无文字）。
# pos = 按钮 godot 左上（panel 算好传入，中心 = pos + size/2 传 builder.create_skill_upgrade_button）。
# on_click = 升级回调（panel 传 Callable(self,"_on_skill_upgrade_clicked").bind(idx)）。
static func create_skill_upgrade_button(skill_host: Control, pos: Vector2, on_click: Callable) -> void:
	var btn: TextureButton = HeroDetailBuilder.create_skill_upgrade_button(skill_host, pos + SKILL_BTN_SIZE * 0.5)
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
	bg.patch_margin_bottom = 5   # 源 capInsets(20,52,200,5)
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

# 源 UI 路径 "UI/ITEM/s10.jpg" → res://assets/ui/ITEM/s10.jpg。
static func _load_ui_texture(ui_path: String) -> Texture2D:
	if ui_path.is_empty():
		return null
	var path: String = ui_path.replace(UI_PATH_PREFIX, UI_PATH_REPLACE) if ui_path.begins_with(UI_PATH_PREFIX) else ui_path
	return _load_texture(path)


static func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
