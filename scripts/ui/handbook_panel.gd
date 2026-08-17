class_name HandbookPanel
extends PopWindow

## 图鉴面板(View 层)— 照源 ui/handbook.lua(719 行)重建装备图鉴。
## 左右双列网格 12 格/页 + 装备图标(已解锁/锁定态)+ 翻页箭头 + book 背景三层 +
## 页面分类标题 + 翻页/切tag 淡入淡出动画 + 横向滑动翻页 + 点击缩放反馈。
## 数据源 EquipmentClassifier.classify_equip(照源 readequip.classifyEquip :481-537)。
## 静态节点(背景三层/12 tag+label/箭头/back/pageLabel/pageTitle)进 handbook_content.tscn
## (preload instantiate + get_node("%..")),panel 管状态 + 切 tag + 翻页 + 装备网格动态挂。
## 坐标源 cocos(800×480 左下) → Godot(960×640 左上):to_godot(cx,cy)=(cx×SC+OX, 640-cy×SC)
## (源 pushScene 全屏缩放,SC=640/480=1.3333)。
##
## 2026-07-20 照源补全 5 项缺口:
## #1 点已解锁装备弹 EquipboardPanel(doSelectElement :105-109 equipcraft context=handbook)
## #2 locked 装备点击 Toast(doEquipTouch :132 NOT_YET_UNLOCKED)
## #3 翻页/切tag FadeOut/In 0.2s(createPage :555-598 pageLayer CCFadeOut→CCFadeIn)
## #4 页面分类标题(setPageTitle :475 tagText.title,ccp(400,431))
## #5 横向滑动翻页(doChangePageTouch :143-172)+ 装备/箭头 began setScale 0.95(doEquipTouch :120
##    /doArrowTouch :250)+ 箭头 0.5s 防抖(doArrowTouch :246 clickTime)
##
## 2026-08-17 批4 Task 5 两件套改造:原 handbook 工厂类退役(文件已删),工厂/fill/常量全并入本类
## (合并后 code 311 行 < View 400 门槛,无需 fills helper);运行时主题 override 5 处清零
## (装备名 label 4 处 + tag label 1 处,转 HandbookEquipNameLabel/HandbookEntryLabel 两态 variation);
## 装备 cell 显示尺寸按批4口径手算 纹理÷CS(原 TexDisplaySize 无条目不÷CS 致偏大 1.28×);
## 补源 :445-447 装备名 label 宽>114 等比缩放。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/handbook_content.tscn")
# tag 按钮 index(1-12) → list key。1=ALL(源 tagTextIndex :26-39)。
const TAG_KEYS: Array[String] = ["ALL", "STR", "AGI", "INT", "HP", "AD", "AP", "ARM", "CRIT", "HPS", "MPS", "HEAL"]
const PER_PAGE: int = 12
# 网格整体上移让 slot1 bg 顶贴近 PageTitle"全部"标题底(.tscn y=84)。correct(=0) 间距 9px
# (源布局),用户要求上移:LIFT=9 → slot1 bg 顶 y=84(贴标题底,间距 0,最大不重叠上移)。
# 偏离源(源间距 9)。>0 往上,每 +1 网格顶上移 1px;>9 网格与标题重叠。
const GRID_LIFT_Y: float = 9.0

# ── 2026-07-20 补全 5 项常量(照源 handbook.lua)──
const LSTR_NOT_UNLOCKED: String = "HANDBOOK.NOT_YET_UNLOCKED_PLEASE_UPGRADE_YOURSELF"   # #2 源 :132
const FADE_TIME: float = 0.2                # #3 源 createPage CCFadeOut/In 0.2
const SWIPE_THRESHOLD: float = 100.0        # #5 源 :11 pageChangeDistanceThreshold
const SWIPE_MAX_TIME: float = 1.0           # #5 源 :12 pageChangeGapThreshold(getMillionTime,<1s 有效)
const PRESS_SCALE: float = 0.95             # #5 源 doEquipTouch:120/doArrowTouch:250 began setScale
const ARROW_CLICK_GAP: float = 0.5          # #5 源 doArrowTouch:246 canClick>0.5

