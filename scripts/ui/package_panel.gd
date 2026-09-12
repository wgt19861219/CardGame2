class_name PackagePanel
extends PopWindow

## 玩家背包（View 层）— 照源 ui/package.lua（721 行，两 identity 多 tab 4 列网格）。
## identity="package" 装备/物品包（5 tab）/ "fragment" 碎片包（3 tab）。
## Logic 走 EquipmentClassifier.classify（双容器适配，第 22 段交付）。
## 批 2 两件套（2026-08-16 核对级）：主壳静态化进 package_content.tscn（bg/equipbg/close/
## handbook/tab/scroll/grid 位置贴图字号全在 tscn+theme），panel 只做业务+信号 connect+fill；
## 物品 cell 动态 fill 挂 %Grid。cell 点击 emit cell_clicked（接 equipboard 浮层）：
## press 记录 → release 位移 <8px 才 emit（源 draglist.lua:906 not dragMode 才 doClickIn），
## 列表拖拽滚动走 DragScrollHelper（2026-09-12 根修，hero_package/ranklist 同范式）。
## 单机化：去掉 lsr 统计上报 + framework statusbar 返回（自带关闭按钮，源 close 注释掉靠 framework）。

# ── identity（源 create(identity)）──
const IDENTITY_PACKAGE: String = "package"
const IDENTITY_FRAGMENT: String = "fragment"

# ── tab 定义（照源 packageres.list_key）──
const TABS_PACKAGE: Array[String] = ["all", "equip", "scroll", "stone", "consume"]
const TABS_FRAGMENT: Array[String] = ["all", "equip", "scroll"]
const TAB_NAMES: Dictionary = {
	"all": "全部", "equip": "装备", "scroll": "卷轴",
	"stone": "灵魂石", "consume": "消耗品",
}
# .tscn 5 tab 满集（fragment 隐藏 stone/consume）。
const TAB_ALL_KEYS: Array[String] = ["all", "equip", "scroll", "stone", "consume"]
const TAB_LSTR_KEYS: Array[String] = [
	"BATTLEPREPARE.WHOLE", "EQUIPCRAFT.GEAR", "EQUIP.REEL", "EQUIP.SOUL_STONE", "EQUIP.CONSUMABLES",
]
const CLASSBTN_RES: String = "res://assets/ui/alpha/HVGA/classbtn.png"
const CLASSBTN_SEL_RES: String = "res://assets/ui/alpha/HVGA/classbtnselected.png"
# cell 显示尺寸（task-11 修）：源 loadEquip :288 createIconWithAmount(data.id) 无 length →
# 显示原点尺寸 = frame 纹理 94×95px ÷CS = 73.37×74.13。步进 75/80 照源 refreshList dx,dy
# （GridContainer sep 2/6 int constant + min size=视觉盒）。
const FRAME_TEX_SIZE: Vector2 = Vector2(94.0, 95.0)
const CELL_VIS_SIZE: Vector2 = Vector2(FRAME_TEX_SIZE.x * 74.0 / 95.0, 74.0)
# 修复轮 B（2026-08-18，历史 6 轮回滚后重开）：frame Sprite2D 等比缩放丢边框立体层
# （equip_frame 94×95px 边框 6 行 黑/白高光×2/灰×2/黑，×0.78 后层混叠高光并档）→
# NinePatchRect 1:1 保层（PIL 实测层界：顶 y2-7/底 y84-88/左 x3-8/右 x85-90 含透明缘）。
# anchors 警告治理：手摆节点（frame/内容层）只设 position/size 不碰 anchors，wrapper
#（custom_minimum_size）隔离 GridContainer fit_child_in_rect。
const FRAME_PATCH_H: int = 9
const FRAME_PATCH_T: int = 8
const FRAME_PATCH_B: int = 11
# fragment_bg 衬底渐变带（PIL 实测顶 y1-11/底 y82-89，含透明缘到 y94）。
const FRAG_BG_PATCH_T: int = 12
const FRAG_BG_PATCH_B: int = 13
# 内容层缩放：目标 icon 视觉 55 嵌 NinePatch 中区。9bc640e 起 create_icon 内部 _load_sprite
# 统一 ÷CS（icon 节点已显示 78/CS），故分母 = 78/CS 而非旧口径纹理 px 78（旧 CELL_INNER_SCALE
# =55/78 系原像素时代设计，统一后叠加成双重 ÷CS → icon 实显 42.9 填不满中区，2026-08-22 修）。
const CELL_INNER_SCALE: float = 55.0 / (78.0 / ReadequipIcon.CONTENT_SCALE)
# icon 归中局部 (9,9)（ICON_OFFSET 口径）→ 视觉起点 = 中区左上 (9,8)：offset = (9,8)-(9,9)×s。
const CELL_CONTENT_OFFSET: Vector2 = Vector2(9.0, 8.0) - Vector2(9.0, 9.0) * CELL_INNER_SCALE
const ICON_LOCAL_POS: Vector2 = Vector2(9.0, 9.0)

