class_name PackagePanel
extends PopWindow

## 玩家背包（View 层）— 照源 ui/package.lua（721 行，两 identity 多 tab 4 列网格）。
## identity="package" 装备/物品包（5 tab）/ "fragment" 碎片包（3 tab）。
## Logic 走 EquipmentClassifier.classify（双容器适配，第 22 段交付）。
## 本段主壳：panel 层（bg.jpg/equipbg/close/handbook button/tab/scroll）静态化进
## package_content.tscn（instantiate + fill），物品 cell 动态 fill 挂 %Grid。
## cell 点击 emit cell_clicked（第 24 段接 equipboard 浮层）。
## 单机化：去掉 lsr 统计上报 + framework statusbar 返回（自带关闭按钮，源 close 注释掉靠 framework）。

# ── identity（源 create(identity)）──
const IDENTITY_PACKAGE: String = "package"
const IDENTITY_FRAGMENT: String = "fragment"

# ── tab 定义（照源 packageres.list_key）──
const TABS_PACKAGE: Array[String] = ["all", "equip", "scroll", "stone", "consume"]
const TABS_FRAGMENT: Array[String] = ["all", "equip", "scroll"]
const TAB_NAMES: Dictionary = {
	"all": "全部", "equip": "装备", "scroll": "卷轴",
	"stone": "魂石", "consume": "消耗品",
}
# .tscn 5 tab 满集（fragment 隐藏 stone/consume）。
const TAB_ALL_KEYS: Array[String] = ["all", "equip", "scroll", "stone", "consume"]
# 源 packageres.list_key name LSTR keys（照源 ui/parameter/packageres.lua:11-30）。
const TAB_LSTR_KEYS: Array[String] = [
	"BATTLEPREPARE.WHOLE", "EQUIPCRAFT.GEAR", "EQUIP.REEL", "EQUIP.SOUL_STONE", "EQUIP.CONSUMABLES",
]
# 源 package.lua:378-462 createListButton classbtn/classbtnselected 纹理（同 hero_package tab）。
const CLASSBTN_RES: String = "res://assets/ui/alpha/HVGA/classbtn.png"
const CLASSBTN_SEL_RES: String = "res://assets/ui/alpha/HVGA/classbtnselected.png"

# panel 层子场景（位置/size 静态化进 .tscn 编辑器可视化调）。
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/package_content.tscn")

# ── Scale9 handbook button 样式（.tscn 普通 Button 运行时套 StyleBoxTexture）──
# 源 createHandbookButton :463-538 sell_number_button Scale9Sprite cap 15,22,15,25。
const HANDBOOK_BTN_CAP: Rect2 = Rect2(15.0, 22.0, 15.0, 25.0)
const HANDBOOK_BTN_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button.png"
const HANDBOOK_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button_down.png"
const HANDBOOK_ICON_RES: String = "res://assets/ui/alpha/HVGA/package_handbook_icon.png"
const HANDBOOK_LABEL_KEY: String = "HERODETAIL.BOOK"   # 源 :514 T(LSTR("HERODETAIL.BOOK"))

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
var _status_refs: Dictionary = {}   # MainStatusBar 货币条 label 引用（_refresh_status 更新）
var _content: Control = null        # .tscn instantiate 根节点（cleanup 引用）
var _equipboard: EquipboardPanel = null   # 单例装备浮层（源 self.equipLayer，点 cell refresh 非重建）


# 源 create(identity) + getListData :370-377。identity 从 PopWindow.identity（构造传入）取，
# 决定 tab 集 + classify 输出取 prop/fragment。调用：PackagePanel.new("package"/"fragment", {}).setup_panel(cm, pd)。
func setup_panel(p_cm: Variant, p_pd: PlayerData) -> void:
	_identity = identity
	cm = p_cm
	pd = p_pd
	_tabs = TABS_PACKAGE if _identity == IDENTITY_PACKAGE else TABS_FRAGMENT
	_both = EquipmentClassifier.classify(pd, cm)
	setup()
	# package/fragment 源是 pushScene 独立场景（framework.lua:615/628），framework 自动建 bg.jpg 全屏背景。
	# 本项目单机化用 PopWindow 弹窗替代 pushScene，故 shade 透明（.tscn FrameworkBg 已还原源视觉）。
	if shade_layer != null:
		shade_layer.color.a = 0
		shade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_content()
	_create_status_bar()   # 源 framework.create :755 sbCreateTitle common 3 货币条（所有非 main 场景建）
	_select_tab("all")
	cell_clicked.connect(_on_cell_clicked)
	register_on_enter(func() -> void: AudioPlayer.play_sfx("common_popup_window"))


