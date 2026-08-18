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
	assert_eq(panel._page_title.text, panel._title_text(1), "默认 ALL 标题")
	panel._switch_tag(2)   # STR
	assert_eq(panel._page_title.text, panel._title_text(2), "切 STR 标题更新")
	panel.remove_window()
	panel.get_parent().queue_free()


func test_title_text_all_12_indices() -> void:
	# #4 title_text 12 个分类标题 LSTR 全解析非空（源 tagText.title1-12 :53-64）
	var panel: HandbookPanel = _make_panel()
	for i in range(1, 13):
		var t: String = panel._title_text(i)
		assert_true(t.length() > 0, "_title_text(" + str(i) + ") 非空")
	panel.remove_window()
	panel.get_parent().queue_free()


# ── 两件套改造守卫（批4 Task 5：builder 退役 + variation 接线）──

func test_builder_retired_gone() -> void:
	# builder 退役守卫：handbook_builder.gd 删除 + panel 无残留引用（scripts/ui _builder.gd 5→4：
	# 剩 main_map + shop_row/task_row/excavate_history_row 三个 row_builder，excavate 批前已在）
	assert_false(ResourceLoader.exists("res://scripts/ui/handbook_builder.gd"), "handbook_builder.gd 已删除")
	var panel_text: String = FileAccess.get_file_as_string("res://scripts/ui/handbook_panel.gd")
	assert_true(panel_text.find("HandbookBuilder") == -1, "panel 无 HandbookBuilder 残留引用")


func test_panel_no_runtime_theme_override() -> void:
	# gd add_theme 5 处清零守卫：字号/颜色/描边全走 theme_type_variation（两件套范式）
	var panel_text: String = FileAccess.get_file_as_string("res://scripts/ui/handbook_panel.gd")
	assert_eq(panel_text.count("add_theme_"), 0, "panel 运行时 add_theme_* 清零")


func test_tag_label_variation_switches_on_select() -> void:
	# tag 选中态两 variation 方案（源 doSelectTag :94-101 选中白/disableShadow、未选中灰/setShadow 黑(0,2)）
	var panel: HandbookPanel = _make_panel()
	var lbl1: Label = panel._tag_ui[1]["label"]
	var lbl2: Label = panel._tag_ui[2]["label"]
	assert_eq(lbl1.theme_type_variation, &"HandbookEntryLabelSelected", "默认 tag1 选中 variation")
	assert_eq(lbl2.theme_type_variation, &"HandbookEntryLabel", "tag2 未选中 variation")
	panel._switch_tag(2)
	assert_eq(lbl1.theme_type_variation, &"HandbookEntryLabel", "切走后 tag1 回未选中")
	assert_eq(lbl2.theme_type_variation, &"HandbookEntryLabelSelected", "tag2 变选中")
	panel.remove_window()
	panel.get_parent().queue_free()


func test_equip_cell_size_source_scale() -> void:
	# 贴图显示尺寸 = 原始像素 ÷ CS(1.28125)（TextureConfig 无 handbook 条目口径）：
	# handbook_equip_bg 148×139（PIL 实测）→ (115.51, 108.49) 点；防 1.28 偏大回退
	var panel: HandbookPanel = _make_panel()
	var info: Dictionary = (panel._list()[0] as Dictionary).duplicate()
	var cell: Control = panel._create_equip_cell(info, panel._player.team_level)
	assert_almost_eq(cell.custom_minimum_size.x, 148.0 / 1.28125, 0.1, "cell 宽 = 148/CS")
	assert_almost_eq(cell.custom_minimum_size.y, 139.0 / 1.28125, 0.1, "cell 高 = 139/CS")
	panel.remove_window()
	panel.get_parent().queue_free()


func test_equip_name_label_uses_variation() -> void:
	# 装备名 label 走 HandbookEquipNameLabel variation（源 createIcon :443-444 18 号 (182,65,21)）
	var panel: HandbookPanel = _make_panel()
	var info: Dictionary = (panel._list()[0] as Dictionary).duplicate()
	var cell: Control = panel._create_equip_cell(info, panel._player.team_level)
	var name_lbl: Label = null
	for c in cell.get_children():
		if c is Label:
			name_lbl = c
	assert_not_null(name_lbl, "cell 含装备名 Label")
	assert_eq(name_lbl.theme_type_variation, &"HandbookEquipNameLabel", "装备名 variation")
	panel.remove_window()
	panel.get_parent().queue_free()


func test_name_label_clamps_over_cell_width() -> void:
	# 源 :445-447 label 宽 >114 → setScale(114/width)（单参等比）
	var panel: HandbookPanel = _make_panel()
	var lbl := Label.new()
	add_child(lbl)
	panel._clamp_label_width(lbl, 228.0)
	assert_almost_eq(lbl.scale.x, 0.5, 0.001, "228 宽等比缩到 0.5")
	assert_almost_eq(lbl.scale.y, 0.5, 0.001, "Y 同比（源 setScale 单参等比）")
	lbl.queue_free()
	panel.remove_window()
	panel.get_parent().queue_free()


