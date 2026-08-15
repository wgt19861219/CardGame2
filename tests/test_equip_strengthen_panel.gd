extends GutTest
# 装备强化面板测试（第三十二轮 Step 1+2+3 骨架 + 第三十三轮 Step 4 材料列表，照源 ui/equipstrengthen.lua）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _find_enchantable_equip() -> int:
	# 排除 SOUL_STONE（源 readequip.lua:357 checkValid 材料过滤同款；魂石属性全 0，
	# 旧版断言靠 name label 假阳性，两件套后 att 动态行需要真装备）
	var et: Dictionary = cm.get_raw_table(&"Equip")
	for id in et:
		var row: Dictionary = et[id]
		if int(row.get("Quality", 0)) >= 2 and String(row.get("Category", "")) != "EQUIP.SOUL_STONE":
			if _has_base_att(row):
				return int(id)
	return 0


func _has_base_att(row: Dictionary) -> bool:
	for key in ["STR", "INT", "AGI", "HP", "AD", "AP", "ARM", "MR"]:
		if float(row.get(key, 0) or 0) != 0.0:
			return true
	return false


func _find_category_equip(cat: String) -> int:
	var et: Dictionary = cm.get_raw_table(&"Equip")
	for id in et:
		var row: Dictionary = et[id]
		if String(row.get("Category", "")) == cat and int(row.get("Enhance Value", 0)) > 0:
			if not bool(row.get("Invisible", false)):
				return int(id)
	return 0


func _find_mt_idx(panel: EquipStrengthenPanel, item_id: int) -> int:
	for i in panel._mt_nodes.size():
		if int(panel._mt_nodes[i]["info"]["id"]) == item_id:
			return i
	return -1


# 源 createEquip:1576-1638 6 槽 + 返回 + hint
func test_panel_assembles() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	assert_eq(panel._equip_icons.size(), 6, "6 槽图标")
	# Phase A：panel 层静态节点（bg/frame/hero_icon/close/stren/faststren/diamond）从 .tscn instantiate
	# （container→content→%Bg/%CloseBtn...），递归扫全子树。container 直接子节点另含 material_bg/equips/talk。
	assert_gt(panel.container.get_child_count(), 0, "container 有子节点（content + 子组件 procedural）")
	assert_not_null(panel._stren_btn, "stren 按钮（.tscn %StrenBtn 套 Scale9）")
	assert_not_null(panel._faststren_btn, "faststren 按钮（.tscn %FastStrenBtn）")
	assert_not_null(panel._diamond_cost_label, "钻石 cost label（.tscn %DiamondCostLabel）")
	panel.remove_window()
	root.queue_free()


# 源 selectEquip:1641 空槽容错（item_id<=0 不可选）
func test_select_empty_slot_no_op() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)   # 无装备
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	panel.select_slot(0)   # 空槽
	assert_eq(panel._selected_slot, -1, "空槽不可选 → _selected_slot 保持 -1")
	panel.remove_window()
	root.queue_free()


# 源 selectEquip:1672/1674 选槽高亮（选中 alpha 1.0，其他 75/255）
func test_select_enchantable_slot() -> void:
	var root := Node.new()
	add_child(root)
	var eid: int = _find_enchantable_equip()
	if eid == 0:
		pass_test("数据表无可附魔装备（quality>=2），跳过")
		root.queue_free()
		return
	var hero := HeroInstance.new(1, 1, 1)
	hero.equip_slots[0] = eid
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	assert_eq(panel._selected_slot, 0, "setup select_slot(0)（可附魔装备）")
	assert_eq(panel._equip_icons[0].modulate.a, 1.0, "槽 0 高亮 alpha 1.0")
	assert_lt(panel._equip_icons[1].modulate.a, 0.5, "槽 1 半透明 alpha 75/255≈0.29")
	var att_count: int = _count_meta(panel._content, "att")
	assert_gt(att_count, 0, "选槽后装备属性 label 创建")
	panel.remove_window()
	root.queue_free()


# 源 selectEquip:1646 quality 1（ml=0）不可附魔提示
func test_select_low_quality_slot_hint() -> void:
	var root := Node.new()
	add_child(root)
	var et: Dictionary = cm.get_raw_table(&"Equip")
	var low_id: int = 0
	for id in et:
		if int(et[id].get("Quality", 0)) == 1:
			low_id = int(id)
			break
	if low_id == 0:
		pass_test("数据表无 quality 1 装备，跳过")
		root.queue_free()
		return
	var hero := HeroInstance.new(1, 1, 1)
	hero.equip_slots[0] = low_id
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	assert_eq(panel._selected_slot, -1, "quality 1 ml=0 不可选")
	# 源 ONLY_GREEN_AND_OVER... LSTR value
	assert_eq(panel.get_talk_text(), String(cm.get_lstr("EQUIPSTRENGTHEN.ONLY_GREEN_AND_OVER_THE_QUALITY_OF_THE_EQUIPMENT_CAN_BE_ENCHANTED")), "低品质提示照源 LSTR")
	panel.remove_window()
	root.queue_free()


# perform_enhance 守卫（未选槽 → false）
func test_perform_enhance_no_slot() -> void:
	var pd := PlayerData.new(cm)
	var hero := HeroInstance.new(1, 1, 1)   # 无装备 → setup select_slot(0) 空槽不选
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm, pd)
	assert_false(panel.perform_enhance({}), "未选槽 → false")


# ===== 第三十三轮 Step 4 材料列表（照源 getMaterialList + addMaterial/deleteMaterial + refreshStrenCost）=====

# 源 readequip.lua:358 checkValid 排除 SOUL_STONE
func test_build_material_list_filters_soul_stone() -> void:
	var soul_id: int = _find_category_equip("EQUIP.SOUL_STONE")
	var parts_id: int = _find_category_equip("EQUIP.PARTS")
	if soul_id == 0 or parts_id == 0:
		pass_test("数据表缺 SOUL_STONE 或 PARTS，跳过")
		return
	var pd := PlayerData.new(cm)
	pd.add_item(soul_id, 5)
	pd.add_item(parts_id, 3)
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm, pd)
	panel.show_window(root)
	var ids: Array = []
	for m in panel._materials:
		ids.append(int(m["id"]))
	assert_true(parts_id in ids, "PARTS 在材料列表")
	assert_false(soul_id in ids, "SOUL_STONE 被过滤")
	panel.remove_window()
	root.queue_free()


