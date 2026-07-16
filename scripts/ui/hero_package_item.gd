class_name HeroPackageItem
extends Control

## 英雄整行卡片（View 层）— 照源 heroitem.lua baseheroitem + packageheroitem 翻译（P0-1）。
## 结构：bg(package_hero_bg 313×123) + ReadheroIcon 头像(7,9) + 名字(177,72) + 力/敏/智 mark(110,72) +
##   拥有：6 装备槽 gocha.png(105+22*i,18)；未拥有：灵魂石进度条 + 可召唤光效 + 头像灰化。
## 坐标：源 cocos bg 空间（左下原点 y上）→ Godot Control（左上原点 y下），_place 翻转 BG_H-y。
## 资源降级：mark icon_str/agi/int 源项目缺图 → ColorRect 属性色块；name rank 后缀简化省略（待精确）。
## cell 260×100（源 refreshHeroList getpos 间距），bg 313×123 透明边缘溢出 cell（照源视觉重叠）。

const BG_RES: String = "res://assets/ui/alpha/HVGA/package_hero_bg.png"
const BG_SIZE: Vector2 = Vector2(313.0, 123.0)
const CELL_SIZE: Vector2 = Vector2(320.0, 100.0)   # 加宽（用户偏好并列清晰），源 getpos 260 间距 + bg 313 透明重叠
const BG_OFFSET: Vector2 = Vector2(3.5, -11.5)        # bg 中心对齐 cell 中心（cell 320 > bg 313，bg 水平不溢出）
const BG_H: float = 123.0
const GOCHA_RES: String = "res://assets/ui/alpha/HVGA/gocha.png"
const PROGRESS_BG_RES: String = "res://assets/ui/alpha/HVGA/heropackage_soulstone_progress_bg.png"
const PROGRESS_RES: String = "res://assets/ui/alpha/HVGA/heropackage_soulstone_progress.png"
const AVAILABLE_RES: String = "res://assets/ui/alpha/HVGA/heropackage_available.png"
const HEAD_POS: Vector2 = Vector2(7.0, 9.0)             # 源 baseheroitem :27 anchor(0,0)
const NAME_POS_Y: float = 72.0                          # 源 :36 y=72 anchor(0,0.5)
const NAME_CENTER_X: float = 177.0                      # 源 :36 x=177-min(w,ow)/2
const NAME_MAX_W: float = 100.0                         # 源 :29 ow=100
const MARK_POS: Vector2 = Vector2(110.0, 72.0)          # 源 :40 anchor(0.5,0.5) scale 0.8
const MARK_SIZE: Vector2 = Vector2(24.0, 24.0)
const EQUIP_X_BASE: float = 105.0                       # 源 createHeroEquips :205
const EQUIP_X_STEP: float = 22.0
const EQUIP_Y: float = 18.0
const EQUIP_SLOT_COUNT: int = 6
const EQUIP_BG_SIZE: float = 22.0                       # 源 scale 22/w（gocha 94）
const EQUIP_ICON_SIZE: float = 16.0                     # 源 :215 scale 16/w
const EQUIP_EMPTY_ALPHA: float = 100.0 / 255.0          # 源 :236 setOpacity(100)
const BAR_BG_POS: Vector2 = Vector2(90.0, 22.0)         # 源 createHeroStone :142 anchor(0,0.5)
const BAR_BG_SCALE_X: float = 0.93                      # 源 :143
const BAR_BG_W: float = 204.0 * 0.93                    # progress_bg 204×34 × scale 0.93
const BAR_BG_H: float = 34.0
const BAR_FILL_H: float = 26.0                          # 源 :149 setTextureRect h=26
const BAR_LABEL_POS: Vector2 = Vector2(80.0, 13.0)      # 源 :152 anchor(0.5,0.5) 相对 barBg
const AVAILABLE_ALPHA: float = 150.0 / 255.0            # 源 :160 setOpacity(150)
const NAME_FALLBACK: String = "?"
const GRAY_MODULATE: Color = Color(0.5, 0.5, 0.5, 1.0)  # 源 setSpriteGray 近似
const CLIP_PREFIX: String = "UI/"
const CLIP_REPLACE: String = "res://assets/ui/"
const MARK_COLORS: Dictionary = {
	"STR": Color(0.90, 0.30, 0.20),
	"AGI": Color(0.30, 0.75, 0.30),
	"INT": Color(0.30, 0.45, 0.95),
}

