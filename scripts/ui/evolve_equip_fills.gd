class_name EvolveEquipFills
extends RefCounted

## 装备进阶列表 fill（源 ui/herodetail/evolveequip.lua 234 行直译）。
## 从 hero.rank 到 RANK_LIST_MAX(23) 每档一行：rank 名 + 6 装备图标；
## eid=0 → lock 占位（源 getUnknownIcon）；点图标 → EquipCraftPanel(context="handbook")。
## 静态结构在 evolve_equip_content.tscn（底板/标题/ScrollContainer）；行与图标数据驱动动态建
## （照源 draglist createEquipInfo 行；源表断档 `if not rankEquip then break`）。

# 源 parameter.lua:43 unit_max_rank=23（列表路线全档；玩家进阶上限 22 见 HeroManager.MAX_EQUIP_RANK）。
const RANK_LIST_MAX: int = 23
const SLOT_COUNT: int = 6
# 源 itemHeight=200 + createEquipList 行距 (itemHeight+8)（VBox separation 补 8）。
const ROW_SIZE: Vector2 = Vector2(254.0, 200.0)
# 源 iconBg S9 herodetail_skill_bg_1.png capInsets CCRectMake(15,15,15,15)（cocos 点坐标，
# 纹理点尺寸 60/CS 下角 cap≈19 纹素恰好包住四角铆钉圆珠 (9..18)²）；Godot patch 系纹素制，
# 四边 19 完整保护圆珠（PIL+视觉双实测 2026-08-30；旧值 15 纹素切进圆珠外缘致四角变形）。
const ROW_BG_RES: String = "res://assets/ui/alpha/HVGA/herodetail_skill_bg_1.png"
const ROW_BG_PATCH: int = 19
# 源图标定位（iconBg 局部 cocos→Godot y 翻转，左上角制）：x=50+(j-1)*80-36、y=200-(126-i*80)-36；
# eid=0 lock 行源 y=123（:93）→ Godot 再 +3。第二排 y 源值 118 观感挤（上 38 下 10 不对称），
# 2026-08-30 用户两轮反馈逐步上移：118→108（下 20）→98（下 30，受控偏离源网格）。
const ICON_POSITIONS: Array[Vector2] = [
	Vector2(14, 38), Vector2(94, 38), Vector2(174, 38),
	Vector2(14, 98), Vector2(94, 98), Vector2(174, 98),
]
const LOCK_Y_OFFSET: float = 3.0
# lock 占位图显示尺寸：源 readequip.lua:604-629 纹理 86px，cocos 显示=点尺寸 86÷CS=67.1
# （嵌白框 73.4 内，源 getCenterPos 口径）；未 ÷CS 的 86 会盖住白框（2026-08-30 实锤）。
const LOCK_DISPLAY_SIZE: float = 86.0 / 1.28125
# 源 rank Label：ccp(10,-20)@行根(anchor 0.5,0.5) → iconBg 局部中心 (135,20)。
const RANK_LABEL_RECT: Rect2 = Rect2(70, 8, 130, 24)
# 源 param.lua:86-109 equip_rank_info + fontconfigs.lua:333-358 equip_*（size 18 覆写 :99 setLabelFontInfo）。
const RANK_INFO: Array[Dictionary] = [
	{"name": "White", "color": Color(1.0, 1.0, 1.0)},
	{"name": "Green", "color": Color(119.0 / 255.0, 255.0 / 255.0, 92.0 / 255.0)},
	{"name": "Green+1", "color": Color(119.0 / 255.0, 255.0 / 255.0, 92.0 / 255.0)},
	{"name": "Blue", "color": Color(81.0 / 255.0, 224.0 / 255.0, 251.0 / 255.0)},
	{"name": "Blue+1", "color": Color(81.0 / 255.0, 224.0 / 255.0, 251.0 / 255.0)},
	{"name": "Blue+2", "color": Color(81.0 / 255.0, 224.0 / 255.0, 251.0 / 255.0)},
	{"name": "Purple", "color": Color(234.0 / 255.0, 92.0 / 255.0, 255.0 / 255.0)},
	{"name": "Purple+1", "color": Color(234.0 / 255.0, 92.0 / 255.0, 255.0 / 255.0)},
	{"name": "Purple+2", "color": Color(234.0 / 255.0, 92.0 / 255.0, 255.0 / 255.0)},
	{"name": "Purple+3", "color": Color(234.0 / 255.0, 92.0 / 255.0, 255.0 / 255.0)},
	{"name": "Purple+4", "color": Color(234.0 / 255.0, 92.0 / 255.0, 255.0 / 255.0)},
	{"name": "Orange", "color": Color(255.0 / 255.0, 134.0 / 255.0, 92.0 / 255.0)},
	{"name": "Orange+1", "color": Color(255.0 / 255.0, 134.0 / 255.0, 92.0 / 255.0)},
	{"name": "Orange+2", "color": Color(255.0 / 255.0, 134.0 / 255.0, 92.0 / 255.0)},
	{"name": "Orange+3", "color": Color(255.0 / 255.0, 134.0 / 255.0, 92.0 / 255.0)},
	{"name": "Orange+4", "color": Color(255.0 / 255.0, 134.0 / 255.0, 92.0 / 255.0)},
	{"name": "Orange+5", "color": Color(255.0 / 255.0, 134.0 / 255.0, 92.0 / 255.0)},
	{"name": "Red", "color": Color(255.0 / 255.0, 60.0 / 255.0, 60.0 / 255.0)},
	{"name": "Red+1", "color": Color(255.0 / 255.0, 60.0 / 255.0, 60.0 / 255.0)},
	{"name": "Red+2", "color": Color(255.0 / 255.0, 60.0 / 255.0, 60.0 / 255.0)},
	{"name": "Red+3", "color": Color(255.0 / 255.0, 60.0 / 255.0, 60.0 / 255.0)},
	{"name": "Red+4", "color": Color(255.0 / 255.0, 60.0 / 255.0, 60.0 / 255.0)},
	{"name": "Red+5", "color": Color(255.0 / 255.0, 60.0 / 255.0, 60.0 / 255.0)},
]


