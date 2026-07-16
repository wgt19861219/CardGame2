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
# 源 hello.lua:311 setContentScaleFactor(615/480)=1.28125（iPhone 资源档）：cocos sprite contentSize=纹理/CS，position 不变。
# → bg 313 纹理显示 313/CS≈244，getpos 列距 260/行距 100 不重叠（间隙 16/4）。Godot 在 _build 整体 scale=1/CS 等价。
const CONTENT_SCALE: float = 1.28125
const CELL_SIZE: Vector2 = Vector2(260.0, 100.0)   # 源 getpos 列间距 260 / 行高 100（卡片中心间距）
const BG_OFFSET: Vector2 = Vector2(-26.5, -11.5)   # bg 中心对齐 cell 中心=(cell-bg纹理)/2；scale 1/CS 后 bg 244 居中 cell
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
# 源 readhero.lua:947 ed.createttf(name, 20) — 名字字号 20（baseheroitem :32 传 shadow {color, offset}）。
const NAME_FONT_SIZE: int = 20
const NAME_SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0)      # 源 baseheroitem :32 shadow.color ccc3(0,0,0)
const NAME_SHADOW_OFFSET_Y: int = 2                         # 源 :32 shadow.offset ccp(0,2)
# 源 heroitem.lua:225/227 plusSign sr + :244 canDealTag tag 资源。
const PLUS_WEAR_RES: String = "res://assets/ui/alpha/HVGA/herodetail-equipadd.png"          # 源 :225 可穿戴蓝+
const PLUS_CRAFT_RES: String = "res://assets/ui/alpha/HVGA/herodetail_icon_plus_yellow.png" # 源 :227 仅可合成黄+
const DEAL_TAG_RES: String = "res://assets/ui/alpha/HVGA/main_deal_tag.png"                 # 源 :244 canDealTag
const PLUS_SIGN_TARGET: float = 24.0   # 源 :233 plusSign setScale(24/w)
const DEAL_TAG_TARGET: float = 24.0    # 源 :244 tag setScale(24/w)
const DEAL_TAG_COCOS: Vector2 = Vector2(240.0, 90.0)   # 源 :245 tag setPosition(240, 90)

var cm: Variant = null
var hero_mgr: HeroManager = null
var pd: PlayerData = null
var tid: int = 0
var is_miss: bool = false
var _entry: Variant = null
var head: ReadheroIcon = null


# 入口：entry 是 HeroInstance（已拥有）或 {tid:int, miss:bool}（未拥有，源 getAllListWithMiss 产物）。
# p_pd 可选 — plusSign 持有判定用（pd=null 时仅查配方 Components>0，与 equip_craft_panel 简化版对齐）。
static func create_from_entry(entry: Variant, p_cm: Variant, p_hero_mgr: HeroManager, p_pd: PlayerData = null) -> HeroPackageItem:
	var item := HeroPackageItem.new()
	item._build(entry, p_cm, p_hero_mgr, p_pd)
	return item


func _build(entry: Variant, p_cm: Variant, p_hero_mgr: HeroManager, p_pd: PlayerData = null) -> void:
	cm = p_cm
	hero_mgr = p_hero_mgr
	pd = p_pd
	_entry = entry
	is_miss = not (entry is HeroInstance)
	tid = ReadheroHandbook.entry_tid(entry)
	custom_minimum_size = CELL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 源 contentScaleFactor 1.28（见 CONTENT_SCALE）：item 整体 scale=1/CS 补偿（bg/头像/装备槽纹理都偏大 1.28），
	# pivot=cell 中心使缩放后内容（bg 244×96）居中 cell 260×100，与源 bg 显示尺寸一致、不重叠。
	pivot_offset = CELL_SIZE * 0.5
	scale = Vector2.ONE / CONTENT_SCALE
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


