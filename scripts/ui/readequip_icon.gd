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
# 源 frame_res：quality 1-5 → white/green/blue/purple/orange
const FRAME_COLORS: Array[String] = ["white", "green", "blue", "purple", "orange"]
const HERO_DEFAULT_QUALITY: int = 1   # 源 createIcon hero 分支 quality 默认 1
const ICON_SIZE: float = 72.0
const ICON_OFFSET: Vector2 = Vector2(9.0, 9.0)
const AMOUNT_POS: Vector2 = Vector2(40.0, 50.0)
const STONE_ICON_POS: Vector2 = Vector2(36.0, 38.0)     # 源 createHeroStone stone ccp(36,38.5)
const SOULSTONE_TAG_POS: Vector2 = Vector2(15.0, 60.0)  # 源 :593 tag ccp(15,60)
const TICK_TAG_POS: Vector2 = Vector2(4.0, 4.0)         # 源 createIconWithTag :871 tag ccp(4,4)
# 装备强化星级（源 createIconWithLevel:1202-1231）：垂直单列 blue(level 颗)/grey(show_gray 到 ml)。
# star_bg（equipupgrade_equip_bg.png）本项目缺 → 降级不画底图。
const STAR_BLUE_RES: String = "res://assets/ui/alpha/HVGA/equipupgrade/equipupgrade_star_blue.png"
const STAR_GREY_RES: String = "res://assets/ui/alpha/HVGA/equipupgrade/equipupgrade_star_grey.png"
const STAR_OX: float = 58.0          # 源 ox（星 x，cocos 相对 bg）
const STAR_OY_COCOS: float = 18.0    # 源 oy（i=1 星 y，cocos 左下原点）
const STAR_DY: float = 10.0          # 源 dy 行间距（垂直单列 dx=0）
const STAR_SCALE: float = 0.9        # 源 :1216/1224 setScale(0.9)
const HALF: float = 0.5              # 星中心定位偏移
# 源 hello.lua:311 setContentScaleFactor(1.28125)：cocos sprite 显示=纹理/CS（无 fix_size 时）。
# 源 :1215/1223 setScale(0.9) 在 /CS 基础上叠加 → 最终 = (纹理/CS) × 0.9
const CONTENT_SCALE: float = 1.28125


# 创建图标节点（品质边框 + 内 Icon + 数量 Label + 可选星级）。id 为 equip id 或 hero tid。
# 源 createIcon（基础）+ createIconWithLevel（+星级）。level=强化等级（蓝星数），show_gray=补灰星占位到 ml。
static func create_icon(id: int, amount: int, cm: Variant, level: int = 0, show_gray: bool = false) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	container.size = Vector2(ICON_SIZE, ICON_SIZE)
	var is_hero: bool = _is_hero(id, cm)
	var quality: int = _get_quality(id, is_hero, cm)
	var frame := _load_sprite(FRAME_DIR + _frame_color(quality) + ".png", DEFAULT_ICON)
	container.add_child(frame)
	var icon_path := _get_icon_path(id, is_hero, cm)
	if icon_path != "":
		var icon := _load_sprite(icon_path, DEFAULT_ICON)
		icon.position = ICON_OFFSET
		container.add_child(icon)
	if amount > 1:
		var lbl := Label.new()
		lbl.text = "x" + str(amount)
		lbl.position = AMOUNT_POS
		container.add_child(lbl)
	if level > 0 or show_gray:
		_add_stars(container, id, level, show_gray, cm)
	# 存 quality/is_hero 供 pop_tavern_loot playBurst 品质光效判断（源 createLootAnim :494/564-625）。
	container.set_meta(&"quality", quality)
	container.set_meta(&"is_hero", is_hero)
	return container


# 源 createIconWithLevel:1214-1229：垂直单列蓝星（level 颗）+ show_gray 灰星占位到 ml。
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


# 源 createIconWithLevel:1215-1218：星 @ (ox, oy+dy*(i-1)) scale 0.9，cocos 锚点 0.5/0.5 中心。
# 源 sprite 显示=纹理/CS（引擎级），setScale(0.9) 在此基础上叠加 → size=纹理/CS 再 scale 0.9。
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
	# 源 cocos (ox, cocos_y) 中心 → Godot 左上 = (ox, ICON_SIZE - cocos_y) - actual_size/2
	t.position = Vector2(STAR_OX, ICON_SIZE - cocos_y) - actual_size * HALF
	return t


## 取 create_icon 建 icon 时存入的 stars 数组（供 playEnhanceAnim 操作；无返空）。
static func get_stars(container: Control) -> Array:
	var v: Variant = container.get_meta("stars", [])
	return v if v is Array else []


## 源 readequip.lua refreshHeroItemStar:1243-1256：stars[1..new_level] 中灰星（type=n）上层加蓝星覆盖
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
	var bg := _load_sprite(FRAGMENT_BG_PATH, DEFAULT_ICON)
	container.add_child(bg)
	var icon_path := _get_icon_path(id, false, cm)
	if icon_path != "":
		var icon := _load_sprite(icon_path, DEFAULT_ICON)
		icon.position = STONE_ICON_POS
		container.add_child(icon)
	var tag := _load_sprite(SOULSTONE_TAG_PATH, DEFAULT_ICON)
	tag.position = SOULSTONE_TAG_POS
	container.add_child(tag)
	if amount > 1:
		var lbl := Label.new()
		lbl.text = "x" + str(amount)
		lbl.position = AMOUNT_POS
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
	tick.position = TICK_TAG_POS
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
		var portrait: String = String(cm.get_raw_table("Unit").get(str(id), {}).get("Portrait", ""))
		if portrait == "":
			return ""
		return HERO_PORTRAIT_DIR + portrait.get_file()
	var icon: String = String(cm.get_raw_table("Equip").get(str(id), {}).get("Icon", ""))
	if icon == "":
		return ""
	return EQUIP_ICON_DIR + icon.get_file()


static func _frame_color(quality: int) -> String:
	var idx: int = clampi(quality - 1, 0, FRAME_COLORS.size() - 1)
	return FRAME_COLORS[idx]


static func _load_sprite(path: String, fallback: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	var res_path := path if ResourceLoader.exists(path) else fallback
	if ResourceLoader.exists(res_path):
		sprite.texture = load(res_path)
	sprite.centered = false
	return sprite