# 源 addMaterial:276 add+1 + addmtInfo[id]+1 + addExp(ehc)
func test_add_material_updates_state() -> void:
	var parts_id: int = _find_category_equip("EQUIP.PARTS")
	var eid: int = _find_enchantable_equip()
	if parts_id == 0 or eid == 0:
		pass_test("数据表缺 PARTS 或可附魔装备，跳过")
		return
	var pd := PlayerData.new(cm)
	pd.add_item(parts_id, 10)
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.equip_slots[0] = eid
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm, pd)
	panel.show_window(root)
	var ehc: int = int(cm.get_raw_table(&"Equip")[str(parts_id)].get("Enhance Value", 0))
	var idx: int = _find_mt_idx(panel, parts_id)
	assert_gt(idx, -1, "材料在网格有索引")
	EquipStrengthenMaterial.add_material(panel,idx)
	assert_eq(int(panel._addmt_info.get(parts_id, 0)), 1, "addmtInfo[id]==1")
	assert_eq(panel._target_exp, panel._ori_exp + float(ehc), "targetExp=ori+ehc")
	panel.remove_window()
	root.queue_free()


# 源 deleteMaterial:300 add-1 + addmtInfo[id]-1 + addExp(-ehc)
func test_delete_material_reverts() -> void:
	var parts_id: int = _find_category_equip("EQUIP.PARTS")
	var eid: int = _find_enchantable_equip()
	if parts_id == 0 or eid == 0:
		pass_test("数据表缺 PARTS 或可附魔装备，跳过")
		return
	var pd := PlayerData.new(cm)
	pd.add_item(parts_id, 10)
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.equip_slots[0] = eid
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm, pd)
	panel.show_window(root)
	var idx: int = _find_mt_idx(panel, parts_id)
	EquipStrengthenMaterial.add_material(panel,idx)
	EquipStrengthenMaterial.delete_material(panel,idx)
	assert_false(panel._addmt_info.has(parts_id) and int(panel._addmt_info[parts_id]) > 0, "addmtInfo[id]==0")
	assert_eq(panel._target_exp, panel._ori_exp, "targetExp 回到 ori")
	panel.remove_window()
	root.queue_free()


# 源 refreshStrenCost:504 金币预览 = getUnitMoney×(target-ori)
func test_refresh_stren_cost_shows_gold() -> void:
	var parts_id: int = _find_category_equip("EQUIP.PARTS")
	var eid: int = _find_enchantable_equip()
	if parts_id == 0 or eid == 0:
		pass_test("数据表缺 PARTS 或可附魔装备，跳过")
		return
	var pd := PlayerData.new(cm)
	pd.add_item(parts_id, 10)
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.equip_slots[0] = eid
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm, pd)
	panel.show_window(root)
	var idx: int = _find_mt_idx(panel, parts_id)
	EquipStrengthenMaterial.add_material(panel,idx)
	# 两件套 Task 5：源 :515 ed.setString(ui.money, cost) 纯数字 + goldicon_small 表意
	# （迁移发明"金币"文字前缀已删，icon 表意照源）
	var money_lbl: Label = panel._content.get_node("%MoneyLabel")
	assert_true(money_lbl.visible and money_lbl.text.is_valid_int() and int(money_lbl.text) > 0, "金币预览显示（纯数字+icon 表意）")
	# 源 NO_MATERIAL_ADDED LSTR value（无材料时 no_cost 显示，有材料 → 切数字）
	assert_true(money_lbl.visible, "有材料 → no_cost 隐 money 显")
	panel.remove_window()
	root.queue_free()


# 源 addMaterial:278 满级守卫（targetExp 达 total → add 拒，hint 经验已满）
func test_add_material_max_level_blocked() -> void:
	var parts_id: int = _find_category_equip("EQUIP.PARTS")
	var eid: int = _find_enchantable_equip()
	if parts_id == 0 or eid == 0:
		pass_test("数据表缺 PARTS 或可附魔装备，跳过")
		return
	var pd := PlayerData.new(cm)
	pd.add_item(parts_id, 10)
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.equip_slots[0] = eid
	hero.equip_exp[0] = 999999   # 远超 total → 满级
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm, pd)
	panel.show_window(root)
	var idx: int = _find_mt_idx(panel, parts_id)
	EquipStrengthenMaterial.add_material(panel,idx)
	# 源 EXPERIENCE_MAXED_OUT LSTR value
	assert_eq(panel.get_talk_text(), String(cm.get_lstr("EQUIPSTRENGTHEN.EXPERIENCE_MAXED_OUT")), "满级 add 被拒提示照源 LSTR")
	assert_false(panel._addmt_info.has(parts_id) and int(panel._addmt_info[parts_id]) > 0, "满级 add 不入 addmtInfo")
	panel.remove_window()
	root.queue_free()


# ===== 第三十四轮 Step 5 强化按钮 + 钻石满级（照源 createStrenButton + doClickStren + upFastStren）=====

# 源 createStrenButton:804-1028 按钮创建
func test_stren_buttons_created() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	assert_not_null(panel._stren_btn, "普通强化按钮已建")
	assert_not_null(panel._faststren_btn, "钻石一键按钮已建")
	assert_not_null(panel._diamond_cost_label, "钻石 cost label 已建")
	panel.remove_window()
	root.queue_free()


# 源 initStrenButton:476 选可附魔槽 → 钻石 cost 显示
func test_diamond_cost_displayed() -> void:
	var eid: int = _find_enchantable_equip()
	if eid == 0:
		pass_test("数据表无可附魔装备，跳过")
		return
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.equip_slots[0] = eid
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	# 两件套 Task 5：源 :964 rmb=纯数字 + task_rmb_icon_2 表意（"钻石"文字前缀为迁移发明已删）
	var rmb_lbl: Label = panel._content.get_node("%RmbLabel")
	assert_true(rmb_lbl.text.is_valid_int() and int(rmb_lbl.text) > 0, "选可附魔槽 → 钻石 cost 显示（纯数字+icon）")
	panel.remove_window()
	root.queue_free()