# 源 baseheroitem :29-37 + readhero.lua:939-985 createHeroNameByInfo — name + "+N" 后缀（hero_star[rank]>0 时）。
# name 与 suffix 两 Label 横向拼接（源 sprite 容器 + 两 createttf 子节点）；suffix 按 rank 段着色。
# 名字本身默认色（源 baseheroitem :32 未传 nameColor），阴影 ccc3(0,0,2)（源 shadow）。
func _create_name() -> void:
	var disp_name: String = cm.get_lstr(_unit_str(&"Display Name", NAME_FALLBACK))
	var rank: int = _rank()
	var star: int = ReadheroHandbook.get_hero_star_by_rank(rank)
	var name_lbl := _make_name_label(disp_name, ReadheroHandbook.NAME_COLOR_DEFAULT)
	add_child(name_lbl)
	var name_size: Vector2 = name_lbl.get_minimum_size()
	var total_w: float = name_size.x
	var suffix_w: float = 0.0
	var suffix_lbl: Label = null
	if star > 0:
		suffix_lbl = _make_name_label("+" + str(star), ReadheroHandbook.get_hero_name_color_by_rank(rank))
		add_child(suffix_lbl)
		suffix_w = suffix_lbl.get_minimum_size().x
		total_w += suffix_w
	# 源 :33-35 ow<w 时 setScale(ow/w)；:36 setPosition(177 - min(w,ow)/2, 72) anchor(0,0.5)
	var scale_val: float = min(1.0, NAME_MAX_W / total_w) if total_w > 0.0 else 1.0
	var pos_x: float = NAME_CENTER_X - min(total_w, NAME_MAX_W) * 0.5
	var base_pos: Vector2 = _place(Vector2(pos_x, NAME_POS_Y), Vector2(0.0, 0.5), Vector2(total_w, name_size.y))
	name_lbl.scale = Vector2(scale_val, scale_val)
	name_lbl.position = base_pos
	if suffix_lbl != null:
		suffix_lbl.scale = Vector2(scale_val, scale_val)
		suffix_lbl.position = base_pos + Vector2(name_size.x * scale_val, 0.0)


func _make_name_label(text: String, font_color: Color) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	lbl.text = text
	lbl.add_theme_color_override("font_color", font_color)
	lbl.add_theme_color_override("font_shadow_color", NAME_SHADOW_COLOR)
	lbl.add_theme_constant_override("shadow_offset_y", NAME_SHADOW_OFFSET_Y)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


# 源 baseheroitem :31 rank = miss and 1 or player.heroes[tid]._rank（miss 默认 1 = 无后缀）。
func _rank() -> int:
	if is_miss:
		return 1
	return (_entry as HeroInstance).rank


# 源 baseheroitem :38-42 markIcon = hero_mark_res[Main Attrib] = icon_str/agi/int.png。
# 资源核实：git ls-files 确认 assets/ui/alpha/HVGA/icon_str/agi/int.png 均缺 → ColorRect 属性色块降级。
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


# 源 packageheroitem createHeroEquips :202-249 — 6 槽 gocha.png 背景 + 装备图标（有）/ 半透明（空 + plusSign）。
# plusSign：空槽查 hero_equip[tid][rank]["Equip{slot} ID"]，可合成则加 + 号（黄+仅可合成 / 蓝+可穿戴）。
# canDealTag：任一槽可穿戴时在 (240,90) 加 main_deal_tag（源 :243-248 isShowTag）。
func _create_equips() -> void:
	var hero: HeroInstance = _entry as HeroInstance
	var show_tag: bool = false
	for i in range(EQUIP_SLOT_COUNT):
		var slot: int = i + 1   # 源 Lua i=1..6（GDScript 0-based +1）
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
			var eid: int = EquipdetailQuery.get_slot_expected_equip(hero, slot, cm)
			if eid > 0 and EquipdetailQuery.is_equip_craftable(eid, cm, pd):
				var can_wear: bool = bool(EquipdetailQuery.can_wear_equip(hero, eid, cm)["can"])
				_create_plus_sign(PLUS_WEAR_RES if can_wear else PLUS_CRAFT_RES, slot_pos, slot_size)
				if can_wear:
					show_tag = true
	if show_tag:
		_create_deal_tag()


# 源 heroitem.lua:231-234 plusSign — setScale(24/w) at (105+22*(i-1), 18) anchor(0.5,0.5) 同 equipBg。
func _create_plus_sign(res_path: String, slot_pos: Vector2, slot_size: Vector2) -> void:
	var tex: Texture2D = _load_tex(res_path)
	if tex == null:
		return
	var orig_w: float = float(tex.get_width())
	var scale_val: float = PLUS_SIGN_TARGET / orig_w if orig_w > 0.0 else 1.0
	var icon_size := tex.get_size() * scale_val
	var icon := TextureRect.new()
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = icon_size
	icon.position = slot_pos + (slot_size - icon_size) * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)


# 源 heroitem.lua:243-248 canDealTag — main_deal_tag.png setScale(24/w) at (240, 90)。
func _create_deal_tag() -> void:
	var tex: Texture2D = _load_tex(DEAL_TAG_RES)
	if tex == null:
		return
	var orig_w: float = float(tex.get_width())
	var scale_val: float = DEAL_TAG_TARGET / orig_w if orig_w > 0.0 else 1.0
	var tag_size := tex.get_size() * scale_val
	var tag := TextureRect.new()
	tag.texture = tex
	tag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tag.size = tag_size
	tag.position = _place(DEAL_TAG_COCOS, Vector2.ZERO, tag_size)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tag)


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
