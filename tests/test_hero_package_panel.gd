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
		assert_gt(detail.split_requested.get_connections().size(), 0, "split_requested 已接（分解闭环）")
		assert_gt(detail.upgrade_skill_requested.get_connections().size(), 0, "upgrade_skill_requested 已接（技能升级闭环）")
		detail.queue_free()
	panel.remove_window()
	root.queue_free()
