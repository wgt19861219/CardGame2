class_name HeroPackageItem
extends Control

## 英雄整行卡片（View 层）— 照源 heroitem.lua baseheroitem + packageheroitem 翻译（P0-1）。
## 结构：bg(package_hero_bg 313×123px ÷CS=244.34×96.00 显示) + ReadheroIcon 头像 bg 局部(7,9) +
##   名字中心(177,72) + 力/敏/智 mark(110,72) + 拥有：6 装备槽 gocha 22×22 (105+22*i,18)；
##   未拥有：灵魂石进度条 + 可召唤光效 + 头像灰化。
## 坐标口径（2026-08-28 根修）：点空间直译 — 全部 offset 已照源 bg 局部坐标直接烘焙进 .tscn
## （源 bg 显示 244.34×96 居中 cell 260×100），废旧"root scale 1/CS + 元素×CS 烘焙"双重变换链
## （旧链 tscn 编辑器所见≠运行所得，且 ×CS 烘焙多处漏 y 翻转/漏 ÷CS：HeadHost 漏翻转致星星压行、
## NameHost 中心 163≠源 177、BAR_BG_W 漏 ÷CS 偏大 1.28×，详见审查报告 2026-08-28）。
## mark 属性图标 icon_str/agi/int（2026-07-18 从 ECCHC 补齐）；name rank 后缀 "+N" 照源
## createHeroNameByInfo（star>0 显示 + 品质色，2026-08-27 核验）。
## cell 260×100（源 refreshHeroList getpos 间距），bg 244.34 宽 < 260 → 相邻列 bg 间隙 15.7 不重叠
## （旧注释"313 溢出 cell 照源视觉重叠"系未÷CS 口径的误判）。head 顶溢出 cell 顶 15=源真容。
##
## Phase A 重构（2026-07-18）：结构静态化进 hero_package_item_content.tscn（instantiate + fill）。
## 两件套接线收口（批 1 Task 9，2026-08-15）：name/suffix/stone 文字走 HeroPackage* variation
## （theme 管）；plusSign/equip 图标节点白名单（动态数据图标，源运行时按槽位状态创建）。
## 两形态（拥有/未拥有）EquipGroup/StoneGroup visible 切换（坑 5）。fill 动态：head/名字/装备图标/plus sign/
## 进度/光效/头像灰化。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/hero_package_item_content.tscn")
# 源 hello.lua:311 setContentScaleFactor(615/480)=1.28125（iPhone 资源档）：cocos sprite contentSize=纹理/CS，position 不变。
# 2026-08-28 根修后仅用于贴图显示尺寸换算（head 104 点直挂），不再做 root 整卡缩放。
const CONTENT_SCALE: float = 1.28125
const CELL_SIZE: Vector2 = Vector2(260.0, 100.0)
const EQUIP_SLOT_COUNT: int = 6
# 源 heroitem.lua:222-228 equipBg setScale(22/w)→22×22；equip setScale(16/w)→16（2026-08-28 根修
# 回归源值；旧 28/20/30 系"root 0.78 缩放下放大补偿"，链拆后视觉回归源 22/16/24 不变）。
const EQUIP_BG_SIZE: float = 22.0
const EQUIP_ICON_SIZE: float = 16.0
const EQUIP_EMPTY_ALPHA: float = 100.0 / 255.0
# 源 bar 满 progress 宽：setTextureRect(150*sa/sn,26)。2026-09-10 贴合根修：源 150 漏考虑父
# barBg scaleX0.93 级联（满宽 139.5 vs 框 147.9 右侧空 8.4，「可召唤」100% 视觉像 94%，源视觉债
# 不再照译）——fill 几何改从 BarBg 节点 offset 推导，满进度四边贴合框（对齐 hero_detail StoneBar
# 满宽=框宽范式）。barBg 自身 204px÷CS×0.93=147.9 宽×26.5 高照旧 .tscn 烘焙。
# 源 label createttf(text,18)@barBg 局部 (80,13)（锚 0.5 中心）：x=80 于未缩放宽 159.2 坐标系≈居中
# 意图（80≈159.2/2，父 scaleX0.93 级联后显示 74.4≈框显示半宽 73.95），故 Godot 版取框中心不直译 80
# （80 直译进 147.9 框偏右 6 点）；y=13 距框底（cocos y 翻转）照译。
const BAR_LABEL_Y_FROM_BOTTOM: float = 13.0
const AVAILABLE_ALPHA: float = 150.0 / 255.0
# 源 heroitem.lua:225/227 plusSign sr + :244 canDealTag tag 资源。
const PLUS_WEAR_RES: String = "res://assets/ui/alpha/HVGA/herodetail-equipadd.png"
const PLUS_CRAFT_RES: String = "res://assets/ui/alpha/HVGA/herodetail_icon_plus_yellow.png"
const DEAL_TAG_RES: String = "res://assets/ui/alpha/HVGA/main_deal_tag.png"
const PLUS_SIGN_TARGET: float = 24.0   # 源 setScale(24/w)（旧 30 系缩放链补偿值）
# summonLight 呼吸动画（源 heroitem.lua:154-167 StoneGroup.SummonLight Tween FadeTo 循环）。
const SUMMON_LIGHT_BREATH_DUR: float = 1.2   # 一次 fade in+out 总时长（秒）
# 源 tag 无 setScale → 显示 21×22px÷CS 宽 16.4（旧 24 系缩放链补偿值）
const DEAL_TAG_TARGET: float = 16.4
const NAME_MAX_W: float = 100.0
const SUFFIX_GAP: float = 2.0   # suffix 与名字末字右缘间距（防加号贴字，2026-08-28 实测加）
const NAME_FALLBACK: String = "?"
# 源 setSpriteGray（resource_manager.lua:871-877）= ccc3(100,100,100)+opacity 180 级联整树
# （2026-08-22 巡检订正：旧 (0.5,0.5,0.5,1.0) 色值与 alpha 均不等价）。
const GRAY_MODULATE: Color = Color(100.0 / 255.0, 100.0 / 255.0, 100.0 / 255.0, 180.0 / 255.0)
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
var _bar_bg: TextureRect = null
var _bar_fill: TextureRect = null
var _bar_fill_src: Texture2D = null   # tscn 原纹理（fill 会换成 AtlasTexture，防二次取宽错读 region）
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
	_content = CONTENT_SCENE.instantiate() as Control
	add_child(_content)
	_cache_nodes()
	_fill_head()
	_fill_name()
	_fill_mark()
	# 红点默认关（tscn TipHost 未标 visible；miss 形态与无可穿槽拥有形态均关），
	# 拥有形态 _fill_equips → _fill_deal_tag 按需置 true。2026-08-18 修复：原置于
	# _fill_equips 之后无条件覆盖，把已点亮的 tag 也压灭（用户实跑反馈"卡片无红点"根因）。
	_tip_host.visible = false
	if is_miss:
		_fill_stone()
	else:
		_fill_equips()
	# 两形态 visible 切换（坑 5）：拥有→EquipGroup / 未拥有→StoneGroup + 头像灰化。
	# TipHost 已从 EquipGroup 拎到根平级（用户决策"红点和装备槽平级"），不跟随 EquipGroup
	# visible 链（miss 形态已在上方默认关）。
	_equip_group.visible = not is_miss
	_stone_group.visible = is_miss


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
	_bar_bg = _content.get_node("%BarBg") as TextureRect
	_bar_fill = _content.get_node("%BarFill") as TextureRect
	_bar_fill_src = _bar_fill.texture
	_stone_label = _content.get_node("%StoneLabel") as Label
	_summon_light = _content.get_node("%SummonLight") as TextureRect
	_equip_slots.clear()
	for i in range(EQUIP_SLOT_COUNT):
		_equip_slots.append(_content.get_node("%EquipSlot" + str(i + 1)) as TextureRect)


