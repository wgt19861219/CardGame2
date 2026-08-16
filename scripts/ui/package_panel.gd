class_name PackagePanel
extends PopWindow

## 玩家背包（View 层）— 照源 ui/package.lua（721 行，两 identity 多 tab 4 列网格）。
## identity="package" 装备/物品包（5 tab）/ "fragment" 碎片包（3 tab）。
## Logic 走 EquipmentClassifier.classify（双容器适配，第 22 段交付）。
## 批 2 两件套（2026-08-16 核对级）：主壳静态化进 package_content.tscn（bg/equipbg/close/
## handbook/tab/scroll/grid 位置贴图字号全在 tscn+theme），panel 只做业务+信号 connect+fill；
## 物品 cell 动态 fill 挂 %Grid。cell 点击 emit cell_clicked（接 equipboard 浮层）。
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
# 显示原点尺寸 = frame 纹理 94×95px ÷CS = 73.37×74.13；ReadequipIcon 的 frame Sprite2D 按
# 纹理原尺寸渲染（hero_detail 装备槽同口径），故 scale 补偿到视觉高 74（94×74/95=73.22 宽，
# 源 73.37 差 0.15px）。GridContainer separation 是 int theme constant（预览实测 1.63 被截 1）
# → 取 sep 2/6 + min size=视觉盒，步进 73.22+2=75（int 化）/ 74+6=80 照源 refreshList dx,dy。
const CELL_SCALE: float = 74.0 / 95.0
const FRAME_TEX_SIZE: Vector2 = Vector2(94.0, 95.0)
const CELL_VIS_SIZE: Vector2 = FRAME_TEX_SIZE * CELL_SCALE

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
var _status_refs: Dictionary = {}   # 已废弃，保留兼容（HudOverlay autoload 接管 HUD）
var _content: Control = null        # .tscn instantiate 根节点（cleanup 引用）
var _equipboard: EquipboardPanel = null   # 单例装备浮层（源 self.equipLayer，点 cell refresh 非重建）


# 决定 tab 集 + classify 输出取 prop/fragment。构造 PackagePanel 实例传 identity，
# 再调 setup_panel(cm, pd)。
func setup_panel(p_cm: Variant, p_pd: PlayerData) -> void:
	play_open_sfx = true   # T4：原 register_on_enter 音效样板上收基类
	transparent_shade = true   # T4：原 shade 透明 hack 上收基类
	_identity = identity
	hud_identity = _identity   # T4：身份切换上收基类（须在 _identity 赋值后取，先取恒空串）
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
func _update_tab_visual() -> void:
	for key in _tab_buttons:
		var btn: TextureButton = _tab_buttons[key]
		var selected: bool = key == _cur_tab
		btn.texture_normal = load(CLASSBTN_SEL_RES if selected else CLASSBTN_RES)
		btn.z_index = 3 if selected else 1


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
# 两侧 frame 均为 94×95px 纹理 → 统一 scale=74/95 + wrapper min size=视觉盒（见 FRAME_TEX_SIZE 注释）。
# GridContainer 的 fit_child_in_rect 会重置直接 child 的 scale（task-11 实测 min 生效 scale 归 1）
# → 包一层 wrapper：外层承载格子 min size（步进 75/80），内层 icon 保 scale（视觉 73.22×74）。
func _make_cell(cell_data: Dictionary) -> Control:
	var amount: int = int(cell_data["amount"])
	var cell: Control
	if _identity == IDENTITY_FRAGMENT:
		cell = ReadequipIcon.create_icon_with_tag(int(cell_data["makeId"]), amount, cm, pd)
	else:
		cell = ReadequipIcon.create_icon(int(cell_data["id"]), amount, cm)
	cell.scale = Vector2.ONE * CELL_SCALE
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	var wrapper := Control.new()
	wrapper.custom_minimum_size = CELL_VIS_SIZE
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.add_child(cell)
	wrapper.gui_input.connect(func(event: InputEvent) -> void: _on_cell_gui_input(event, cell_data))
	return wrapper


func _on_cell_gui_input(event: InputEvent, cell_data: Dictionary) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		AudioPlayer.play_sfx("common_click_feedback")
		cell_clicked.emit(cell_data)


func _on_close_pressed() -> void:
	AudioPlayer.play_sfx("common_close_popup_window")
	remove_window()
