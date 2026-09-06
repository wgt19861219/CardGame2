extends GutTest
# Phase 6 package 复刻第 24 段：EquipboardPanel 浮层测试（2026-07-05）。
# 照源 equipboard ofpackage.lua 2 按钮（左卖出 + 右动态 prop/consume/fragment）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _find_equip_id_by_category(category: String) -> int:
	var raw: Dictionary = cm.get_raw_table(&"Equip")
	for tid_str in raw:
		if String(raw[tid_str].get(&"Category", "")) == category:
			return int(tid_str)
	return 0


func _find_consume_pill_id() -> int:
	var raw: Dictionary = cm.get_raw_table(&"Equip")
	for tid_str in raw:
		var row: Dictionary = raw[tid_str]
		if String(row.get(&"Category", "")) == "EQUIP.CONSUMABLES" and String(row.get(&"Consume Type", "")) == "EQUIP.EXPERIENCE_PILL":
			return int(tid_str)
	return 0


func _find_hero_fragment_recipe() -> Dictionary:
	var raw: Dictionary = cm.get_raw_table(&"Fragment")
	for tid_str in raw:
		if int(tid_str) < 100:
			return {"tid": int(tid_str), "frag_id": int(raw[tid_str].get(&"Fragment ID", 0))}
	return {}


# ── propType 判定（照源 refreshPropType）──

func test_prop_type_prop() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_id_by_category("EQUIP.PARTS")
	assert_gt(eid, 0, "PARTS id 存在")
	var cell: Dictionary = {"id": eid, "makeId": eid, "amount": 3, "category": "EQUIP.PARTS", "type": 1}
	var panel := EquipboardPanel.new("equipboard", {})
	panel.setup_panel(cell, cm, pd)
	panel.show_window(root)
	assert_eq(panel._prop_type, "prop", "PARTS → prop")
	assert_eq(panel._right_button_label(), "详情", "prop 右按钮=详情")
	panel.remove_window()
	root.queue_free()


func test_prop_type_consume() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var eid: int = _find_consume_pill_id()
	assert_gt(eid, 0, "EXPERIENCE_PILL id 存在")
	var cell: Dictionary = {"id": eid, "makeId": eid, "amount": 2, "category": "EQUIP.CONSUMABLES", "type": 1}
	var panel := EquipboardPanel.new("equipboard", {})
	panel.setup_panel(cell, cm, pd)
	panel.show_window(root)
	assert_eq(panel._prop_type, "consume", "EXPERIENCE_PILL → consume")
	assert_eq(panel._right_button_label(), "使用", "consume 右按钮=使用")
	panel.remove_window()
	root.queue_free()


func test_prop_type_fragment() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var recipe: Dictionary = _find_hero_fragment_recipe()
	assert_false(recipe.is_empty(), "Fragment 表有英雄配方")
	var frag_id: int = int(recipe["frag_id"])
	var hero_tid: int = int(recipe["tid"])
	var cell: Dictionary = {"id": frag_id, "makeId": hero_tid, "amount": 5, "category": "BATTLE.HERO", "type": 2, "needAmount": 10}
	var panel := EquipboardPanel.new("equipboard", {})
	panel.setup_panel(cell, cm, pd)
	panel.show_window(root)
	assert_eq(panel._prop_type, "fragment", "碎片 cell（makeId!=id）→ fragment")
	assert_eq(panel._right_button_label(), "合成", "fragment 右按钮=合成")
	panel.remove_window()
	root.queue_free()


# 通用碎片（makeId==id，无配方）归 prop（源 UNIVERSAL_DEBRIS）。
# 注：本项目 fragments 容器只存魂石（都有 Fragment 表配方），无"无配方碎片"场景，此 case 跳过。


# ── 装备名本地化（Equip.json Name 存 LSTR key，须过 get_lstr 翻译后显示）──

func test_equip_name_translated_not_raw_key() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_id_by_category("EQUIP.PARTS")
	var cell: Dictionary = {"id": eid, "makeId": eid, "amount": 3, "category": "EQUIP.PARTS", "type": 1}
	var panel := EquipboardPanel.new("equipboard", {})
	panel.setup_panel(cell, cm, pd)
	panel.show_window(root)
	var name_key: String = String(cm.get_raw_table(&"Equip").get(str(eid), {}).get(&"Name", ""))
	assert_eq(panel._equip_name(), String(cm.get_lstr(name_key)), "装备名 = get_lstr(Name key) 翻译结果")
	assert_false(panel._equip_name().begins_with("EQUIP."), "装备名非 LSTR key 原文（漏翻译会显示英文 key 且超长）")
	panel.remove_window()
	root.queue_free()