# panel 层子场景（位置/size/贴图/字号全静态化进 .tscn + theme variation）。
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/package_content.tscn")

const HANDBOOK_LABEL_KEY: String = "HERODETAIL.BOOK"

signal cell_clicked(cell_data: Dictionary)   # 第 24 段接 equipboard 浮层（源 doSelectEquip → equipboard）

var cm: Variant = null
var pd: PlayerData = null
var _identity: String = ""
var _tabs: Array[String] = []
var _both: Dictionary = {}        # classify 输出 {prop, fragment}
var _cur_tab: String = "all"
var _tab_buttons: Dictionary = {}  # tab_key(String) -> TextureButton
var _tab_labels: Dictionary = {}   # tab_key(String) -> Label（运行时跟随 button position/size）
var _grid: GridContainer = null
var _scroll: ScrollContainer = null     # %ScrollHost（拖拽滚动宿主）
var _drag_state: Dictionary = {}        # DragScrollHelper 拖拽滚动跨帧基准
var _cell_press: Variant = null         # cell press 位置基准（tap 位移判定）
var _status_refs: Dictionary = {}   # 已废弃，保留兼容（HudOverlay autoload 接管 HUD）
var _content: Control = null        # .tscn instantiate 根节点（cleanup 引用）
var _equipboard: EquipboardPanel = null   # 单例装备浮层（源 self.equipLayer，点 cell refresh 非重建）


# 决定 tab 集 + classify 输出取 prop/fragment。构造 PackagePanel 实例传 identity，
# 再调 setup_panel(cm, pd)。
func setup_panel(p_cm: Variant, p_pd: PlayerData) -> void:
	play_open_sfx = true   # T4：原 register_on_enter 音效样板上收基类
	transparent_shade = true   # T4：原 shade 透明 hack 上收基类
	_identity = identity   # HUD 版式不随弹窗切（源 package z=120 scene 级盖 HUD，通用遮蔽接管，2026-09-08）
	cm = p_cm
	pd = p_pd
	_tabs = TABS_PACKAGE if _identity == IDENTITY_PACKAGE else TABS_FRAGMENT
	_both = EquipmentClassifier.classify(pd, cm)
	setup()
	# package/fragment 源是 pushScene 独立场景（framework.lua:615/628），framework 自动建 bg.jpg 全屏背景。
	# 本项目单机化用 PopWindow 弹窗替代 pushScene，故 shade 透明（.tscn FrameworkBg 已还原源视觉）。
	_build_content()
	_create_status_bar()
	_select_tab("all")
	cell_clicked.connect(_on_cell_clicked)


# panel 层从 .tscn instantiate（位置/贴图/字号全在 tscn+theme）+ fill 动态数据 + 绑定信号。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	(_content.get_node("%CloseBtn") as TextureButton).pressed.connect(_on_close_pressed)
	_setup_handbook_button()
	_setup_tab_buttons()
	_grid = _content.get_node("%Grid") as GridContainer
	_scroll = _content.get_node("%ScrollHost") as ScrollContainer


