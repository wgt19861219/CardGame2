class_name PackagePanel
extends PopWindow

## 玩家背包（View 层）— 照源 ui/package.lua（721 行，两 identity 多 tab 4 列网格）。
## identity="package" 装备/物品包（5 tab）/ "fragment" 碎片包（3 tab）。
## Logic 走 EquipmentClassifier.classify（双容器适配，第 22 段交付）。
## 本段主壳：多 tab + 4 列网格滚动（ScrollContainer+GridContainer，源 draglist 等价）+ cell 展示。
## cell 点击 emit cell_clicked（第 24 段接 equipboard 浮层）。坐标用源 cocos 值（Phase 4 视觉校准）。
## 单机化：去掉 lsr 统计上报 + framework statusbar 返回（用自带关闭按钮，源 close 注释掉靠 framework）。

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

# ── 坐标常量（源 cocos 值）──
const BG_POS: Vector2 = Vector2(500.0, 213.0)             # 源 :622 equipbg
const TAB_ORIGIN: Vector2 = Vector2(706.0, 363.0)         # 源 :379 ox,oy
const TAB_DY: float = 60.0                                # 源 :380
const TAB_SIZE: Vector2 = Vector2(90.0, 50.0)
const SCROLL_POS: Vector2 = Vector2(355.0, 35.0)          # 源 :353 cliprect (355,35,295,355)
const SCROLL_SIZE: Vector2 = Vector2(295.0, 355.0)
const GRID_COLUMNS: int = 4                               # 源 4 列（refreshList :258）
const CLOSE_BTN_POS: Vector2 = Vector2(20.0, 15.0)  # 左上角留小边（用户偏好更靠左上角）
const CLOSE_BTN_SIZE: Vector2 = Vector2(80.0, 40.0)
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/backbtn.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/backbtn-disabled.png"

# ── 资源 ──
const BG_PATH: String = "res://assets/ui/alpha/HVGA/package_equip_bg.png"
const FRAMEWORK_BG: String = "res://assets/ui/alpha/HVGA/bg.jpg"   # 源 framework.lua:749 全屏背景（pushScene 场景）
# 源 hello.lua:311 setContentScaleFactor(1.28125)：cocos sprite 显示=纹理/CS（无 fix_size 时）。
# TextureRect 默认 size=纹理原始（偏大 1.28），照源无 fix_size 的纯 Sprite 统一 /CS。
const CONTENT_SCALE: float = 1.28125

signal cell_clicked(cell_data: Dictionary)   # 第 24 段接 equipboard 浮层（源 doSelectEquip → equipboard）

var cm: Variant = null
var pd: PlayerData = null
var _identity: String = ""
var _tabs: Array[String] = []
var _both: Dictionary = {}        # classify 输出 {prop, fragment}
var _cur_tab: String = "all"
var _tab_buttons: Dictionary = {}  # tab_key(String) -> Button
var _grid: GridContainer = null
var _status_refs: Dictionary = {}   # MainStatusBar 货币条 label 引用（_refresh_status 更新）


# 源 cocos(800×480 左下) → Godot(960×640 左上):cx+80, 560-cy（同 daily_login/battle_view_coords 标准）。
# Phase 4 早期直接用源值漏转，2026-07-14 补 to_godot（CLOSE_BTN_POS 850,590 是 Godot-native 不转）。
func _g(pos: Vector2) -> Vector2:
	return BattleViewCoords.to_godot(pos.x, pos.y)


# 源 create(identity) + getListData :370-377。identity 从 PopWindow.identity（构造传入）取，
# 决定 tab 集 + classify 输出取 prop/fragment。调用：PackagePanel.new("package"/"fragment", {}).setup_panel(cm, pd)。
func setup_panel(p_cm: Variant, p_pd: PlayerData) -> void:
	_identity = identity
	cm = p_cm
	pd = p_pd
	_tabs = TABS_PACKAGE if _identity == IDENTITY_PACKAGE else TABS_FRAGMENT
	_both = EquipmentClassifier.classify(pd, cm)
	setup()
	# package/fragment 源是 pushScene 独立场景（framework.lua:615/628），有 framework bg.jpg 全屏背景；
	# 本项目单机化用 PopWindow 弹窗替代 pushScene，故 shade 透明 + 补全屏 bg.jpg 还原源视觉。
	if shade_layer != null:
		shade_layer.color.a = 0
		shade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_fullscreen_bg()
	_create_bg()
	_create_close_button()
	_create_tab_buttons()
	_create_grid()
	_create_status_bar()   # 源 framework.create :755 sbCreateTitle common 3 货币条（所有非 main 场景建）
	_select_tab("all")
	cell_clicked.connect(_on_cell_clicked)
	register_on_enter(func() -> void: AudioPlayer.play_sfx("common_popup_window"))


