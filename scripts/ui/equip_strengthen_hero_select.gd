class_name EquipStrengthenHeroSelect
extends PopWindow

## 附魔面板换英雄选择浮层（View 层）— 照源 doChangeHero:1720 弹 selectwindow(hero)
## + setHeroIcon:1728-1776 选英雄回调。单机化最小重建：team 英雄横排头像条，
## 点选回调 on_pick(hero)，当前英雄全亮/其余压暗。2026-09-08 根修「附魔锁死船长」补回。

const CELL_SIZE: Vector2 = Vector2(104.0, 148.0)   # 头像 104 + 名字行（余量避星标压字）
const CELL_GAP: float = 12.0
const GRID_COLUMNS: int = 5   # 每行 5 格（5×116=580<800 屏宽）
const MAX_LIST_H: float = 308.0   # 列表限高（2 行 + gap；超出滚动，源 selectwindow 全屏滚动列表等价）
const DIM_ALPHA: float = 0.45
const BG_COLOR: Color = Color(0.0, 0.0, 0.0, 200.0 / 255.0)
const BOARD_RES: String = "res://assets/ui/alpha/HVGA/equipupgrade/equipupgrade_frame.png"
const BOARD_PAD: float = 28.0   # 底板四周留白
const TITLE_KEY: String = "EQUIPSTRENGTHEN.PLEASE_SELECT_HERO"

var _on_pick: Callable = Callable()
var _list: ScrollContainer = null   # 选英雄滚动列表（2026-10-08 #9 拖动滚动宿主）
var _drag_state: Dictionary = {}    # DragScrollHelper 拖拽滚动跨帧基准
var _cell_press: Variant = null     # 格 press 基准（release is_tap 判定，2026-10-08 #9）


## heroes: 待选英雄（全部拥有英雄）；current_inst_id 当前英雄（高亮；-1 未选态全亮）。
func setup_panel(heroes: Array, current_inst_id: int, p_cm: Variant, on_pick: Callable) -> void:
	_on_pick = on_pick
	play_open_sfx = true
	setup()
	shade_layer.color = BG_COLOR
	_build_row(heroes, current_inst_id, p_cm)
	play_scale_in()


func _build_row(heroes: Array, current_inst_id: int, p_cm: Variant) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := Label.new()
	title.text = String(p_cm.get_lstr(TITLE_KEY))
	title.theme_type_variation = &"EquipStrenMaterialLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # 撑满行宽真居中
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	# 5 列网格 + 限高滚动（全英雄 15+ 个时 3 行+ 溢出屏幕顶掉标题，2026-09-08 四轮；
	# 源 selectwindow ofhero 即全屏滚动列表）
	var row := GridContainer.new()
	row.columns = GRID_COLUMNS
	row.add_theme_constant_override("h_separation", int(CELL_GAP))
	row.add_theme_constant_override("v_separation", int(CELL_GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var no_current: bool = current_inst_id < 0
	for h in heroes:
		row.add_child(_make_cell(h, no_current or current_inst_id == int(h.inst_id), p_cm))
	var grid_min: Vector2 = row.get_combined_minimum_size()
	var list := ScrollContainer.new()
	list.custom_minimum_size = Vector2(grid_min.x, minf(grid_min.y, MAX_LIST_H))
	list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(list)
	list.add_child(row)
	_list = list
	# 手动居中（container 非 Container 不驱动 anchor 布局）：底板包 box，整体落屏幕中心
	var box_min: Vector2 = box.get_combined_minimum_size()
	var board := NinePatchRect.new()
	board.texture = load(BOARD_RES) as Texture2D
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(board)
	container.add_child(box)
	board.position = Vector2(400.0, 240.0) - box_min * 0.5 - Vector2(BOARD_PAD, BOARD_PAD)
	board.size = box_min + Vector2(BOARD_PAD, BOARD_PAD) * 2.0
	box.position = Vector2(400.0, 240.0) - box_min * 0.5


# 单格：ReadheroIcon 头像 + 名字，点击回调 on_pick；当前英雄全亮、其余压暗（源列表选中态等价）。
# current_inst_id<0 = 未选英雄态（源 nohead），全部正常亮度。
func _make_cell(h: HeroInstance, is_current: bool, p_cm: Variant) -> Control:
	var cell := VBoxContainer.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_theme_constant_override("separation", 6)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	var head_slot := Control.new()   # Node2D 头像不参与 VBox 布局，Control 占位槽撑出 104 高
	head_slot.custom_minimum_size = Vector2(104.0, 104.0)
	head_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := ReadheroIcon.new()
	head.setup({"id": int(h.tid), "rank": int(h.rank), "stars": int(h.stars)}, p_cm)
	head_slot.add_child(head)
	cell.add_child(head_slot)
	var name_lbl := Label.new()
	name_lbl.text = HeroDetailFills.get_display_name(h, p_cm)
	name_lbl.theme_type_variation = &"EatexpHeroNameLabel"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # 撑满格宽真居中
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(name_lbl)
	cell.modulate.a = 1.0 if is_current else DIM_ALPHA
	var picked: HeroInstance = h
	cell.gui_input.connect(func(ev: InputEvent) -> void: _on_cell_input(ev, picked))
	return cell


# 列表按住拖动滚动（DragScrollHelper.handle_input，daily_login 2026-10-06 同款接线；
# 群反馈 #9「装备附魔不能上下拖动选择角色」——ScrollContainer 只有滚轮无拖拽，
# 触屏/鼠标按住拖动零响应，英雄 3 行+ 时下半列表选不到）。
func _input(event: InputEvent) -> void:
	DragScrollHelper.handle_input(_list, event, _drag_state)


# 格输入：press 记基准 → release 位移 <8px 才选中（DragScrollHelper.is_tap）。
# 旧版按下即选——接拖动滚动后按住拖动会误触选中关窗，2026-10-08 与 #9 一并根修
# （package_panel/hero_package_panel 同范式；格 gui_input 收不到格外的 release，天然安全）。
func _on_cell_input(event: InputEvent, picked: HeroInstance) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_cell_press = mb.global_position
		return
	var tap_pick: bool = DragScrollHelper.is_tap(_cell_press, mb.global_position)
	_cell_press = null
	if not tap_pick:
		return
	AudioPlayer.play_sfx("common_close_popup_window")
	remove_window()
	if _on_pick.is_valid():
		_on_pick.call(picked)
