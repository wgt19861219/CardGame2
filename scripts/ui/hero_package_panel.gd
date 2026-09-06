class_name HeroPackagePanel
extends PopWindow

## 英雄背包（View 层）— 照源 heropackage.lua 完整重建（P0-1 整行卡片）。
## list_bg 背景 + 4 class tab（all/front/middle/back 切换）+ ScrollContainer 英雄网格
## （HeroPackageItem 整行卡片，2 列 260×100）+ 未召唤分隔线（list_line 行模板）+
## herosplit 分解按钮 + close 按钮。tab 分类委托 ReadheroHandbook.classify_handbook。
##
## 两件套范式（批 1 Task 9，2026-08-15）：静态结构全进 hero_package_content.tscn
## （base 层 + herosplit 按钮 + z 序）+ hero_package_list_line.tscn（分隔线行模板）；
## 本文件只做业务、信号 connect、fill（零静态节点构造，3 个弹窗工厂白名单）。
## 坐标源 cocos(800×480 左下) → Godot(800×480 左上)：(x, 480-y)，offsetx=-20 只作用于
## 源 position 显式 +offsetx 的元素（list_bg/tab/label/draglist；herosplit 无）。
## 残留：close 按钮使用 framework statusbar backbtn（源 heroPackage 无 close，framework 注入返回）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/hero_package_content.tscn")
const LIST_LINE_SCENE: PackedScene = preload("res://scenes/ui/hero_package_list_line.tscn")
const CLASSBTN_RES: String = "res://assets/ui/alpha/HVGA/classbtn.png"
const CLASSBTN_SEL_RES: String = "res://assets/ui/alpha/HVGA/classbtnselected.png"
const TAB_KEYS: Array[String] = ["all", "front", "middle", "back"]
const TAB_LSTR_KEYS: Array[String] = [
	"BATTLEPREPARE.WHOLE", "UNIT.FRONT_ROW", "UNIT.MIDDLE_ROW", "UNIT.REAR_ROW"
]
const TAB_LABELS: Array[String] = ["全部", "前排", "中排", "后排"]   # cm=null fallback（与源 LSTR 值同步）
const TAB_BTN_NAMES: Array[String] = ["TabAllBtn", "TabFrontBtn", "TabMiddleBtn", "TabBackBtn"]
const TAB_LBL_NAMES: Array[String] = ["TabAllLabel", "TabFrontLabel", "TabMiddleLabel", "TabBackLabel"]
const CELL_SIZE: Vector2 = Vector2(260.0, 100.0)
# 源 getpos 坐标基准（全屏 cocos 直译）：首列中心 x=255+offsetx(−20)=235 → GridHost x=235−cell 半宽 130=105；
# 首行 cell 中心 y=335 → 顶=480−335−50=95 → GridHost y=95−87（clip 顶）=8（2026-08-28 根修；
# 旧实现漏此基准致整列左偏 15.6+整体高 8、bg 外缘被裁剪区吞）。
const GRID_ORIGIN: Vector2 = Vector2(105.0, 8.0)
const LIST_LINE_LSTR_KEY: String = "HEROPACKAGE.THE_FOLLOWING_HEROES_HAVE_NOT_BEEN_SUMMONED"
const LIST_LINE_FALLBACK: String = "以下英雄尚未召唤"   # cm=null fallback（= 源 LSTR_zh-CN 值）
# 源 refreshHeroList getLinepos(:306-313)：分隔线中心 x=365 全屏 → GridHost 局部 (365+80-185)=260（两列中缝）。
# 2026-08-28 根修：HeroScroll 改源 cliprect 全宽（左缘 0）后 GridHost 局部=全屏，中心=GRID_ORIGIN_X+260=365。
const LIST_LINE_CENTER_X: float = 365.0
# 源 getpos(:318-319)：preLineAmount>0 时未拥有段 toy-30 整体下移 30；分隔线在 gap 中点（边界+15）。
const MISS_GAP: float = 30.0
# 源 createHeroList(:298)：initListHeight = 100*ceil(ta/2)+40（40 = gap 30 + 尾余量 10）。
const LIST_TAIL_H: float = 40.0
# herosplit 按钮文字（源 :727 heropackage.1.10.1.001，cm=null fallback）。
const HEROSPLIT_LSTR_KEY: String = "heropackage.1.10.1.001"
const HEROSPLIT_FALLBACK: String = "分解"