# 拖拽滚动（2026-09-12：Godot 4 ScrollContainer 桌面仅滚轮/滚动条无拖拽，源 draglist
# 手势补齐；hero_package/ranklist/evolve_equip 同范式）。equipboard 浮层打开时不转发
# （源 bt 触摸优先级：顶层浮层吃掉事件，背后列表不响应）。
func _input(event: InputEvent) -> void:
	if _scroll == null:
		return
	if _equipboard != null and is_instance_valid(_equipboard):
		return
	DragScrollHelper.handle_input(_scroll, event, _drag_state)


# %HandbookBtn 常驻 tscn（三态/字号走 theme variation），fragment 时 visible=false；
# package 时 fill icon/label 文案并绑点击。
func _setup_handbook_button() -> void:
	var btn: Button = _content.get_node("%HandbookBtn") as Button
	if _identity != IDENTITY_PACKAGE:
		btn.visible = false
		return
	var lbl: Label = btn.get_node("HandbookLabel") as Label
	lbl.text = String(cm.get_lstr(HANDBOOK_LABEL_KEY))
	btn.pressed.connect(_on_handbook_pressed)


# .tscn 5 tab 常驻（rect/stretch/variation 静态化），按 identity 隐藏不用的（fragment 隐 stone/consume）。
func _setup_tab_buttons() -> void:
	for i in range(TAB_ALL_KEYS.size()):
		var key: String = TAB_ALL_KEYS[i]
		var btn: TextureButton = _content.get_node("%Tab" + key.capitalize() + "Btn") as TextureButton
		var lbl: Label = _content.get_node("%Tab" + key.capitalize() + "Label") as Label
		if _tabs.has(key):
			btn.pressed.connect(_select_tab.bind(key))
			_tab_buttons[key] = btn
			lbl.text = str(cm.get_lstr(TAB_LSTR_KEYS[i])) if cm != null else String(TAB_NAMES.get(key, key))
			_tab_labels[key] = lbl
		else:
			btn.visible = false
			lbl.visible = false
	_update_tab_visual()


# package/fragment 源是 pushScene 独立场景，framework 在新场景顶层建货币条；
# 本项目单机化改 PopWindow 弹窗（避 pushScene），但 bg.jpg 全屏遮 main_scene 货币条，
# HudOverlay 切 identity（package/fragment 跟随构造传入）。
func _create_status_bar() -> void:
	_refresh_status()


# 刷新货币条数值（委托 HudOverlay autoload）。
func _refresh_status() -> void:
	HudOverlay.refresh()




func _on_handbook_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var panel := HandbookPanel.new("handbook", {})
	panel.setup_panel(pd)
	panel.show_window(get_parent())


func _select_tab(key: String) -> void:
	_cur_tab = key
	AudioPlayer.play_sfx("common_click_feedback")
	_update_tab_visual()
	_fill_grid()


# 选中 tab texture_normal=classbtnselected z=3 凸出；未选中 classbtn z=1（同 hero_package _update_tab_visual）。
# z_as_relative=false（审查 F1）：本 panel 挂 PopWindow z=100 absolute，按钮若 relative 累加
# effective 101/103 > 弹窗兜底 100 会穿透（如 HandbookPanel）；与 .tscn 侧 label 24/ScrollHost 10
# 同款绝对化，层序保持源值（label 24 > 按钮 1/3 < 100）。
func _update_tab_visual() -> void:
	for key in _tab_buttons:
		var btn: TextureButton = _tab_buttons[key]
		var selected: bool = key == _cur_tab
		btn.texture_normal = load(CLASSBTN_SEL_RES if selected else CLASSBTN_RES)
		btn.z_index = 3 if selected else 1
		btn.z_as_relative = false