# ── 网格/贴图常量(源 :13-22 + createIcon :423-452,自 builder 迁入)──
# (源 pushScene),不用 popup 居中(cx+80),改全屏缩放铺满. SC=640/480,OFFSET_X=400×SC-480(横向居中).
const SCREEN_SCALE: float = 1.3333
const OFFSET_X: float = -53.33
const BASE_Y: float = 640.0
const LEFT_FIRST: Vector2 = Vector2(196.0, 356.0)
const RIGHT_FIRST: Vector2 = Vector2(476.0, 356.0)
const GAP: Vector2 = Vector2(130.0, 115.0)
const EQUIP_ICON_POS: Vector2 = Vector2(57.0, 64.0)
const EQUIP_NAME_POS: Vector2 = Vector2(57.0, 17.0)
# 源 :445 label:getContentSize().width > 114 → setScale(114/width) 等比缩(2026-08-17 补)
const NAME_CLAMP_WIDTH: float = 114.0
# 贴图显示尺寸 = 纹理原始像素 ÷ CS(1.28125)(批4 口径:TextureConfig 无 handbook 条目;
# PIL 实测 handbook_equip_bg 148×139[非正方形]、handbook_icon_bg/lock 86×86)。
const CONTENT_SCALE: float = 1.28125
const EQUIP_BG_SIZE: Vector2 = Vector2(148.0 / CONTENT_SCALE, 139.0 / CONTENT_SCALE)
const ICON_BG_SIZE: Vector2 = Vector2(86.0 / CONTENT_SCALE, 86.0 / CONTENT_SCALE)
# tag 资源路径(选中态切 texture 用,.tscn 已设 normal/pressed,选中需切 normal)
const TAG_LEFT: String = "res://assets/ui/alpha/HVGA/handbook_left.png"
const TAG_LEFT_SEL: String = "res://assets/ui/alpha/HVGA/handbook_left_select.png"
const TAG_RIGHT: String = "res://assets/ui/alpha/HVGA/handbook_right.png"
const TAG_RIGHT_SEL: String = "res://assets/ui/alpha/HVGA/handbook_right_select.png"
# 装备 cell 资源(动态建)
const EQUIP_BG_RES: String = "res://assets/ui/alpha/HVGA/handbook_equip_bg.png"
const ICON_BG_RES: String = "res://assets/ui/alpha/HVGA/handbook_icon_bg.png"
const ICON_LOCK_RES: String = "res://assets/ui/alpha/HVGA/handbook_icon_lock.png"
# 12 tag LSTR key(源 tagText :41-52,tagTextIndex :26-39 顺序)。1-6 左 / 7-12 右。
const TAG_LSTR: Array[String] = [
	"BATTLEPREPARE.WHOLE", "HERO_EQUIP.STRENGTH", "HERO_EQUIP.AGILITY", "HERO_EQUIP.INTELLIGENCE",
	"HANDBOOK.HEALTH", "HANDBOOK.PHYSICAL_ATTACK", "HANDBOOK.MAGIC_ATTACK", "HANDBOOK.ARMOR",
	"HANDBOOK.CRIT", "HANDBOOK.HEALTH_SUPPLY", "HANDBOOK.MAGIC_SUPPLY", "SKILL.HEAL",
]
# 12 tag 分类标题 LSTR(源 tagText.title1-12 :53-64,切 tag 时 pageTitle 显示)。与 TAG_LSTR 同序。
const TITLE_LSTR: Array[String] = [
	"HANDBOOK.WHOLE", "HANDBOOK.POWER", "HANDBOOK.AGILITY", "HANDBOOK.INTELLIGENCE",
	"BASERES.MAXIMUM_HP", "BASERES.PHYSICAL_ATTACK", "BASERES.MAGIC_STRENGTH", "BASERES.PHYSICAL_ARMOR",
	"HANDBOOK.PHYSICAL_CRIT_MAGIC_CRIT", "BASERES.RECOVER_HP_AFTER_EACH_BATTLE",
	"BASERES.REPLENISH_ENERGY_AFTER_EACH_BATTLE", "BASERES.IMPROVE_THERAPEUTIC_SKILL_EFFECT",
]
const TAG_COUNT: int = 12

