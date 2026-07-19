class_name HeroPackagePanel
extends PopWindow

## 英雄背包（View 层）— 照源 heropackage.lua 完整重建（P0-1 整行卡片）。
## list_bg 背景 + 4 class tab（all/front/middle/back 切换，classbtn/classbtnselected）+
## ScrollContainer 英雄网格（HeroPackageItem 整行卡片：头像+名字+mark+装备槽/灵魂石条，2 列 260×100）+
## 未召唤英雄分隔线（listLine：equip_detail_title_bg + "尚未召唤" 文字）+ close 按钮。
## tab 分类委托 ReadheroHandbook.classify_handbook（Logic 层，含未召唤英雄 + 按位置分）。
## 坐标源 cocos(800×480 左下) → Godot(960×640 左上)：(cx+OFFSET_X+80, 560-cy)，OFFSET_X=-20（源 :486 self.offsetx）。
## 残留：close 按钮使用 framework statusbar backbtn（源 heroPackage 无 close，framework 注入返回）。
##
## Phase A 重构（2026-07-17）：base 层（list_bg + 4 class tab + close + ScrollContainer）静态化进
## hero_package_content.tscn（instantiate + fill），位置/size 编辑器可视化调，照 hero_detail 范式。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/hero_package_content.tscn")
const OFFSET_X: float = -20.0
const CLASSBTN_RES: String = "res://assets/ui/alpha/HVGA/classbtn.png"
const CLASSBTN_SEL_RES: String = "res://assets/ui/alpha/HVGA/classbtnselected.png"
const TAB_KEYS: Array[String] = ["all", "front", "middle", "back"]
# 源 4 tab buttonPress（classbtnselected）+ buttonLabel LSTR。const 不能调运行时 cm.get_lstr → _build_content 运行时填。
const TAB_LSTR_KEYS: Array[String] = [
	"BATTLEPREPARE.WHOLE", "UNIT.FRONT_ROW", "UNIT.MIDDLE_ROW", "UNIT.REAR_ROW"
]
const TAB_LABELS: Array[String] = ["全部", "前排", "中排", "后排"]   # cm=null fallback（与源 LSTR 值同步）
const TAB_BTN_NAMES: Array[String] = ["TabAllBtn", "TabFrontBtn", "TabMiddleBtn", "TabBackBtn"]
const TAB_LBL_NAMES: Array[String] = ["TabAllLabel", "TabFrontLabel", "TabMiddleLabel", "TabBackLabel"]
# 源 draglist 卡片网格 getpos :315-323：第一张中心 cocos(255+offsetx=235, 335)，列间距 260（:321）/ 行高 100（:322）。
const CELL_SIZE: Vector2 = Vector2(260.0, 100.0)   # 源 getpos 列间距 260 / 行高 100（卡片中心间距）
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
var _grid: Control = null
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
	_build_content()
	_classify_heroes()
	_refresh_list()