# 源 doClickStren:626 addmtInfo → enhance → 材料消耗 + exp 增加
func test_do_click_stren_consumes() -> void:
	var parts_id: int = _find_category_equip("EQUIP.PARTS")
	var eid: int = _find_enchantable_equip()
	if parts_id == 0 or eid == 0:
		pass_test("数据表缺 PARTS 或可附魔装备，跳过")
		return
	var pd := PlayerData.new(cm)
	pd.add_item(parts_id, 10)
	pd.hero_manager.add_money(1000000)
	var root := Node.new()
	add_child(root)
	var iid: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(iid)
	hero.equip_slots[0] = eid
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm, pd)
	panel.show_window(root)
	var idx: int = _find_mt_idx(panel, parts_id)
	EquipStrengthenMaterial.add_material(panel,idx)
	var exp_before: float = float(hero.equip_exp[0])
	panel.do_click_stren()
	assert_true(float(hero.equip_exp[0]) > exp_before, "do_click_stren 后 exp 增加")
	assert_eq(int(pd.items.get(parts_id, 0)), 9, "材料扣 1")
	panel.remove_window()
	root.queue_free()


# 源 upFastStren:701 op_type=2 钻石满级
func test_do_click_fast_stren_to_max() -> void:
	var eid: int = _find_enchantable_equip()
	if eid == 0:
		pass_test("数据表无可附魔装备，跳过")
		return
	var pd := PlayerData.new(cm)
	pd.add_diamond(999999)
	var root := Node.new()
	add_child(root)
	var iid: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(iid)
	hero.equip_slots[0] = eid
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm, pd)
	panel.show_window(root)
	var dia_before: int = pd.diamond
	panel.do_click_fast_stren()
	var le: Array = ReadequipData.get_equip_level_exp(eid, cm)["le"]
	var total: float = 0.0
	for v in le:
		total += float(v)
	assert_eq(float(hero.equip_exp[0]), total, "钻石一键 → exp 满级")
	assert_true(pd.diamond < dia_before, "钻石消耗")
	panel.remove_window()
	root.queue_free()


# 源 upFastStren:706 钻石不足 → hint
func test_do_click_fast_stren_no_diamond() -> void:
	var eid: int = _find_enchantable_equip()
	if eid == 0:
		pass_test("数据表无可附魔装备，跳过")
		return
	var pd := PlayerData.new(cm)
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.equip_slots[0] = eid
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm, pd)
	panel.show_window(root)
	panel.do_click_fast_stren()
	assert_eq(panel.get_talk_text(), "钻石不足", "钻石不足提示")
	panel.remove_window()
	root.queue_free()


# ===== 第三十五轮 NPC 对话系统 + 飘字动画（照源 createnpcTalk/doTalk/doSpeak + playAddmtAnim/playAddExpAnim）=====

# 源 createnpcTalk:11-43 + :2148 NPC 头像：setup 后建 NPC 头像 + 气泡 + 文字容器
func test_npc_talk_container_assembled() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	assert_not_null(panel._talk_container, "NPC 对话容器已建")
	assert_not_null(panel._npc_sprite, "NPC 头像 sprite 已建")
	assert_not_null(panel._talk_frame, "对话气泡 NinePatchRect 已建")
	assert_not_null(panel._talk_label, "对话文字 Label 已建")
	panel.remove_window()
	root.queue_free()


# 源 doTalk/doSpeak：_do_talk 常驻 modulate.a=1.0；_do_speak 同样初始不透明
func test_do_talk_and_speak_visible() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	EquipStrengthenAnim.hide_talk(panel)
	EquipStrengthenAnim.do_talk(panel,"常驻提示")
	assert_eq(panel.get_talk_text(), "常驻提示", "_do_talk 设文字")
	assert_true(panel.is_talk_visible(), "_do_talk 常驻可见")
	EquipStrengthenAnim.hide_talk(panel)
	assert_false(panel.is_talk_visible(), "_hide_talk 隐藏")
	EquipStrengthenAnim.do_speak(panel,"淡出提示")
	assert_eq(panel.get_talk_text(), "淡出提示", "_do_speak 设文字")
	assert_true(panel.is_talk_visible(), "_do_speak 初始可见（淡出前）")
	panel.remove_window()
	root.queue_free()


# 源 createnpcTalk:40 max(60, label.height+42)：空文字气泡高度 >= 60
func test_talk_frame_min_height() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	EquipStrengthenAnim.set_talk_text(panel,"")
	assert_true(panel._talk_frame.size.y >= 60.0, "气泡高度 >= 源最小 60")
	panel.remove_window()
	root.queue_free()


# 源 selectEquip:1664 未满级 doTalk PLEASE_ADD_MATERIAL 常驻
func test_select_slot_please_add_hint() -> void:
	var eid: int = _find_enchantable_equip()
	if eid == 0:
		pass_test("数据表无可附魔装备，跳过")
		return
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.equip_slots[0] = eid
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	# 源 PLEASE_ADD_MATERIAL_IT_CAN_BE_ADDED_TO_ALL_EQUIPMENTS LSTR value
	assert_eq(panel.get_talk_text(), String(cm.get_lstr("EQUIPSTRENGTHEN.PLEASE_ADD_MATERIAL_IT_CAN_BE_ADDED_TO_ALL_EQUIPMENTS")), "选可附魔槽 → PLEASE_ADD 常驻提示照源 LSTR")
	panel.remove_window()
	root.queue_free()


# 源 addMaterial:294/295 playAddmtAnim + playAddExpAnim：_add_material 生成 "+ehc" 飘字 label
func test_add_material_spawns_exp_label() -> void:
	var parts_id: int = _find_category_equip("EQUIP.PARTS")
	var eid: int = _find_enchantable_equip()
	if parts_id == 0 or eid == 0:
		pass_test("数据表缺 PARTS 或可附魔装备，跳过")
		return
	var pd := PlayerData.new(cm)
	pd.add_item(parts_id, 10)
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.equip_slots[0] = eid
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm, pd)
	panel.show_window(root)
	var idx: int = _find_mt_idx(panel, parts_id)
	var ehc: int = int(cm.get_raw_table(&"Equip")[str(parts_id)].get("Enhance Value", 0))
	EquipStrengthenMaterial.add_material(panel,idx)
	# 两件套 Task 5：飘字挂 %FxHost（content 树深层），递归扫全子树
	assert_true(_find_label_recursive(panel._content, "+" + str(ehc)), "_add_material 生成 +ehc 飘字 label（playAddExpAnim）")
	panel.remove_window()
	root.queue_free()


