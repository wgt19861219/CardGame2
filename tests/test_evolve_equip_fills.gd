extends GutTest
## EvolveEquipFills 装备进阶列表 fill 单测 + hero_detail_content.tscn 装备 tab 守卫。
## 覆盖：fill_equip_list 建行数（表内从 hero.rank 起连续档）、行结构（S9 行根 + 1 rank Label
## + 6 图标）、rank Label 文本/位置、icon 位置（含 eid=0 lock +3 偏移）、重复 fill 清旧行、
## tscn 守卫（%EquipAdvanceBtn/%TabEquipView 存在 + 止态）。
## gap 诚实标注（同 test_hero_detail_equip_slots）：gui_input 点击触发无 headless 单测
## （GUT InputEventMouseButton lambda 限制），靠代码审查 + 运行时行为保证。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _first_hero_tid() -> int:
	var table: Dictionary = cm.get_raw_table(&"Hero_equip")
	return int(table.keys()[0])


# 期望行数独立重算（源 getAllEquip 语义：从 from_rank 起连续非空档，断档即停）
func _expected_rows(tid: int, from_rank: int) -> int:
	var equips: Dictionary = cm.get_raw_table(&"Hero_equip").get(str(tid), {})
	var count: int = 0
	for rank in range(from_rank, EvolveEquipFills.RANK_LIST_MAX + 1):
		if equips.get(str(rank), {}).is_empty():
			break
		count += 1
	return count


func _make_view() -> Control:
	var scene: PackedScene = load("res://scenes/ui/evolve_equip_content.tscn")
	return scene.instantiate() as Control


# 行数=表内从 hero.rank(默认1) 起连续档数；行根 NinePatchRect（源 S9 iconBg 254×200）。
func test_fill_equip_list_builds_rows() -> void:
	var view: Control = _make_view()
	add_child_autofree(view)
	var tid: int = _first_hero_tid()
	var hero := HeroInstance.new(tid)
	EvolveEquipFills.fill_equip_list(view, hero, cm, func(_eid: int) -> void: pass)
	var row_box: VBoxContainer = view.get_node("%RowContainer") as VBoxContainer
	assert_eq(row_box.get_child_count(), _expected_rows(tid, hero.rank), "行数=表内连续档数")
	var first: NinePatchRect = row_box.get_child(0) as NinePatchRect
	assert_not_null(first, "行根为 NinePatchRect")
	assert_eq(first.custom_minimum_size, EvolveEquipFills.ROW_SIZE, "行尺寸 254×200（源 scaleSize）")
	assert_eq(first.patch_margin_left, EvolveEquipFills.ROW_BG_PATCH, "S9 四侧 cap 15（源 capInsets）")
	# 拖拽滚动宿主（DragScrollHelper 补桌面拖拽；重复 fill 不重挂）
	var scroll: ScrollContainer = view.get_node("%EquipScroll") as ScrollContainer
	assert_not_null(scroll.get_node_or_null("__DragHost"), "拖拽宿主已挂 EquipScroll")
	EvolveEquipFills.fill_equip_list(view, hero, cm, func(_eid: int) -> void: pass)
	assert_eq(scroll.get_children().filter(func(c: Node) -> bool: return c.name == "__DragHost").size(), 1, "二次 fill 不重挂宿主")


# 每行 1 rank Label + 6 图标；rank 文本/颜色取 RANK_INFO[rank-1]（源 equip_rank_info）。
func test_row_structure_rank_label() -> void:
	var view: Control = _make_view()
	add_child_autofree(view)
	var tid: int = _first_hero_tid()
	var hero := HeroInstance.new(tid)
	EvolveEquipFills.fill_equip_list(view, hero, cm, func(_eid: int) -> void: pass)
	var row_box: VBoxContainer = view.get_node("%RowContainer") as VBoxContainer
	var first: NinePatchRect = row_box.get_child(0) as NinePatchRect
	var labels: int = 0
	var icons: int = 0
	for c in first.get_children():
		if c is Label:
			labels += 1
		else:
			icons += 1
	assert_eq(labels, 1, "每行恰 1 个 rank Label")
	assert_eq(icons, EvolveEquipFills.SLOT_COUNT, "每行 6 个装备图标（eid=0 为 lock 占位）")
	var rank_label: Label = first.get_child(0) as Label
	var expect_info: Dictionary = EvolveEquipFills.RANK_INFO[hero.rank - 1]
	assert_eq(rank_label.text, String(expect_info["name"]), "rank 文本=equip_rank_info 名")
	assert_eq(rank_label.get_theme_color("font_color"), expect_info["color"], "rank 颜色=equip_* 字体色")
	assert_eq(rank_label.position, EvolveEquipFills.RANK_LABEL_RECT.position, "rank Label 行顶部居中")