func test_equip_cell_icon_or_lock_structure() -> void:
	# 源 createIcon :428-441：解锁 → readequip icon；锁定(lr>level) → icon_bg + lock 居中(源 icon@(33,33)=中心)
	var panel: HandbookPanel = _make_panel()
	var info: Dictionary = (panel._list()[0] as Dictionary).duplicate()
	var open_cell: Control = panel._create_equip_cell(info, panel._player.MAX_TEAM_LEVEL)
	assert_true(bool(open_cell.get_meta(&"is_open")), "满级 cell 解锁")
	var locked_cell: Control = panel._create_equip_cell(info, 1)
	var lr: int = int(info.get("lr", 1))
	if lr > 1:
		assert_false(bool(locked_cell.get_meta(&"is_open")), "level=1 且 lr>1 → 锁定")
		var icon_bg: Control = locked_cell.get_child(1) as Control
		assert_eq(icon_bg.get_child_count(), 1, "icon_bg 含 lock 子")
		var lock: Control = icon_bg.get_child(0) as Control
		assert_almost_eq(lock.position.x, (icon_bg.size.x - lock.size.x) / 2.0, 0.1, "lock 居中 x")
		assert_almost_eq(lock.position.y, (icon_bg.size.y - lock.size.y) / 2.0, 0.1, "lock 居中 y")
	panel.remove_window()
	panel.get_parent().queue_free()


func test_equip_cell_icon_centered_per_source() -> void:
	# 2026-08-18 修复轮 C 守卫：源 createIcon :429/:439 icon/iconBg:setPosition(57,64) 是
	# cocos 默认锚点(0.5,0.5)=【中心】语义 → Godot 左上角 position 须减半尺寸。
	# 修复前漏减致 icon 中心相对 cell 中心偏 (+47,+35)（右下半身位）。
	var panel: HandbookPanel = _make_panel()
	var info: Dictionary = (panel._list()[0] as Dictionary).duplicate()
	var open_cell: Control = panel._create_equip_cell(info, panel._player.MAX_TEAM_LEVEL)
	var icon: Control = open_cell.get_child(1) as Control
	var icon_center: Vector2 = icon.position + icon.size * 0.5
	assert_almost_eq(icon_center.x, 57.0, 0.1, "icon 中心 x = 源 equipIconPosX(57)")
	assert_almost_eq(icon_center.y, 139.0 / 1.28125 - 64.0, 0.1, "icon 中心 y = bg 高-源 64（中心锚换算）")
	var locked_cell: Control = panel._create_equip_cell(info, 1)
	if int(info.get("lr", 1)) > 1:
		var icon_bg: Control = locked_cell.get_child(1) as Control
		var bg_center: Vector2 = icon_bg.position + icon_bg.size * 0.5
		assert_almost_eq(bg_center.x, 57.0, 0.1, "锁定 icon_bg 中心 x = 57")
		assert_almost_eq(bg_center.y, 139.0 / 1.28125 - 64.0, 0.1, "锁定 icon_bg 中心 y 同源")
	panel.remove_window()
	panel.get_parent().queue_free()


func test_equip_name_label_centered_after_ready() -> void:
	# 2026-08-18 修复轮 C 守卫：源 createIcon :448 label:setPosition(57,17) 中心锚语义 →
	# 入树 ready 后按 variation 18 号真实 minsize 居中（_layout_name_label），
	# 且 clamp 缩放围绕中心 pivot。修复前 label 左上定位致中心偏右、底部溢出 bg 底边。
	var panel: HandbookPanel = _make_panel()
	var info: Dictionary = (panel._list()[0] as Dictionary).duplicate()
	var cell: Control = panel._create_equip_cell(info, panel._player.MAX_TEAM_LEVEL)
	add_child(cell)
	await get_tree().process_frame
	var lbl: Label = null
	for c in cell.get_children():
		if c is Label:
			lbl = c
	assert_almost_eq(lbl.position.x + lbl.size.x * 0.5, 57.0, 0.1, "label 中心 x = 源 equipNameLabelPosX(57)")
	assert_almost_eq(lbl.position.y + lbl.size.y * 0.5, 139.0 / 1.28125 - 17.0, 0.1,
		"label 中心 y = bg 高-源 17（中心锚换算）")
	assert_almost_eq(lbl.pivot_offset.x, lbl.size.x * 0.5, 0.1, "pivot 居中（clamp 围绕中心缩）")
	cell.queue_free()
	panel.remove_window()
	panel.get_parent().queue_free()


func test_open_cell_click_opens_equipcraft() -> void:
	# #1 源 doSelectElement :105-109 → equipcraft.createPanel :1277 equipLayer = equipboard.init("ofcraft")
	# 装备详情面板（equipboard base，属性/描述/卖出）。本项目复用 EquipboardPanel（package 已实现）。
	var panel: HandbookPanel = _make_panel()
	var root: Node = panel.get_parent()
	var before: int = root.get_child_count()
	var eid: int = int((panel._list()[0] as Dictionary)["id"])
	panel._handle_cell_click(true, eid)   # is_open=true → _open_equipcraft → EquipboardPanel
	assert_eq(root.get_child_count(), before + 1, "弹出 EquipboardPanel 子节点")
	var board: Node = root.get_child(root.get_child_count() - 1)
	assert_true(board is EquipboardPanel, "新节点是 EquipboardPanel")
	board.queue_free()
	panel.remove_window()
	root.queue_free()


func test_locked_cell_click_does_not_crash() -> void:
	# #2 源 doEquipTouch :132：locked 装备点击 Toast（headless Toast 降级，不崩）
	var panel: HandbookPanel = _make_panel()
	panel._handle_cell_click(false, 1)   # is_open=false → Toast（headless 安全）
	assert_true(true, "locked click 未崩（Toast headless 降级）")
	panel.remove_window()
	panel.get_parent().queue_free()