# 当前 tab 填充 grid（_select_tab + _on_sold 刷新共用）。
func _fill_grid() -> void:
	for c in _grid.get_children():
		c.free()
	var table: Dictionary = _both["prop"] if _identity == IDENTITY_PACKAGE else _both["fragment"]
	var cells: Array = table.get(_cur_tab, [])
	for cell_data in cells:
		_grid.add_child(_make_cell(cell_data as Dictionary))


# cell 点击 → 弹 EquipboardPanel（第 24 段，照源 doSelectEquip → equipboard ofpackage）。
func _on_cell_clicked(cell_data: Dictionary) -> void:
	# _equipboard 卖出/close 后自 remove_window → is_instance_valid 失效 → 下次点 cell 新建。
	if _equipboard != null and is_instance_valid(_equipboard):
		_equipboard.refresh(cell_data)
		return
	_equipboard = EquipboardPanel.new("equipboard", {})
	_equipboard.setup_panel(cell_data, cm, pd)
	_equipboard.sold.connect(_on_sold)
	_equipboard.composed.connect(_on_sold)   # 合成同理：碎片消耗后重 classify + 重填 grid + 刷货币条（源 downFragmentCompose consumeAmount :47-74）
	_equipboard.show_window(self)   # 挂 package（照源 equipboard.mainLayer 挂 package.mainLayer），随 package remove_window / 退出场景销毁


# 卖出后重 classify + 重填当前 tab（持有量变化，cell 可能消失）+ 刷新货币条（金币变化）。
func _on_sold(_item_id: int) -> void:
	_both = EquipmentClassifier.classify(pd, cm)
	_fill_grid()
	_refresh_status()


# package → create_icon（装备/物品）；fragment → create_icon_with_tag（魂石图标 + 可合成 fragment_tick 角标，第 28 段）。
# 修复轮 B：cell 结构 = wrapper(格子盒 min 73.22×74，步进 75/80) + [NinePatchRect 边框 1:1 保立体层
# （fragment 侧先垫 fragment_bg 衬底）+ 内容层（ReadequipIcon 产物去 frame/bg Sprite2D，icon 归中
# (9,9)，scale 55/78 落 NinePatch 中区）]。GridContainer 的 fit_child_in_rect 会重置直接 child 的
# scale（task-11 实测）→ wrapper 隔离；手摆节点不设 anchors（历史 anchors/size 警告根治）。
func _make_cell(cell_data: Dictionary) -> Control:
	var amount: int = int(cell_data["amount"])
	var is_frag: bool = _identity == IDENTITY_FRAGMENT
	var cell: Control
	if is_frag:
		cell = ReadequipIcon.create_icon_with_tag(int(cell_data["makeId"]), amount, cm, pd)
	else:
		cell = ReadequipIcon.create_icon(int(cell_data["id"]), amount, cm)
	# 提取 ReadequipIcon 已选的品质框/衬底纹理（create_hero_stone_icon 不存 quality meta，
	# 探针实证 get_meta 恒缺省 → 品质色降级；直接复用原 Sprite2D 纹理最稳）。
	var frame_tex: Texture2D = null
	var bg_tex: Texture2D = null
	for c in cell.get_children():
		var spr := c as Sprite2D
		if spr == null or spr.texture == null:
			continue
		var p: String = spr.texture.resource_path
		if p.begins_with(ReadequipIcon.FRAME_DIR) or p.begins_with(ReadequipIcon.FRAGMENT_FRAME_DIR):
			frame_tex = spr.texture
		elif p == ReadequipIcon.FRAGMENT_BG_PATH:
			bg_tex = spr.texture
	var wrapper := Control.new()
	wrapper.custom_minimum_size = CELL_VIS_SIZE
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	if bg_tex != null:
		wrapper.add_child(_make_cell_frame(bg_tex, FRAG_BG_PATCH_T, FRAG_BG_PATCH_B))
	if frame_tex != null:
		wrapper.add_child(_make_cell_frame(frame_tex, FRAME_PATCH_T, FRAME_PATCH_B))
	_strip_frame_sprites(cell)
	_center_cell_icon(cell)
	cell.scale = Vector2.ONE * CELL_INNER_SCALE
	cell.position = CELL_CONTENT_OFFSET
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(cell)
	wrapper.gui_input.connect(func(event: InputEvent) -> void: _on_cell_gui_input(event, cell_data))
	return wrapper