var _player: PlayerData
var _cm: Variant = null
var _tabs_data: Dictionary = {}      # classify_equip 结果 {key: [{id,name,lr}]}
var _tag_ui: Dictionary = {}         # {index(1-12): {button, label}}
var _current_tag: int = 1            # 默认 ALL(源 create :714 createPage("ALL",1))
var _page: int = 1
var _page_amount: int = 1
var _grid_layer: Control = null      # .tscn %EquipGridHost(常驻,翻页/tag 切换时清子节点重建)
var _page_label: Label = null
var _page_title: Label = null        # #4 页面分类标题(源 pageTitle)
var _press_pos: Vector2 = Vector2.ZERO  # #5 cell 按下起点(doChangePageTouch began pos)
var _press_time: float = 0.0            # #5 cell 按下时间
var _is_changing_page: bool = false     # #5 滑动翻页标志(抑制同次 click,源 isChangePage)
var _last_arrow_click: float = -1.0     # #5 箭头防抖(源 clickTime)
var _is_fading: bool = false            # #3 翻页动画进行中(防动画期间重入)


func setup_panel(p_player: PlayerData) -> void:
	transparent_shade = true   # T4：原 shade 透明 hack 上收基类
	_player = p_player
	_cm = p_player.cm
	setup()
	# handbook 照源是全屏场景(源 handbook.lua:618 base=basescene + bg.jpg,.tscn FrameworkBg 已固化),
	# shade 透明不遮背景(同 HeroPackagePanel)。
	# 全屏场景(照源 pushScene 替换 package):z_index 提高盖住底层 package 内部高 z 元素。
	# package tab/Grid z=1-3 照源 package.lua,Godot z_index 同 canvas 全局比较(cocos z 局部于 mainLayer),
	# handbook 挂 MainScene z=0 会被 package z=3 元素穿透显示在上。z=100 盖住(> package 内部 z max)。
	z_index = 100
	_tabs_data = EquipmentClassifier.classify_equip(_cm, _player.MAX_TEAM_LEVEL)
	_build_content()


# 建 UI 内容。静态元素(背景/12 tag/箭头/back/pageLabel/pageTitle)从 .tscn instantiate + fill/连信号;
# 装备网格动态挂 %EquipGridHost(翻页/tag 切换时清子节点重建)。
func _build_content() -> void:
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	(content.get_node("%BackBtn") as TextureButton).pressed.connect(remove_window)
	# collect .tscn 已建 12 tag button + label + fill LSTR text(源 tagText :41-52,自 builder 并入)
	for i in range(1, TAG_COUNT + 1):
		var btn: TextureButton = content.get_node("%Tag" + str(i) + "Btn") as TextureButton
		var lbl: Label = content.get_node("%Tag" + str(i) + "Label") as Label
		_tag_ui[i] = {"button": btn, "label": lbl}
		lbl.text = _lstr(TAG_LSTR[i - 1])
	# #5 箭头缩放反馈(button_down/up,源 doArrowTouch :250/260)+ 翻页(pressed,含 0.5s 防抖)
	var arrow_l: TextureButton = content.get_node("%ArrowLeftBtn") as TextureButton
	var arrow_r: TextureButton = content.get_node("%ArrowRightBtn") as TextureButton
	arrow_l.button_down.connect(_on_arrow_down.bind(arrow_l))
	arrow_l.button_up.connect(_on_arrow_up.bind(arrow_l))
	arrow_l.pressed.connect(_on_prev_page)
	arrow_r.button_down.connect(_on_arrow_down.bind(arrow_r))
	arrow_r.button_up.connect(_on_arrow_up.bind(arrow_r))
	arrow_r.pressed.connect(_on_next_page)
	_page_label = content.get_node("%PageLabel") as Label
	_page_title = content.get_node("%PageTitle") as Label   # #4
	_grid_layer = content.get_node("%EquipGridHost") as Control
	for i in range(1, TAG_COUNT + 1):
		(_tag_ui[i]["button"] as TextureButton).pressed.connect(_switch_tag.bind(i))
	_update_tag_visual()
	_refresh_grid()


func _switch_tag(index: int) -> void:
	if index == _current_tag:
		return
	AudioPlayer.play_sfx("common_click_feedback")
	_current_tag = index
	_page = 1
	_update_tag_visual()
	_refresh_grid()