# Phase A 重构：base 层从 hero_package_content.tscn instantiate（位置/size 可视化）。
# .tscn 已固化：list_bg + 4 tab + 4 label + close + ScrollContainer + GridHost。
# 本函数取节点引用 + fill 动态 LSTR 文本 + 绑定 pressed 信号。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	for i in range(TAB_KEYS.size()):
		var key: String = TAB_KEYS[i]
		var btn: TextureButton = content.get_node("%" + TAB_BTN_NAMES[i]) as TextureButton
		# stretch_mode 强制 SCALE：ignore_texture_size=true 时默认 KEEP（纹理原尺寸 145×75 溢出 button 框），
		# 致纹理 center 偏离 button center（字偏左上）+ 纹理 75 高重叠。SCALE 让纹理缩到 /CS 后的 button size。
		btn.stretch_mode = TextureButton.STRETCH_SCALE
		btn.pressed.connect(_on_tab_pressed.bind(key))
		_tabs[key] = btn
		var lbl: Label = content.get_node("%" + TAB_LBL_NAMES[i]) as Label
		lbl.text = cm.get_lstr(TAB_LSTR_KEYS[i]) if cm != null else TAB_LABELS[i]
		_tab_labels[key] = lbl
	# close = backbtn 返回主界面（源 framework statusbar 注入 backbtn）。
	var close_btn: TextureButton = content.get_node("%CloseBtn") as TextureButton
	close_btn.stretch_mode = TextureButton.STRETCH_SCALE   # 同 tab：backbtn 纹理 74×75 也要缩到 /CS size
	close_btn.pressed.connect(_on_close_pressed)
	_scroll = content.get_node("%HeroScroll") as ScrollContainer
	_grid = content.get_node("%GridHost") as Control
	# 源 heropackage.lua z-order：list_bg z=2(:497) / buttonLabel z=4(:542 等) / draglist zorder=10(:762)。
	# tab z 动态切在 _update_tab_visual（选中 3 / 未选中 1）。照源运行时 setZOrder（源即运行时设）。
	(content.get_node("ListBg") as TextureRect).z_index = 2
	_scroll.z_index = 10
	for key in _tab_labels:
		var lbl: Label = _tab_labels[key] as Label
		lbl.z_index = 4
		# label 框运行时对齐 button（.tscn label offset 仅作编辑器预览），内部 halign/valign CENTER → 文字几何居中
		var btn: TextureButton = _tabs[key] as TextureButton
		# -3：字精确居中 button 几何中心(195)后视觉略偏下（椭圆主体 center 194.5 + 中文字视觉重心），
		# 上移 3px 落到 ~192，相对椭圆主体略偏上，视觉正中。
		lbl.position = Vector2(btn.offset_left, btn.offset_top - 3.0)
		lbl.size = Vector2(btn.offset_right - btn.offset_left, btn.offset_bottom - btn.offset_top)
	_update_tab_visual()
	# 分解按钮（2026-07-19 接线完成）：HeroSplitWindow 务实方案——内联英雄网格 + 返还预览 + 二次确认。
	# 源 herosplit 联机系统（selectwindow/split_return local_server 空壳）单机化简化，详见 hero_split_window.gd。
	_add_herosplit_button(content)


# 源 heropackage.lua:682-747 herosplit ui_info：Scale9 classbtn 120×75 at ccp(695,60) + label。
func _add_herosplit_button(content: Control) -> void:
	var btn_pos: Vector2 = _to_godot(Vector2(695.0, 60.0))   # 源 :687
	var btn := UiScale9Button.make(
		CLASSBTN_RES, CLASSBTN_RES,
		btn_pos, Vector2(120.0, 75.0),
		Rect2(40.0, 25.0, 40.0, 25.0),   # 源 :684 capInsets
		cm.get_lstr(&"heropackage.1.10.1.001") if cm != null else "分解",
		Color.WHITE)
	btn.pressed.connect(_on_herosplit_pressed)
	content.add_child(btn)


# 源 heropackage.lua herosplit 按钮 → split.popMain（单机化：弹 HeroSplitWindow）。
func _on_herosplit_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var window := HeroSplitWindow.new("herosplit", {})
	window.setup_panel(_hero_mgr, cm, pd)
	window.split_done.connect(_refresh_after_change)
	window.show_window(get_parent())


func _update_tab_visual() -> void:
	# 源 doChangeList（heropackage.lua:16-23）：选中 tab setZOrder(3) 凸出 list_bg(z=2)；
	# 未选中 setZOrder(1) 被背景框挡（重叠区左缘约 30px）；texture_normal 切 classbtn/selected。
	for key in _tabs:
		var btn: TextureButton = _tabs[key]
		var selected: bool = key == _clid
		btn.texture_normal = load(CLASSBTN_SEL_RES if selected else CLASSBTN_RES)
		btn.z_index = 3 if selected else 1


