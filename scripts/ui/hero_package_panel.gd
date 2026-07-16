class_name HeroPackagePanel
extends PopWindow

## 英雄背包（View 层）— 照源 heropackage.lua 完整重建（P0-1 整行卡片）。
## list_bg 背景 + 4 class tab（all/front/middle/back 竖排切换，classbtn/classbtnselected）+
## ScrollContainer 英雄网格（HeroPackageItem 整行卡片：头像+名字+mark+装备槽/灵魂石条，2 列 260×100）+
## 未召唤英雄分隔线（listLine：equip_detail_title_bg + "尚未召唤" 文字）+ close/碎片按钮。
## tab 分类委托 ReadheroHandbook.classify_handbook（Logic 层，含未召唤英雄 + 按位置分）。
## 坐标源 cocos(800×480 左下) → Godot(960×640 左上)：(cx+OFFSET_X+80, 560-cy)，OFFSET_X=-20。
## 残留：close/碎片按钮文字降级（common_tips_button_close 资源缺）。

# ReadheroIcon 用全局 class_name（readhero_icon.gd），不 const :Script preload（避免注解 Script 致 := 推断失败，memory: gdscript-const-script-preload-class-name）。

const OFFSET_X: float = -20.0
const LIST_BG_RES: String = "res://assets/ui/alpha/HVGA/package_herolist_bg.png"
const LIST_BG_COCOS: Vector2 = Vector2(385.0, 215.0)   # 源 :501
const LIST_BG_SIZE: Vector2 = Vector2(720.0, 410.0)   # 视觉加大（装 2 卡片 bg 313 并列 + 边距），源 :504 fix_size 570×375
const CLASSBTN_RES: String = "res://assets/ui/alpha/HVGA/classbtn.png"
const CLASSBTN_SEL_RES: String = "res://assets/ui/alpha/HVGA/classbtnselected.png"
const TAB_KEYS: Array[String] = ["all", "front", "middle", "back"]
# TAB 文字照源走 LSTR（cm=null 时 fallback）；const 不能调运行时 cm.get_lstr → _create_tabs 运行时填。
const TAB_LSTR_KEYS: Array[String] = [
	"BATTLEPREPARE.WHOLE", "UNIT.FRONT_ROW", "UNIT.MIDDLE_ROW", "UNIT.REAR_ROW"
]
const TAB_LABELS: Array[String] = ["全部", "前排", "中排", "后排"]   # cm=null fallback（与源 LSTR 值同步）
const TAB_COCOS_Y: Array[float] = [365.0, 305.0, 245.0, 185.0]      # 源 :517/560/603/646
const TAB_COCOS_X: float = 707.0
const LABEL_CENTER_OFFSET: Vector2 = Vector2(20.0, 10.0)   # label 居中估算偏移（size 未 layout）
# 通用左右边距：内容（ScrollContainer）距 bg 边框左右内边距（通用常量，后续面板复用统一样式）。
const LIST_PADDING_X: float = 35.0
# draglist 内容区：bg position.x = _to_godot(385,215).x - LIST_BG_SIZE.x*0.5 = 445 - 360 = 85（445 = 385-20(OFFSET_X)+80）；
# LIST_TOPLEFT = bg + 左右 LIST_PADDING_X + 垂直居中 (LIST_BG_SIZE.y-348)/2。随 LIST_BG_SIZE 自动。
const LIST_TOPLEFT: Vector2 = Vector2(445.0 - LIST_BG_SIZE.x * 0.5 + LIST_PADDING_X, 140.0 + (LIST_BG_SIZE.y - 348.0) * 0.5)
const LIST_SIZE: Vector2 = Vector2(LIST_BG_SIZE.x - 2.0 * LIST_PADDING_X, 348.0)
const CELL_SIZE: Vector2 = Vector2(320.0, 100.0)   # 源 getpos 260 间距 / 100 行高（加宽同步 hero_package_item，bg 313 不重叠）
const CLOSE_BTN_POS: Vector2 = Vector2(20.0, 15.0)  # 左上角留小边（用户偏好更靠左上角）
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/backbtn.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/backbtn-disabled.png"
const LIST_LINE_BG_RES: String = "res://assets/ui/alpha/HVGA/equip_detail_title_bg.png"   # 源 prepareLoad :403
const LIST_LINE_LSTR_KEY: String = "HEROPACKAGE.THE_FOLLOWING_HEROES_HAVE_NOT_BEEN_SUMMONED"   # 源 :407
const LIST_LINE_FALLBACK: String = "以下英雄尚未召唤"   # cm=null fallback（= 源 LSTR_zh-CN 值）