func _find_label_recursive(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for c in node.get_children():
		if _find_label_recursive(c, text):
			return true
	return false


func _count_meta(node: Node, meta_key: String) -> int:
	var count: int = 0
	if node.has_meta(meta_key):
		count += 1
	for c in node.get_children():
		count += _count_meta(c, meta_key)
	return count


# ===== LSTR 化验收（第三十六轮 照源 T(LSTR(...)) → cm.get_lstr）=====

# 源 createStrenButton:902/1013 按钮标签走 LSTR（ENCHANTING/ONECLICK_ENCHANTING）
func test_stren_button_labels_use_lstr() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	# apply_with_label 套 Scale9 + 加 Label 子节点（BtnLabel 变体），文字在子 Label 而非 btn.text
	# （参照 equip_craft_tree.gd:300 btn.get_child(0) as Label 范式）。
	var enchant_lbl: Label = panel._stren_btn.get_child(0) as Label
	var oneclick_lbl: Label = panel._faststren_btn.get_child(0) as Label
	assert_not_null(enchant_lbl, "_stren_btn 第一子节点是 Label")
	assert_not_null(oneclick_lbl, "_faststren_btn 第一子节点是 Label")
	var enchant_text := enchant_lbl.text if enchant_lbl != null else ""
	var oneclick_text := oneclick_lbl.text if oneclick_lbl != null else ""
	assert_eq(enchant_text, String(cm.get_lstr("EQUIPSTRENGTHEN.ENCHANTING")), "普通强化按钮标签照源 LSTR")
	assert_eq(oneclick_text, String(cm.get_lstr("EQUIPSTRENGTHEN.ONECLICK_ENCHANTING")), "一键强化按钮标签照源 LSTR")
	panel.remove_window()
	root.queue_free()


# 源 doStrenReply:73/75 成功/失败 hint 走 LSTR（成功路径用 _on_enhance_done(true)）
func test_on_enhance_done_success_uses_lstr() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	panel._on_enhance_done(true)
	assert_eq(panel.get_talk_text(), String(cm.get_lstr("EQUIPSTRENGTHEN.CONGRATULATIONS_ENCHANTED_SUCCESSFULLY")), "成功提示照源 LSTR")
	panel._on_enhance_done(false)
	assert_eq(panel.get_talk_text(), String(cm.get_lstr("EQUIPSTRENGTHEN.UNFORTUNATELY_ENCHANTED_FAILED")), "失败提示照源 LSTR")
	panel.remove_window()
	root.queue_free()


# 源 baseres.lua:115-121 enhance_level_res（附魔等级文字查表）
func test_baseres_enhance_level_text() -> void:
	# 源 enhance_level_res[1]=普通附魔 / [2]=高级附魔 / [3]=专家级附魔 / [4]=宗师级附魔 / [5]=传说级附魔
	assert_eq(BaseresData.get_enhance_level_text(1, cm), String(cm.get_lstr("BASERES.COMMON_ENCHANT")), "level 1 → 普通附魔")
	assert_eq(BaseresData.get_enhance_level_text(2, cm), String(cm.get_lstr("BASERES.SENIOR_ENCHANTING")), "level 2 → 高级附魔")
	assert_eq(BaseresData.get_enhance_level_text(3, cm), String(cm.get_lstr("BASERES.EXPERT_ENCHANTING")), "level 3 → 专家级附魔")
	assert_eq(BaseresData.get_enhance_level_text(4, cm), String(cm.get_lstr("BASERES.GRAND_MASTER_ENCHANTING")), "level 4 → 宗师级附魔")
	assert_eq(BaseresData.get_enhance_level_text(5, cm), String(cm.get_lstr("BASERES.LEGENDARY_ENCHANTING")), "level 5 → 传说级附魔")
	assert_eq(BaseresData.get_enhance_level_text(0, cm), "", "level 0 → 空串（调用方走 UNENCHANTED 分支）")
	assert_eq(BaseresData.get_enhance_level_text(99, cm), "", "越界 → 空串（源 or '' 容错）")


# 源 doShowmbPrompt:1971 CLICK_HERE_TO_OPEN（含 \N 换行占位，LSTR 生成器 2026-07-16 修 regex 后入表）
func test_material_hint_label_uses_lstr_with_newline() -> void:
	var eid: int = _find_enchantable_equip()
	if eid == 0:
		pass_test("数据表无可附魔装备，跳过")
		return
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.equip_slots[0] = eid
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	# material_label 文本 = CLICK_HERE LSTR value（含 \n 换行，Label text 自动渲染）
	var expected: String = String(cm.get_lstr("EQUIPSTRENGTHEN.CLICK_HERE_TO_OPEN_THE_PACK\\N_YOU_CAN_USE_ANY_EQUIPMENT_TO_ENCHANT"))
	assert_eq(panel._material_label.text, expected, "材料提示照源 LSTR（含 \\N 解码后 \\n 换行）")
	assert_true(expected.find("\n") >= 0, "LSTR value 含换行符（源 \\n 换行占位保留）")
	panel.remove_window()
	root.queue_free()


# ── 两件套守卫（批 1 Task 5，2026-08-15）：框架照源直译 + theme variation + 填充绑定 ──
# 源 equipstrengthen.lua create(:1994-2158)/createnpcTalk(:11-42)/createStrenButton(:789-1028)/
# createExpBar(:1109-1223)/createEquipAtt(:1416-1503) 静态树进 equip_strengthen_content.tscn；
# panel 只做业务/信号/fill。坐标 cocos(800x480 左下)→godot(960x640 左上) via (x+80, 560-y)，
# 显示尺寸=纹理像素÷CS(1.28125)，readnode 中心锚=源 createNode 默认 (0.5,0.5)。

const CS: float = 1.28125


func _instantiate_content() -> Control:
	var scene: PackedScene = load("res://scenes/ui/equip_strengthen_content.tscn") as PackedScene
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	return inst


func _assert_color_eq(actual: Color, expect: Color, msg: String) -> void:
	assert_almost_eq(actual.r, expect.r, 0.001, msg + " [r]")
	assert_almost_eq(actual.g, expect.g, 0.001, msg + " [g]")
	assert_almost_eq(actual.b, expect.b, 0.001, msg + " [b]")


func _center_of(n: Control) -> Vector2:
	return Vector2((n.offset_left + n.offset_right) / 2.0, (n.offset_top + n.offset_bottom) / 2.0)


# 源 create frame(400,230)/back(65,430) 中心锚 + setHeroIcon(:1728) head/name
func test_content_frame_layout_follows_source() -> void:
	var inst: Control = _instantiate_content()
	var frame: TextureRect = inst.get_node("Frame") as TextureRect
	assert_almost_eq(_center_of(frame).x, 480.0, 0.5, "frame 中心 x=480")
	assert_almost_eq(_center_of(frame).y, 330.0, 0.5, "frame 中心 y=330（源 230）")
	assert_almost_eq(frame.offset_right - frame.offset_left, 916.0 / CS, 0.5, "frame 宽=916/CS")
	assert_almost_eq(frame.offset_bottom - frame.offset_top, 580.0 / CS, 0.5, "frame 高=580/CS")
	var close: TextureButton = inst.get_node("%CloseBtn") as TextureButton
	assert_almost_eq(_center_of(close).x, 145.0, 0.5, "close 中心 x=145（源 65）")
	assert_almost_eq(_center_of(close).y, 130.0, 0.5, "close 中心 y=130（源 430）")
	assert_almost_eq(close.offset_right - close.offset_left, 74.0 / CS, 0.5, "close 宽=74/CS")
	var hero_icon: TextureRect = inst.get_node("HeroIcon") as TextureRect
	assert_almost_eq(_center_of(hero_icon).x, 215.0, 0.5, "heroIcon 中心 x=215（源 135）")
	assert_almost_eq(_center_of(hero_icon).y, 220.0, 0.5, "heroIcon 中心 y=220（源 340）")
	var head_host: Control = inst.get_node("%HeroHeadHost") as Control
	assert_almost_eq(_center_of(head_host).x, 215.0, 0.5, "HeadHost 与 heroIcon 同心")
	assert_almost_eq(head_host.offset_right - head_host.offset_left, 104.0, 0.5, "HeadHost 104×104（ReadheroIcon 容器）")
	var hero_name: Label = inst.get_node("%HeroName") as Label
	assert_almost_eq(_center_of(hero_name).x, 210.0, 1.0, "heroName 中心 x=210（源 :1758 中心 130）")
	assert_almost_eq(_center_of(hero_name).y, 165.0, 1.0, "heroName 中心 y=165（源 395）")


# 源 create npc(638,378) readnode 中心锚（三坑#2：中心锚勿当左下）+ createnpcTalk :11-42
func test_npc_and_talk_layout_follows_source() -> void:
	var inst: Control = _instantiate_content()
	var npc: TextureRect = inst.get_node("%NpcSprite") as TextureRect
	assert_almost_eq(_center_of(npc).x, 718.0, 0.5, "NPC 中心 x=718（源 638 中心锚）")
	assert_almost_eq(_center_of(npc).y, 182.0, 0.5, "NPC 中心 y=182（源 378）")
	assert_almost_eq(npc.offset_right - npc.offset_left, 267.0 / CS, 0.5, "NPC 宽=267/CS")
	var frame: NinePatchRect = inst.get_node("%TalkFrame") as NinePatchRect
	assert_almost_eq((frame.offset_left + frame.offset_right) / 2.0, 725.0, 0.5, "气泡中心 x=725（源 645）")
	assert_almost_eq(frame.offset_top, 255.0, 0.5, "气泡顶 y=255（源 :23 anchor(0.5,1) 305）")
	assert_almost_eq(frame.offset_right - frame.offset_left, 224.0, 0.5, "气泡宽 224（源 :21）")
	assert_eq(frame.patch_margin_left, 30, "气泡 cap left=30（源 :20）")
	assert_eq(frame.patch_margin_right, 91, "气泡 cap right=266-30-145")
	var talk_lbl: Label = inst.get_node("%TalkLabel") as Label
	assert_almost_eq(talk_lbl.offset_left, 625.0, 0.5, "对话文字左 x=625（725-200/2）")
	assert_almost_eq(talk_lbl.offset_top, 278.0, 0.5, "对话文字顶 y=278（源 :28 anchor(0.5,1) 282）")
	assert_almost_eq(talk_lbl.offset_right - talk_lbl.offset_left, 200.0, 0.5, "对话文字宽 200（源 :31）")
	assert_eq(talk_lbl.autowrap_mode != TextServer.AUTOWRAP_OFF, true, "对话文字自动换行（源 setLabelDimensions）")


# 源 createStrenButton :805-1024：money_bg(665,185)/no_cost(665,185)/money_icon(615,183)/
# money(715,183 右中)/stren(666,145)/rmb_bg(665,102)/rmb_icon(620,100)/rmb(715,100 右中)/faststren(666,60)
func test_stren_buttons_layout_follows_source() -> void:
	var inst: Control = _instantiate_content()
	var stren: Button = inst.get_node("%StrenBtn") as Button
	assert_almost_eq(_center_of(stren).x, 746.0, 0.5, "stren 中心 x=746（源 666）")
	assert_almost_eq(_center_of(stren).y, 415.0, 0.5, "stren 中心 y=415（源 145）")
	assert_almost_eq(stren.offset_right - stren.offset_left, 125.0, 0.5, "stren 宽 125（源 scaleSize）")
	assert_almost_eq(stren.offset_bottom - stren.offset_top, 45.0, 0.5, "stren 高 45")
	var fast: Button = inst.get_node("%FastStrenBtn") as Button
	assert_almost_eq(_center_of(fast).x, 746.0, 0.5, "faststren 中心 x=746（源 666）")
	assert_almost_eq(_center_of(fast).y, 500.0, 0.5, "faststren 中心 y=500（源 60）")
	var money_bg: TextureRect = inst.get_node("%MoneyBg") as TextureRect
	assert_almost_eq(_center_of(money_bg).x, 745.0, 0.5, "money_bg 中心 x=745（源 665）")
	assert_almost_eq(_center_of(money_bg).y, 375.0, 0.5, "money_bg 中心 y=375（源 185）")
	assert_almost_eq(money_bg.offset_right - money_bg.offset_left, 158.0 / CS, 0.5, "money_bg 宽=158/CS")
	var no_cost: Label = inst.get_node("%NoCostLabel") as Label
	assert_almost_eq(_center_of(no_cost).y, 375.0, 0.5, "no_cost 中心 y=375（源 185）")
	var money_icon: TextureRect = inst.get_node("%MoneyIcon") as TextureRect
	assert_almost_eq(_center_of(money_icon).x, 695.0, 0.5, "money_icon 中心 x=695（源 615）")
	assert_almost_eq(_center_of(money_icon).y, 377.0, 0.5, "money_icon 中心 y=377（源 183）")
	var money_lbl: Label = inst.get_node("%MoneyLabel") as Label
	assert_almost_eq(money_lbl.offset_right, 795.0, 0.5, "money 右端 x=795（源 715 右中锚）")
	assert_almost_eq((money_lbl.offset_top + money_lbl.offset_bottom) / 2.0, 377.0, 0.5, "money 中心 y=377")
	var rmb_icon: TextureRect = inst.get_node("%RmbIcon") as TextureRect
	assert_almost_eq(_center_of(rmb_icon).x, 700.0, 0.5, "rmb_icon 中心 x=700（源 620）")
	assert_almost_eq(_center_of(rmb_icon).y, 460.0, 0.5, "rmb_icon 中心 y=460（源 100）")
	var rmb_lbl: Label = inst.get_node("%RmbLabel") as Label
	assert_almost_eq(rmb_lbl.offset_right, 795.0, 0.5, "rmb 右端 x=795（源 715 右中锚）")
	assert_almost_eq((rmb_lbl.offset_top + rmb_lbl.offset_bottom) / 2.0, 460.0, 0.5, "rmb 中心 y=460")


# 源 createExpBar :1127-1218：bar_bg(400,212)/b_lv(75,235 左中)/n_lv(725,235 右中)/
# bar(72,213 左中 裁剪条)/anim_bar(同 bar 隐)/ehc(400,212)
func test_exp_bar_layout_follows_source() -> void:
	var inst: Control = _instantiate_content()
	var bar_bg: TextureRect = inst.get_node("%BarBg") as TextureRect
	assert_almost_eq(_center_of(bar_bg).x, 480.0, 0.5, "bar_bg 中心 x=480（源 400）")
	assert_almost_eq(_center_of(bar_bg).y, 348.0, 0.5, "bar_bg 中心 y=348（源 212）")
	assert_almost_eq(bar_bg.offset_right - bar_bg.offset_left, 842.0 / CS, 0.5, "bar_bg 宽=842/CS")
	var bar: TextureRect = inst.get_node("%Bar") as TextureRect
	assert_almost_eq(bar.offset_left, 152.0, 0.5, "bar 左端 x=152（源 72 左中锚）")
	assert_almost_eq((bar.offset_top + bar.offset_bottom) / 2.0, 347.0, 0.5, "bar 中心 y=347（源 213）")
	assert_true(bar.texture is AtlasTexture, "bar 走 AtlasTexture 裁剪（源 setTextureRect 宽随值）")
	var anim: TextureRect = inst.get_node("%AnimBar") as TextureRect
	assert_almost_eq(anim.offset_left, 152.0, 0.5, "anim_bar 左端同 bar")
	assert_false(anim.visible, "anim_bar 默认隐（源 :1199）")
	var b_lv: Label = inst.get_node("%BarLevelLabel") as Label
	assert_almost_eq(b_lv.offset_left, 155.0, 0.5, "b_lv 左端 x=155（源 75 左中锚）")
	assert_almost_eq((b_lv.offset_top + b_lv.offset_bottom) / 2.0, 325.0, 0.5, "b_lv 中心 y=325（源 235）")
	var n_lv: Label = inst.get_node("%NextLevelLabel") as Label
	assert_almost_eq(n_lv.offset_right, 805.0, 0.5, "n_lv 右端 x=805（源 725 右中锚）")
	assert_almost_eq((n_lv.offset_top + n_lv.offset_bottom) / 2.0, 325.0, 0.5, "n_lv 中心 y=325")
	var ehc: Label = inst.get_node("%EhcLabel") as Label
	assert_almost_eq(_center_of(ehc).x, 480.0, 0.5, "ehc 中心 x=480（源 400）")
	assert_almost_eq(_center_of(ehc).y, 348.0, 0.5, "ehc 中心 y=348（源 212）")


# 源 createEquipAtt ui_info :1443-1492：name_bg(345,415 左中)/name(347,415)/level(347,385)
func test_att_area_layout_follows_source() -> void:
	var inst: Control = _instantiate_content()
	var name_bg: TextureRect = inst.get_node("AttHost/AttNameBg") as TextureRect
	assert_almost_eq(name_bg.offset_left, 425.0, 0.5, "name_bg 左端 x=425（源 345 anchor(0,0.5)）")
	assert_almost_eq((name_bg.offset_top + name_bg.offset_bottom) / 2.0, 145.0, 0.5, "name_bg 中心 y=145（源 415）")
	assert_almost_eq(name_bg.offset_right - name_bg.offset_left, 197.0 / CS, 0.5, "name_bg 宽=197/CS")
	var name_lbl: Label = inst.get_node("%AttNameLabel") as Label
	assert_almost_eq(name_lbl.offset_left, 427.0, 0.5, "name 左端 x=427（源 347）")
	assert_almost_eq((name_lbl.offset_top + name_lbl.offset_bottom) / 2.0, 145.0, 0.5, "name 中心 y=145")
	var level_lbl: Label = inst.get_node("%AttLevelLabel") as Label
	assert_almost_eq(level_lbl.offset_left, 427.0, 0.5, "level 左端 x=427（源 347）")
	assert_almost_eq((level_lbl.offset_top + level_lbl.offset_bottom) / 2.0, 175.0, 0.5, "level 中心 y=175（源 385）")


# 源 doShowmbPrompt :1959-1982 宽窄两态 + createmtListLayer :393-412 cliprect(98,42,500,155)
# 三坑#3：可滚动列表→场景级裁剪层
func test_material_area_layout_follows_source() -> void:
	var inst: Control = _instantiate_content()
	var mbg: NinePatchRect = inst.get_node("%MaterialBg") as NinePatchRect
	assert_almost_eq(_center_of(mbg).x, 480.0, 0.5, "材料 bg 宽态中心 x=480（源 400）")
	assert_almost_eq(_center_of(mbg).y, 440.0, 0.5, "材料 bg 中心 y=440（源 120）")
	assert_almost_eq(mbg.offset_right - mbg.offset_left, 660.0, 0.5, "材料 bg 宽态 660（源 :1976）")
	assert_almost_eq(mbg.offset_bottom - mbg.offset_top, 154.0, 0.5, "材料 bg 高 154")
	var mlbl: Label = inst.get_node("%MaterialLabel") as Label
	assert_almost_eq(_center_of(mlbl).x, 405.0, 0.5, "材料提示中心 x=405（源 325）")
	assert_almost_eq(_center_of(mlbl).y, 440.0, 0.5, "材料提示中心 y=440（源 120）")
	assert_false(mlbl.visible, "材料提示默认隐（源 :2144 visible=false）")
	var clip: Control = inst.get_node("%MtClip") as Control
	assert_almost_eq(clip.offset_left, 178.0, 0.5, "裁剪层左=源 cliprect 98+80")
	assert_almost_eq(clip.offset_top, 363.0, 0.5, "裁剪层顶=560-(42+155)")
	assert_almost_eq(clip.offset_right, 678.0, 0.5, "裁剪层右=178+500")
	assert_almost_eq(clip.offset_bottom, 518.0, 0.5, "裁剪层底=560-42")
	assert_true(clip.clip_contents, "裁剪层 clip_contents（源 ClippingNode）")


# 源 createEquip:1576-1638 + getEquipPos:1566（2列3行 中心 235..387/155..299 → godot 315..387/155..299）
func test_equip_slot_hosts_static() -> void:
	var inst: Control = _instantiate_content()
	var centers: Array[Vector2] = [
		Vector2(315.0, 155.0), Vector2(387.0, 155.0),
		Vector2(315.0, 227.0), Vector2(387.0, 227.0),
		Vector2(315.0, 299.0), Vector2(387.0, 299.0),
	]
	for i in 6:
		var host: Control = inst.get_node("%EquipSlot" + str(i)) as Control
		assert_almost_eq(_center_of(host).x, centers[i].x, 0.5, "槽 %d 中心 x" % i)
		assert_almost_eq(_center_of(host).y, centers[i].y, 0.5, "槽 %d 中心 y" % i)
		assert_not_null(host.get_node_or_null("EmptyRect"), "槽 %d 空位占位常驻（源 gocha）" % i)
		assert_eq(host.mouse_filter, Control.MOUSE_FILTER_STOP, "槽 %d 响应点击" % i)


# theme 表项断言（方法学沉淀：GUT 节点级不解析 variation，读 default_theme.tres 表项）
func test_theme_equip_stren_entries() -> void:
	var theme: Theme = load("res://resources/themes/default_theme.tres") as Theme
	# 源 :817-866 size18 阴影(0,2)（no_cost/money/rmb/no_fastcost/att name 共用规格）
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "EquipStrenLabel18"), 18, "通用 18 号")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "EquipStrenLabel18") as Color,
		Color.WHITE, "通用 18 号白")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_shadow_color", "EquipStrenLabel18") as Color,
		Color.BLACK, "通用 18 号黑阴影")
	# 源 :1145-1156 b_lv/n_lv size18 ccc3(146,0,9) 阴影(0,1)
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "EquipStrenBarLevelLabel"), 18, "等级字号 18")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "EquipStrenBarLevelLabel") as Color,
		Color(146.0 / 255.0, 0.0, 9.0 / 255.0), "等级色 (146,0,9)")
	# 源 :1203-1217 ehc size16 stroke(0,0,0,2)
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "EquipStrenEhcLabel"), 16, "ehc 字号 16")
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_CONSTANT, "outline_size", "EquipStrenEhcLabel"), 2, "ehc 描边 2")
	# 源 :1475-1492 level size18 ccc3(255,120,0) 阴影(0,1)
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "EquipStrenAttLevelLabel"), 18, "附魔等级字号 18")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "EquipStrenAttLevelLabel") as Color,
		Color(1.0, 120.0 / 255.0, 0.0), "附魔等级色 (255,120,0)")
	# 源 :2126-2145 material_label size22 白
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "EquipStrenMaterialLabel"), 22, "材料提示字号 22")
	# 源 :26-32 talk label size18 白
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "EquipStrenTalkLabel"), 18, "对话字号 18")
	# 源 createAttList :1366-1414 四色 18 号 + 阴影(0,1)
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "EquipStrenAttPreLabel"), 18, "att pre 18")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "EquipStrenAttPreLabel") as Color,
		Color.WHITE, "att pre 白")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "EquipStrenAttValLabel") as Color,
		Color(1.0, 0.0, 0.0), "att 红")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "EquipStrenAttAddLabel") as Color,
		Color(0.0, 1.0, 0.0), "add 绿")
	_assert_color_eq(theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "EquipStrenAttSufLabel") as Color,
		Color.BLACK, "suf 黑")


