class_name HeroPackagePanel
extends PopWindow

## 英雄背包（View 层）— 照源 heropackage.lua 完整重建（替 Phase 5 文字简化版）。
## list_bg 背景 + 4 class tab（all/front/middle/back 竖排切换，classbtn/classbtnselected）+
## ScrollContainer 英雄网格（ReadheroIcon 头像替文字行，2 列 260×100）+ close/碎片按钮。
## tab 分类按 Unit.Position Type（cm.get_raw_table，照 crusade_data 模式）。
## 坐标源 cocos(800×480 左下) → Godot(960×640 左上)：(cx+OFFSET_X+80, 560-cy)，OFFSET_X=-20。
## 残留：close/碎片按钮文字降级（common_tips_button_close 资源缺）；未召唤英雄分隔线待补。

# ReadheroIcon 用全局 class_name（readhero_icon.gd），不 const :Script preload（避免注解 Script 致 := 推断失败，memory: gdscript-const-script-preload-class-name）。

const OFFSET_X: float = -20.0
const LIST_BG_RES: String = "res://assets/ui/alpha/HVGA/package_herolist_bg.png"
const LIST_BG_COCOS: Vector2 = Vector2(385.0, 215.0)   # 源 :501
const LIST_BG_SIZE: Vector2 = Vector2(570.0, 375.0)    # 源 :504 fix_size
const CLASSBTN_RES: String = "res://assets/ui/alpha/HVGA/classbtn.png"
const CLASSBTN_SEL_RES: String = "res://assets/ui/alpha/HVGA/classbtnselected.png"
const TAB_KEYS: Array[String] = ["all", "front", "middle", "back"]
const TAB_LABELS: Array[String] = ["全部", "前排", "中排", "后排"]   # 源 BATTLEPREPARE.WHOLE / UNIT.FRONT/MIDDLE/REAR_ROW
const TAB_COCOS_Y: Array[float] = [365.0, 305.0, 245.0, 185.0]      # 源 :517/560/603/646
const TAB_COCOS_X: float = 707.0
const LABEL_CENTER_OFFSET: Vector2 = Vector2(20.0, 10.0)   # label 居中估算偏移（size 未 layout）
# draglist rect 源 (135+offsetx, 45, 500, 348) → Godot 左上
const LIST_TOPLEFT: Vector2 = Vector2(135.0 + OFFSET_X + 80.0, 560.0 - 45.0 - 348.0)
const LIST_SIZE: Vector2 = Vector2(500.0, 348.0)
const CELL_SIZE: Vector2 = Vector2(260.0, 100.0)   # 源 refreshHeroList getpos 260 间距 / 100 行高
const CLOSE_BTN_POS: Vector2 = Vector2(800.0, 50.0)
const FRAG_BTN_POS: Vector2 = Vector2(700.0, 50.0)
const POS_FRONT: String = "Front"
const POS_MIDDLE: String = "Middle"
const POS_REAR: String = "Rear"

var cm: Variant = null
var pd: PlayerData = null
var _hero_mgr: HeroManager = null
var _clid: String = "all"
var _tabs: Dictionary = {}      # key -> TextureButton
var _tab_labels: Dictionary = {}   # key -> Label
var _scroll: ScrollContainer = null
var _grid: GridContainer = null
var _hero_by_class: Dictionary = {}   # clid -> Array[HeroInstance]


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
	_create_bg()
	_create_tabs()
	_create_list_container()
	_create_close_button()
	_create_fragment_button()
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
		lbl.text = TAB_LABELS[i]
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
func _create_list_container() -> void:
	_scroll = ScrollContainer.new()
	_scroll.position = LIST_TOPLEFT
	_scroll.size = LIST_SIZE
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	container.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", int(CELL_SIZE.x - ReadheroIcon.CONTAINER_SIZE.x))
	_grid.add_theme_constant_override("v_separation", int(CELL_SIZE.y - ReadheroIcon.CONTAINER_SIZE.y))
	_scroll.add_child(_grid)


# 源 getAllList classify("handbook","position")：Unit.Position Type 分前/中/后（照 crusade_data 模式）。
func _classify_heroes() -> void:
	var all: Array = []
	var front: Array = []
	var middle: Array = []
	var back: Array = []
	var raw: Dictionary = {}
	if cm != null and cm.has_method("get_raw_table"):
		raw = cm.get_raw_table(&"Unit")
	for inst_id in _hero_mgr.heroes:
		var hero: HeroInstance = _hero_mgr.heroes[inst_id]
		all.append(hero)
		var pos_type: String = ""
		if raw.has(str(hero.tid)):
			pos_type = String(raw[str(hero.tid)].get(&"Position Type", ""))
		if pos_type.find(POS_FRONT) >= 0:
			front.append(hero)
		elif pos_type.find(POS_MIDDLE) >= 0:
			middle.append(hero)
		elif pos_type.find(POS_REAR) >= 0:
			back.append(hero)
	_hero_by_class = {"all": all, "front": front, "middle": middle, "back": back}


# 源 refreshHeroList + loadHero：每个英雄 packageItem.create(tid) → heroIcon 头像。
# 本项目 ReadheroIcon.create_icon_by_hero 替纯文字行；2 列网格（源 getpos 260 间距/100 行高）。
func _refresh_list() -> void:
	for c in _grid.get_children():
		c.free()
	var list: Array = _hero_by_class.get(_clid, [])
	for hero in list:
		var cell := Control.new()
		cell.custom_minimum_size = CELL_SIZE
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		var icon := ReadheroIcon.create_icon_by_hero(hero, cm)
		icon.position = (CELL_SIZE - ReadheroIcon.CONTAINER_SIZE) * 0.5
		cell.add_child(icon)
		cell.gui_input.connect(_on_hero_gui_input.bind(hero))
		_grid.add_child(cell)


func _on_hero_gui_input(event: InputEvent, hero: HeroInstance) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_on_hero_clicked(hero)


# 残留：close/碎片按钮文字降级（common_tips_button_close.png 资源缺，后续统一纹理化）。
func _create_close_button() -> void:
	var btn := Button.new()
	btn.text = "关闭"
	btn.position = CLOSE_BTN_POS
	btn.size = Vector2(80, 40)
	btn.pressed.connect(remove_window)
	container.add_child(btn)


func _create_fragment_button() -> void:
	var btn := Button.new()
	btn.text = "碎片合成"
	btn.position = FRAG_BTN_POS
	btn.size = Vector2(90, 40)
	btn.pressed.connect(_open_fragment_list)
	container.add_child(btn)


func _open_fragment_list() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var panel := FragmentListPanel.new("fragmentlist", {})
	panel.setup_panel(cm, pd)
	panel.show_window(get_parent())


# 源 doClickInHeroLayer clickHero（:191-233）：点英雄 → HeroDetailPanel（card 模式）。
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


func _refresh_after_change() -> void:
	call_deferred("_rebuild_after_change")


func _rebuild_after_change() -> void:
	_classify_heroes()
	_refresh_list()