var cm: Variant = null
var hero_mgr: HeroManager = null
var tid: int = 0
var is_miss: bool = false
var _entry: Variant = null
var head: ReadheroIcon = null


# 入口：entry 是 HeroInstance（已拥有）或 {tid:int, miss:bool}（未拥有，源 getAllListWithMiss 产物）。
static func create_from_entry(entry: Variant, p_cm: Variant, p_hero_mgr: HeroManager) -> HeroPackageItem:
	var item := HeroPackageItem.new()
	item._build(entry, p_cm, p_hero_mgr)
	return item


func _build(entry: Variant, p_cm: Variant, p_hero_mgr: HeroManager) -> void:
	cm = p_cm
	hero_mgr = p_hero_mgr
	_entry = entry
	is_miss = not (entry is HeroInstance)
	tid = ReadheroHandbook.entry_tid(entry)
	custom_minimum_size = CELL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_create_bg()
	_create_head()
	_create_name()
	_create_mark()
	if is_miss:
		_create_stone()
	else:
		_create_equips()


func _create_bg() -> void:
	var bg := TextureRect.new()
	bg.texture = _load_tex(BG_RES)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.size = BG_SIZE
	bg.position = BG_OFFSET
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


# 源 baseheroitem :20-28 — miss 用 createIcon{id,rank=1}（无 level/stars）；拥有用 createIconByHero。
func _create_head() -> void:
	if is_miss:
		head = ReadheroIcon.new()
		head.setup({"id": tid, "rank": 1}, cm)
	else:
		head = ReadheroIcon.create_icon_by_hero(_entry as HeroInstance, cm)
	head.position = _place(HEAD_POS, Vector2.ZERO, ReadheroIcon.CONTAINER_SIZE)
	add_child(head)


# 源 baseheroitem :29-37 createHeroNameByInfo — name + rank 后缀（后缀简化省略，待 getHeroStarByRank 精确翻译）。
func _create_name() -> void:
	# 源 Unit.lua ["Display Name"] = LSTR("Unit.hero.alias.001")，Lua load 时 LSTR 宏翻译成中文；
	# lua_to_json 转 Unit.json 只存 key 字符串，View 层须 cm.get_lstr 解析成当前语言（源 readhero.createttf 等价）。
	var disp_name: String = cm.get_lstr(_unit_str(&"Display Name", NAME_FALLBACK))
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.text = disp_name
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	var ls: Vector2 = lbl.get_minimum_size()
	var pos_x: float = NAME_CENTER_X - min(ls.x, NAME_MAX_W) * 0.5
	lbl.position = _place(Vector2(pos_x, NAME_POS_Y), Vector2(0.0, 0.5), ls)
	if ls.x > NAME_MAX_W:
		lbl.scale.x = NAME_MAX_W / ls.x


# 源 baseheroitem :38-42 markIcon = hero_mark_res[Main Attrib]；icon_str/agi/int 源缺图 → ColorRect 降级。
func _create_mark() -> void:
	var attrib: String = _unit_str(&"Main Attrib", "")
	if attrib.is_empty():
		return
	var mark := ColorRect.new()
	mark.color = MARK_COLORS.get(attrib, Color(0.5, 0.5, 0.5))
	mark.size = MARK_SIZE
	mark.position = _place(MARK_POS, Vector2(0.5, 0.5), MARK_SIZE)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mark)


# 源 packageheroitem createHeroEquips :202-249 — 6 槽 gocha.png 背景 + 装备图标（有）/ 半透明（空）。
# plusSign（可合成 + 号）+ canDealTag 降级省略（待 isEquipCraftable/canWearEquip 翻译）。
func _create_equips() -> void:
	var hero: HeroInstance = _entry as HeroInstance
	for i in range(EQUIP_SLOT_COUNT):
		var cocos_x: float = EQUIP_X_BASE + EQUIP_X_STEP * float(i)
		var slot_size := Vector2(EQUIP_BG_SIZE, EQUIP_BG_SIZE)
		var slot_pos: Vector2 = _place(Vector2(cocos_x, EQUIP_Y), Vector2(0.5, 0.5), slot_size)
		var slot_bg := TextureRect.new()
		slot_bg.texture = _load_tex(GOCHA_RES)
		slot_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot_bg.size = slot_size
		slot_bg.position = slot_pos
		slot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(slot_bg)
		var item_id: int = int(hero.equip_slots[i])
		if item_id > 0:
			_create_equip_icon(item_id, slot_pos)
		else:
			slot_bg.modulate = Color(1.0, 1.0, 1.0, EQUIP_EMPTY_ALPHA)


