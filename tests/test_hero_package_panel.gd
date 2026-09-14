extends GutTest
# HeroPackagePanel 测试（2026-07-13 重建）：背景 list_bg + 4 class tab + ScrollContainer 网格 ReadheroIcon 头像 + close/碎片。
# 替原 Phase 5 文字行测试（英雄从 container 直接 Button 改为 _grid cell + gui_input）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_panel_lists_heroes_in_grid() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	mgr.add_hero(2)
	var panel := HeroPackagePanel.new("heropackage", {})
	panel.setup_panel(mgr, cm)
	panel.show_window(root)
	# 2 英雄 → _grid 2 cell（替原 container 文字 Button 行）
	assert_eq(panel._grid.get_child_count(), 2, "2 英雄 cell（ReadheroIcon 头像替文字行）")
	panel.remove_window()
	root.queue_free()


# 点英雄 → 打开 HeroDetailPanel（源 doClickInHeroLayer clickHero）。
func test_hero_click_opens_detail() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	var panel := HeroPackagePanel.new("heropackage", {})
	panel.setup_panel(mgr, cm)
	panel.show_window(root)
	var hero: HeroInstance = mgr.heroes.values()[0]
	panel._on_hero_clicked(hero)   # gui_input 信号测试复杂，直接调处理函数
	var has_detail: bool = false
	for c in root.get_children():
		if c is HeroDetailPanel:
			has_detail = true
			c.queue_free()
			break
	assert_true(has_detail, "点英雄 → HeroDetailPanel")
	panel.remove_window()
	root.queue_free()


# _on_hero_clicked 接 HeroDetailPanel 升星/分解/技能升级信号（2026-07-05 第 14 段，重建后保持）。
func test_hero_click_connects_action_signals() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	var panel := HeroPackagePanel.new("heropackage", {})
	panel.setup_panel(mgr, cm)
	panel.show_window(root)
	var hero: HeroInstance = mgr.heroes.values()[0]
	panel._on_hero_clicked(hero)
	var detail: HeroDetailPanel = null
	for c in root.get_children():
		if c is HeroDetailPanel:
			detail = c
			break
	assert_not_null(detail, "HeroDetailPanel 弹出")
	if detail != null:
		assert_gt(detail.evolve_requested.get_connections().size(), 0, "evolve_requested 已接（升星闭环）")
		# split 入口搬回 hero_package（herosplit 按钮），不再从 hero_detail 进（4→2 回源 2026-07-18）。
		assert_gt(detail.upgrade_skill_requested.get_connections().size(), 0, "upgrade_skill_requested 已接（技能升级闭环）")
		detail.queue_free()
	panel.remove_window()
	root.queue_free()


# item scale=1/CS（补偿源 contentScaleFactor 1.28）+ 同行 bg 不重叠验证（2026-07-16 bg 313 偏大重叠修复）。
func test_grid_item_scaled_no_overlap() -> void:
	var root := Control.new()
	root.size = Vector2(960, 640)
	add_child(root)
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	mgr.add_hero(2)
	mgr.add_hero(3)
	mgr.add_hero(4)
	var panel := HeroPackagePanel.new("heropackage", {})
	panel.setup_panel(mgr, cm)
	panel.show_window(root)
	await wait_physics_frames(3)   # 等 Control layout
	var items: Array = []
	for c in panel._grid.get_children():
		if c is HeroPackageItem:
			items.append(c)
	assert_gt(items.size(), 1, "≥2 item 验证同行重叠")
	var first: HeroPackageItem = items[0]
	assert_almost_eq(first.scale.x, 1.0, 0.01, "item 无整卡缩放（2026-08-28 根修拆 1/CS 链，点空间直译）")
	# bg 显示尺寸 = 313×123px ÷CS = 244.34×96.00（源 createSprite 无条目 → 纹理/CS）
	var bg0: TextureRect = _first_texture(first)
	if bg0 != null:
		assert_almost_eq(bg0.size.x, 313.0 / HeroPackageItem.CONTENT_SCALE, 0.5, "bg 显示宽=313/CS")
		assert_almost_eq(bg0.size.y, 123.0 / HeroPackageItem.CONTENT_SCALE, 0.5, "bg 显示高=123/CS")
	# 同行前两 item 的 bg 全局 rect 不重叠（源列距 260 > bg 244.34，间隙 15.66）
	var bg1: TextureRect = _first_texture(items[0])
	var bg2: TextureRect = _first_texture(items[1])
	if bg1 != null and bg2 != null:
		var r1: Rect2 = bg1.get_global_rect()
		var r2: Rect2 = bg2.get_global_rect()
		var gap: float = r2.position.x - r1.end.x
		print("bg1=" + str(r1) + " bg2=" + str(r2) + " gap=" + str(gap))
		assert_almost_eq(gap, 260.0 - 313.0 / HeroPackageItem.CONTENT_SCALE, 1.0, "列间隙=260−bg宽≈15.7（源）")
	panel.remove_window()
	root.queue_free()