func _on_tab_pressed(key: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_clid = key
	_update_tab_visual()
	_refresh_list()


# 源 getAllList :446 classify("handbook","position")：委托 ReadheroHandbook（含未召唤英雄 + 按位置分）。
func _classify_heroes() -> void:
	_hero_by_class = ReadheroHandbook.classify_handbook(cm, _hero_mgr)


# 源 refreshHeroList + loadHero：每条目 packageItem.create(tid) → HeroPackageItem 整行卡片。
# 已拥有→未拥有分界处插 listLine 分隔线（源 prepareLoad listLine + refreshHeroList setVisible 分界）。
# _grid 为 .tscn %GridHost（Control，非 GridContainer 避免子节点 scale reset，2026-07-16 实测）。
func _refresh_list() -> void:
	for c in _grid.get_children():
		c.free()
	var list: Array = _hero_by_class.get(_clid, [])
	var col := 0
	var row := 0
	for i in range(list.size()):
		var entry: Variant = list[i]
		if _is_handbook_boundary(list, i):
			if col == 1:
				var fill := Control.new()
				fill.custom_minimum_size = CELL_SIZE
				fill.position = Vector2(CELL_SIZE.x, row * CELL_SIZE.y)
				fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_grid.add_child(fill)
				col = 0
				row += 1
			_add_list_line_at(0, row)
			row += 1
		var item := HeroPackageItem.create_from_entry(entry, cm, _hero_mgr, pd)
		item.position = Vector2(col * CELL_SIZE.x, row * CELL_SIZE.y)
		item.gui_input.connect(_on_item_gui_input.bind(entry))
		_grid.add_child(item)
		col += 1
		if col >= 2:
			col = 0
			row += 1
	var total_rows := row + (1 if col > 0 else 0)
	if total_rows < 1:
		total_rows = 1
	_grid.custom_minimum_size = Vector2(CELL_SIZE.x * 2.0, CELL_SIZE.y * float(total_rows))


# 分界：当前是最后一个 HeroInstance 且下一条是 miss dict（已拥有→未拥有过渡，源 refreshHeroList :344 preLineAmount）。
func _is_handbook_boundary(list: Array, i: int) -> bool:
	if i >= list.size() - 1:
		return false
	return list[i] is HeroInstance and not (list[i + 1] is HeroInstance)


# 源 prepareLoad :398-411 listLine：equip_detail_title_bg 300×16 + "尚未召唤" 文字。
# GridContainer 不支持跨列，分隔线 + 空 cell 占位凑一行（2 列补齐）。
func _add_list_line_at(col: int, row: int) -> void:
	var line := Control.new()
	line.custom_minimum_size = CELL_SIZE
	line.position = Vector2(col * CELL_SIZE.x, row * CELL_SIZE.y)
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
	spacer.position = Vector2((col + 1) * CELL_SIZE.x, row * CELL_SIZE.y)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.add_child(spacer)


func _on_item_gui_input(event: InputEvent, entry: Variant) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_on_entry_clicked(entry)


# 源 framework.lua statusbar backbtn：hero_scene 独立场景（change_scene 切入），backbtn change_scene 回主界面 = 1 次返回。
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
	# split 入口搬回 hero_package（herosplit 按钮，源 :459-477），不再从 hero_detail 进（4→2 回源 2026-07-18）。
	detail.upgrade_rank_requested.connect(func() -> void:
		if detail.perform_upgrade_rank():
			detail.refresh_content())
	detail.upgrade_skill_requested.connect(func(idx: int) -> void:
		if detail.perform_upgrade_skill(idx):
			Events.bus.emit_tutorial_step(&"SUcomplete")
			detail.refresh_content())
	# 源 heropackage.lua:228 clickHero → draglist.listLayer:setVisible(false) 隐藏列表，
	# 避卡片星透过 hero_detail 弹窗半透 shade（0.588）。
	# 治本：整个 hero_package container 隐藏。源 herodetail 靠 mainLayer z=120 + 不透明 bg 盖住 hero_package，
	# 目标 hero_detail 是 PopWindow（shade 半透 0.588），盖不住 hero_package 全部内容（tab/close/list_bg/卡片全透，
	# 不只 ListBg）→ 须整体隐藏 container。detail 关闭（tree_exiting）恢复。
	# _scroll 内的 draglist 照源 :228 也 setVisible(false)，container.visible 已含，无需单独设。
	container.visible = false
	detail.show_window(get_parent())
	# 源 :156 destroyHandler → listLayer:setVisible(true) 关详情后恢复。
	detail.tree_exiting.connect(func() -> void: container.visible = true)


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
