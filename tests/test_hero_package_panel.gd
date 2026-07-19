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
			return c
		var sub: TextureRect = _first_texture(c)
		if sub != null:
			return sub
	return null