# 源 doChangeList z-order（heropackage.lua:16-23）：选中 tab setZOrder(3) 凸出 list_bg(z=2)，
# 未选中 setZOrder(1) 被背景框挡左缘。静态 z：list_bg=2(:497)/buttonLabel=4(:542)/draglist=10(:762)。
func test_tab_zorder_matches_source() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	var panel := HeroPackagePanel.new("heropackage", {})
	panel.setup_panel(mgr, cm)
	panel.show_window(root)
	# 默认 clid="all"：选中 tab z=13（凸出），其余 z=11（2026-08-28 根修：源 3/1 相对关系 + 11 基准位，
	# HeroScroll z10 全宽化后 tab 恒在其上保点击）
	assert_eq((panel._tabs["all"] as TextureButton).z_index, 13, "all 选中 z=13")
	assert_eq((panel._tabs["front"] as TextureButton).z_index, 11, "front 未选中 z=11")
	# 静态 z（照源 ui_info z 值）：ListBg=2 / label=12 / HeroScroll(draglist)=10
	var content: Control = panel._scroll.get_parent() as Control
	assert_eq((content.get_node("ListBg") as TextureRect).z_index, 2, "ListBg z=2（源 list_bg）")
	assert_eq((panel._tab_labels["all"] as Label).z_index, 15, "label z=15（恒在按钮 z11/13 上；旧 12 被选中按钮 13 盖文字回归）")
	assert_eq(panel._scroll.z_index, 10, "HeroScroll z=10（源 draglist zorder）")
	# 切到 front：front 升 z=13，all 回 z=11
	panel._on_tab_pressed("front")
	assert_eq((panel._tabs["front"] as TextureButton).z_index, 13, "切 front 后 front z=13")
	assert_eq((panel._tabs["all"] as TextureButton).z_index, 11, "切 front 后 all 回 z=11")
	panel.remove_window()
	root.queue_free()


# Phase A 重构（2026-07-18）：item bg 在 content 子场景下，递归扫描（坑 6 .tscn 多一层 content）。
static func _first_texture(node: Node) -> TextureRect:
	for c in node.get_children():
		if c is TextureRect:
			return c as TextureRect
		var sub: TextureRect = _first_texture(c)
		if sub != null:
			return sub
	return null


# ── 两件套守卫（批 1 Task 9，2026-08-15）：herosplit 静态化 + listLine 行模板 + theme variation + 零静态 .new() ──

const CS: float = 1.28125
const LINE_W: float = 388.0 / CS
const LINE_H: float = 22.0 / CS


func _instantiate_content() -> Control:
	var scene: PackedScene = load("res://scenes/ui/hero_package_content.tscn") as PackedScene
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	return inst


func _assert_color_eq(actual: Color, expect: Color, msg: String) -> void:
	assert_almost_eq(actual.r, expect.r, 0.001, msg + " [r]")
	assert_almost_eq(actual.g, expect.g, 0.001, msg + " [g]")
	assert_almost_eq(actual.b, expect.b, 0.001, msg + " [b]")


