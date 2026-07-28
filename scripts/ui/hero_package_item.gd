class_name HeroPackageItem
extends Control

## 英雄整行卡片（View 层）— 照源 heroitem.lua baseheroitem + packageheroitem 翻译（P0-1）。
## 结构：bg(package_hero_bg 313×123) + ReadheroIcon 头像(7,9) + 名字(177,72) + 力/敏/智 mark(110,72) +
##   拥有：6 装备槽 gocha.png(105+22*i,18)；未拥有：灵魂石进度条 + 可召唤光效 + 头像灰化。
## 坐标：源 cocos bg 空间（左下原点 y上）→ Godot Control（左上原点 y下），_place 翻转 BG_H-y。
## mark 属性图标 icon_str/agi/int（2026-07-18 从 ECCHC 补齐，不再降级）；name rank 后缀简化省略（待精确）。
## cell 260×100（源 refreshHeroList getpos 间距），bg 313×123 透明边缘溢出 cell（照源视觉重叠）。
##
## Phase A 重构（2026-07-18）：结构（bg + head host + name/suffix + mark + 6 equip slot + deal tag +
## stone bar）静态化进 hero_package_item_content.tscn（instantiate + fill），位置/size 编辑器可视化调。
## 两形态（拥有/未拥有）EquipGroup/StoneGroup visible 切换（坑 5）。fill 动态：head/名字/装备图标/plus sign/
## 进度/光效/头像灰化。坐标照源 _place 烘焙进 .tscn（BG_OFFSET + cocos→godot 翻转）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/hero_package_item_content.tscn")
# 源 hello.lua:311 setContentScaleFactor(615/480)=1.28125（iPhone 资源档）：cocos sprite contentSize=纹理/CS，position 不变。
# → bg 313 纹理显示 313/CS≈244，getpos 列距 260/行距 100 不重叠（间隙 16/4）。Godot 在 _build 整体 scale=1/CS 等价。
const CONTENT_SCALE: float = 1.28125
const CELL_SIZE: Vector2 = Vector2(260.0, 100.0)
const BG_OFFSET: Vector2 = Vector2(-26.5, -11.5)   # bg 中心对齐 cell 中心；scale 1/CS 后 bg 244 居中 cell
const BG_H: float = 123.0
const EQUIP_SLOT_COUNT: int = 6
const EQUIP_BG_SIZE: float = 28.0                       # ⚠️偏离源 22（源 scale 22/w gocha 94）→ 28 放大易辨识（用户决策 2026-07-18）
const EQUIP_ICON_SIZE: float = 20.0                     # ⚠️偏离源 16，按源比例 16/22×28≈20 同步放大
const EQUIP_EMPTY_ALPHA: float = 100.0 / 255.0
const BAR_BG_W: float = 204.0 * 0.93                    # progress_bg 204×34 × scale 0.93（源 :143）
const BAR_BG_H: float = 34.0                            # progress_bg 纹理高（源 :142 204×34）
const BAR_FILL_H: float = 26.0
const BAR_FILL_OFFSET: Vector2 = Vector2(63.5, 80.5)    # _place 烘焙（= bar_bg_pos + (0, BAR_BG_H-BAR_FILL_H)）
const BAR_LABEL_POS: Vector2 = Vector2(80.0, 13.0)
const BAR_BG_POS: Vector2 = Vector2(63.5, 72.5)         # _place 烘焙（bar_bg_pos）
const AVAILABLE_ALPHA: float = 150.0 / 255.0
# 源 heroitem.lua:225/227 plusSign sr + :244 canDealTag tag 资源。
const PLUS_WEAR_RES: String = "res://assets/ui/alpha/HVGA/herodetail-equipadd.png"
const PLUS_CRAFT_RES: String = "res://assets/ui/alpha/HVGA/herodetail_icon_plus_yellow.png"
const DEAL_TAG_RES: String = "res://assets/ui/alpha/HVGA/main_deal_tag.png"
const PLUS_SIGN_TARGET: float = 30.0   # ⚠️偏离源 24，按源比例 24/22×28≈30 同步放大（用户决策 2026-07-18）
# summonLight 呼吸动画（源 heroitem.lua:154-167 StoneGroup.SummonLight Tween FadeTo 循环）。
const SUMMON_LIGHT_BREATH_DUR: float = 1.2   # 一次 fade in+out 总时长（秒）
const DEAL_TAG_TARGET: float = 24.0
const NAME_CENTER_X: float = 177.0
const NAME_POS_Y: float = 72.0
const NAME_MAX_W: float = 100.0
const NAME_FALLBACK: String = "?"
const NAME_COLOR_DEFAULT: Color = Color(1.0, 1.0, 1.0, 1.0)
const GRAY_MODULATE: Color = Color(0.5, 0.5, 0.5, 1.0)
const CLIP_PREFIX: String = "UI/"
const CLIP_REPLACE: String = "res://assets/ui/"
const MARK_RES: Dictionary = {
	"STR": "res://assets/ui/alpha/HVGA/icon_str.png",
	"AGI": "res://assets/ui/alpha/HVGA/icon_agi.png",
	"INT": "res://assets/ui/alpha/HVGA/icon_int.png",
}