# tag 选中态:切 texture + z_index + label 两 variation(源 doSelectTag :90-101:选中白/disableShadow
# z=9,未选中灰/setShadow(黑,(0,2)) z=4;颜色/阴影走 HandbookEntryLabel[Selected] variation)。
func _update_tag_visual() -> void:
	for i in range(1, TAG_COUNT + 1):
		var btn: TextureButton = _tag_ui[i]["button"]
		var lbl: Label = _tag_ui[i]["label"]
		var is_right: bool = i > 6
		var selected: bool = i == _current_tag
		var sel: String = TAG_RIGHT_SEL if is_right else TAG_LEFT_SEL
		var norm: String = TAG_RIGHT if is_right else TAG_LEFT
		btn.texture_normal = load(sel if selected else norm) as Texture2D
		btn.z_index = 9 if selected else 4
		lbl.theme_type_variation = &"HandbookEntryLabelSelected" if selected else &"HandbookEntryLabel"
		lbl.z_index = 9 if selected else 4


# #3 翻页/切 tag:旧 cell FadeOut 0.2 → queue_free → 建 new cell FadeIn 0.2(照源 pageLayer 交叉淡入淡出)。
# #4 切 tag 更新 pageTitle 文字(源 setPageTitle :475 tagText.title)。 EquipGridHost 常驻只动画其子 cell。
func _refresh_grid() -> void:
	if _page_title != null:
		_page_title.text = _title_text(_current_tag)
	_page_amount = maxi(ceili(float(_list().size()) / float(PER_PAGE)), 1)
	_page = clampi(_page, 1, _page_amount)
	if _page_label != null:
		_page_label.text = "· %d / %d ·" % [_page, _page_amount]
	var old_cells: Array = _grid_layer.get_children()
	if old_cells.is_empty():
		_build_grid_cells()   # 首屏:建 cell + FadeIn(_build_grid_cells 内部管 _is_fading)
	else:
		_is_fading = true
		_fade_out_and_free(old_cells, _build_grid_cells)


func _list() -> Array:
	return _tabs_data.get(TAG_KEYS[_current_tag - 1], [])


# #5 每 cell 连 gui_input(_on_cell_input)统一处理 click + 横向滑动翻页(照源 doEquipTouch+doChangePageTouch)。
func _build_grid_cells() -> void:
	var list: Array = _list()
	var start: int = PER_PAGE * (_page - 1)
	var end: int = min(start + PER_PAGE, list.size())
	var new_cells: Array = []
	for i in range(start, end):
		var info: Dictionary = list[i]
		var slot: int = i - start + 1
		var cell: Control = _create_equip_cell(info, _player.team_level)
		cell.position = _icon_position(slot) - cell.custom_minimum_size * 0.5 - Vector2(0, GRID_LIFT_Y)
		var is_open: bool = bool(cell.get_meta(&"is_open", false))
		var eid: int = int(cell.get_meta(&"id", 0))
		cell.gui_input.connect(_on_cell_input.bind(cell, is_open, eid))
		_grid_layer.add_child(cell)
		new_cells.append(cell)
	_fade_in(new_cells)


