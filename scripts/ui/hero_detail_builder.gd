class_name HeroDetailBuilder
extends RefCounted

## HeroDetailPanel 视觉工厂（Phase A+B 重构 2026-07-17 + builder P2 拆分 2026-07-20）。
## base 层 fill（portrait/name board/stars/info/action/stone bar）+ tab 按钮 Scale9 样式。
## base 层 + tab view 位置+size 静态化进 hero_detail_content.tscn（编辑器可视化调）。
## card 基础（frame/art/name）+ skill 行绘制 + desc board 已外迁 HeroDetailTabs（P2 拆分）。

const OFFSET_X: float = 80.0
const BASE_Y: float = 560.0

# ---- name_frame 名条品质边框（源 player.lua:2121 name_frames 表 + getIconNameFrameByRank:2149）----
# rank 1-22 → 帧编号（含重复条目保源语义：rank 10/11 同图、12-19 同图、20-22 同图）。
const NAME_FRAME_DIR: String = "res://assets/ui/alpha/HVGA/herodetail_name_frame_"
const NAME_FRAME_BY_RANK: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 11, 11, 11, 11, 11, 11, 11, 11, 12, 12, 12]

# ---- portrait FCA（源 createHeroFca window.lua:11-18）----
const HERO_FCA_COCOS: Vector2 = Vector2(400.0, 265.0)
const HERO_FCA_SCALE: float = 1.5
const PORTRAIT_COCOS: Vector2 = Vector2(125.0, 320.0)   # 降级静态立绘中心
const PORTRAIT_MAX_SIZE: Vector2 = Vector2(200.0, 280.0)
const PORTRAIT_PREFIX: String = "UI/"
const PORTRAIT_REPLACE: String = "res://assets/ui/"
const STAR_COUNT: int = 5


static func to_godot(cx: float, cy: float) -> Vector2:
	return Vector2(cx + OFFSET_X, BASE_Y - cy)


# ==================== base 层 fill（Phase A：.tscn 已建节点，填动态数据 + 样式）====================

# 统一准备 base 层动态数据 + 按钮样式。base = .tscn instantiate 后的 %BaseLayer。
# 返 {gs_label, tab_buttons}（panel 持有：gs_label 供 refresh_gs_after_wear，tab_buttons 供 tab 切换）。
static func setup_base(base: Control, hero: HeroInstance, cm: Variant) -> Dictionary:
	fill_portrait(base.get_node("%PortraitHost"), hero, cm)
	fill_name_board(base.get_node("%TypeIcon"), base.get_node("%NameLabel"), base.get_node_or_null("%NameFrame"), hero, cm)
	fill_stars(_collect_yellow_stars(base), hero.stars)
	var gs_label: Label = fill_info_board(base, hero, cm)
	fill_action_labels(base, hero, cm)
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


# fill %TypeIcon texture（源 hero_mark_res STR/AGI/INT，item.lua:1-5）+ %NameLabel text（Display Name）
# + %NameFrame texture（源 getIconNameFrameByRank，rank 1-22 → 12 张品质边框）。
static func fill_name_board(type_icon: TextureRect, name_label: Label, name_frame: TextureRect, hero: HeroInstance, cm: Variant) -> void:
	var attrib: String = String(cm.lookup("Unit", "Main Attrib", int(hero.tid))) if cm != null else ""
	var type_res: String = _type_icon_res(attrib)
	if not type_res.is_empty() and ResourceLoader.exists(type_res):
		type_icon.texture = load(type_res) as Texture2D
	name_label.text = get_display_name(hero, cm)
	if name_frame != null:
		var frame_no: int = _name_frame_no(int(hero.rank))
		var frame_res: String = NAME_FRAME_DIR + str(frame_no) + ".png"
		if ResourceLoader.exists(frame_res):
			name_frame.texture = load(frame_res) as Texture2D


# rank → name_frame 帧编号（源 player.lua:2149 getIconNameFrameByRank = name_frames[rank]）。
# rank 超出 1-22 范围 clamp 到边界（防御）。
static func _name_frame_no(rank: int) -> int:
	if rank < 1:
		rank = 1
	elif rank > NAME_FRAME_BY_RANK.size():
		rank = NAME_FRAME_BY_RANK.size()
	return NAME_FRAME_BY_RANK[rank - 1]


static func _type_icon_res(attrib: String) -> String:
	match attrib:
		"HERO_EQUIP.STRENGTH":
			return "res://assets/ui/alpha/HVGA/icon_str.png"
		"HERO_EQUIP.AGILITY":
			return "res://assets/ui/alpha/HVGA/icon_agi.png"
		"HERO_EQUIP.INTELLIGENCE":
			return "res://assets/ui/alpha/HVGA/icon_int.png"
	return ""


# Unit Display Name（源 card/name 共用，LSTR key → 本地化名）。tabs._fill_card_name 也调本方法。
static func get_display_name(hero: HeroInstance, cm: Variant) -> String:
	if cm == null:
		return ""
	var name_key: String = String(cm.lookup("Unit", "Display Name", int(hero.tid)))
	return String(cm.get_lstr(name_key))


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