func _create_equip_icon(item_id: int, slot_pos: Vector2) -> void:
	var res: Variant = cm.lookup(&"Equip", "Icon", item_id)
	if res == null or not (res is String):
		return
	var path: String = (res as String).replace(CLIP_PREFIX, CLIP_REPLACE)
	var tex: Texture2D = _load_tex(path)
	if tex == null:
		return
	var icon_size := Vector2(EQUIP_ICON_SIZE, EQUIP_ICON_SIZE)
	var icon := TextureRect.new()
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = icon_size
	# 源 :214 equip 与 equipBg 同位（cocos_x, 18）anchor(0.5,0.5) → 中心对齐 slot
	icon.position = slot_pos + (Vector2(EQUIP_BG_SIZE, EQUIP_BG_SIZE) - icon_size) * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)


# 源 packageheroitem createHeroStone :126-178 — 进度条 + 文字 + 可召唤光效 + 头像灰化。
func _create_stone() -> void:
	var sa: int = ReadheroHandbook.get_stone_amount(tid, cm, hero_mgr)
	var sn: int = ReadheroHandbook.get_stone_need(tid, cm, hero_mgr)
	var need: int = sn if sn > 0 else 1
	var ratio: float = clampf(float(sa) / float(need), 0.0, 1.0)
	var bg_size := Vector2(BAR_BG_W, BAR_BG_H)
	var bar_bg_pos: Vector2 = _place(BAR_BG_POS, Vector2(0.0, 0.5), bg_size)
	var bar_bg := TextureRect.new()
	bar_bg.texture = _load_tex(PROGRESS_BG_RES)
	bar_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar_bg.size = bg_size
	bar_bg.position = bar_bg_pos
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_bg)
	var bar_size := Vector2(BAR_BG_W * ratio, BAR_FILL_H)
	var bar := TextureRect.new()
	bar.texture = _load_tex(PROGRESS_RES)
	bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.size = bar_size
	# 源 bar anchor(0,0) at barBg(0,0)：bar 左下角=barBg 左下角 → Godot bar 在 barBg 底部偏移
	bar.position = bar_bg_pos + Vector2(0.0, BAR_BG_H - BAR_FILL_H)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	_create_stone_label(sa, sn, bar_bg_pos, bg_size)
	if sa >= sn:
		_create_summon_light()
	# 源 :120 setSpriteGray(head.ori_icon) — 未拥有头像灰化
	if head != null and head.ori_icon != null:
		head.ori_icon.modulate = GRAY_MODULATE


func _create_stone_label(sa: int, sn: int, bar_bg_pos: Vector2, bg_size: Vector2) -> void:
	var text: String = "可召唤" if sa >= sn else "%d/%d" % [sa, sn]
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	var ls: Vector2 = lbl.get_minimum_size()
	# 源 :152 label anchor(0.5,0.5) at barBg(80,13)（相对 barBg 中心坐标系）
	lbl.position = bar_bg_pos + Vector2(BAR_LABEL_POS.x, BAR_BG_H - BAR_LABEL_POS.y) - ls * 0.5


# 源 :154-167 summonLight heropackage_available.png 居中 + opacity 150 闪烁；单机化静态（不动画）。
func _create_summon_light() -> void:
	var light := TextureRect.new()
	light.texture = _load_tex(AVAILABLE_RES)
	light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	light.size = BG_SIZE
	light.position = BG_OFFSET
	light.modulate = Color(1.0, 1.0, 1.0, AVAILABLE_ALPHA)
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(light)


# cocos(bg 空间,左下原点)→Godot(cell 空间,左上原点) 转换 + BG_OFFSET。
# anchor 是 cocos 的 setAnchorPoint(ax,ay)；node_size 是节点尺寸。
static func _place(cocos_pos: Vector2, anchor: Vector2, node_size: Vector2) -> Vector2:
	var gx: float = cocos_pos.x - anchor.x * node_size.x
	var gy: float = BG_H - cocos_pos.y - (1.0 - anchor.y) * node_size.y
	return BG_OFFSET + Vector2(gx, gy)


func _unit_str(field: StringName, fallback: String) -> String:
	var row: Dictionary = cm.get_raw_table(&"Unit").get(str(tid), {})
	var v: Variant = row.get(field, null)
	if v == null:
		return fallback
	return str(v)


static func _load_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