# 源 framework.lua:755 sbCreateTitle（所有非 main 场景建 3 货币条 money/rmb/vit，common 模式）。
# package/fragment 源是 pushScene 独立场景，framework 在新场景顶层建货币条；
# 本项目单机化改 PopWindow 弹窗（避 pushScene），但 bg.jpg 全屏遮 main_scene 货币条，
# 故在 container 自建（照 hero_scene.gd:41 范式，挂 bg.jpg 之上，统一 MainStatusBar 常量）。
func _create_status_bar() -> void:
	_status_refs = MainStatusBar.build_bars_only(container, MainStatusBar.BAR_POS_X, MainStatusBar.BAR_Y, Callable(self, "_on_vitality_plus"))
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


# 源 framework.lua:749-751 pushScene 场景全屏 bg.jpg（package/fragment 源是独立场景）。
func _create_fullscreen_bg() -> void:
	var bg := TextureRect.new()
	bg.texture = load(FRAMEWORK_BG)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.position = Vector2.ZERO
	bg.size = Vector2(960.0, 640.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)


func _create_bg() -> void:
	if not ResourceLoader.exists(BG_PATH):
		return   # headless/缺图降级（不阻塞 Logic）
	var bg_tex: Texture2D = load(BG_PATH) as Texture2D
	var bg := TextureRect.new()
	bg.texture = bg_tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# 源 package.lua:613-625 equipbg t="Sprite" config={}，显示=纹理/CS（见 CONTENT_SCALE 注释）
	var bg_size: Vector2 = bg_tex.get_size() / CONTENT_SCALE
	bg.size = bg_size
	bg.position = _g(BG_POS) - bg_size / 2.0   # 源 setPosition 中心锚定→Godot
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)


func _create_close_button() -> void:
	var btn: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, CLOSE_BTN_POS)
	btn.pressed.connect(_on_close_pressed)
	container.add_child(btn)


# 源 createListButton :378-462：右侧竖排 tab 按钮，第 1 个默认选中。
func _create_tab_buttons() -> void:
	for i in range(_tabs.size()):
		var key: String = _tabs[i]
		var btn := Button.new()
		btn.text = String(TAB_NAMES.get(key, key))
		btn.position = _g(Vector2(TAB_ORIGIN.x, TAB_ORIGIN.y - TAB_DY * i))
		btn.size = TAB_SIZE
		btn.toggle_mode = true
		btn.pressed.connect(func() -> void: _select_tab(key))
		container.add_child(btn)
		_tab_buttons[key] = btn


# 源 createListLayer :350-369：draglist 滚动区。本项目 ScrollContainer+GridContainer columns=4 等价。
func _create_grid() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = _g(SCROLL_POS)
	scroll.size = SCROLL_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED   # 源仅垂直滚动
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	container.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	scroll.add_child(_grid)


# 源 doChangeList :202-229：切 tab toggle 可见 + createList(bothList[identity][name])。
func _select_tab(key: String) -> void:
	_cur_tab = key
	AudioPlayer.play_sfx("common_click_feedback")
	for k in _tab_buttons:
		var btn: Button = _tab_buttons[k]
		btn.button_pressed = (k == key)
	_fill_grid()


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
	var board := EquipboardPanel.new("equipboard", {})
	board.setup_panel(cell_data, cm, pd)
	board.sold.connect(_on_sold)
	board.show_window(get_parent())


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
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		AudioPlayer.play_sfx("common_click_feedback")
		cell_clicked.emit(cell_data)


func _on_close_pressed() -> void:
	AudioPlayer.play_sfx("common_close_popup_window")
	remove_window()