# fill 行为：源 refreshStrenCost :504-533 无材料 no_cost 显/icon+money 隐；有材料反转
func test_fill_money_area_visibility_toggle() -> void:
	var parts_id: int = _find_category_equip("EQUIP.PARTS")
	var eid: int = _find_enchantable_equip()
	if parts_id == 0 or eid == 0:
		pass_test("数据表缺 PARTS 或可附魔装备，跳过")
		return
	var pd := PlayerData.new(cm)
	pd.add_item(parts_id, 10)
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.equip_slots[0] = eid
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm, pd)
	panel.show_window(root)
	var no_cost: Label = panel._content.get_node("%NoCostLabel")
	var money_icon: TextureRect = panel._content.get_node("%MoneyIcon")
	var money_lbl: Label = panel._content.get_node("%MoneyLabel")
	assert_true(no_cost.visible, "无材料 no_cost 显（源 :518）")
	assert_false(money_icon.visible, "无材料 money_icon 隐（源 :519）")
	assert_false(money_lbl.visible, "无材料 money 隐（源 :520）")
	var idx: int = _find_mt_idx(panel, parts_id)
	EquipStrengthenMaterial.add_material(panel, idx)
	assert_false(no_cost.visible, "加材料 no_cost 隐（源 :522）")
	assert_true(money_icon.visible, "加材料 money_icon 显（源 :523）")
	assert_true(money_lbl.visible, "加材料 money 显（源 :524）")
	assert_eq(money_lbl.text.is_valid_int(), true, "金币数为纯数字（源 :515 ed.setString(money, cost) 无前缀）")
	panel.remove_window()
	root.queue_free()