var cm: Variant = null
var pd: PlayerData = null
var _hero_mgr: HeroManager = null
var _clid: String = "all"
var _tabs: Dictionary = {}      # key -> TextureButton
var _tab_labels: Dictionary = {}   # key -> Label
var _scroll: ScrollContainer = null
var _grid: GridContainer = null
var _hero_by_class: Dictionary = {}   # clid -> Array[Variant]（HeroInstance 或 {tid,miss} dict）


static func _to_godot(cocos: Vector2) -> Vector2:
	return Vector2(cocos.x + OFFSET_X + 80.0, 560.0 - cocos.y)


func setup_panel(hero_mgr: HeroManager, p_cm: Variant = null, p_pd: PlayerData = null) -> void:
	_hero_mgr = hero_mgr
	cm = p_cm
	pd = p_pd
	setup()
	# heroPackage 照源 framework 是全屏场景（bg.jpg 在 hero_scene 底层），无 PopWindow shade 黑遮罩。
	# shade 透明（a=0）不遮 bg.jpg，但 visible=true 保持 container 子树可见（container 挂 shade_layer 下，visible=false 会连隐藏整个内容）。
	if shade_layer != null:
		shade_layer.color.a = 0
		shade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_close_button()
	_create_bg()
	_create_tabs()
	_create_list_container()
	_classify_heroes()
	_refresh_list()


# 源 ui_info list_bg（:492-506）：package_herolist_bg.png anchor(0.5,0.5) (385+offsetx,215) fix 570×375。
func _create_bg() -> void:
	var bg := TextureRect.new()
	bg.texture = load(LIST_BG_RES)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.position = _to_godot(LIST_BG_COCOS) - LIST_BG_SIZE * 0.5
	bg.size = LIST_BG_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)


# 源 4 tab（all/front/middle/back）：listButton classbtn + buttonPress classbtnselected + Label。
# 简化为单 TextureButton 切 texture_normal（选中=selected 纹理）+ Label 居中。
func _create_tabs() -> void:
	for i in range(TAB_KEYS.size()):
		var key: String = TAB_KEYS[i]
		var g: Vector2 = _to_godot(Vector2(TAB_COCOS_X, TAB_COCOS_Y[i]))
		var btn := TextureButton.new()
		btn.texture_normal = load(CLASSBTN_RES)
		btn.texture_pressed = load(CLASSBTN_SEL_RES)
		btn.position = g - _tex_size(CLASSBTN_RES) * 0.5
		btn.pressed.connect(_on_tab_pressed.bind(key))
		container.add_child(btn)
		_tabs[key] = btn
		var lbl := Label.new()
		lbl.text = cm.get_lstr(TAB_LSTR_KEYS[i]) if cm != null else TAB_LABELS[i]
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.position = g - LABEL_CENTER_OFFSET
		container.add_child(lbl)
		_tab_labels[key] = lbl
	_update_tab_visual()


func _tex_size(res_path: String) -> Vector2:
	var tex = load(res_path)
	if tex is Texture2D:
		return tex.get_size()
	return Vector2(80.0, 50.0)


func _update_tab_visual() -> void:
	for key in _tabs:
		(_tabs[key] as TextureButton).texture_normal = load(CLASSBTN_SEL_RES if key == _clid else CLASSBTN_RES)


func _on_tab_pressed(key: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_clid = key
	_update_tab_visual()
	_refresh_list()


# 源 draglist（:758-772）cliprect 800×348 rect 500×348 → Godot ScrollContainer + GridContainer 2 列。
# item 自身 custom_minimum_size=CELL_SIZE，separation=0（cell 紧贴 = 源 260×100 间距）。
func _create_list_container() -> void:
	_scroll = ScrollContainer.new()
	_scroll.position = LIST_TOPLEFT
	_scroll.size = LIST_SIZE
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	container.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 0)
	_grid.add_theme_constant_override("v_separation", 0)
	_scroll.add_child(_grid)


# 源 getAllList :446 classify("handbook","position")：委托 ReadheroHandbook（含未召唤英雄 + 按位置分）。
func _classify_heroes() -> void:
	_hero_by_class = ReadheroHandbook.classify_handbook(cm, _hero_mgr)


# 源 refreshHeroList + loadHero：每条目 packageItem.create(tid) → HeroPackageItem 整行卡片。
# 已拥有→未拥有分界处插 listLine 分隔线（源 prepareLoad listLine + refreshHeroList setVisible 分界）。
func _refresh_list() -> void:
	for c in _grid.get_children():
		c.free()
	var list: Array = _hero_by_class.get(_clid, [])
	for i in range(list.size()):
		var entry: Variant = list[i]
		if _is_handbook_boundary(list, i):
			_add_list_line()
		var item := HeroPackageItem.create_from_entry(entry, cm, _hero_mgr, pd)
		item.gui_input.connect(_on_item_gui_input.bind(entry))
		_grid.add_child(item)