# 装备 cell 工厂(照源 createIcon :423-452,自 builder 并入):bg + 解锁 readequip icon /
# 锁定 icon_bg+lock 居中 + 装备名 label(HandbookEquipNameLabel variation,超 114 宽等比缩)。
# lr > player_level 锁定(源 :428 ed.player:getLevel() >= info.lr 才开)。
func _create_equip_cell(info: Dictionary, player_level: int) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = EQUIP_BG_SIZE
	cell.size = EQUIP_BG_SIZE
	cell.pivot_offset = EQUIP_BG_SIZE * 0.5   # 中心缩放(began setScale 0.95 围绕中心,源 anchor 0.5,0.5)
	cell.scale = Vector2(SCREEN_SCALE, SCREEN_SCALE)   # 全屏放大(跟 book_bg ×SC,cell 内部源坐标自动放大)
	var bg := TextureRect.new()
	bg.texture = load(EQUIP_BG_RES) as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.size = EQUIP_BG_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(bg)
	var lr: int = int(info.get("lr", 1))
	var name_text: String = _lstr(String(info.get("name", "")))
	var is_open: bool = player_level >= lr
	if is_open:
		var icon: Control = ReadequipIcon.create_icon(int(info["id"]), 0, _cm)
		icon.position = Vector2(EQUIP_ICON_POS.x, EQUIP_BG_SIZE.y - EQUIP_ICON_POS.y)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon)
	else:
		var icon_bg := TextureRect.new()
		icon_bg.texture = load(ICON_BG_RES) as Texture2D
		icon_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_bg.size = ICON_BG_SIZE
		icon_bg.position = Vector2(EQUIP_ICON_POS.x, EQUIP_BG_SIZE.y - EQUIP_ICON_POS.y)
		icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon_bg)
		var lock := TextureRect.new()
		lock.texture = load(ICON_LOCK_RES) as Texture2D
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.size = ICON_BG_SIZE
		lock.position = (icon_bg.size - lock.size) * 0.5   # 源 :436 icon@(33,33)=icon_bg 中心(86/CS≈67 中心 33.5)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_bg.add_child(lock)
		name_text = _lstr("HANDBOOK.LV_D_ACTIVATED") % lr
	var lbl := Label.new()
	lbl.text = name_text
	lbl.theme_type_variation = &"HandbookEquipNameLabel"
	lbl.position = Vector2(EQUIP_NAME_POS.x, EQUIP_BG_SIZE.y - EQUIP_NAME_POS.y)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(lbl)
	_clamp_label_width(lbl, lbl.get_minimum_size().x)
	cell.set_meta(&"is_open", is_open)
	cell.set_meta(&"id", int(info["id"]))
	return cell


# 源 :445-447 label:getContentSize().width > 114 → label:setScale(114/width)(单参等比)。
func _clamp_label_width(lbl: Label, measured_width: float) -> void:
	if measured_width > NAME_CLAMP_WIDTH:
		var s: float = NAME_CLAMP_WIDTH / measured_width
		lbl.scale = Vector2(s, s)


# 分类标题 LSTR(源 tagText.title1-12 :53-64,自 builder 并入)。
func _title_text(index: int) -> String:
	if index < 1 or index > TAG_COUNT:
		return ""
	return _lstr(TITLE_LSTR[index - 1])


func _lstr(key: String) -> String:
	if _cm != null and _cm.has_method("get_lstr"):
		return String(_cm.get_lstr(key))
	return key


# 源 pushScene 全屏缩放:cocos 800×480 → Godot 960×640(SC=640/480,横向 OFFSET_X 居中,自 builder 并入)。
func _to_godot(cx: float, cy: float) -> Vector2:
	return Vector2(cx * SCREEN_SCALE + OFFSET_X, BASE_Y - cy * SCREEN_SCALE)


# 12 格网格中心坐标(源 getIconPosition :412-421,自 builder 并入)。slot 1-6 左列 / 7-12 右列。
func _icon_position(slot: int) -> Vector2:
	if slot < 1 or slot > 12:
		return Vector2.ZERO
	if slot <= 6:
		var s: int = slot - 1
		return _to_godot(LEFT_FIRST.x + GAP.x * float(s % 2), LEFT_FIRST.y - GAP.y * float(int(s / 2)))
	var r: int = slot - 7
	return _to_godot(RIGHT_FIRST.x + GAP.x * float(r % 2), LEFT_FIRST.y - GAP.y * float(int(r / 2)))


# #3 new cells FadeIn(modulate.a 0→1,源 createPage :593 CCFadeIn 0.2)。
func _fade_in(cells: Array) -> void:
	if cells.is_empty():
		_is_fading = false
		return
	var tw: Tween = create_tween()
	for c in cells:
		(c as Control).modulate.a = 0.0
		tw.parallel().tween_property(c, "modulate:a", 1.0, FADE_TIME)
	tw.finished.connect(func() -> void: _is_fading = false)


# #3 old cells FadeOut → queue_free → 建新(回调,源 createPage :582-594 CCFadeOut→remove→FadeIn)。
func _fade_out_and_free(cells: Array, after: Callable) -> void:
	var tw: Tween = create_tween()
	for c in cells:
		tw.parallel().tween_property(c, "modulate:a", 0.0, FADE_TIME)
	tw.finished.connect(func() -> void:
		for c in cells:
			(c as Control).queue_free()
		after.call()
	)