var cm: Variant = null
var pd: PlayerData = null
var _hero_mgr: HeroManager = null
var _clid: String = "all"
var _tabs: Dictionary = {}      # key -> TextureButton
var _tab_labels: Dictionary = {}   # key -> Label
var _scroll: ScrollContainer = null
var _grid: Control = null
var _hero_by_class: Dictionary = {}   # clid -> Array[Variant]（HeroInstance 或 {tid,miss} dict）


func setup_panel(hero_mgr: HeroManager, p_cm: Variant = null, p_pd: PlayerData = null) -> void:
	hud_identity = "heropackage"   # T4：原 apply/remove override 样板上收基类
	transparent_shade = true   # T4：原 shade 透明 hack 上收基类
	_hero_mgr = hero_mgr
	cm = p_cm
	pd = p_pd
	setup()
	# heroPackage 照源 framework 是全屏场景（bg.jpg 在 hero_scene 底层），无 PopWindow shade 黑遮罩。
	# shade 透明（a=0）不遮 bg.jpg，但 visible=true 保持 container 子树可见（container 挂 shade_layer 下，visible=false 会连隐藏整个内容）。
	_build_content()
	_classify_heroes()
	_refresh_list()


# 两件套范式：base 层 + herosplit 组从 hero_package_content.tscn instantiate（位置/size/z 已固化）。
# 本函数取节点引用 + fill 动态 LSTR 文本 + 绑定 pressed 信号。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	for i in range(TAB_KEYS.size()):
		var key: String = TAB_KEYS[i]
		var btn: TextureButton = content.get_node("%" + TAB_BTN_NAMES[i]) as TextureButton
		# stretch_mode 强制 SCALE：ignore_texture_size=true 时默认 KEEP（纹理原尺寸溢出 button 框），
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
	# 2026-08-30 点击回归修复：Godot 输入命中按树序逆序遍历（z_index 只影响绘制）——
	# HeroScroll(mf=STOP) 照源 cliprect 全宽覆盖 tab 区域，tscn 树序 tab 在 scroll 前则
	# 点击全被 scroll 吞（d62b856 全宽化回归，z=11 只保绘制不保命中）。tab 运行时移到
	# scroll 后保命中（视觉不变：z 11/13>10 恒绘于其上；先例 battle_hero_panel move_child）。
	for key in TAB_KEYS:
		content.move_child(_tabs[key] as Node, -1)
		content.move_child(_tab_labels[key] as Node, -1)
	_update_tab_visual()
	# herosplit 分解按钮（Task 9 静态化）：结构/9 宫格/坐标全在 .tscn，fill 只接信号 + LSTR 文本。
	# ⚠️源 refreshSplitButton endPoint=0 永假默认隐藏；本项目作为 HeroSplitWindow 唯一入口常驻（受控偏离）。
	var split_btn: Button = content.get_node("%HerosplitBtn") as Button
	split_btn.pressed.connect(_on_herosplit_pressed)
	(split_btn.get_node("%HerosplitLabel") as Label).text = \
		cm.get_lstr(HEROSPLIT_LSTR_KEY) if cm != null else HEROSPLIT_FALLBACK


func _on_herosplit_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var window := HeroSplitWindow.new("herosplit", {})
	window.setup_panel(_hero_mgr, cm, pd)
	window.split_done.connect(_refresh_after_change)
	window.show_window(get_parent())