# createEquipList（evolveequip.lua:106-121）：rank 从 hero.rank 起每档一行，表断档即停。
# 重复调用（_rebuild_content 恢复 equip tab）先清旧行。
static func fill_equip_list(view: Control, hero: HeroInstance, cm: Variant, on_open: Callable) -> void:
	if view == null or hero == null:
		return
	var scroll := view.get_node_or_null("%EquipScroll") as ScrollContainer
	var row_box: VBoxContainer = view.get_node_or_null("%RowContainer") as VBoxContainer
	if scroll == null or row_box == null:
		return
	_hide_scroll_bar(scroll)
	_attach_drag_host(scroll)
	for c in row_box.get_children():
		c.queue_free()
	var hero_equips: Dictionary = cm.get_raw_table(&"Hero_equip").get(str(hero.tid), {}) if cm != null else {}
	for rank in range(hero.rank, RANK_LIST_MAX + 1):
		var rank_equip: Dictionary = hero_equips.get(str(rank), {})
		# 源 getAllEquip:18 `if not rankEquip then break end`（表断档停，非跳过空行）。
		if rank_equip.is_empty():
			break
		row_box.add_child(_build_rank_row(rank, rank_equip, cm, on_open))


# createEquipInfo（:29-104）：S9 行背景 + rank Label + 6 图标（eid=0 lock 占位不接点击）。
static func _build_rank_row(rank: int, rank_equip: Dictionary, cm: Variant, on_open: Callable) -> Control:
	var row := NinePatchRect.new()
	row.texture = load(ROW_BG_RES) as Texture2D
	row.patch_margin_left = ROW_BG_PATCH
	row.patch_margin_top = ROW_BG_PATCH
	row.patch_margin_right = ROW_BG_PATCH
	row.patch_margin_bottom = ROW_BG_PATCH
	row.custom_minimum_size = ROW_SIZE
	row.size = ROW_SIZE
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info: Dictionary = RANK_INFO[rank - 1] if rank >= 1 and rank <= RANK_INFO.size() else {}
	var rank_label := Label.new()
	rank_label.text = String(info.get("name", "Rank %d" % rank))
	rank_label.position = RANK_LABEL_RECT.position
	rank_label.size = RANK_LABEL_RECT.size
	rank_label.add_theme_font_size_override("font_size", 18)
	rank_label.add_theme_color_override("font_color", info.get("color", Color.WHITE))
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rank_label)
	for i in SLOT_COUNT:
		var eid: int = int(rank_equip.get("Equip" + str(i + 1) + " ID", 0))
		# eid>0 createIcon(equipId)（amount=1 不画数量角标）；eid=0 getUnknownIcon（复用装备槽
		# _create_lock_icon，其内部按 FRAME_TEX_SIZE 94×95 撑容器供槽位锚定——列表网格须还原
		# 72 容器，否则 lock 较普通 icon 偏右下错位，2026-08-30 用户反馈）。
		var icon: Control
		if eid > 0:
			icon = ReadequipIcon.create_icon(eid, 1, cm)
		else:
			# 源 getUnknownIcon（readequip.lua:604-629）：白框+gocha+lock 居中。不复用装备槽
			# _create_lock_icon（其内部撑容器 94×95 且 lock 86 纹素未 ÷CS——大图盖白框+容器错位，
			# 2026-08-30 用户反馈）；列表自制：lock 显示 86÷CS=67.1 嵌框内（cocos getContentSize 点尺寸口径）。
			icon = ReadequipIcon.create_icon(0, 1, cm)
			var lock := TextureRect.new()
			lock.texture = load(HeroDetailEquipSlots.LOCK_ICON_RES) as Texture2D
			lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			lock.set_anchors_preset(Control.PRESET_CENTER)
			var half: float = LOCK_DISPLAY_SIZE * 0.5
			lock.offset_left = -half
			lock.offset_right = half
			lock.offset_top = -half - 2.0   # 源 ccp(0,2) 上偏 → Godot y 减 2
			lock.offset_bottom = half - 2.0
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.add_child(lock)
		icon.position = ICON_POSITIONS[i] + (Vector2(0, LOCK_Y_OFFSET) if eid == 0 else Vector2.ZERO)
		if eid > 0:
			icon.gui_input.connect(_make_icon_handler(eid, on_open, icon))
		row.add_child(icon)
	return row