# #5 箭头翻页(含 0.5s 防抖,源 doArrowTouch :246 canClick)。
func _on_prev_page() -> void:
	if not _arrow_can_click():
		return
	_last_arrow_click = _now()
	AudioPlayer.play_sfx("common_click_feedback")
	_turn_page(-1)


func _on_next_page() -> void:
	if not _arrow_can_click():
		return
	_last_arrow_click = _now()
	AudioPlayer.play_sfx("common_click_feedback")
	_turn_page(1)


# 实际翻页(无防抖,滑动/箭头共用)。源 setPage :538-553。
func _turn_page(dir: int) -> void:
	var np: int = _page + dir
	if np < 1 or np > _page_amount:
		return
	_page = np
	_refresh_grid()


func _arrow_can_click() -> bool:
	return _last_arrow_click < 0.0 or _now() - _last_arrow_click > ARROW_CLICK_GAP


# #5 箭头缩放反馈(源 doArrowTouch :250/260 setScale 0.95/1),围绕中心(pivot_offset)。
func _on_arrow_down(btn: TextureButton) -> void:
	btn.pivot_offset = btn.size * 0.5
	btn.scale = Vector2(PRESS_SCALE, PRESS_SCALE)


func _on_arrow_up(btn: TextureButton) -> void:
	btn.scale = Vector2.ONE


# #5 cell gui_input:合并源 doEquipTouch(装备 began缩放+click)+ doChangePageTouch(横向滑动翻页)。
# cell mouse_filter 默认 STOP 收事件,内层 bg/icon/label 都 IGNORE(事件到 cell)。
func _on_cell_input(event: InputEvent, cell: Control, is_open: bool, eid: int) -> void:
	if _is_fading:
		return   # 动画中忽略(防动画期间重入)
	if not (event is InputEventMouseButton) or (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.pressed:
		_press_pos = mb.position
		_press_time = _now()
		_is_changing_page = false
		_set_icon_scale(cell, PRESS_SCALE)
	else:
		_set_icon_scale(cell, 1.0)
		var dx: float = mb.position.x - _press_pos.x
		var dy: float = mb.position.y - _press_pos.y
		# 横向滑动翻页(源 doChangePageTouch :157-164:水平为主 + |dx|>100 + 时间<1s)
		if abs(dx) > abs(dy) and abs(dx) > SWIPE_THRESHOLD and _now() - _press_time < SWIPE_MAX_TIME:
			_turn_page(1 if dx < 0.0 else -1)   # 左滑下一页 / 右滑上一页
			_is_changing_page = true
		elif not _is_changing_page:
			_handle_cell_click(is_open, eid)
		_press_pos = Vector2.ZERO


# 只缩 [1]（含 frame+equip+amount 或 icon_bg+lock），不缩 bg 和 name（源照搬）。
func _set_icon_scale(cell: Control, scale_factor: float) -> void:
	if cell.get_child_count() < 2:
		return
	var icon_node: CanvasItem = cell.get_child(1) as CanvasItem
	if icon_node == null:
		return
	icon_node.scale = Vector2(scale_factor, scale_factor)


func _handle_cell_click(is_open: bool, eid: int) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	if is_open:
		_open_equipcraft(eid)
	else:
		_show_toast(_cm.get_lstr(LSTR_NOT_UNLOCKED))


# #1 源 doSelectElement :105-109:equipcraft.create({context="handbook", eid=id})。
# equipLayer = equipboard.init("ofcraft", {id, level})。equipboard base = 装备详情面板（属性/描述/卖出）。
# 当前 EquipCraftPanel 直接显示合成树（craftTree）而非 equipboard 详情，跟源初始状态不符。
# 修正：handbook 点装备先弹 EquipboardPanel（装备详情，照源 equipLayer ofcraft），复用 package 已实现的 EquipboardPanel。
func _open_equipcraft(eid: int) -> void:
	var cell_data: Dictionary = {
		"id": eid,
		"amount": int(_player.items.get(eid, 0)),
	}
	var panel := EquipboardPanel.new("equipboard", {})
	panel.setup_panel(cell_data, _cm, _player, true)   # modal=true（handbook 模态弹窗，居中 + 点外关闭）
	panel.show_window(get_parent())
	# handbook 自身 z_index=100，弹窗必须 z>100 才能浮在 handbook 上方
	panel.z_index = 101


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