# 源 heropackage.lua:680-753 herosplit 组（Scale9 classbtn cap(40,25,40,25) + icon + label）静态化：
# 按钮 position=ccp(695,60)（无 offsetx）中心锚，scaleSize=DGSizeMake(120,75)=(93.75,58.59)，
# → 中心 to_godot(695,60)=(775,500)；icon fix_height=24 中心 (20,29)；label DGccp(72,37)=(56.25,28.9) 中心。
# herosplit_tag 不迁移：源 refreshSplitButton(:455-478) 双分支 setVisible(false) 死代码，受控裁剪。
# ⚠️源按钮默认隐藏（endPoint=0 永假），本项目作为 HeroSplitWindow 唯一入口常驻（受控偏离，见任务报告）。
func test_content_herosplit_static_follows_source() -> void:
	var inst: Control = _instantiate_content()
	var btn: Button = inst.get_node_or_null("%HerosplitBtn") as Button
	assert_not_null(btn, "herosplit 按钮常驻 tscn（Button）")
	if btn == null:
		return
	assert_eq(btn.theme_type_variation, &"HeroPackageSplitBtn", "herosplit 走 9 宫格 variation")
	assert_almost_eq((btn.offset_left + btn.offset_right) / 2.0, 695.0, 0.5, "herosplit 中心 x=775（源 695 无 offsetx）")
	assert_almost_eq((btn.offset_top + btn.offset_bottom) / 2.0, 420.0, 0.5, "herosplit 中心 y=500")
	assert_almost_eq(btn.offset_right - btn.offset_left, 120.0 * 0.78125, 0.5, "herosplit 宽=DG(120)=93.75")
	assert_almost_eq(btn.offset_bottom - btn.offset_top, 75.0 * 0.78125, 0.5, "herosplit 高=DG(75)=58.59")
	var icon: TextureRect = btn.get_node_or_null("%HerosplitIcon") as TextureRect
	assert_not_null(icon, "icon 常驻（equip_soulstone_tag）")
	if icon != null:
		assert_almost_eq((icon.offset_left + icon.offset_right) / 2.0, 20.0, 0.5, "icon 中心 x=20（源 ccp(20,29)）")
		assert_almost_eq((icon.offset_top + icon.offset_bottom) / 2.0, 58.59 - 29.0, 0.5, "icon 中心 y=58.59-29")
		assert_almost_eq(icon.offset_bottom - icon.offset_top, 24.0, 0.5, "icon 高=源 fix_height 24")
	var lbl: Label = btn.get_node_or_null("%HerosplitLabel") as Label
	assert_not_null(lbl, "label 常驻（分解）")
	if lbl != null:
		assert_almost_eq((lbl.offset_left + lbl.offset_right) / 2.0, 72.0 * 0.78125, 0.5, "label 中心 x=DG(72)=56.25")
		assert_almost_eq((lbl.offset_top + lbl.offset_bottom) / 2.0, 58.59 - 37.0 * 0.78125, 0.5, "label 中心 y=DG 翻转")
		assert_eq(lbl.theme_type_variation, &"HeroPackageSplitLabel", "label 走 variation")
	assert_null(inst.get_node_or_null("%HerosplitTag"), "herosplit_tag 不迁移（源死代码受控裁剪）")


# 源 4 tab label pos=ccp(710+offsetx, 365/304/244/184) 中心锚 → Godot 中心 (770, 195/256/316/376)。
# 旧实现运行时对齐 button 框（中心 767）→ 本批照源直译进 tscn（label x 源比 button 右偏 3px 视觉微调）。
func test_content_tab_labels_follows_source() -> void:
	var inst: Control = _instantiate_content()
	var expects: Dictionary = {
		"TabAllLabel": Vector2(690.0, 115.0),
		"TabFrontLabel": Vector2(690.0, 176.0),
		"TabMiddleLabel": Vector2(690.0, 236.0),
		"TabBackLabel": Vector2(690.0, 296.0),
	}
	for name in expects:
		var lbl: Label = inst.get_node("%" + name) as Label
		assert_almost_eq((lbl.offset_left + lbl.offset_right) / 2.0, (expects[name] as Vector2).x, 0.5,
			name + " 中心 x=770（源 710+offsetx=690）")
		assert_almost_eq((lbl.offset_top + lbl.offset_bottom) / 2.0, (expects[name] as Vector2).y, 0.5,
			name + " 中心 y 照源")
		assert_eq(lbl.theme_type_variation, &"HeroPackageTabLabel", name + " 走 variation")
		assert_false(lbl.has_theme_font_size_override("font_size"), name + " 无字号 override（theme 管）")