# 点图标（gui_input）→ on_open(eid) → panel 开 EquipCraftPanel（源 :77-90 btRegisterButtonClick
# 完整 click 语义）。拖拽列表不误触：press 记 meta → release 位移 <8px 才触发
# （DragScrollHelper.is_tap，ranklist 修复轮四同范式）；meta 记基准避 lambda 捕获改写坑。
static func _make_icon_handler(eid: int, on_open: Callable, icon: Control) -> Callable:
	return func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb := ev as InputEventMouseButton
			if mb.pressed:
				icon.set_meta(&"press_pos", mb.global_position)
			elif DragScrollHelper.is_tap(icon.get_meta(&"press_pos", null), mb.global_position):
				icon.set_meta(&"press_pos", null)
				on_open.call(eid)
			else:
				icon.set_meta(&"press_pos", null)


# 拖拽滚动宿主：Godot 4 ScrollContainer 桌面仅滚轮无鼠标拖拽（2026-08-29 诊断实测 drag 不动），
# DragScrollHelper 补齐源 draglist 手势语义。挂 EquipScroll 常驻（重复 fill 不重挂）。
static func _attach_drag_host(scroll: ScrollContainer) -> void:
	if scroll.get_node_or_null("__DragHost") != null:
		return
	var host := DragHost.new()
	host.name = "__DragHost"
	host.scroll = scroll
	scroll.add_child(host)
	host.set_process_input(true)   # inner class _input 自动检测不稳（2026-08-29 诊断实测），显式启用


class DragHost:
	extends Node
	var scroll: ScrollContainer = null
	var state: Dictionary = {}

	func _input(event: InputEvent) -> void:
		DragScrollHelper.handle_input(scroll, event, state)


# 隐藏 EquipScroll 垂直滚动条视觉（StyleBoxEmpty 覆盖，同 detail tab AttribListHost 做法——
# hero_detail_panel.gd 引擎缺口例外：内置滚动条样式不可经 theme 关）。
static func _hide_scroll_bar(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	var bar: Control = scroll.get_node_or_null("_v_scroll") as Control
	if bar == null:
		return
	var empty := StyleBoxEmpty.new()
	bar.add_theme_stylebox_override("scroll", empty)
	bar.add_theme_stylebox_override("grabber", empty)
	bar.add_theme_stylebox_override("grabber_highlight", empty)
	bar.add_theme_stylebox_override("grabber_pressed", empty)