# fill 行为：源 initStrenButton :476-478 rmb=纯数字 + doShowMaxLevel :1924-1927 满级切提示
func test_fill_fast_stren_cost_number() -> void:
	var eid: int = _find_enchantable_equip()
	if eid == 0:
		pass_test("数据表无可附魔装备，跳过")
		return
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.equip_slots[0] = eid
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	var rmb_lbl: Label = panel._content.get_node("%RmbLabel")
	var rmb_icon: TextureRect = panel._content.get_node("%RmbIcon")
	assert_true(rmb_lbl.text.is_valid_int(), "钻石 cost 为纯数字（源 :964 无前缀）")
	assert_true(int(rmb_lbl.text) > 0, "可附魔装备钻石 cost>0")
	assert_true(rmb_icon.visible, "rmb_icon 显")
	panel.remove_window()
	root.queue_free()


# fill 行为：源 createEquipAtt name/level 文字 + attList 首行左端（refreshAttListPos :1334 ox=347）
func test_fill_att_labels_and_list_row() -> void:
	var eid: int = _find_enchantable_equip()
	if eid == 0:
		pass_test("数据表无可附魔装备，跳过")
		return
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.equip_slots[0] = eid
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	var name_lbl: Label = panel._content.get_node("%AttNameLabel")
	assert_ne(name_lbl.text, "", "装备名 fill（源 :1459 getEquipName）")
	var level_lbl: Label = panel._content.get_node("%AttLevelLabel")
	assert_ne(level_lbl.text, "", "附魔等级 fill（源 :1478 getLevelText）")
	# 动态 att 行首列（pre）左端 x=427（源 ox=347 → +80），行内内容宽拼接（:1339-1361）
	var first_pre: Label = null
	for child in panel._content.get_node("AttHost").get_children():
		if child is Label and child.has_meta("att"):
			var lbl: Label = child as Label
			if first_pre == null or lbl.position.x < first_pre.position.x:
				first_pre = lbl
	assert_not_null(first_pre, "动态属性行已建（meta att）")
	if first_pre != null:
		assert_almost_eq(first_pre.position.x, 427.0, 2.0, "首列 pre 左端 x=427（源 347+80）")
	panel.remove_window()
	root.queue_free()