# 格子边框层（NinePatch 1:1 保立体，历史等比缩放层混叠的反案）。
func _make_cell_frame(p_texture: Texture2D, patch_t: int, patch_b: int) -> NinePatchRect:
	var frame := NinePatchRect.new()
	frame.texture = p_texture
	frame.patch_margin_left = FRAME_PATCH_H
	frame.patch_margin_top = patch_t
	frame.patch_margin_right = FRAME_PATCH_H
	frame.patch_margin_bottom = patch_b
	frame.size = CELL_VIS_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return frame


# 去 ReadequipIcon 产物里的底图层（equip_frame_*/fragment_frame_* + underlay 衬底
# [gocha/fragment_bg，ReadequipIcon set_meta 标记]），由 NinePatchRect 边框层接管。
# gocha 衬底 1fc781e 补画后必须一并 strip：否则①盖在 NinePatch 边框层上（cell 后 add
# 画最上）；②抢 _center_cell_icon 的"第一个 Sprite2D"归中位致真 icon 错位
# （2026-08-22 背包反馈回归）。按 meta 而非路径删：icon 资源缺失时内容节点 fallback
# 同 gocha 纹理（碎片 Icon 字段资源缺，探针实证），按路径会误删占位。
func _strip_frame_sprites(cell: Control) -> void:
	for c in cell.get_children():
		var spr := c as Sprite2D
		if spr == null or spr.texture == null:
			continue
		var p: String = spr.texture.resource_path
		if p.begins_with(ReadequipIcon.FRAME_DIR) or p.begins_with(ReadequipIcon.FRAGMENT_FRAME_DIR) \
				or spr.has_meta(&"underlay"):
			spr.free()


# icon 归中：strip 后第一个非 tag/tick 的 Sprite2D 定位 (9,9)（container 72 基准左上口径），
# 使内容层缩放后 icon 视觉恰嵌 NinePatch 中区。icon 资源缺失时内容节点 fallback gocha
# 纹理（无 underlay meta 不被 strip）仍归中作占位；fragment 侧 STONE_ICON_POS (36,38)
# 既有偏移溢出格子，此处归中——package 特有定位，不动 ReadequipIcon 通用件。
func _center_cell_icon(cell: Control) -> void:
	for c in cell.get_children():
		var spr := c as Sprite2D
		if spr == null or spr.texture == null:
			continue
		var p: String = spr.texture.resource_path
		if p == ReadequipIcon.SOULSTONE_TAG_PATH or p == ReadequipIcon.TICK_PATH:
			continue
		spr.position = ICON_LOCAL_POS
		return


# cell 点击（2026-09-12 根修）：press 记录 → release 位移 <8px 才触发（DragScrollHelper.is_tap）。
# 旧实现按下即 emit，想按住拖动滚动时起始 press 误触弹 equipboard、列表没法拖。
# 源 draglist.lua:906 touchEnded 且 not dragMode 才 doClickIn（tap 语义照译，hero_package 同范式）。
func _on_cell_gui_input(event: InputEvent, cell_data: Dictionary) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_cell_press = mb.global_position
		else:
			if DragScrollHelper.is_tap(_cell_press, mb.global_position):
				AudioPlayer.play_sfx("common_click_feedback")
				cell_clicked.emit(cell_data)
			_cell_press = null


func _on_close_pressed() -> void:
	AudioPlayer.play_sfx("common_close_popup_window")
	remove_window()
