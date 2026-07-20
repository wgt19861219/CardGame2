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
	# 翻页逻辑测 _turn_page(绕过 _on_next/prev_page 的 0.5s 防抖,#5 doArrowTouch clickTime)
	var panel: HandbookPanel = _make_panel()
	if panel._page_amount > 1:
		var p0: int = panel._page
		panel._turn_page(1)
		assert_eq(panel._page, p0 + 1, "下一页 +1")
		panel._turn_page(-1)
		assert_eq(panel._page, p0, "上一页回原页")
	else:
		panel._turn_page(1)
		assert_eq(panel._page, 1, "单页时不翻页")
	panel.remove_window()
	panel.get_parent().queue_free()


func test_default_tag_is_all() -> void:
	var panel: HandbookPanel = _make_panel()
	assert_eq(panel._current_tag, 1, "默认 ALL tag（源 create :714）")
	assert_eq(panel.TAG_KEYS[0], "ALL", "TAG_KEYS[0] = ALL")
	panel.remove_window()
	panel.get_parent().queue_free()


# ── 2026-07-20 补全 5 项测试 ──

func test_arrow_click_gap_debounces() -> void:
	# #5 源 doArrowTouch :246 canClick = clickTime==nil or time-clickTime>0.5
	var panel: HandbookPanel = _make_panel()
	if panel._page_amount > 1:
		var p0: int = panel._page
		panel._on_next_page()   # 首次 _last_arrow_click=-1 → 翻页
		assert_eq(panel._page, p0 + 1, "首次箭头翻页")
		panel._on_next_page()   # <0.5s 防抖拦截
		assert_eq(panel._page, p0 + 1, "0.5s 内连点被防抖拦截")
	panel.remove_window()
	panel.get_parent().queue_free()


func test_page_title_updates_on_tag_switch() -> void:
	# #4 源 setPageTitle :475 tagText.title（切 tag 时 pageTitle 文字变）
	var panel: HandbookPanel = _make_panel()
	assert_eq(panel._page_title.text, HandbookBuilder.title_text(1, cm), "默认 ALL 标题")
	panel._switch_tag(2)   # STR
	assert_eq(panel._page_title.text, HandbookBuilder.title_text(2, cm), "切 STR 标题更新")
	panel.remove_window()
	panel.get_parent().queue_free()


func test_builder_title_text_all_12_indices() -> void:
	# #4 HandbookBuilder.title_text 12 个分类标题 LSTR 全解析非空
	for i in range(1, 13):
		var t: String = HandbookBuilder.title_text(i, cm)
		assert_true(t.length() > 0, "title_text(" + str(i) + ") 非空")


func test_open_cell_click_opens_equipcraft() -> void:
	# #1 源 doSelectElement :105-109：点已解锁装备弹 EquipCraftPanel（context=handbook,hero=null）
	var panel: HandbookPanel = _make_panel()
	var root: Node = panel.get_parent()
	var before: int = root.get_child_count()
	var eid: int = int((panel._list()[0] as Dictionary)["id"])
	panel._handle_cell_click(true, eid)   # is_open=true → _open_equipcraft
	assert_eq(root.get_child_count(), before + 1, "弹出 EquipCraftPanel 子节点")
	var craft: Node = root.get_child(root.get_child_count() - 1)
	assert_true(craft is EquipCraftPanel, "新节点是 EquipCraftPanel")
	craft.queue_free()
	panel.remove_window()
	root.queue_free()


func test_locked_cell_click_does_not_crash() -> void:
	# #2 源 doEquipTouch :132：locked 装备点击 Toast（headless Toast 降级，不崩）
	var panel: HandbookPanel = _make_panel()
	panel._handle_cell_click(false, 1)   # is_open=false → Toast（headless 安全）
	assert_true(true, "locked click 未崩（Toast headless 降级）")
	panel.remove_window()
	panel.get_parent().queue_free()