# 源静态 z：list_bg=2(:497) / buttonLabel=4(:542) / draglist zorder=10(:762)——tscn 固化（旧实现 panel 运行时设）。
func test_content_static_zorder() -> void:
	var inst: Control = _instantiate_content()
	assert_eq((inst.get_node("ListBg") as CanvasItem).z_index, 2, "ListBg z=2（tscn 固化）")
	assert_eq((inst.get_node("%HeroScroll") as CanvasItem).z_index, 10, "HeroScroll z=10（tscn 固化）")
	# 2026-08-28 根修：HeroScroll 照源 cliprect 全宽化（z10）→ tab btn z=11/label z=15 恒在其上
	# 绘制；label 15 > 选中按钮 13（z12 时选中 tab 文字被按钮贴图盖住，PIL 白像素 11 vs 正常 1501 实证）。
	# 注意：z 只保绘制；点击命中靠 panel 运行时 move_child tab 到 scroll 后（见树序守卫测试）。
	for name in ["TabAllBtn", "TabFrontBtn", "TabMiddleBtn", "TabBackBtn"]:
		assert_eq((inst.get_node("%" + name) as CanvasItem).z_index, 11, name + " z=11（tscn 固化）")
	for name in ["TabAllLabel", "TabFrontLabel", "TabMiddleLabel", "TabBackLabel"]:
		assert_eq((inst.get_node("%" + name) as CanvasItem).z_index, 15, name + " z=15（tscn 固化，恒在按钮上）")


# listLine 行模板（源 prepareLoad:398-411：line 300×16 + equip_detail_title_bg 388×22 + size20 标题）。
func test_list_line_template_static_tree() -> void:
	var scene: PackedScene = load("res://scenes/ui/hero_package_list_line.tscn") as PackedScene
	assert_not_null(scene, "list_line 行模板 tscn 存在")
	if scene == null:
		return
	var line: Control = scene.instantiate() as Control
	add_child_autofree(line)
	assert_almost_eq(line.offset_right - line.offset_left, LINE_W, 0.1, "line 宽=title_bg 388/CS")
	assert_almost_eq(line.offset_bottom - line.offset_top, LINE_H, 0.1, "line 高=title_bg 22/CS")
	assert_not_null((line.get_node("Bg") as TextureRect).texture, "Bg 贴图接线（equip_detail_title_bg）")
	var lbl: Label = line.get_node("%LineLabel") as Label
	assert_eq(lbl.theme_type_variation, &"HeroPackageListLineLabel", "line 标题走 variation")


# 源 listLine 定位：中心 x=365 全屏（getLinepos:306 两列中缝）→ GridHost 局部 260；
# y 在已拥有/未拥有交界（源 gap 中点，本项目无 -30 gap → 交界即近似，受控偏离见报告）。
func test_list_line_position_follows_source() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)   # 1 拥有（占 row0）→ 边界在 row0/row1 之间
	# miss 列表只收有碎片的未拥有（get_miss_list stone_amount>0）：喂 1 片（<召唤需求）→ tid=2 追加尾部
	mgr.items[ReadheroHandbook.get_stone_id(2, cm)] = 1
	var panel := HeroPackagePanel.new("heropackage", {})
	panel.setup_panel(mgr, cm)
	panel.show_window(root)
	var line: Control = null
	for c in panel._grid.get_children():
		if c != null and is_instance_valid(c) and not (c is HeroPackageItem) and c.get_meta(&"list_line", false):
			line = c
			break
	assert_not_null(line, "存在分隔线（1 拥有 + miss 分界）")
	if line != null:
		assert_almost_eq(line.position.x + line.size.x * 0.5, 365.0, 1.0, "line 中心 x=中缝 365 全屏（源 getLinepos；2026-08-28 根修 scroll 全宽后 GridHost 局部=全屏）")
		assert_almost_eq(line.position.y + line.size.y * 0.5, 115.0, 1.0, "line 中心 y=边界 100+gap 半 15（源 gap 中点）")
	panel.remove_window()
	root.queue_free()