# ── 卖出流程（pd.sell_equip + sold 信号）──

func test_sell_flow() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_id_by_category("EQUIP.PARTS")
	pd.add_item(eid, 3)
	var cell: Dictionary = {"id": eid, "makeId": eid, "amount": 3, "category": "EQUIP.PARTS", "type": 1}
	var panel := EquipboardPanel.new("equipboard", {})
	panel.setup_panel(cell, cm, pd)
	panel.show_window(root)
	var sold_args: Array = []   # Array 引用类型避免 lambda 捕获 int 按值
	panel.sold.connect(func(i: int) -> void: sold_args.append(i))
	panel._on_sell_pressed()   # 触发卖出（pd.sell_equip + sold emit + remove_window）
	assert_eq(int(pd.items.get(eid, 0)), 2, "卖出扣 1（3→2）")
	assert_eq(sold_args.size(), 1, "sold 信号 emit 一次")
	assert_eq(int(sold_args[0]), eid, "sold item_id")
	assert_true(pd.hero_manager.gold > 0, "卖出加金币（hero_manager.gold）")
	root.queue_free()


# ── 合成按钮弹 FragmentComposePanel（fragment 右按钮）──

func test_compose_opens_fragment_compose_panel() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var recipe: Dictionary = _find_hero_fragment_recipe()
	var frag_id: int = int(recipe["frag_id"])
	var hero_tid: int = int(recipe["tid"])
	var cell: Dictionary = {"id": frag_id, "makeId": hero_tid, "amount": 5, "category": "BATTLE.HERO", "type": 2, "needAmount": 10}
	var panel := EquipboardPanel.new("equipboard", {})
	panel.setup_panel(cell, cm, pd)
	panel.show_window(root)
	panel._on_right_pressed()   # fragment → _open_compose
	var has_compose: bool = false
	for c in root.get_children():
		if c is FragmentComposePanel:
			has_compose = true
			c.queue_free()
			break
	assert_true(has_compose, "fragment 右按钮弹 FragmentComposePanel")
	panel.remove_window()
	root.queue_free()


# ── 合成回调（FragmentComposePanel.composed → equipboard emit composed + 关闭，源 downFragmentCompose :21-46）──

func test_compose_emits_composed_signal() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var recipe: Dictionary = _find_hero_fragment_recipe()
	var frag_id: int = int(recipe["frag_id"])
	var hero_tid: int = int(recipe["tid"])
	var cell: Dictionary = {"id": frag_id, "makeId": hero_tid, "amount": 5, "category": "BATTLE.HERO", "type": 2, "needAmount": 10}
	var panel := EquipboardPanel.new("equipboard", {})
	panel.setup_panel(cell, cm, pd)
	panel.show_window(root)
	var composed_args: Array = []
	panel.composed.connect(func(i: int) -> void: composed_args.append(i))
	panel._on_frag_composed()   # 触发合成回调（emit composed + remove_window）
	assert_eq(composed_args.size(), 1, "composed 信号 emit 一次")
	assert_eq(int(composed_args[0]), frag_id, "composed item_id = 碎片 id")
	assert_true(panel.is_queued_for_deletion(), "合成后 equipboard queue_free 关闭（源 consumeAmount :55 amount<=0 popout 等价）")
	root.queue_free()


# ── 批4 Task 6 两件套改造守卫（gd 运行时主题 override 清零 + variation 接管）──

const PANEL_SCRIPT_PATH: String = "res://scripts/ui/equipboard_panel.gd"


func test_panel_no_runtime_theme_override() -> void:
	var src: String = FileAccess.get_file_as_string(PANEL_SCRIPT_PATH)
	var count: int = src.count("add_theme")
	assert_eq(count, 0, "panel 源码零运行时 add_theme_* override（样式全走 default_theme variation）")