# 分界：当前是最后一个 HeroInstance 且下一条是 miss dict（已拥有→未拥有过渡，源 refreshHeroList :344 preLineAmount）。
func _is_handbook_boundary(list: Array, i: int) -> bool:
	if i >= list.size() - 1:
		return false
	return list[i] is HeroInstance and not (list[i + 1] is HeroInstance)


# 源 prepareLoad :398-411 listLine：equip_detail_title_bg 300×16 + "尚未召唤" 文字。
# GridContainer 不支持跨列，分隔线 + 空 cell 占位凑一行（2 列补齐）。
func _add_list_line() -> void:
	var line := Control.new()
	line.custom_minimum_size = CELL_SIZE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := TextureRect.new()
	bg.texture = load(LIST_LINE_BG_RES)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.size = Vector2(300.0, 16.0)
	bg.position = Vector2(0.0, CELL_SIZE.y * 0.5 - 8.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(bg)
	var lbl := Label.new()
	lbl.text = cm.get_lstr(LIST_LINE_LSTR_KEY) if cm != null else LIST_LINE_FALLBACK
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.position = Vector2(60.0, CELL_SIZE.y * 0.5 - 10.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(lbl)
	_grid.add_child(line)
	var spacer := Control.new()
	spacer.custom_minimum_size = CELL_SIZE
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.add_child(spacer)


func _on_item_gui_input(event: InputEvent, entry: Variant) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_on_entry_clicked(entry)


# backbtn 返回按钮（照源 framework statusbar 注入 backbtn）：hero_scene 是独立场景（change_scene 切入），
# backbtn 直接 change_scene 回主界面 = 1 次返回。加 container 上（与其他大面板统一，避 hero_scene 兄弟层级遮挡）。
func _create_close_button() -> void:
	var btn: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, CLOSE_BTN_POS)
	btn.pressed.connect(_on_close_pressed)
	container.add_child(btn)


func _on_close_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	SceneManager.change_scene("res://scenes/main_menu/main_scene.tscn")


# 碎片合成入口源 heropackage.lua 无（grep 确认只有 herosplit 分解 + classbtn tab，无 fragment），
# 照源去掉占位按钮（2026-07-14 用户验收反馈）。碎片列表从装备板 equipboard ofpackage 进。


# 源 doClickInHeroLayer（:144-247）：clickHero 已拥有→detail；clickMissHero 未拥有→召唤/碎片详情。
func _on_entry_clicked(entry: Variant) -> void:
	if entry is HeroInstance:
		_on_hero_clicked(entry as HeroInstance)
	else:
		_on_miss_clicked(entry)


# 源 clickHero（:191-233）：已拥有 → HeroDetailPanel（card 模式）。
func _on_hero_clicked(hero: HeroInstance) -> void:
	AudioPlayer.play_sfx("common_popup_window")   # 源 heroPackage.clickHero（soundres.lua:185）
	Events.bus.emit_tutorial_step(&"SUclickHero")   # 源 heropackage.lua:201 ed.endTeach "SUclickHero"
	var detail := HeroDetailPanel.new("herodetail", {})
	detail.setup_panel(hero, cm, _hero_mgr, pd)
	detail.evolve_requested.connect(func() -> void:
		if detail.perform_evolve():
			detail.refresh_content())
	detail.split_requested.connect(func() -> void:
		if not detail.perform_split().is_empty():
			detail.remove_window()
			_refresh_after_change())
	detail.upgrade_rank_requested.connect(func() -> void:
		if detail.perform_upgrade_rank():
			detail.refresh_content())
	detail.upgrade_skill_requested.connect(func(idx: int) -> void:
		if detail.perform_upgrade_skill(idx):
			Events.bus.emit_tutorial_step(&"SUcomplete")
			detail.refresh_content())
	detail.show_window(get_parent())


# 源 clickMissHero（:163-190）：未拥有 → 碎片足够则 hero_evolve 召唤；不足源弹 stonedetail（本项目未实现，降级）。
func _on_miss_clicked(entry: Variant) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var miss_tid: int = ReadheroHandbook.entry_tid(entry)
	if ReadheroHandbook.check_stone_enough(miss_tid, cm, _hero_mgr):
		var result: Dictionary = _hero_mgr.hero_evolve(miss_tid)
		if bool(result.get("ok", false)):
			_refresh_after_change()


func _refresh_after_change() -> void:
	call_deferred("_rebuild_after_change")


func _rebuild_after_change() -> void:
	_classify_heroes()
	_refresh_list()