# fill 1 action button（%UpgradeRankBtn）LSTR text。
# ⚠️偏离源：evolve 文字按钮已删（用户简化决策 2026-07-18），升星由 %GetStoneBtn +号按钮触发。
# UpgradeRankBtn 用独立 Label 子节点 %UpgradeRankLabel 居中（Button.text 内嵌 label 受 stylebox
# content_margin 干扰致字体偏左上，改独立 Label anchors_preset=15 full_rect + horizontal/vertical_alignment=1
# 稳定居中，范式同 tab 按钮 fill_tab_labels）。按钮样式走 theme variation（HeroDetailTab，tscn 已接线）。
static func fill_action_labels(base: Control, hero: HeroInstance, cm: Variant) -> void:
	var labels: Dictionary = {
		"UpgradeRankBtn": String(cm.get_lstr(&"HERODETAIL.ADVANCE_")) if cm != null else "进阶",
	}
	for btn_name in labels:
		var btn: Button = base.get_node("%" + btn_name)
		# 满级时隐藏进阶按钮（源 doClickUpgrade :701-705 满级 Toast + 不可进；
		# 本项目隐藏按钮更直观，参照 fill_stone_bar is_max_star 范式）
		if btn_name == "UpgradeRankBtn" and hero != null and hero.rank >= HeroManager.MAX_EQUIP_RANK:
			btn.visible = false
			continue
		# fill 独立 Label 子节点（.tscn 已建 %XxxLabel），不 fill Button.text
		var label_key: String = btn_name.replace("Btn", "Label")
		var lbl: Label = btn.get_node_or_null("%" + label_key)
		if lbl != null:
			lbl.text = labels[btn_name]


# sa/sn 来自 ReadheroHandbook.get_stone_amount/get_stone_need；is_max_star 时 label 变「已进化到顶级」+ 隐藏 stone_bar/get_stone/evolve 按钮。
const STONE_BAR_W: float = 180.0
const STONE_BAR_OFFSET_X: float = 279.5   # StoneBar offset_left（bg 偏移 221.5 + 源局部 58）
const LSTR_MAX_STAR: StringName = &"HERODETAIL.HAVE_EVOLVED_TO_TOP"
static func fill_stone_bar(base: Control, hero: HeroInstance, cm: Variant, hero_mgr: HeroManager) -> void:
	var stone_icon: TextureRect = base.get_node("%StoneIcon") as TextureRect
	var bar_bg: TextureRect = base.get_node("%StoneBarBg") as TextureRect
	var bar: TextureRect = base.get_node("%StoneBar") as TextureRect
	var lbl: Label = base.get_node("%StoneBarLabel") as Label
	var get_stone: TextureButton = base.get_node("%GetStoneBtn") as TextureButton
	var sa: int = ReadheroHandbook.get_stone_amount(int(hero.tid), cm, hero_mgr)
	var sn: int = ReadheroHandbook.get_stone_need(int(hero.tid), cm, hero_mgr)
	var max_stars: int = int(cm.get_int(&"Unit", int(hero.tid), &"Max Stars")) if cm != null else 5
	var is_max_star: bool = hero.stars >= max_stars
	var text: String = (String(cm.get_lstr(LSTR_MAX_STAR)) if cm != null else "已进化到顶级") if is_max_star else ("%d/%d" % [sa, sn])
	lbl.text = text
	stone_icon.visible = not is_max_star
	bar_bg.visible = not is_max_star
	bar.visible = not is_max_star
	get_stone.visible = not is_max_star
	if is_max_star:
		lbl.visible = true   # 满星仍显示 label
		return
	var ratio: float = clampf(float(sa) / float(sn if sn > 0 else 1), 0.0, 1.0)
	bar.offset_right = STONE_BAR_OFFSET_X + STONE_BAR_W * ratio


# 收集 3 tab 按钮（%TabDetailBtn/%TabCardBtn/%TabSkillBtn）→ {key: Button}。
static func collect_tab_buttons(base: Control) -> Dictionary:
	return {
		"detail": base.get_node("%TabDetailBtn"),
		"card": base.get_node("%TabCardBtn"),
		"skill": base.get_node("%TabSkillBtn"),
	}


# fill 3 tab LSTR text（源 :1468/:1545/:1622 HERODETAIL.DETAILED_PROPERTIES / ILLUSTRATIONS / TODOLIST.SKILLS_UPGRADING）。
# 按钮样式走 theme variation（HeroDetailTab/HeroDetailTabActive，tscn 接线 + panel 切选中态）。
# 文字 fill 到独立 Label 子节点 %TabXxxLabel（Button.text 内嵌 label 受 stylebox content_margin 干扰致字体偏左上，
# 改独立 Label anchors_preset=15 full_rect + horizontal/vertical_alignment=1 稳定居中，范式同 hero_package tab）。
static func fill_tab_labels(tab_buttons: Dictionary, cm: Variant) -> void:
	var labels: Dictionary = {
		"detail": String(cm.get_lstr(&"HERODETAIL.DETAILED_PROPERTIES")) if cm != null else "详细属性",
		"card": String(cm.get_lstr(&"HERODETAIL.ILLUSTRATIONS")) if cm != null else "图鉴",
		"skill": String(cm.get_lstr(&"TODOLIST.SKILLS_UPGRADING")) if cm != null else "技能升级",
	}
	for key in tab_buttons:
		var btn: Button = tab_buttons[key] as Button
		# fill 独立 Label 子节点（.tscn 已建 %TabXxxLabel，命名规则 Tab{Key}Label）
		var label_name: String = "Tab" + key.capitalize() + "Label"
		var lbl: Label = btn.get_node_or_null("%" + label_name)
		if lbl != null:
			lbl.text = labels[key]