func test_static_labels_use_variations() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_id_by_category("EQUIP.PARTS")
	var cell: Dictionary = {"id": eid, "makeId": eid, "amount": 3, "category": "EQUIP.PARTS", "type": 1}
	var panel := EquipboardPanel.new("equipboard", {})
	panel.setup_panel(cell, cm, pd)
	panel.show_window(root)
	var frame: Control = panel._frame
	assert_eq((frame.get_node("%NameLabel") as Label).theme_type_variation, &"EquipboardNameLabel", "NameLabel variation（源 board.lua:323-337 size24 棕+影）")
	assert_eq((frame.get_node("%AmountLabel") as Label).theme_type_variation, &"EquipboardHaveLabel", "AmountLabel variation（源 board.lua:60 size20）")
	assert_eq((frame.get_node("%MoneyBoard/%MoneyContent/%SellTitleLabel") as Label).theme_type_variation, &"EquipboardHaveLabel", "SellTitleLabel 与 HaveLabel 同参数共用（源 ccc3(67,59,56) size20）")
	assert_eq((frame.get_node("%MoneyBoard/%MoneyContent/%SellNumberLabel") as Label).theme_type_variation, &"EquipboardPriceLabel", "SellNumberLabel variation（源 ofpackage.lua:91-104 ccc3(155,34,14) size18）")
	assert_eq((frame.get_node("%SellBtn/%SellLabel") as Label).theme_type_variation, &"EquipboardBtnLabel", "SellLabel variation（源 fontinfo ui_normal_button+shadow(42,31,22)）")
	assert_eq((frame.get_node("%RightBtn/%RightLabel") as Label).theme_type_variation, &"EquipboardBtnLabel", "RightLabel variation")
	panel.remove_window()
	root.queue_free()


func test_buttons_use_button_variation() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_id_by_category("EQUIP.PARTS")
	var cell: Dictionary = {"id": eid, "makeId": eid, "amount": 3, "category": "EQUIP.PARTS", "type": 1}
	var panel := EquipboardPanel.new("equipboard", {})
	panel.setup_panel(cell, cm, pd)
	panel.show_window(root)
	assert_eq((panel._frame.get_node("%SellBtn") as Button).theme_type_variation, &"EquipboardBtn", "SellBtn 九宫格三态走 EquipboardBtn variation")
	assert_eq((panel._frame.get_node("%RightBtn") as Button).theme_type_variation, &"EquipboardBtn", "RightBtn 同 variation")
	panel.remove_window()
	root.queue_free()


func test_att_rows_use_variation_and_ignore_mouse() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_id_by_category("EQUIP.PARTS")
	var cell: Dictionary = {"id": eid, "makeId": eid, "amount": 3, "category": "EQUIP.PARTS", "type": 1}
	var panel := EquipboardPanel.new("equipboard", {})
	panel.setup_panel(cell, cm, pd)
	panel.show_window(root)
	var host: VBoxContainer = panel._frame.get_node("%AttHost") as VBoxContainer
	assert_gt(host.get_child_count(), 0, "PARTS 装备至少一行属性")
	for c in host.get_children():
		var lbl: Label = c as Label
		if lbl == null:
			continue
		assert_eq(lbl.theme_type_variation, &"EquipboardAttLabel", "属性行 variation（源 board.lua:142-159 size18 ccc3(64,63,63)+影）")
		assert_eq(lbl.mouse_filter, Control.MOUSE_FILTER_IGNORE, "属性行装饰 Label 不吞点击")
	panel.remove_window()
	root.queue_free()


func test_fragment_row_uses_lstr_and_variation() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	var recipe: Dictionary = _find_hero_fragment_recipe()
	var frag_id: int = int(recipe["frag_id"])
	var hero_tid: int = int(recipe["tid"])
	var cell: Dictionary = {"id": frag_id, "makeId": hero_tid, "amount": 5, "category": "BATTLE.HERO", "type": 2, "needAmount": 10}
	var panel := EquipboardPanel.new("equipboard", {})
	panel.setup_panel(cell, cm, pd)
	panel.show_window(root)
	var host: VBoxContainer = panel._frame.get_node("%AttHost") as VBoxContainer
	var frag_lbl: Label = null
	for c in host.get_children():
		var lbl: Label = c as Label
		if lbl != null and String(cm.get_lstr("EQUIPINFO.SYNTHESIS_REQUIRES_FRAGMENT_")) in lbl.text:
			frag_lbl = lbl
			break
	assert_not_null(frag_lbl, "碎片行存在且标题走 LSTR（源 board.lua:209-222，非硬编码中文）")
	if frag_lbl != null:
		assert_string_contains(frag_lbl.text, "5/10", "碎片行数量 %d/%d（源 board.lua:227）")
		assert_eq(frag_lbl.theme_type_variation, &"EquipboardFragmentLabel", "碎片行 variation（源 ccc3(66,45,28) size18+影）")
	panel.remove_window()
	root.queue_free()