func _update_tab_visual() -> void:
	# 未选中 z=11 被选中(13)与滚动内容盖（源 setZOrder(1/3) 相对关系 + 11 基准位：
	# HeroScroll z10 全宽化后 tab 须恒在其上保点击，2026-08-28 根修）；texture_normal 切 classbtn/selected。
	for key in _tabs:
		var btn: TextureButton = _tabs[key]
		var selected: bool = key == _clid
		btn.texture_normal = load(CLASSBTN_SEL_RES if selected else CLASSBTN_RES)
		# 两态贴图显示宽不同（classbtn 134px→104.58 / selected 145px→113.17，px÷CS），
		# tscn 补 stretch_mode=0 后 rect 管渲染，须随贴图切换等比宽防选中态压扁 8%
		# （2026-08-31 全库 stretch 清偿，同 battle_prepare 四轮判例，中心保持不动）。
		var tab_w: float = 113.17 if selected else 104.58
		var tab_cx: float = btn.position.x + btn.size.x * 0.5
		btn.size.x = tab_w
		btn.position.x = tab_cx - tab_w * 0.5
		btn.z_index = 13 if selected else 11


func _on_tab_pressed(key: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_clid = key
	_update_tab_visual()
	_refresh_list()


func _classify_heroes() -> void:
	_hero_by_class = ReadheroHandbook.classify_handbook(cm, _hero_mgr)


# 已拥有→未拥有分界处插 listLine 分隔线（源 prepareLoad listLine + refreshHeroList setVisible 分界）。
# _grid 为 .tscn %GridHost（Control，非 GridContainer 避免子节点 scale reset，2026-07-16 实测）；
# 手动绝对定位（col/row 计数器），空位不建占位节点。
func _refresh_list() -> void:
	for c in _grid.get_children():
		c.free()
	var list: Array = _hero_by_class.get(_clid, [])
	var col := 0
	var row := 0
	var miss_gap: float = 0.0   # 源 getpos toy-30：分界后未拥有段整体下移 30
	for i in range(list.size()):
		var entry: Variant = list[i]
		var item := HeroPackageItem.create_from_entry(entry, cm, _hero_mgr, pd)
		item.position = GRID_ORIGIN + Vector2(col * CELL_SIZE.x, row * CELL_SIZE.y + miss_gap)
		item.gui_input.connect(_on_item_gui_input.bind(entry))
		_grid.add_child(item)
		col += 1
		if col >= 2:
			col = 0
			row += 1
		# 边界检查在 item[i] 放置后（i = 最后已拥有）：line 位于已拥有段底界下方 gap 中点（源
		# preLineAmount 补齐偶数行语义 → 边界 = 已占用行数；源旧实现 line 在最后已拥有上方属错位）。
		if _is_handbook_boundary(list, i):
			var boundary_row: int = row + (1 if col > 0 else 0)
			_add_list_line_at(boundary_row)
			row = boundary_row
			col = 0
			miss_gap = MISS_GAP
	var total_rows := row + (1 if col > 0 else 0)
	if total_rows < 1:
		total_rows = 1
	_grid.custom_minimum_size = Vector2(GRID_ORIGIN.x + CELL_SIZE.x * 2.0, GRID_ORIGIN.y + CELL_SIZE.y * float(total_rows) + LIST_TAIL_H)


# 分界：当前是最后一个 HeroInstance 且下一条是 miss dict（已拥有→未拥有过渡，源 refreshHeroList :344 preLineAmount）。
func _is_handbook_boundary(list: Array, i: int) -> bool:
	if i >= list.size() - 1:
		return false
	return list[i] is HeroInstance and not (list[i + 1] is HeroInstance)


# 分隔线（源 prepareLoad:398-411 + getLinepos:306-313）：hero_package_list_line.tscn 行模板
# instantiate + fill 文本 + 定位。中心 x=中缝 260（源 365 全屏）、y=已拥有末行底+15（gap 中点，
# gap=MISS_GAP 30 由未拥有段下移形成，照源无 bg 重叠）。
func _add_list_line_at(boundary_row: int) -> void:
	var line: Control = LIST_LINE_SCENE.instantiate() as Control
	line.set_meta(&"list_line", true)
	line.position = Vector2(
		LIST_LINE_CENTER_X - line.size.x * 0.5,
		float(boundary_row) * CELL_SIZE.y + MISS_GAP * 0.5 - line.size.y * 0.5)
	(line.get_node("%LineLabel") as Label).text = \
		cm.get_lstr(LIST_LINE_LSTR_KEY) if cm != null else LIST_LINE_FALLBACK
	_grid.add_child(line)


func _on_item_gui_input(event: InputEvent, entry: Variant) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_on_entry_clicked(entry)


func _on_close_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	SceneManager.change_scene("res://scenes/main_menu/main_scene.tscn")


func _on_entry_clicked(entry: Variant) -> void:
	if entry is HeroInstance:
		_on_hero_clicked(entry as HeroInstance)
	else:
		_on_miss_clicked(entry)


func _on_hero_clicked(hero: HeroInstance) -> void:
	AudioPlayer.play_sfx("common_popup_window")
	Events.bus.emit_tutorial_step(&"SUclickHero")
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
			detail.refresh_content())   # 2026-09-06 用户定谳：升级反馈滑入也退役（重建全静默；滑入只属点 tab 源行为）
	# 觉醒信号（单机化新增）：成功 perform_awake 内部已弹展示面板并衔接触发 refresh_content，
	# 这里仅挂占位保持信号注册对称（实际刷新由 awake panel.closed 触发，避免双刷新）。
	detail.awake_requested.connect(func() -> void:
		detail.perform_awake())
	# 避卡片星透过 hero_detail 弹窗半透 shade（0.588）。
	# 治本：整个 hero_package container 隐藏。源 herodetail 靠 mainLayer z=120 + 不透明 bg 盖住 hero_package，
	# 目标 hero_detail 是 PopWindow（shade 半透 0.588），盖不住 hero_package 全部内容（tab/close/list_bg/卡片全透，
	# 不只 ListBg）→ 须整体隐藏 container。detail 关闭（tree_exiting）恢复。
	# _scroll 内的 draglist 照源 :228 也 setVisible(false)，container.visible 已含，无需单独设。
	container.visible = false
	# 货币栏（hero_scene 顶部）也要隐藏：hero_detail 是 PopWindow（shade 半透 0.588）盖不住货币栏，
	# 货币栏从 shade 半透露出（变暗叠在 detail tab view 上）视觉遮挡（2026-07-20 用户反馈）。
	var host: Node = get_parent()
	if host != null and host.has_method(&"set_bars_visible"):
		host.set_bars_visible(false)
	detail.show_window(host)
	detail.tree_exiting.connect(func() -> void:
		container.visible = true
		if host != null and host.has_method(&"set_bars_visible"):
			host.set_bars_visible(true))


func _on_miss_clicked(entry: Variant) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var miss_tid: int = ReadheroHandbook.entry_tid(entry)
	if ReadheroHandbook.check_stone_enough(miss_tid, cm, _hero_mgr):
		var result: Dictionary = _hero_mgr.hero_evolve(miss_tid)
		if bool(result.get("ok", false)):
			_refresh_after_change()
	else:
		_open_stone_detail(miss_tid)


func _open_stone_detail(tid: int) -> void:
	var panel := StoneDetailPanel.new("stonedetail", {})
	panel.setup_panel(tid, cm, pd, _hero_mgr)
	# 盖不住 hero_package 全部内容 → 须整体隐藏 container（同 _on_hero_clicked 范式）。
	container.visible = false
	var host: Node = get_parent()
	if host != null and host.has_method(&"set_bars_visible"):
		host.set_bars_visible(false)
	panel.show_window(host)
	panel.tree_exiting.connect(func() -> void:
		container.visible = true
		if host != null and host.has_method(&"set_bars_visible"):
			host.set_bars_visible(true))


func _refresh_after_change() -> void:
	call_deferred("_rebuild_after_change")


func _rebuild_after_change() -> void:
	_classify_heroes()
	_refresh_list()