# panel 层从 .tscn instantiate（位置/size 可视化）+ fill 动态数据 + 绑定信号。
# 源 create :597-685：equipbg Sprite + handbook button + list button + listLayer（draglist）。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	(_content.get_node("%CloseBtn") as TextureButton).pressed.connect(_on_close_pressed)
	_setup_handbook_button()
	_setup_tab_buttons()
	_grid = _content.get_node("%Grid") as GridContainer


# 源 createHandbookButton :463-538：仅 identity=="package" 建图鉴按钮（fragment 不建）。
# .tscn %HandbookBtn 常驻，fragment 时 visible=false；package 时套 Scale9 style + fill icon/label。
func _setup_handbook_button() -> void:
	var btn: Button = _content.get_node("%HandbookBtn") as Button
	if _identity != IDENTITY_PACKAGE:
		btn.visible = false
		return   # 源 :526 仅 package 建（fragment 不建）
	_apply_handbook_style(btn)
	# 源 :498-509 Sprite package_handbook_icon（parent="handbook"，anchor 0.5,0.5，显示=纹理/CS）。
	var icon_rect: TextureRect = btn.get_node("HandbookIcon") as TextureRect
	if ResourceLoader.exists(HANDBOOK_ICON_RES):
		icon_rect.texture = load(HANDBOOK_ICON_RES) as Texture2D
	# 源 :510-524 Label T(LSTR("HERODETAIL.BOOK")) fontinfo="ui_normal_button"(17 号白字) + ccc3(255,255,255)。
	var lbl: Label = btn.get_node("HandbookLabel") as Label
	lbl.text = String(cm.get_lstr(HANDBOOK_LABEL_KEY))
	btn.pressed.connect(_on_handbook_pressed)


# .tscn 普通 Button 套 Scale9 StyleBoxTexture（normal/hover=sell_number_button, pressed=sell_number_button_down）。
# 视觉等价源 Scale9Sprite sell_number_button + press mask sell_number_button_down。
func _apply_handbook_style(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_stylebox(HANDBOOK_BTN_RES, HANDBOOK_BTN_CAP))
	btn.add_theme_stylebox_override("hover", _make_stylebox(HANDBOOK_BTN_RES, HANDBOOK_BTN_CAP))
	btn.add_theme_stylebox_override("pressed", _make_stylebox(HANDBOOK_BTN_PRESS_RES, HANDBOOK_BTN_CAP))


static func _make_stylebox(res_path: String, cap: Rect2) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	var tex: Texture2D = load(res_path) as Texture2D
	sb.texture = tex
	sb.texture_margin_left = cap.position.x
	sb.texture_margin_top = cap.position.y
	if tex != null:
		sb.texture_margin_right = tex.get_width() - cap.position.x - cap.size.x
		sb.texture_margin_bottom = tex.get_height() - cap.position.y - cap.size.y
	return sb


# 源 createListButton :378-462：右侧竖排 tab 按钮，第 1 个默认选中。
# .tscn 5 tab 常驻（位置可视化），按 identity 隐藏不用的（fragment 隐 stone/consume）。
func _setup_tab_buttons() -> void:
	for i in range(TAB_ALL_KEYS.size()):
		var key: String = TAB_ALL_KEYS[i]
		var btn: TextureButton = _content.get_node("%Tab" + key.capitalize() + "Btn") as TextureButton
		var lbl: Label = _content.get_node("%Tab" + key.capitalize() + "Label") as Label
		if _tabs.has(key):
			# stretch_mode 强制 SCALE（ignore_texture_size=true 默认 KEEP 纹理原尺寸溢出，同 hero_package 范式）。
			btn.stretch_mode = TextureButton.STRETCH_SCALE
			btn.pressed.connect(_select_tab.bind(key))
			_tab_buttons[key] = btn
			lbl.text = str(cm.get_lstr(TAB_LSTR_KEYS[i])) if cm != null else String(TAB_NAMES.get(key, key))
			lbl.z_index = 24   # 源 createListButton label z=24（classbtn normal z=1/3, press z=20, label 最上）
			# label 框运行时对齐 button（.tscn offset 仅预览），上移 3px 视觉居中（同 hero_package）。
			lbl.position = Vector2(btn.offset_left, btn.offset_top - 3.0)
			lbl.size = Vector2(btn.offset_right - btn.offset_left, btn.offset_bottom - btn.offset_top)
			_tab_labels[key] = lbl
		else:
			btn.visible = false
			lbl.visible = false
	_update_tab_visual()