var cm: Variant = null
var hero_mgr: HeroManager = null
var pd: PlayerData = null
var tid: int = 0
var is_miss: bool = false
var _entry: Variant = null
var head: ReadheroIcon = null
var _content: Control = null
var _name_host: Control = null
var _name_lbl: Label = null
var _suffix_lbl: Label = null
var _mark_rect: TextureRect = null
var _equip_group: Control = null
var _stone_group: Control = null
var _equip_slots: Array[TextureRect] = []
var _tip_host: Control = null
var _deal_tag: TextureRect = null
var _bar_fill: TextureRect = null
var _stone_label: Label = null
var _summon_light: TextureRect = null
var _summon_light_tween: Tween = null


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
	# pivot=cell 中心使缩放后内容（bg 244×96）居中 cell 260×100，与源 bg 显示尺寸一致、不重叠。
	pivot_offset = CELL_SIZE * 0.5
	scale = Vector2.ONE / CONTENT_SCALE
	_content = CONTENT_SCENE.instantiate() as Control
	add_child(_content)
	_cache_nodes()
	_fill_head()
	_fill_name()
	_fill_mark()
	if is_miss:
		_fill_stone()
	else:
		_fill_equips()
	# 两形态 visible 切换（坑 5）：拥有→EquipGroup / 未拥有→StoneGroup + 头像灰化。
	# TipHost 已从 EquipGroup 拎到根平级（用户决策"红点和装备槽平级"），不再跟随 EquipGroup visible 链，
	# 此处显式按形态控可见（未拥有形态无装备可穿戴，红点必隐）。
	_equip_group.visible = not is_miss
	_stone_group.visible = is_miss
	_tip_host.visible = false


# Phase A 重构：取 .tscn 节点引用（fill 用）。
func _cache_nodes() -> void:
	_name_host = _content.get_node("%NameHost") as Control
	_name_lbl = _content.get_node("%NameLabel") as Label
	_suffix_lbl = _content.get_node("%SuffixLabel") as Label
	_mark_rect = _content.get_node("%MarkRect") as TextureRect
	_equip_group = _content.get_node("%EquipGroup") as Control
	_stone_group = _content.get_node("%StoneGroup") as Control
	_tip_host = _content.get_node("%TipHost") as Control
	_deal_tag = _content.get_node("%DealTag") as TextureRect
	_bar_fill = _content.get_node("%BarFill") as TextureRect
	_stone_label = _content.get_node("%StoneLabel") as Label
	_summon_light = _content.get_node("%SummonLight") as TextureRect
	_equip_slots.clear()
	for i in range(EQUIP_SLOT_COUNT):
		_equip_slots.append(_content.get_node("%EquipSlot" + str(i + 1)) as TextureRect)


# HeadHost 已在 _place(HEAD_POS) 烘焙位置，head position=0 挂 host。
func _fill_head() -> void:
	if is_miss:
		head = ReadheroIcon.new()
		head.setup({"id": tid, "rank": 1}, cm)
	else:
		head = ReadheroIcon.create_icon_by_hero(_entry as HeroInstance, cm)
	head.position = Vector2.ZERO
	(_content.get_node("%HeadHost") as Control).add_child(head)


