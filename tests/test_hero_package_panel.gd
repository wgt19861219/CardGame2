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
	assert_almost_eq(first.scale.x, 1.0 / HeroPackageItem.CONTENT_SCALE, 0.01, "item scale=1/CS（0.78）补偿 contentScaleFactor")
	# 同行前两 item 的 bg 全局 rect 不重叠
	var bg1: TextureRect = _first_texture(items[0])
	var bg2: TextureRect = _first_texture(items[1])
	if bg1 != null and bg2 != null:
		var r1: Rect2 = bg1.get_global_rect()
		var r2: Rect2 = bg2.get_global_rect()
		var gap: float = r2.position.x - r1.end.x
		print("bg1=" + str(r1) + " bg2=" + str(r2) + " gap=" + str(gap))
		assert_true(gap > 0.0, "同行 bg 不重叠（gap=" + str(gap) + "）")
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
	# 默认 clid="all"：选中 tab z=3（凸出），其余 z=1（被 list_bg z=2 挡）
	assert_eq((panel._tabs["all"] as TextureButton).z_index, 3, "all 选中 z=3")
	assert_eq((panel._tabs["front"] as TextureButton).z_index, 1, "front 未选中 z=1")
	# 静态 z（照源 ui_info z 值）：ListBg=2 / label=4 / HeroScroll(draglist)=10
	var content: Control = panel._scroll.get_parent() as Control
	assert_eq((content.get_node("ListBg") as TextureRect).z_index, 2, "ListBg z=2（源 list_bg）")
	assert_eq((panel._tab_labels["all"] as Label).z_index, 4, "label z=4（源 buttonLabel）")
	assert_eq(panel._scroll.z_index, 10, "HeroScroll z=10（源 draglist zorder）")
	# 切到 front：front 升 z=3，all 回 z=1
	panel._on_tab_pressed("front")
	assert_eq((panel._tabs["front"] as TextureButton).z_index, 3, "切 front 后 front z=3")
	assert_eq((panel._tabs["all"] as TextureButton).z_index, 1, "切 front 后 all 回 z=1")
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
	assert_almost_eq((btn.offset_left + btn.offset_right) / 2.0, 775.0, 0.5, "herosplit 中心 x=775（源 695 无 offsetx）")
	assert_almost_eq((btn.offset_top + btn.offset_bottom) / 2.0, 500.0, 0.5, "herosplit 中心 y=500")
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
		"TabAllLabel": Vector2(770.0, 195.0),
		"TabFrontLabel": Vector2(770.0, 256.0),
		"TabMiddleLabel": Vector2(770.0, 316.0),
		"TabBackLabel": Vector2(770.0, 376.0),
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
	for name in ["TabAllLabel", "TabFrontLabel", "TabMiddleLabel", "TabBackLabel"]:
		assert_eq((inst.get_node("%" + name) as CanvasItem).z_index, 4, name + " z=4（tscn 固化）")


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
	mgr.fragments[ReadheroHandbook.get_stone_id(2, cm)] = 1
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
		assert_almost_eq(line.position.x + line.size.x * 0.5, 260.0, 1.0, "line 中心 x=中缝 260（源 365）")
		assert_almost_eq(line.position.y + line.size.y * 0.5, 115.0, 1.0, "line 中心 y=边界 100+gap 半 15（源 gap 中点）")
	panel.remove_window()
	root.queue_free()


# 两件套红线：静态结构零 .new(（herosplit/listLine/占位 spacer 全静态或模板 instantiate）。
# 白名单 = 3 个业务弹窗工厂（HeroDetailPanel/StoneDetailPanel/HeroSplitWindow）。
# 计数用 ".new("（带参构造 HeroDetailPanel.new("id") 不含 ".new()" 字面，旧写法漏检）。
func test_panel_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/hero_package_panel.gd")
	assert_eq(text.count(".new("), text.count("HeroDetailPanel.new(") + text.count("StoneDetailPanel.new(")
		+ text.count("HeroSplitWindow.new("), "静态节点零 .new(，仅 3 弹窗工厂白名单")


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