# HeadHost 位置 .tscn 固化（bg 局部(7,9) 点空间直译，head 底=cell y89、顶溢出 cell 顶 15=源真容）。
# head 直接 scale 1 挂 host（ReadheroIcon 本按 104 点空间设计，2026-08-28 根修拆掉 ×CS/÷CS 抵消链）。
func _fill_head() -> void:
	if is_miss:
		head = ReadheroIcon.new()
		head.setup({"id": tid, "rank": 1}, cm)
	else:
		head = ReadheroIcon.create_icon_by_hero(_entry as HeroInstance, cm)
	head.position = Vector2.ZERO
	(_content.get_node("%HeadHost") as Control).add_child(head)


# name 与 suffix 两 Label 横向拼接；suffix 按 rank 段着色（fill 动态 override）。
# 名字默认白/阴影走 HeroPackageNameLabel variation（theme 管，禁运行时样式 override）。
func _fill_name() -> void:
	var disp_name: String = cm.get_lstr(_unit_str(&"Display Name", NAME_FALLBACK))
	var rank: int = _rank()
	var star: int = ReadheroHandbook.get_hero_star_by_rank(rank)
	_name_lbl.text = disp_name
	if star > 0:
		_suffix_lbl.text = "+" + str(star)
		_suffix_lbl.add_theme_color_override("font_color", ReadheroHandbook.get_hero_name_color_by_rank(rank))
		_suffix_lbl.visible = true
	else:
		_suffix_lbl.visible = false
	_relayout_name()
	# _build 阶段 item 未挂树（create_from_entry 先 fill 后 _grid.add_child），theme 链断致
	# get_minimum_size 用默认字体测量 ≠ variation 渲染字体，4 字名 suffix 叠末字（2026-08-28 实测）。
	# deferred 一帧后 item 已挂树、theme 可解析，重测修正。
	call_deferred("_relayout_name")


