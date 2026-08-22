class_name ReadequipIcon
extends RefCounted

## 装备/英雄图标 View 工具（照源 readequip.lua createIcon :671 + createIconWithAmount :792）。
## 品质边框（equip_frame_<quality>）+ Equip.Icon / Unit.Portrait + 数量 Label。
## poptavernloot / herodetail / 背包共用。headless 安全（ResourceLoader.exists 预检）。

const FRAME_DIR: String = "res://assets/ui/alpha/HVGA/equip_frame_"
const FRAGMENT_FRAME_DIR: String = "res://assets/ui/alpha/HVGA/fragment_frame_"
const EQUIP_ICON_DIR: String = "res://assets/ui/ITEM/"
const HERO_PORTRAIT_DIR: String = "res://assets/ui/HERO/"
const DEFAULT_ICON: String = "res://assets/ui/alpha/HVGA/gocha.png"
const FRAGMENT_BG_PATH: String = "res://assets/ui/alpha/HVGA/fragment_bg.png"
const SOULSTONE_TAG_PATH: String = "res://assets/ui/alpha/HVGA/equip_soulstone_tag.png"
const TICK_PATH: String = "res://assets/ui/alpha/HVGA/fragment_tick.png"
# 源 readequip.lua:3-10 frame_res 六档：quality5 无专属图复用 purple、6=orange。
# 旧表只写 5 档致 quality5 误映 orange（2026-08-22 用户反馈边框颜色错档）。
const FRAME_COLORS: Array[String] = ["white", "green", "blue", "purple", "purple", "orange"]
const HERO_DEFAULT_QUALITY: int = 1
const ICON_SIZE: float = 72.0
# 子元素定位照源逻辑坐标系（y 向上，frame 逻辑尺寸 94/CS×95/CS≈73.4×74.1，2026-08-22 重写）：
# 装备内图中心 (36,39)（readequip.lua:721/:727）；hero 头像同位 + s2=(frame逻辑宽-9)/头宽缩放（:733-738）；
# 魂石头像中心 (36,38.5)（:593）+ s2 同（:600）；魂石 tag 中心 (15,60)（:597）；
# 数量标签右缘 (68,18)（:806 anchor(1,0.5)）；tick 角标左下 (4,4)（:871 anchor(0,0)）。
# 旧常量 (9,9)/(36,38)/(15,60)/(40,50)/(4,4) 直抄未翻 y 未适配逻辑系，2026-08-22 魂石观感回归后作废。
const EQUIP_CENTER_UP: Vector2 = Vector2(36.0, 39.0)
const STONE_CENTER_UP: Vector2 = Vector2(36.0, 38.5)
const STONE_TAG_CENTER_UP: Vector2 = Vector2(15.0, 60.0)
const AMOUNT_RIGHT_X: float = 68.0
const AMOUNT_CENTER_Y_UP: float = 18.0
const TICK_POS_UP: Vector2 = Vector2(4.0, 4.0)
const FRAME_INSET: float = 9.0   # 源 s2=(frame逻辑宽-9)/内容宽 → 内容显示 64.4
const GOCHA_BG_PATH: String = "res://assets/ui/alpha/HVGA/gocha.png"
const FRAGMENT_TAG_PATH: String = "res://assets/ui/alpha/HVGA/fragment_tag.png"
# 圆形裁剪（源 createClippingNode：CCClippingNode + stencil 拉伸至内容尺寸 → shader 等价，
# portrait_mask.gdshader 同款，readhero_icon 已用）。魂石/碎片默认 alphaThreshold=0.5
# （源 createClippingNodeOnly 默认），hero 头像 equip_stencil 0.02（源 :727）。
const PortraitMaskShader: Shader = preload("res://shaders/portrait_mask.gdshader")
const FRAGMENT_STENCIL_PATH: String = "res://assets/ui/alpha/HVGA/fragment_stencil.png"
const EQUIP_STENCIL_PATH: String = "res://assets/ui/alpha/HVGA/equip_stencil.png"
# 装备强化星级（源 createIconWithLevel:1202-1231）：垂直单列 blue(level 颗)/grey(show_gray 到 ml)。
# star_bg（equipupgrade_equip_bg.png）本项目缺 → 降级不画底图。
const STAR_BLUE_RES: String = "res://assets/ui/alpha/HVGA/equipupgrade/equipupgrade_star_blue.png"
const STAR_GREY_RES: String = "res://assets/ui/alpha/HVGA/equipupgrade/equipupgrade_star_grey.png"
const STAR_OX: float = 58.0
const STAR_OY_COCOS: float = 18.0
const STAR_DY: float = 10.0
const STAR_SCALE: float = 0.9
const HALF: float = 0.5              # 星中心定位偏移
const CONTENT_SCALE: float = 1.28125