# fill 行为：材料格挂裁剪层 + ehcBg（源 createmt :127-132 漏译本批补）
func test_fill_material_icons_clipped_with_ehc_bg() -> void:
	var parts_id: int = _find_category_equip("EQUIP.PARTS")
	var eid: int = _find_enchantable_equip()
	if parts_id == 0 or eid == 0:
		pass_test("数据表缺 PARTS 或可附魔装备，跳过")
		return
	var pd := PlayerData.new(cm)
	pd.add_item(parts_id, 10)
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.equip_slots[0] = eid
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm, pd)
	panel.show_window(root)
	var clip: Control = panel._content.get_node("%MtClip")
	assert_gt(clip.get_child_count(), 0, "材料格挂裁剪层")
	var icon: Control = clip.get_child(0) as Control
	var has_ehc_bg: bool = false
	for c in icon.get_children():
		if (c as Node).get("texture") != null and String((c as Node).name).find("EhcBg") >= 0:
			has_ehc_bg = true
	assert_true(has_ehc_bg, "材料格带 ehcBg 数量底（源 :127-132）")
	panel.remove_window()
	root.queue_free()


# fill 行为：源 setHeroIcon :1728-1776 head 替换 heroIcon 框 + 名字（单机化 hero 已定即显示）
func test_fill_hero_head_and_name() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	var head_host: Control = panel._content.get_node("%HeroHeadHost")
	assert_gt(head_host.get_child_count(), 0, "英雄头像已 fill（源 setHeroIcon 换 readhero icon）")
	assert_false(panel._content.get_node("HeroIcon").visible, "头像框隐（源 :1741 removeFromParent）")
	var name_lbl: Label = panel._content.get_node("%HeroName")
	assert_ne(name_lbl.text, "", "英雄名 fill（源 :1753 createHeroName）")
	panel.remove_window()
	root.queue_free()