# NameHost 位置/尺寸 .tscn 固化（用户决策，不按源动态算法）。name+suffix 拼接整体在 NameHost 内部居中：
# 算整体宽 total_w，左起点 = (NameHost 宽 - total_w×scale) / 2，suffix 紧贴 name 右侧。
# host_w 用 offset（.tscn 固化值），不读 size（_build 阶段未布局 size 可能为 0）。
func _relayout_name() -> void:
	var name_size: Vector2 = _name_lbl.get_minimum_size()
	var suffix_visible: bool = _suffix_lbl.visible
	var suffix_w: float = _suffix_lbl.get_minimum_size().x if suffix_visible else 0.0
	var total_w: float = name_size.x + suffix_w
	if total_w <= 0.0:
		return
	var scale_val: float = min(1.0, NAME_MAX_W / total_w)
	var host_w: float = _name_host.offset_right - _name_host.offset_left
	var render_w: float = total_w * scale_val
	var start_x: float = (host_w - render_w) * 0.5
	_name_lbl.scale = Vector2(scale_val, scale_val)
	_name_lbl.position = Vector2(start_x, 0.0)
	if suffix_visible:
		_suffix_lbl.scale = Vector2(scale_val, scale_val)
		_suffix_lbl.position = Vector2(start_x + name_size.x * scale_val + SUFFIX_GAP, 0.0)


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
# canDealTag 判据走 EquipdetailQuery.is_slot_ready_to_wear（与快捷栏 heroPackage 红点同一判定
# 拆粒度，源 readhero.lua:734-750 checkEquipableProp 单英雄单槽 vs framework 聚合），
# 任一槽可穿（已持有可穿或可合成可穿）时在 (240,90) 加 main_deal_tag（源 :243-248 isShowTag）。
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
		if EquipdetailQuery.is_slot_ready_to_wear(hero, i, cm, pd):
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
	# 2026-09-10 贴合根修：fill 四边几何从 BarBg offset 推导（_build 未挂树 size 可能 0，用 offset 差，
	# 同 _relayout_name host_w 范式）——满进度右缘=框右缘、高=框高，不再复刻源 setTextureRect(150)
	# 漏父级 scaleX0.93 的右侧 8.4 空隙。
	var frame_w: float = _bar_bg.offset_right - _bar_bg.offset_left
	_bar_fill.offset_left = _bar_bg.offset_left
	_bar_fill.offset_top = _bar_bg.offset_top
	_bar_fill.offset_right = _bar_bg.offset_left + frame_w * ratio
	_bar_fill.offset_bottom = _bar_bg.offset_bottom
	# 纹理照源 setTextureRect(150*sa/sn,26) 截取左段语义（2026-09-10 二轮根修）：stretch SCALE 整条
	# 压缩会把条左端 13px 透明带随 ratio 缩小（9.4×ratio 点 vs 框描边恒 8.7 点），小比例时条内容
	# 起点左移出框描边——「数量小时左边不对齐边框」。AtlasTexture region 与 rect 同步按 ratio 截取，
	# 纹理有效压缩比恒等于框 → 任意比例条内容恒与框描边对齐、纹理无水平压扁。
	var fill_tex := AtlasTexture.new()
	fill_tex.atlas = _bar_fill_src
	fill_tex.region = Rect2(0.0, 0.0, float(_bar_fill_src.get_width()) * ratio,
		float(_bar_fill_src.get_height()))
	_bar_fill.texture = fill_tex
	_fill_stone_label(sa, sn)
	# label 中心化尺寸测量同 _relayout_name 坑：_build 未挂树 theme 链断，get_minimum_size 用
	# 默认字体测量（48）≠ 挂树后 variation 渲染宽（54）→ 中心偏移 3 点；deferred 重定位校正。
	call_deferred("_fill_stone_label", sa, sn)
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
	# 中心 x=框中心 / y=框底上 13（均自 BarBg offset 推导，同 _fill_stone 单一事实源）。
	var center: Vector2 = Vector2(
		(_bar_bg.offset_left + _bar_bg.offset_right) * 0.5,
		_bar_bg.offset_bottom - BAR_LABEL_Y_FROM_BOTTOM)
	_stone_label.position = center - ls * 0.5


func _rank() -> int:
	if is_miss:
		return 1
	return (_entry as HeroInstance).rank


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