# sprite 显示尺寸（_load_sprite 已 scale=1/CS → 显示=纹理/CS 逻辑点）。
static func _vis_size(s: Sprite2D) -> Vector2:
	if s.texture == null:
		return Vector2.ZERO
	return s.texture.get_size() * s.scale.x


# 源中心点定位（cocos y 向上、anchor 0.5）→ Godot 左上：pos = (cx, frame逻辑高-cy) - 半显示尺寸。
static func _place_center(s: Sprite2D, center_up: Vector2, frame_h: float) -> void:
	s.position = Vector2(center_up.x, frame_h - center_up.y) - _vis_size(s) * 0.5


# 头像/魂石内容缩放到 frame 逻辑宽-9（源 s2 语义）：sprite.scale 总值 = 目标宽/纹理px
# （= 源 (1/CS)×s2 的代数化简，显示=目标宽）。
static func _fit_inset(s: Sprite2D, frame_w: float) -> void:
	if s.texture == null or s.texture.get_size().x <= 0.0:
		return
	var target: float = frame_w - FRAME_INSET
	s.scale = Vector2(target / s.texture.get_size().x, target / s.texture.get_size().x)


# 圆形裁剪（源 CCClippingNode + stencil 拉伸至内容尺寸 → UV 对齐直接同 UV 采样）。
static func _apply_stencil(s: Sprite2D, stencil_path: String, threshold: float) -> void:
	if s.texture == null or not ResourceLoader.exists(stencil_path):
		return
	var mat := ShaderMaterial.new()
	mat.shader = PortraitMaskShader
	mat.set_shader_parameter("mask_tex", load(stencil_path))
	mat.set_shader_parameter("alpha_threshold", threshold)
	s.material = mat