# 两件套红线：静态结构零 .new(（herosplit/listLine/占位 spacer 全静态或模板 instantiate）。
# 白名单 = 5 个业务弹窗工厂（HeroDetailPanel/StoneDetailPanel/HeroSplitWindow
# + 2026-09-09 召唤链 HeroAwakePanel 卡展示 / SummonConfirm 确认框——SummonConfirm
# 是 Control 非 PopWindow，工厂 .new 挂 panel；GetNewHeroPopup 由卡 close_handler 链式
# 工厂（在回调里 .new，也被本计数覆盖））。
# 计数用 ".new("（带参构造 HeroDetailPanel.new("id") 不含 ".new()" 字面，旧写法漏检）。
func test_panel_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/hero_package_panel.gd")
	assert_eq(text.count(".new("), text.count("HeroDetailPanel.new(") + text.count("StoneDetailPanel.new(")
		+ text.count("HeroSplitWindow.new(") + text.count("HeroAwakePanel.new(")
		+ text.count("SummonConfirm.new(") + text.count("GetNewHeroPopup.new("),
		"静态节点零 .new(，仅 5 弹窗工厂白名单（召唤链 +2）")


# herosplit 按钮 → HeroSplitWindow（2026-07-19 接线，本批静态化后行为保持）。
func test_herosplit_pressed_opens_window() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	var panel := HeroPackagePanel.new("heropackage", {})
	panel.setup_panel(mgr, cm, PlayerData.new(cm))
	panel.show_window(root)
	panel._on_herosplit_pressed()
	var has_split: bool = false
	for c in root.get_children():
		if c is HeroSplitWindow:
			has_split = true
			c.queue_free()
			break
	assert_true(has_split, "herosplit 按钮 → HeroSplitWindow")
	panel.remove_window()
	root.queue_free()


# 2026-08-30 点击回归修复守卫：Godot 输入命中按树序逆序遍历，z_index 只影响绘制不参与
# 命中——d62b856 把 HeroScroll 照源 cliprect 全宽化（rect 0~800 覆盖 tab x 634.7~739.3）
# 且 mf=STOP，tscn 树序 tab 在 scroll 前时点击全被 scroll 吞（z=11 修绘制不修命中）。
# panel 须运行时把 tab btn+label move_child 到 scroll 之后保命中（视觉不变：z 恒绘于其上）。
func test_tab_input_priority_over_scroll_tree_order() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	var panel := HeroPackagePanel.new("heropackage", {})
	panel.setup_panel(mgr, cm)
	panel.show_window(root)
	await wait_physics_frames(3)
	var content: Control = panel._scroll.get_parent() as Control
	# 前提事实：scroll rect 确实覆盖 tab 区域（全宽化是视觉根修产物，不可缩回）
	var scroll_rect: Rect2 = panel._scroll.get_rect()
	var front_btn: Control = content.get_node("%TabFrontBtn") as Control
	assert_true(scroll_rect.intersects(front_btn.get_rect()),
		"HeroScroll rect 覆盖 tab（照源 cliprect 全宽既成事实）")
	# 守卫：4 tab 按钮 + label 树序都必须在 HeroScroll 之后（点击命中优先）
	var scroll_idx: int = panel._scroll.get_index()
	for name in ["TabAllBtn", "TabFrontBtn", "TabMiddleBtn", "TabBackBtn",
			"TabAllLabel", "TabFrontLabel", "TabMiddleLabel", "TabBackLabel"]:
		var node: Control = content.get_node("%" + name) as Control
		assert_gt(node.get_index(), scroll_idx,
			name + " 树序在 HeroScroll 后（命中按树序，z_index 不参与）")
	panel.remove_window()
	root.queue_free()


