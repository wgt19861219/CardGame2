extends GutTest
# HandbookPanel + EquipmentClassifier.classify_equip 测试（2026-07-13 重建）。
# 数据层（12 tag 属性分类）+ View 层（背景/12 tag/箭头/网格装配 + tag 切换 + 翻页）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# ── 数据层 classify_equip（照源 readequip.classifyEquip :481-537）──

func test_classify_equip_returns_all_12_tags() -> void:
	var tabs: Dictionary = EquipmentClassifier.classify_equip(cm, PlayerData.MAX_TEAM_LEVEL)
	for key in ["ALL", "STR", "AGI", "INT", "HP", "AD", "AP", "ARM", "CRIT", "HPS", "MPS", "HEAL"]:
		assert_true(tabs.has(key), "含 tag: " + key)
		assert_true(tabs[key] is Array, key + " 是 Array")
	assert_gt((tabs["ALL"] as Array).size(), 0, "ALL 含装备（PARTS/SYNTHETICS 非隐藏）")


func test_str_tag_only_str_equips() -> void:
	var tabs: Dictionary = EquipmentClassifier.classify_equip(cm, PlayerData.MAX_TEAM_LEVEL)
	var raw: Dictionary = cm.get_raw_table(&"Equip")
	for cell in tabs["STR"]:
		var row: Dictionary = raw[str(cell["id"])]
		assert_gt(int(row.get("STR", 0)), 0, "STR tag 装备 STR>0")


func test_crit_tag_includes_mcrit() -> void:
	var tabs: Dictionary = EquipmentClassifier.classify_equip(cm, PlayerData.MAX_TEAM_LEVEL)
	var raw: Dictionary = cm.get_raw_table(&"Equip")
	for cell in tabs["CRIT"]:
		var row: Dictionary = raw[str(cell["id"])]
		assert_true(int(row.get("CRIT", 0)) > 0 or int(row.get("MCRIT", 0)) > 0, "CRIT tag 含 CRIT 或 MCRIT")


func test_all_sorted_by_lr_then_id() -> void:
	var tabs: Dictionary = EquipmentClassifier.classify_equip(cm, PlayerData.MAX_TEAM_LEVEL)
	var list: Array = tabs["ALL"]
	for i in range(1, list.size()):
		var a: Dictionary = list[i - 1]
		var b: Dictionary = list[i]
		assert_true(int(a["lr"]) < int(b["lr"]) or (int(a["lr"]) == int(b["lr"]) and int(a["id"]) <= int(b["id"])),
			"ALL 按 {lr,id} 升序")


func test_excludes_non_parts_category() -> void:
	var tabs: Dictionary = EquipmentClassifier.classify_equip(cm, PlayerData.MAX_TEAM_LEVEL)
	var raw: Dictionary = cm.get_raw_table(&"Equip")
	for cell in tabs["ALL"]:
		var row: Dictionary = raw[str(cell["id"])]
		var cat: String = String(row.get("Category", ""))
		assert_true(cat == "EQUIP.PARTS" or cat == "EQUIP.SYNTHETICS", "仅 PARTS/SYNTHETICS 入图鉴: " + cat)


func test_excludes_hidden_equips() -> void:
	var tabs: Dictionary = EquipmentClassifier.classify_equip(cm, PlayerData.MAX_TEAM_LEVEL)
	var raw: Dictionary = cm.get_raw_table(&"Equip")
	for cell in tabs["ALL"]:
		var row: Dictionary = raw[str(cell["id"])]
		assert_false(bool(row.get("Hide", false)), "隐藏装备不入图鉴")


func test_can_display_filters_over_level_cap() -> void:
	# team_level_max=1 → 仅 Display Level<=1 的装备入图鉴
	var low: Dictionary = EquipmentClassifier.classify_equip(cm, 1)
	var full: Dictionary = EquipmentClassifier.classify_equip(cm, PlayerData.MAX_TEAM_LEVEL)
	assert_true((low["ALL"] as Array).size() <= (full["ALL"] as Array).size(), "低等级 cap 过滤更多装备")


# ── View 层装配 + 交互 ──

func _make_panel() -> HandbookPanel:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var panel := HandbookPanel.new("handbook", {})
	panel.setup_panel(pd)
	panel.show_window(root)
	return panel


func test_panel_builds_12_tags_and_arrows() -> void:
	var panel: HandbookPanel = _make_panel()
	assert_eq(panel._tag_ui.size(), 12, "12 tag 按钮")
	assert_not_null(panel._page_label, "页码 Label 存在")
	assert_gt(panel._page_amount, 0, "页数>=1")
	panel.remove_window()
	panel.get_parent().queue_free()


func test_switch_tag_changes_current_and_resets_page() -> void:
	var panel: HandbookPanel = _make_panel()
	panel._page = 3
	panel._switch_tag(3)   # INT
	assert_eq(panel._current_tag, 3, "切到 INT tag")
	assert_eq(panel._page, 1, "切 tag 回第 1 页")
	panel.remove_window()
	panel.get_parent().queue_free()


func test_next_prev_page_navigation() -> void:
	var panel: HandbookPanel = _make_panel()
	if panel._page_amount > 1:
		var p0: int = panel._page
		panel._on_next_page()
		assert_eq(panel._page, p0 + 1, "下一页 +1")
		panel._on_prev_page()
		assert_eq(panel._page, p0, "上一页回原页")
	else:
		panel._on_next_page()
		assert_eq(panel._page, 1, "单页时不翻页")
	panel.remove_window()
	panel.get_parent().queue_free()


func test_default_tag_is_all() -> void:
	var panel: HandbookPanel = _make_panel()
	assert_eq(panel._current_tag, 1, "默认 ALL tag（源 create :714）")
	assert_eq(panel.TAG_KEYS[0], "ALL", "TAG_KEYS[0] = ALL")
	panel.remove_window()
	panel.get_parent().queue_free()