# 源 framework.lua:755 sbCreateTitle（所有非 main 场景建 3 货币条 money/rmb/vit，common 模式）。
# package/fragment 源是 pushScene 独立场景，framework 在新场景顶层建货币条；
# 本项目单机化改 PopWindow 弹窗（避 pushScene），但 bg.jpg 全屏遮 main_scene 货币条，
# 故在 .tscn %StatusHost 自建（照 hero_scene.gd:41 范式，统一 MainStatusBar 常量）。
func _create_status_bar() -> void:
	var host: Control = _content.get_node("%StatusHost") as Control
	_status_refs = MainStatusBar.build_bars_only(host, MainStatusBar.BAR_POS_X, MainStatusBar.BAR_Y, Callable(self, "_on_vitality_plus"))
	_refresh_status()


# 刷新货币条数值（委托 MainStatusBar.refresh，照 hero_scene.gd:45）。
func _refresh_status() -> void:
	if pd == null or _status_refs.is_empty():
		return
	MainStatusBar.refresh(_status_refs, pd.team_level, pd.hero_manager.gold, pd.diamond, pd.vitality, pd.vitality_max, pd.player_name, pd.vip_level, pd.avatar)


# 体力加号（照源 statusbar vitality_add_icon→buyVitality；单机化直接买 + Toast，同 main_scene/hero_scene）。
func _on_vitality_plus() -> void:
	if pd == null:
		return
	if not pd.can_buy_vitality():
		Toast.show_message("今日购买体力次数已达上限")
		return
	if pd.buy_vitality():
		Toast.show_message("购买体力 +120")
		_refresh_status()
	else:
		Toast.show_message("钻石不足")


# 源 doClickHandbook :230-238：ed.ui.handbook.create + pushScene。
func _on_handbook_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var panel := HandbookPanel.new("handbook", {})
	panel.setup_panel(pd)
	panel.show_window(get_parent())


# 源 doChangeList :202-229：切 tab toggle 可见 + createList(bothList[identity][name])。
func _select_tab(key: String) -> void:
	_cur_tab = key
	AudioPlayer.play_sfx("common_click_feedback")
	_update_tab_visual()
	_fill_grid()


# 源 doChangeList（package.lua:202-229）+ createListButton normal/press 切换：
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
	# 源 doSelectEquip :185-200：首次 create+popin，已有 → refresh(id) 切换内容（非模态浮层，不阻塞 cell 点击）。
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


# 源 loadEquip :278-318：package createIconWithAmount(id) / fragment createIconWithTag(makeId)。
# package → create_icon（装备/物品）；fragment → create_icon_with_tag（魂石图标 + 可合成 fragment_tick 角标，第 28 段）。
func _make_cell(cell_data: Dictionary) -> Control:
	var amount: int = int(cell_data["amount"])
	var cell: Control
	if _identity == IDENTITY_FRAGMENT:
		cell = ReadequipIcon.create_icon_with_tag(int(cell_data["makeId"]), amount, cm, pd)
	else:
		cell = ReadequipIcon.create_icon(int(cell_data["id"]), amount, cm)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.gui_input.connect(func(event: InputEvent) -> void: _on_cell_gui_input(event, cell_data))
	return cell


# 源 doClickInList :162-177 → doSelectEquip(id) → equipboard。第 24 段接 equipboard 浮层。
func _on_cell_gui_input(event: InputEvent, cell_data: Dictionary) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		AudioPlayer.play_sfx("common_click_feedback")
		cell_clicked.emit(cell_data)


func _on_close_pressed() -> void:
	AudioPlayer.play_sfx("common_close_popup_window")
	remove_window()