# variation 数值断言走 theme 资源表项（方法学沉淀：GUT 节点级不解析 variation）。
func test_theme_hero_package_entries() -> void:
	var theme: Theme = load("res://resources/themes/default_theme.tres") as Theme
	# tab label（源 :535-548 fontinfo ui_normal_button + size=20：17 号白+阴影(63,5,0)(0,2)，size 覆盖）
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "HeroPackageTabLabel"), 20,
		"tab 字号 20 照源 size 覆盖")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "HeroPackageTabLabel") as Color,
		Color.WHITE, "tab 白色照源")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_shadow_color", "HeroPackageTabLabel") as Color,
		Color(63.0 / 255.0, 5.0 / 255.0, 0.0), "tab 阴影 (63,5,0) 照源 ui_normal_button")
	# herosplit label（源 :723-741 size24 白 + shadow(42,31,22) offset(0,2)）
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "HeroPackageSplitLabel"), 24,
		"herosplit 字号 24 照源")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_shadow_color", "HeroPackageSplitLabel") as Color,
		Color(42.0 / 255.0, 31.0 / 255.0, 22.0 / 255.0), "herosplit 阴影 (42,31,22) 照源")
	# listLine 标题（源 prepareLoad:407-409 size20 ccc3(231,206,19)）
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "HeroPackageListLineLabel"), 20,
		"listLine 字号 20 照源")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "HeroPackageListLineLabel") as Color,
		Color(231.0 / 255.0, 206.0 / 255.0, 19.0 / 255.0), "listLine 色 (231,206,19) 照源")
	# item 名字（源 heroitem.lua:32 size20 白 + 黑阴影(0,2)，readhero.createHeroNameByInfo 同规格）
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "HeroPackageNameLabel"), 20,
		"item 名字字号 20 照源")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_shadow_color", "HeroPackageNameLabel") as Color,
		Color.BLACK, "item 名字黑阴影照源")
	# item 石头进度文字（源 heroitem.lua:151 createttf(text,18) 无色配置→白）
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "HeroPackageStoneLabel"), 18,
		"item 石头文字字号 18 照源（旧实现 14 为随手值修正）")


# ── 召唤动画链（2026-09-09 补全：源 heropackage.lua clickMissHero :160-172
#    showConfirmDialog → doSummon → doSummonReply :107-124 announce popHeroCard
#    → popherocard doClickLayer → getNewHero 展示 → 确定）──
# 此前迁移漏整链：点击直接静默召唤（无确认框、无卡展示、无新英雄展示动画）。

const SUMMON_LSTR_KEY: String = "HEROPACKAGE.SUMMON_HERO_TAKES_D_GOLD_COINS_CONFIRM_TO_CALL"

func _find_first_of_type(node: Node, type_class: Variant) -> Node:
	for c in node.get_children():
		if is_instance_of(c, type_class):
			return c
		var found: Node = _find_first_of_type(c, type_class)
		if found != null:
			return found
	return null


func test_summon_flow_confirm_card_and_new_hero() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := HeroManager.new(cm)
	# tid=2 初始 1 星：召唤需 10 碎片（HeroStars[1].Summon Fragments）+ 1000 金币
	mgr.items[ReadheroHandbook.get_stone_id(2, cm)] = 10
	mgr.gold = 2000
	mgr.add_hero(1)
	var panel := HeroPackagePanel.new("heropackage", {})
	panel.setup_panel(mgr, cm)
	panel.show_window(root)
	panel._on_miss_clicked({"tid": 2, "miss": true})
	# ① 确认框弹出（源 :163-172），确认前不召唤
	var dlg: SummonConfirm = _find_first_of_type(panel, SummonConfirm) as SummonConfirm
	assert_not_null(dlg, "可召唤 miss 点击 → 召唤确认框（源 showConfirmDialog）")
	if dlg == null:
		panel.remove_window()
		root.queue_free()
		return
	assert_null(mgr.find_hero_by_tid(2), "确认前不执行召唤")
	assert_true(dlg.get_message().find(str(ReadheroHandbook.get_summon_cost(2, cm))) != -1,
		"确认框文案含金币花费（源 getSummonCost %d 格式化）")
	# ② 确认 → 召唤 + 英雄卡弹窗（源 doSummonReply → announce popHeroCard）
	dlg._on_ok()
	assert_not_null(mgr.find_hero_by_tid(2), "确认后召唤成功（hero_evolve miss 分支）")
	await get_tree().process_frame
	var card: HeroAwakePanel = _find_first_of_type(root, HeroAwakePanel) as HeroAwakePanel
	assert_not_null(card, "召唤成功弹英雄卡展示（源 popHeroCard：bg/light/卡/FCA 动画）")
	if card == null:
		panel.remove_window()
		root.queue_free()
		return
	# ③ 卡点击 → 新英雄展示（源 doClickLayer amount<=1 → getNewHero）
	card._on_click_layer()
	await get_tree().process_frame
	var popup: GetNewHeroPopup = _find_first_of_type(root, GetNewHeroPopup) as GetNewHeroPopup
	assert_not_null(popup, "卡点击 → getNewHero 新英雄展示弹窗")
	if popup == null:
		panel.remove_window()
		root.queue_free()
		return
	# ④ 确定 → 关闭
	popup._on_ok()
	await get_tree().process_frame
	assert_false(is_instance_valid(popup) and popup.is_inside_tree(),
		"确定关闭 getNewHero（源 dookTouch destroy；freed 实例按判例 is_instance_valid 先判）")
	panel.remove_window()
	root.queue_free()