# 两件套红线：panel 静态结构零 .new()（白名单式；静态节点全在 content tscn，
# ReadheroIcon=头像数据工厂，eatexp ReadheroIcon 同款白名单先例）
func test_panel_no_static_construction() -> void:
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/equip_strengthen_panel.gd")
	assert_eq(text.count(".new()"), text.count("ReadheroIcon.new()"),
		"panel 静态节点零 .new()，仅头像工厂白名单")


# 源 refreshStrenCost:527 YOUR_MONEY_IS_NOT_ENOUGH 不足提示（金币不足路径）
func test_money_short_uses_lstr() -> void:
	var parts_id: int = _find_category_equip("EQUIP.PARTS")
	var eid: int = _find_enchantable_equip()
	if parts_id == 0 or eid == 0:
		pass_test("数据表缺 PARTS 或可附魔装备，跳过")
		return
	var pd := PlayerData.new(cm)
	pd.add_item(parts_id, 10)
	# 不给金币 → 任何 cost 都判不足
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	hero.equip_slots[0] = eid
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm, pd)
	panel.show_window(root)
	var idx: int = _find_mt_idx(panel, parts_id)
	EquipStrengthenMaterial.add_material(panel,idx)
	assert_eq(panel.get_talk_text(), String(cm.get_lstr("EQUIPSTRENGTHEN.YOUR_MONEY_IS_NOT_ENOUGH")), "金币不足提示照源 LSTR")
	panel.remove_window()
	root.queue_free()