# icon 位置照源网格（x=50+(j-1)*80、y=126-i*80 翻转）；eid=0 lock 再 +3（源 :93 y=123）。
func test_icon_grid_positions() -> void:
	var view: Control = _make_view()
	add_child_autofree(view)
	var tid: int = _first_hero_tid()
	var hero := HeroInstance.new(tid)
	EvolveEquipFills.fill_equip_list(view, hero, cm, func(_eid: int) -> void: pass)
	var row_box: VBoxContainer = view.get_node("%RowContainer") as VBoxContainer
	var first: NinePatchRect = row_box.get_child(0) as NinePatchRect
	var rank_equip: Dictionary = cm.get_raw_table(&"Hero_equip").get(str(tid), {}).get(str(hero.rank), {})
	var icon_idx: int = 0
	for c in first.get_children():
		if c is Label:
			continue
		var eid: int = int(rank_equip.get("Equip" + str(icon_idx + 1) + " ID", 0))
		var expect: Vector2 = EvolveEquipFills.ICON_POSITIONS[icon_idx]
		if eid == 0:
			expect += Vector2(0, EvolveEquipFills.LOCK_Y_OFFSET)
			assert_eq((c as Control).size, Vector2(ReadequipIcon.ICON_SIZE, ReadequipIcon.ICON_SIZE),
				"lock 容器还原 72（_create_lock_icon 内部 94×95 撑容器须复位，防偏右下错位）")
		assert_eq((c as Control).position, expect, "icon %d 位置照源网格（eid=%d）" % [icon_idx, eid])
		icon_idx += 1


# 重复 fill（_rebuild_content 恢复 equip tab）先清旧行不叠加。
func test_fill_equip_list_clears_old_rows() -> void:
	var view: Control = _make_view()
	add_child_autofree(view)
	var tid: int = _first_hero_tid()
	var hero := HeroInstance.new(tid)
	EvolveEquipFills.fill_equip_list(view, hero, cm, func(_eid: int) -> void: pass)
	EvolveEquipFills.fill_equip_list(view, hero, cm, func(_eid: int) -> void: pass)
	await get_tree().process_frame   # 清行用 queue_free（延迟释放），等一帧再计数
	var row_box: VBoxContainer = view.get_node("%RowContainer") as VBoxContainer
	assert_eq(row_box.get_child_count(), _expected_rows(tid, hero.rank), "二次 fill 不叠加")


# hero_detail_content.tscn 守卫：EquipAdvanceBtn + TabEquipView 存在且止态正确。
func test_hero_detail_content_has_equip_tab_nodes() -> void:
	var scene: PackedScene = load("res://scenes/ui/hero_detail_content.tscn")
	var content: Control = scene.instantiate() as Control
	add_child_autofree(content)
	var btn: Control = content.get_node_or_null("%EquipAdvanceBtn")
	assert_not_null(btn, "左上装备进阶按钮存在")
	var equip_view: Control = content.get_node_or_null("%TabEquipView") as Control
	assert_not_null(equip_view, "TabEquipView 实例存在")
	assert_false(equip_view.visible, "equip tab 止态隐藏")
	assert_eq(equip_view.offset_left, -200.0, "equip tab 止态 -200（源 pop 终点）")


# icon 点击位移判别：静点（press/release 同点）触发 on_open；拖动（位移>8px）不触发
# （gui_input.emit 走信号引擎路径，规避 GUT 直调 lambda 坑；真实事件分发由实机裁决）。
func test_icon_tap_vs_drag() -> void:
	var view: Control = _make_view()
	add_child_autofree(view)
	var tid: int = _first_hero_tid()
	var hero := HeroInstance.new(tid)
	var opened: Array = []
	EvolveEquipFills.fill_equip_list(view, hero, cm, func(eid: int) -> void: opened.append(eid))
	var row_box: VBoxContainer = view.get_node("%RowContainer") as VBoxContainer
	var first: Control = row_box.get_child(0) as Control
	var icon: Control = null
	for ch in first.get_children():
		if not (ch is Label) and (ch as Control).gui_input.get_connections().size() > 0:
			icon = ch as Control   # 取第一个 eid>0 已连接的 icon（eid=0 lock 无连接）
			break
	assert_not_null(icon, "存在可点击装备图标（eid>0）")
	var ic: Vector2 = icon.get_global_rect().get_center()
	# 静点：press + release 同点
	icon.gui_input.emit(_mb(ic, true))
	icon.gui_input.emit(_mb(ic, false))
	assert_eq(opened.size(), 1, "静点触发 on_open（完整 click 语义）")
	# 拖动：press 原点 + release 位移 100px（is_tap 阈值 8）
	icon.gui_input.emit(_mb(ic, true))
	icon.gui_input.emit(_mb(ic + Vector2(0, 100), false))
	assert_eq(opened.size(), 1, "位移 100 的拖动不触发（拖动≠点击）")


# DragHost 拖拽集成：press → motion → scroll_vertical 变化（方法直调无 lambda 坑；
# 真实 _input 分发由实机裁决）。
func test_drag_host_scrolls() -> void:
	var view: Control = _make_view()
	add_child_autofree(view)
	var tid: int = _first_hero_tid()
	var hero := HeroInstance.new(tid)
	EvolveEquipFills.fill_equip_list(view, hero, cm, func(_eid: int) -> void: pass)
	await get_tree().process_frame   # Container 布局 deferred：等一帧 VBox size 就绪（max>0）
	var scroll: ScrollContainer = view.get_node("%EquipScroll") as ScrollContainer
	var host: Node = scroll.get_node("__DragHost")
	assert_not_null(host, "拖拽宿主存在")
	var c: Vector2 = scroll.get_global_rect().get_center()
	var evp := InputEventMouseButton.new()
	evp.button_index = MOUSE_BUTTON_LEFT
	evp.pressed = true
	evp.position = c
	evp.global_position = c
	host._input(evp)
	var evm := InputEventMouseMotion.new()
	evm.position = c - Vector2(0, 100)
	evm.global_position = evm.position
	evm.button_mask = MOUSE_BUTTON_MASK_LEFT
	host._input(evm)
	assert_gt(scroll.scroll_vertical, 0, "向上拖 100px 后 sv>0（内容下移，sv=start-dy=100）")


func _mb(pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	return ev