# 创建图标节点（品质边框 + 内 Icon + 数量 Label + 可选星级）。id 为 equip id 或 hero tid。
static func create_icon(id: int, amount: int, cm: Variant, level: int = 0, show_gray: bool = false) -> Control:
	# 源 :705-712 按 Equip.Category 分流：碎片/魂石走专用图标（帧/衬底/tag/内缩各不同）。
	# 2026-08-22 照源补分流——此前商店魂石/碎片商品误走装备分支致观感错。
	# 源 createIconWithLevel:1206 星级在分流后统一加于 bg（魂石带星），两分支补 _add_stars。
	if not _is_hero(id, cm):
		var category: String = String(cm.get_raw_table("Equip").get(str(id), {}).get("Category", ""))
		var diverted: Control = null
		if category == "EQUIP.SOUL_STONE":
			diverted = create_hero_stone_icon(id, amount, cm)
		elif category == "EQUIP.FRAGMENT":
			diverted = create_fragment_icon(id, amount, cm)
		if diverted != null:
			if level > 0 or show_gray:
				_add_stars(diverted, id, level, show_gray, cm)
				diverted.set_meta(&"quality", _get_quality(id, false, cm))
				diverted.set_meta(&"is_hero", false)
			return diverted
	var container := Control.new()
	container.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	container.size = Vector2(ICON_SIZE, ICON_SIZE)
	var is_hero: bool = _is_hero(id, cm)
	var quality: int = _get_quality(id, is_hero, cm)
	var frame := _load_sprite(FRAME_DIR + _frame_color(quality) + ".png", DEFAULT_ICON)
	container.add_child(frame)
	# 源 :719-722 equip 分支有 gocha 衬底 z=-2（frame 之下、内容之上）——此前漏画。
	var gocha := _load_sprite(GOCHA_BG_PATH, DEFAULT_ICON)
	container.add_child(gocha)
	var frame_h: float = _vis_size(frame).y
	var frame_w: float = _vis_size(frame).x
	var icon_path := _get_icon_path(id, is_hero, cm)
	if icon_path != "":
		var icon := _load_sprite(icon_path, DEFAULT_ICON)
		# hero 头像缩放到 frame宽-9（源 :733-738 itemType=="hero" s2）+ 圆形裁剪
		# （源 :727 createClippingNode(equip_stencil, 0.02)）；装备内图无缩放无裁剪（源同）。
		if is_hero:
			_fit_inset(icon, frame_w)
			_apply_stencil(icon, EQUIP_STENCIL_PATH, 0.02)
		_place_center(icon, EQUIP_CENTER_UP, frame_h)
		container.add_child(icon)
	if amount > 1:
		var lbl := Label.new()
		lbl.text = "x" + str(amount)
		# 源 :803-807 anchor(1,0.5) (68,18)：右缘距左 68、中心距底 18（Label 数字图降级，口径对齐）。
		lbl.size = Vector2(56.0, 16.0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.position = Vector2(AMOUNT_RIGHT_X - 56.0, frame_h - AMOUNT_CENTER_Y_UP - 8.0)
		container.add_child(lbl)
	if level > 0 or show_gray:
		_add_stars(container, id, level, show_gray, cm)
	# 存 quality/is_hero 供 pop_tavern_loot playBurst 品质光效判断（源 createLootAnim :494/564-625）。
	container.set_meta(&"quality", quality)
	container.set_meta(&"is_hero", is_hero)
	return container


# stars 存 container meta（供 playEnhanceAnim 操作 setVisible，源 stars[i].icon 等价）。
static func _add_stars(container: Control, id: int, level: int, show_gray: bool, cm: Variant) -> void:
	var ml: int = int(ReadequipData.get_equip_level_exp(id, cm).get("ml", 0))
	if ml < 1:
		return
	var stars: Array = []
	for i in range(1, level + 1):
		var s: TextureRect = _make_star(STAR_BLUE_RES, i)
		container.add_child(s)
		stars.append({"type": "y", "icon": s})
	if show_gray:
		for i in range(level + 1, ml + 1):
			var s: TextureRect = _make_star(STAR_GREY_RES, i)
			container.add_child(s)
			stars.append({"type": "n", "icon": s})
	container.set_meta("stars", stars)


static func _make_star(res_path: String, i: int) -> TextureRect:
	var t: TextureRect = TextureRect.new()
	var tex: Texture2D = load(res_path)
	if tex != null:
		t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var base_size: Vector2 = TexDisplaySize.display_size(res_path) if tex != null else Vector2.ZERO
	t.size = base_size
	t.scale = Vector2(STAR_SCALE, STAR_SCALE)
	var actual_size: Vector2 = base_size * STAR_SCALE
	var cocos_y: float = STAR_OY_COCOS + STAR_DY * (i - 1)
	t.position = Vector2(STAR_OX, ICON_SIZE - cocos_y) - actual_size * HALF
	return t


## 取 create_icon 建 icon 时存入的 stars 数组（供 playEnhanceAnim 操作；无返空）。
static func get_stars(container: Control) -> Array:
	var v: Variant = container.get_meta("stars", [])
	return v if v is Array else []


## （同 position/scale，照源 parent:addChild 不删灰）+ stars[i].icon 指向蓝，type=y。
## 强化后点亮前重建（playEnhanceAnim 前调，initHeroEquip:1508）。0-based：stars[0..new_level-1]。
## 蓝星 visible=false（合并源 refresh 默认显 + playEnhanceAnim:1561 立即隐，同帧等价）→ playStarAnim 逐颗点亮。
static func refresh_stars(container: Control, new_level: int) -> void:
	var stars: Array = get_stars(container)
	for i in range(0, new_level):
		if i >= stars.size():
			break
		var entry: Dictionary = stars[i]
		if String(entry.get("type", "")) == "n":
			var old_star: TextureRect = entry.get("icon", null)
			if old_star == null or not is_instance_valid(old_star):
				continue
			var pos: Vector2 = old_star.position
			var blue := TextureRect.new()
			var tex: Texture2D = load(STAR_BLUE_RES)
			if tex != null:
				blue.texture = tex
			blue.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			# 同 _make_star：源 :1249-1252 setScale(0.9)，size=纹理×CS/CS 与灰星一致（覆盖等位）
			blue.size = TexDisplaySize.display_size(STAR_BLUE_RES) if tex != null else Vector2.ZERO
			blue.scale = old_star.scale
			blue.position = pos
			blue.visible = false
			blue.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(blue)
			stars[i] = {"type": "y", "icon": blue}
	container.set_meta("stars", stars)


# 创建魂石图标（照源 createHeroStone :571-602）：fragment_frame 边框 + fragment_bg + Icon + equip_soulstone_tag。
# id = 碎片物品 id（Fragment 表的 Fragment ID）。源用 createClippingNode 圆形 mask（fragment_stencil），
# 本项目简化直接 Sprite2D（headless 安全，与 create_icon 一致不 mask）。Phase 4 视觉校准补 mask。
static func create_hero_stone_icon(id: int, amount: int, cm: Variant) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	container.size = Vector2(ICON_SIZE, ICON_SIZE)
	var quality: int = _get_quality(id, false, cm)
	var frame := _load_sprite(FRAGMENT_FRAME_DIR + _frame_color(quality) + ".png", DEFAULT_ICON)
	container.add_child(frame)
	var frame_h: float = _vis_size(frame).y
	var frame_w: float = _vis_size(frame).x
	# 源 :578-581 equipBg=fragment_bg anchor(0,0)(0,0) frame 左下→Godot 左上（centered=false 默认）。
	var bg := _load_sprite(FRAGMENT_BG_PATH, DEFAULT_ICON)
	container.add_child(bg)
	var icon_path := _get_icon_path(id, false, cm)
	if icon_path != "":
		var icon := _load_sprite(icon_path, DEFAULT_ICON)
		_fit_inset(icon, frame_w)   # 源 :600 s2=(frame逻辑宽-9)/stone宽
		_place_center(icon, STONE_CENTER_UP, frame_h)
		_apply_stencil(icon, FRAGMENT_STENCIL_PATH, 0.5)   # 源 :592 createClippingNode(fragment_stencil) 默认 0.5
		container.add_child(icon)
	var tag := _load_sprite(SOULSTONE_TAG_PATH, DEFAULT_ICON)
	_place_center(tag, STONE_TAG_CENTER_UP, frame_h)
	container.add_child(tag)
	if amount > 1:
		var lbl := Label.new()
		lbl.text = "x" + str(amount)
		lbl.size = Vector2(56.0, 16.0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.position = Vector2(AMOUNT_RIGHT_X - 56.0, frame_h - AMOUNT_CENTER_Y_UP - 8.0)
		container.add_child(lbl)
	return container


# 创建碎片图标（照源 createFragment :538-568）：与魂石同构但内缩 -12、tag 用 fragment_tag、
# 内容中心 (36,38)。源用 fragment_stencil 圆形 clip，本项目同魂石简化不 mask（Phase 4 校准补）。
static func create_fragment_icon(id: int, amount: int, cm: Variant) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	container.size = Vector2(ICON_SIZE, ICON_SIZE)
	var quality: int = _get_quality(id, false, cm)
	var frame := _load_sprite(FRAGMENT_FRAME_DIR + _frame_color(quality) + ".png", DEFAULT_ICON)
	container.add_child(frame)
	var frame_h: float = _vis_size(frame).y
	var frame_w: float = _vis_size(frame).x
	var bg := _load_sprite(FRAGMENT_BG_PATH, DEFAULT_ICON)
	container.add_child(bg)
	var icon_path := _get_icon_path(id, false, cm)
	if icon_path != "":
		var icon := _load_sprite(icon_path, DEFAULT_ICON)
		# 源 :562 s2=(frame逻辑宽-12)/icon宽 → 显示 61.4（碎片比魂石 -9 略小）
		if icon.texture != null and icon.texture.get_size().x > 0.0:
			var target: float = frame_w - 12.0
			icon.scale = Vector2(target / icon.texture.get_size().x, target / icon.texture.get_size().x)
		_place_center(icon, Vector2(36.0, 38.0), frame_h)
		_apply_stencil(icon, FRAGMENT_STENCIL_PATH, 0.5)   # 源 :552 createClippingNode(fragment_stencil)
		container.add_child(icon)
	var tag := _load_sprite(FRAGMENT_TAG_PATH, DEFAULT_ICON)
	_place_center(tag, STONE_TAG_CENTER_UP, frame_h)
	container.add_child(tag)
	if amount > 1:
		var lbl := Label.new()
		lbl.text = "x" + str(amount)
		lbl.size = Vector2(56.0, 16.0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.position = Vector2(AMOUNT_RIGHT_X - 56.0, frame_h - AMOUNT_CENTER_Y_UP - 8.0)
		container.add_child(lbl)
	return container


# 创建带可合成角标的碎片图标（照源 createIconWithTag :841-876）。
# tid = 英雄/装备 tid（Fragment 表 key），内部反查 Fragment[tid] 得碎片物品 id 显示魂石图标。
# 可合成（pd.hero_manager.is_fragment_composable）时加 fragment_tick 角标。
static func create_icon_with_tag(tid: int, amount: int, cm: Variant, pd: PlayerData) -> Control:
	var frag_info: Dictionary = cm.get_raw_table(&"Fragment").get(str(tid), {})
	var frag_id: int = int(frag_info.get(&"Fragment ID", tid))
	var container: Control = create_hero_stone_icon(frag_id, amount, cm)
	if pd.hero_manager.is_fragment_composable(tid):
		_add_tick_tag(container)
	return container


static func _add_tick_tag(container: Control) -> void:
	var tick := _load_sprite(TICK_PATH, DEFAULT_ICON)
	# 源 :869-871 anchor(0,0) (4,4) frame 左下 → Godot 左上 y = frame逻辑高-4-tick显示高。
	var frame_h: float = 95.0 / CONTENT_SCALE   # tick 只挂在 create_hero_stone_icon 产物上（fragment_frame 95px）
	tick.position = Vector2(TICK_POS_UP.x, frame_h - TICK_POS_UP.y - _vis_size(tick).y)
	container.add_child(tick)


static func _is_hero(id: int, cm: Variant) -> bool:
	var unit_row: Dictionary = cm.get_raw_table("Unit").get(str(id), {})
	return String(unit_row.get("Unit Type", "")) == "Hero"


static func _get_quality(id: int, is_hero: bool, cm: Variant) -> int:
	if is_hero:
		return HERO_DEFAULT_QUALITY
	var equip_row: Dictionary = cm.get_raw_table("Equip").get(str(id), {})
	return int(equip_row.get("Quality", HERO_DEFAULT_QUALITY))


static func _get_icon_path(id: int, is_hero: bool, cm: Variant) -> String:
	if is_hero:
		var portrait: String = str(cm.get_raw_table("Unit").get(str(id), {}).get("Portrait", ""))
		if portrait == "":
			return ""
		return HERO_PORTRAIT_DIR + portrait.get_file()
	var icon: String = str(cm.get_raw_table("Equip").get(str(id), {}).get("Icon", ""))
	if icon == "":
		return ""
	# 源 readequip.lua:548/:581 直接用表内完整路径——Equip 表 Icon 前缀混存
	# UI/ITEM/（613）+ UI/HERO/（108 英雄魂石）+ UI/alpha/（1），只取 basename 硬拼
	# ITEM 目录会让魂石全落 gocha 占位图（2026-08-18 批5 验收反馈实证）。
	if icon.begins_with("UI/"):
		return "res://assets/ui/" + icon.substr(3)
	return EQUIP_ICON_DIR + icon.get_file()


static func _frame_color(quality: int) -> String:
	var idx: int = clampi(quality - 1, 0, FRAME_COLORS.size() - 1)
	return FRAME_COLORS[idx]


static func _load_sprite(path: String, fallback: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	var res_path := path if ResourceLoader.exists(path) else fallback
	if ResourceLoader.exists(res_path):
		sprite.texture = load(res_path)
		# 源显示 = 纹理 px ÷ CS（hello.lua:311）。Sprite2D 无拉伸语义（纹理原像素直显），
		# 不折算则 frame 92px 直画 92（源 71.8），图标大 1.28× 溢出 72 容器压文字
		# （2026-08-22 商店行重叠根因，纹理px直用系统债家族）。统一 scale 回显示口径。
		sprite.scale = Vector2(1.0 / CONTENT_SCALE, 1.0 / CONTENT_SCALE)
	sprite.centered = false
	return sprite