# ── 列表拖拽滚动 + 行点击 tap 判定（2026-09-10：魂石修复后可召唤置顶、列表变长，
#    暴露按下即触发进详情 + ScrollContainer 桌面无鼠标拖拽两个缺口；
#    源 draglist.lua:906 not dragMode 才 doClickIn，照 ranklist/evolve_equip 修复轮四范式）──

static func _mb(pressed: bool, pos: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.global_position = pos
	ev.position = pos
	return ev


# 纯按下（未释放）不开详情：拖拽滚动的起始 press 不误触。
func test_item_press_only_does_not_open_detail() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	var panel := HeroPackagePanel.new("heropackage", {})
	panel.setup_panel(mgr, cm)
	panel.show_window(root)
	var hero: HeroInstance = mgr.heroes.values()[0]
	panel._on_item_gui_input(_mb(true, Vector2(200, 150)), hero)
	assert_true(panel.container.visible,
		"纯 press 不开详情（源 draglist release 才 doClickIn，2026-09-10 前按下即触发）")
	panel.remove_window()
	root.queue_free()


# 按住拖动（release 位移 >8px 阈值）不触发详情：拖拽滚动全程可放心按在卡片上。
func test_item_drag_release_does_not_open_detail() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	var panel := HeroPackagePanel.new("heropackage", {})
	panel.setup_panel(mgr, cm)
	panel.show_window(root)
	var hero: HeroInstance = mgr.heroes.values()[0]
	panel._on_item_gui_input(_mb(true, Vector2(200, 150)), hero)
	panel._on_item_gui_input(_mb(false, Vector2(200, 185)), hero)   # 位移 35px > 8px 阈值
	assert_true(panel.container.visible, "拖动后 release 位移超阈值 → 不开详情")
	panel.remove_window()
	root.queue_free()


# 完整 tap 链（press + release 位移 <8px）仍进英雄详情。
func test_item_tap_within_threshold_opens_detail() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	var panel := HeroPackagePanel.new("heropackage", {})
	panel.setup_panel(mgr, cm)
	panel.show_window(root)
	var hero: HeroInstance = mgr.heroes.values()[0]
	panel._on_item_gui_input(_mb(true, Vector2(200, 150)), hero)
	panel._on_item_gui_input(_mb(false, Vector2(203, 152)), hero)   # 位移 ~3.6px < 8px
	assert_false(panel.container.visible, "tap（release 位移 <8px）→ 进英雄详情（源 doClickIn）")
	panel.remove_window()
	root.queue_free()


# 召唤确认框全屏模态（2026-09-10 二轮根修）：_ready 在树内 set_anchors_preset(FULL_RECT)
# 会调整 offsets 保持当前 rect(0×0) 不变 → 尺寸恒 0 → 不可见+无命中+模态失效
# （用户实机「点击可召唤英雄无反应」=确认框弹出但 0 尺寸不渲染）。修复=改
# set_anchors_and_offsets_preset 真正拉满父 rect。
func test_summon_confirm_full_rect_when_parented() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	var panel := HeroPackagePanel.new("heropackage", {})
	panel.setup_panel(mgr, cm)
	panel.show_window(root)
	var dlg := SummonConfirm.new()
	dlg.set_message("test")
	panel.add_child(dlg)
	await get_tree().process_frame
	assert_eq(dlg.size, Vector2(800.0, 480.0), "SummonConfirm 挂 panel 后全屏（修复前 size=0 不可见）")
	assert_eq(dlg.mouse_filter, Control.MOUSE_FILTER_STOP, "全屏 STOP 模态拦截底层")
	assert_eq(dlg.z_index, 50, "绘制层盖宿主 content 内 z 10~15（修复前 z=0 被列表盖，文字只从行缝漏出）")
	dlg.queue_free()
	panel.remove_window()
	root.queue_free()


# ShopRefreshConfirm 同病守卫（shop 挂 container.add_child 同样在树内 _ready）。
func test_shop_refresh_confirm_full_rect_when_parented() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	var panel := HeroPackagePanel.new("heropackage", {})
	panel.setup_panel(mgr, cm)
	panel.show_window(root)
	var popup := ShopRefreshConfirm.new()
	popup.set_message("test")
	panel.container.add_child(popup)
	await get_tree().process_frame
	assert_eq(popup.size, Vector2(800.0, 480.0), "ShopRefreshConfirm 挂 container 后全屏")
	popup.queue_free()
	panel.remove_window()
	root.queue_free()


# 鼠标拖拽滚动（DragScrollHelper 补源 draglist 手势）：上滑 → scroll_vertical 增。
# miss 段照源 get_miss_list 只收持有碎片的未拥有英雄——须塞碎片列表才超视口可滚。
func test_drag_helper_scrolls_hero_list() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := HeroManager.new(cm)
	mgr.add_hero(1)
	for tid: int in range(2, 13):   # 11 个未拥有英雄各 1 碎片 → 12 条 6 行 648px > 348 视口
		mgr.items[ReadheroHandbook.get_stone_id(tid, cm)] = 1
	var panel := HeroPackagePanel.new("heropackage", {})
	panel.setup_panel(mgr, cm)
	panel.show_window(root)
	await get_tree().process_frame   # 布局完成再读 global_rect
	var scroll: ScrollContainer = panel._scroll
	var rect: Rect2 = scroll.get_global_rect()
	var press_pos: Vector2 = rect.position + rect.size * 0.5
	var state: Dictionary = {}
	var before: float = scroll.scroll_vertical
	DragScrollHelper.handle_input(scroll, _mb(true, press_pos), state)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.global_position = press_pos + Vector2(0, -60.0)   # 上滑 60px 看下方内容
	motion.position = motion.global_position
	DragScrollHelper.handle_input(scroll, motion, state)
	assert_gt(scroll.scroll_vertical, before,
		"鼠标拖拽上滑滚动英雄包裹列表（源 draglist drag；Godot 桌面 ScrollContainer 无拖拽）")
	panel.remove_window()
	root.queue_free()


# 2026-09-14 翻页顺序根修守卫：点英雄打开详情须传"当前 tab 已拥有英雄列表"
# （照源 heropackage.lua:209-221），顺序 = order_heroes 等级→星级→rank 降序——
# 旧实现详情内部取获得序致左右切换与列表显示不一致（用户反馈"切换顺序错乱"）。
func test_hero_click_passes_ordered_paging_list() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := HeroManager.new(cm)
	var a: HeroInstance = mgr.get_hero(mgr.add_hero(1))
	var b: HeroInstance = mgr.get_hero(mgr.add_hero(2))
	var c: HeroInstance = mgr.get_hero(mgr.add_hero(3))
	a.level = 1   # 获得序 a,b,c；等级序 c(3) > b(2) > a(1)，两序刻意相反
	b.level = 2
	c.level = 3
	var panel := HeroPackagePanel.new("heropackage", {})
	panel.setup_panel(mgr, cm)
	panel.show_window(root)
	panel._on_hero_clicked(a)
	var detail: HeroDetailPanel = null
	for ch in root.get_children():
		if ch is HeroDetailPanel:
			detail = ch
			break
	assert_not_null(detail, "HeroDetailPanel 弹出")
	if detail != null:
		assert_eq(detail._hero_ids, [c.inst_id, b.inst_id, a.inst_id],
			"翻页列表 = order_heroes 等级降序（回归点：旧获得序 [a,b,c]）")
		assert_eq(detail._current_idx, 2, "点击 a 在翻页列表中的索引")
		detail.queue_free()
	panel.remove_window()
	root.queue_free()
