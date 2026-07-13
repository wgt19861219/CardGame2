extends GutTest
# Phase 6 package 复刻 View 主壳：PackagePanel 测试（2026-07-05 第 23 段）。
# 照源 package.lua 两 identity 多 tab + 4 列网格。Logic 走 EquipmentClassifier.classify。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 从 Equip 表动态取某 Category 的一个 id（避免硬编码 id 脆弱）。
func _find_equip_id_by_category(category: String) -> int:
	var raw: Dictionary = cm.get_raw_table(&"Equip")
	for tid_str in raw:
		if String(raw[tid_str].get(&"Category", "")) == category:
			return int(tid_str)
	return 0


# 从 Fragment 表取一个英雄产物配方（key<100）：{tid, frag_id}。
func _find_hero_fragment_recipe() -> Dictionary:
	var raw: Dictionary = cm.get_raw_table(&"Fragment")
	for tid_str in raw:
		if int(tid_str) < 100:
			return {"tid": int(tid_str), "frag_id": int(raw[tid_str].get(&"Fragment ID", 0))}
	return {}


func _make_panel(p_identity: String, p_pd: PlayerData) -> PackagePanel:
	var panel := PackagePanel.new(p_identity, {})
	panel.setup_panel(cm, p_pd)
	return panel


# ── identity → tab 集（源 packageres.list_key）──

func test_setup_package_5_tabs() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	assert_eq(panel._tab_buttons.size(), 5, "package identity 5 tab（all/equip/scroll/stone/consume）")
	assert_eq(panel._tabs, ["all", "equip", "scroll", "stone", "consume"], "tab 顺序照源 packageres")
	assert_true(bool(panel._tab_buttons["all"].button_pressed), "默认 all tab 选中")
	panel.remove_window()
	root.queue_free()


func test_setup_fragment_3_tabs() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := _make_panel("fragment", pd)
	panel.show_window(root)
	assert_eq(panel._tab_buttons.size(), 3, "fragment identity 3 tab（all/equip/scroll）")
	assert_eq(panel._tabs, ["all", "equip", "scroll"], "tab 顺序照源 packageres")
	panel.remove_window()
	root.queue_free()


# ── 网格填充（classify 输出 → cell）──

func test_package_grid_fills_from_items() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_id_by_category("EQUIP.PARTS")
	assert_gt(eid, 0, "PARTS id 存在")
	pd.add_item(eid, 3)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	assert_eq(panel._grid.get_child_count(), 1, "all tab 显示 1 个 PARTS cell")
	panel.remove_window()
	root.queue_free()


func test_fragment_grid_fills_from_fragments() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var recipe: Dictionary = _find_hero_fragment_recipe()
	assert_false(recipe.is_empty(), "Fragment 表有英雄配方")
	pd.hero_manager.add_fragment(int(recipe["frag_id"]), 5)
	var panel := _make_panel("fragment", pd)
	panel.show_window(root)
	assert_eq(panel._grid.get_child_count(), 1, "fragment all tab 显示 1 个英雄碎片 cell")
	panel.remove_window()
	root.queue_free()


# ── tab 切换 ──

func test_tab_switch_changes_grid() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var parts_id: int = _find_equip_id_by_category("EQUIP.PARTS")
	var reel_id: int = _find_equip_id_by_category("EQUIP.REEL")
	pd.add_item(parts_id, 1)
	pd.add_item(reel_id, 1)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	assert_eq(panel._grid.get_child_count(), 2, "all tab = PARTS+REEL 2 cell")
	panel._select_tab("equip")
	assert_eq(panel._grid.get_child_count(), 1, "equip tab 只 PARTS（REEL 是 scroll）")
	panel._select_tab("scroll")
	assert_eq(panel._grid.get_child_count(), 1, "scroll tab 只 REEL")
	assert_true(bool(panel._tab_buttons["scroll"].button_pressed), "scroll tab 选中态")
	assert_false(bool(panel._tab_buttons["equip"].button_pressed), "equip tab 取消选中")
	panel.remove_window()
	root.queue_free()


# ── cell 点击链（gui_input → cell_clicked，第 24 段接 equipboard）──

func test_cell_has_click_handler() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_id_by_category("EQUIP.PARTS")
	pd.add_item(eid, 1)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	var cell: Control = panel._grid.get_child(0)
	assert_gt(cell.gui_input.get_connections().size(), 0, "cell gui_input 已连（点击 emit cell_clicked）")
	panel.remove_window()
	root.queue_free()


# 空背包不崩（grid 空）。
func test_empty_player_grid() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	assert_eq(panel._grid.get_child_count(), 0, "空玩家 grid 空")
	panel.remove_window()
	root.queue_free()