# name 与 suffix 两 Label 横向拼接；suffix 按 rank 段着色。名字本身默认色，阴影 ccc3(0,0,2)（.tscn 已固化）。
func _fill_name() -> void:
	var disp_name: String = cm.get_lstr(_unit_str(&"Display Name", NAME_FALLBACK))
	var rank: int = _rank()
	var star: int = ReadheroHandbook.get_hero_star_by_rank(rank)
	_name_lbl.text = disp_name
	_name_lbl.add_theme_color_override("font_color", NAME_COLOR_DEFAULT)
	var name_size: Vector2 = _name_lbl.get_minimum_size()
	var total_w: float = name_size.x
	var suffix_w: float = 0.0
	if star > 0:
		_suffix_lbl.text = "+" + str(star)
		_suffix_lbl.add_theme_color_override("font_color", ReadheroHandbook.get_hero_name_color_by_rank(rank))
		_suffix_lbl.visible = true
		suffix_w = _suffix_lbl.get_minimum_size().x
		total_w += suffix_w
	else:
		_suffix_lbl.visible = false
	# NameHost 位置/尺寸 .tscn 固化（用户决策，不按源动态算法）。name+suffix 拼接整体在 NameHost 内部居中：
	# fill 算整体宽 total_w，左起点 = (NameHost 宽 - total_w×scale) / 2，suffix 紧贴 name 右侧。
	# host_w 用 offset（.tscn 固化值），不读 size（_build 阶段未布局 size 可能为 0）。
	var scale_val: float = min(1.0, NAME_MAX_W / total_w) if total_w > 0.0 else 1.0
	var host_w: float = _name_host.offset_right - _name_host.offset_left
	var render_w: float = total_w * scale_val
	var start_x: float = (host_w - render_w) * 0.5
	_name_lbl.scale = Vector2(scale_val, scale_val)
	_name_lbl.position = Vector2(start_x, 0.0)
	if star > 0:
		_suffix_lbl.scale = Vector2(scale_val, scale_val)
		_suffix_lbl.position = Vector2(start_x + name_size.x * scale_val, 0.0)


# 2026-07-18 从 ECCHC 补齐资源（此前缺图降级 ColorRect 色块，现恢复 TextureRect 图标）。
func _fill_mark() -> void:
	var attrib: String = _unit_str(&"Main Attrib", "")
	var res_path: String = MARK_RES.get(attrib, "") if not attrib.is_empty() else ""
	if res_path.is_empty():
		_mark_rect.visible = false
		return
	var tex: Texture2D = _load_tex(res_path)
	if tex == null:
		_mark_rect.visible = false
		return
	_mark_rect.texture = tex
	_mark_rect.visible = true


# plusSign：空槽查 hero_equip[tid][rank]["Equip{slot} ID"]，可合成则加 + 号（黄+仅可合成 / 蓝+可穿戴）。
# canDealTag：任一槽可穿戴时在 (240,90) 加 main_deal_tag（源 :243-248 isShowTag，DealTag position 已烘焙）。
func _fill_equips() -> void:
	var hero: HeroInstance = _entry as HeroInstance
	var show_tag: bool = false
	var slot_size := Vector2(EQUIP_BG_SIZE, EQUIP_BG_SIZE)
	for i in range(EQUIP_SLOT_COUNT):
		var slot_bg: TextureRect = _equip_slots[i]
		var slot: int = i + 1
		var item_id: int = int(hero.equip_slots[i])
		if item_id > 0:
			slot_bg.modulate = Color(1.0, 1.0, 1.0, 1.0)
			_fill_equip_icon(item_id, slot_bg, slot_size)
		else:
			slot_bg.modulate = Color(1.0, 1.0, 1.0, EQUIP_EMPTY_ALPHA)
			var eid: int = EquipdetailQuery.get_slot_expected_equip(hero, slot, cm)
			if eid > 0 and EquipdetailQuery.is_equip_craftable(eid, cm, pd):
				var can_wear: bool = bool(EquipdetailQuery.can_wear_equip(hero, eid, cm)["can"])
				_fill_plus_sign(PLUS_WEAR_RES if can_wear else PLUS_CRAFT_RES, slot_bg, slot_size)
				if can_wear:
					show_tag = true
	if show_tag:
		_fill_deal_tag()


