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
	assert_eq(int((panel._tab_buttons["all"] as TextureButton).z_index), 3, "默认 all tab 选中（z=3）")
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
	assert_eq(int((panel._tab_buttons["scroll"] as TextureButton).z_index), 3, "scroll tab 选中态（z=3）")
	assert_eq(int((panel._tab_buttons["equip"] as TextureButton).z_index), 1, "equip tab 取消选中（z=1）")
	panel.remove_window()
	root.queue_free()


# tab classbtn 纹理化（2026-07-19，照源 package.lua:378-462 createListButton + hero_package 范式）。
func test_tab_buttons_use_classbtn_texture() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	var all_btn: TextureButton = panel._tab_buttons["all"] as TextureButton
	assert_eq(all_btn.stretch_mode, TextureButton.STRETCH_SCALE, "tab stretch_mode=SCALE（避 KEEP 纹理原尺寸溢出）")
	assert_eq(all_btn.texture_normal.resource_path, PackagePanel.CLASSBTN_SEL_RES, "选中 tab texture_normal=classbtnselected")
	var equip_btn: TextureButton = panel._tab_buttons["equip"] as TextureButton
	assert_eq(equip_btn.texture_normal.resource_path, PackagePanel.CLASSBTN_RES, "未选中 tab texture_normal=classbtn")
	var all_lbl: Label = panel._tab_labels["all"] as Label
	assert_eq(all_lbl.text, "全部", "all tab label LSTR 填充（BATTLEPREPARE.WHOLE=全部）")
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


# 点 cell 弹 equipboard（单例 + refresh 切换，源 doSelectEquip :185-200 首次 create / 已有 refresh）。
func test_cell_click_switch_refresh_equipboard() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var parts_id: int = _find_equip_id_by_category("EQUIP.PARTS")
	var reel_id: int = _find_equip_id_by_category("EQUIP.REEL")
	assert_gt(parts_id, 0, "PARTS id 存在")
	assert_gt(reel_id, 0, "REEL id 存在")
	pd.add_item(parts_id, 1)
	pd.add_item(reel_id, 1)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	# 首次点 parts cell → 建 _equipboard（非模态浮层）
	panel._on_cell_clicked({"id": parts_id, "amount": 1, "type": 1})
	assert_not_null(panel._equipboard, "首次点 cell 建 _equipboard")
	var board1: EquipboardPanel = panel._equipboard
	assert_eq(board1._item_id, parts_id, "首次 _item_id=parts")
	# 再点 reel cell → refresh 同实例（不重建，源 doSelectEquip refresh；非模态不阻塞 cell 点击）
	panel._on_cell_clicked({"id": reel_id, "amount": 1, "type": 1})
	assert_eq(panel._equipboard, board1, "再点 cell refresh 同实例（非重建）")
	assert_eq(panel._equipboard._item_id, reel_id, "refresh 切换 _item_id=reel")
	panel._equipboard.remove_window()
	panel.remove_window()
	root.queue_free()


# 合成回调刷新 grid（equipboard.composed → _on_sold 重 classify + 重填，源 downFragmentCompose consumeAmount :47-74）。
func test_compose_refreshes_grid() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var parts_id: int = _find_equip_id_by_category("EQUIP.PARTS")
	pd.add_item(parts_id, 1)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	assert_eq(panel._grid.get_child_count(), 1, "初始 1 cell")
	panel._on_cell_clicked({"id": parts_id, "amount": 1, "type": 1})
	assert_not_null(panel._equipboard, "点 cell 建 _equipboard")
	pd.sell_equip(parts_id, 1)   # 模拟持有量变化（合成/卖出消耗，1→0）
	panel._equipboard.composed.emit(parts_id)   # 触发 composed → _on_sold 刷新
	assert_eq(panel._grid.get_child_count(), 0, "composed → _on_sold 刷新 grid，持有量 0 cell 消失")
	panel.remove_window()
	root.queue_free()


# ── 顶部货币条（源 framework.lua:755 sbCreateTitle common，所有非 main 场景建 3 货币条）──

func test_status_bar_built_with_three_bars() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := _make_panel("package", pd)
	panel.show_window(root)
	# _status_refs 由 _create_status_bar 装配，含 gold/diamond/vitality 三个 Label ref。
	assert_true(panel._status_refs.has("gold"), "货币条 gold label 装好")
	assert_true(panel._status_refs.has("diamond"), "货币条 diamond label 装好")
	assert_true(panel._status_refs.has("vitality"), "货币条 vitality label 装好")
	# gold label 应显示玩家当前金币（int(PlayerData.hero_manager.gold)，新玩家默认 0）
	var gold_lbl: Label = panel._status_refs["gold"]
	assert_eq(gold_lbl.text, str(pd.hero_manager.gold), "gold label 显示玩家金币")
	panel.remove_window()
	root.queue_free()


func test_status_bar_built_on_fragment_identity_too() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := _make_panel("fragment", pd)
	panel.show_window(root)
	assert_true(panel._status_refs.has("vitality"), "fragment identity 也建货币条（源 framework common）")
	panel.remove_window()
	root.queue_free()