func _fill_plus_sign(res_path: String, slot_bg: TextureRect, slot_size: Vector2) -> void:
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
	icon.position = (slot_size - icon_size) * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_bg.add_child(icon)


# 位置由 %TipHost 在编辑器可视化调（DealTag 本地 (0,0)，size fill）。
func _fill_deal_tag() -> void:
	var tex: Texture2D = _load_tex(DEAL_TAG_RES)
	if tex == null:
		return   # 保持 _tip_host.visible = false
	var orig_w: float = float(tex.get_width())
	var scale_val: float = DEAL_TAG_TARGET / orig_w if orig_w > 0.0 else 1.0
	var tag_size := tex.get_size() * scale_val
	_deal_tag.size = tag_size
	_tip_host.visible = true


func _fill_equip_icon(item_id: int, slot_bg: TextureRect, slot_size: Vector2) -> void:
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
	icon.position = (slot_size - icon_size) * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_bg.add_child(icon)


func _fill_stone() -> void:
	var sa: int = ReadheroHandbook.get_stone_amount(tid, cm, hero_mgr)
	var sn: int = ReadheroHandbook.get_stone_need(tid, cm, hero_mgr)
	var need: int = sn if sn > 0 else 1
	var ratio: float = clampf(float(sa) / float(need), 0.0, 1.0)
	var fill_w: float = BAR_BG_W * ratio
	_bar_fill.offset_left = BAR_FILL_OFFSET.x
	_bar_fill.offset_top = BAR_FILL_OFFSET.y
	_bar_fill.offset_right = BAR_FILL_OFFSET.x + fill_w
	_bar_fill.offset_bottom = BAR_FILL_OFFSET.y + BAR_FILL_H
	_fill_stone_label(sa, sn)
	# 源 heroitem.lua:154-167：可召唤时 SummonLight 呼吸 FadeTo 循环（_modulate.a 1→0.3→1 pingpong）。
	_play_summon_light_breath(sa >= sn)
	if head != null and head.ori_icon != null:
		head.ori_icon.modulate = GRAY_MODULATE


# SummonLight 呼吸 Tween（源 heroitem.lua:154-167）：可召唤时启动 modulate.a 循环（1→0.3 pingpong），
# 不可召唤时停 Tween + 隐藏。HeroPackageItem 是 RefCounted（不在树），create_tween 需绑定节点
# 才能自动跟随 lifecycle。绑定到 _summon_light（节点本身在树）保证 item free 时 tween 一并销毁。
func _play_summon_light_breath(active: bool) -> void:
	if _summon_light == null or not is_instance_valid(_summon_light):
		return
	if _summon_light_tween != null and is_instance_valid(_summon_light_tween):
		_summon_light_tween.kill()
		_summon_light_tween = null
	if not active:
		_summon_light.visible = false
		_summon_light.modulate.a = 1.0
		return
	_summon_light.visible = true
	_summon_light.modulate.a = 1.0
	_summon_light_tween = _summon_light.create_tween()
	_summon_light_tween.set_loops(0)   # 无限循环（源 FadeTo repeat forever）
	_summon_light_tween.tween_property(_summon_light, "modulate:a", 0.3, SUMMON_LIGHT_BREATH_DUR * 0.5).set_trans(Tween.TRANS_SINE)
	_summon_light_tween.tween_property(_summon_light, "modulate:a", 1.0, SUMMON_LIGHT_BREATH_DUR * 0.5).set_trans(Tween.TRANS_SINE)


func _fill_stone_label(sa: int, sn: int) -> void:
	var text: String = "可召唤" if sa >= sn else "%d/%d" % [sa, sn]
	_stone_label.text = text
	var ls: Vector2 = _stone_label.get_minimum_size()
	_stone_label.position = BAR_BG_POS + Vector2(BAR_LABEL_POS.x, BAR_BG_H - BAR_LABEL_POS.y) - ls * 0.5


func _rank() -> int:
	if is_miss:
		return 1
	return (_entry as HeroInstance).rank


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
