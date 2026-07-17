extends GutTest
# 装备强化面板测试（第三十二轮 Step 1+2+3 骨架 + 第三十三轮 Step 4 材料列表，照源 ui/equipstrengthen.lua）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _find_enchantable_equip() -> int:
	var et: Dictionary = cm.get_raw_table(&"Equip")
	for id in et:
		if int(et[id].get("Quality", 0)) >= 2:
			return int(id)
	return 0


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
	var att_count: int = 0
	for child in panel.container.get_children():
		if child.has_meta("att"):
			att_count += 1
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
	assert_true(panel._cost_label.text.find("金币") >= 0, "金币预览显示")
	# 源 NO_MATERIAL_ADDED LSTR value（无材料时显示，有材料 → 非此文本）
	assert_false(panel._cost_label.text == String(cm.get_lstr("EQUIPSTRENGTHEN.NO_MATERIAL_ADDED")), "有材料 → 非提示")
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
	assert_true(panel._diamond_cost_label.text.find("钻石") >= 0, "选可附魔槽 → 钻石 cost 显示")
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
	var found: bool = false
	for child in panel.container.get_children():
		if child is Label and (child as Label).text == "+" + str(ehc):
			found = true
			break
	assert_true(found, "_add_material 生成 +ehc 飘字 label（playAddExpAnim）")
	panel.remove_window()
	root.queue_free()


# ===== LSTR 化验收（第三十六轮 照源 T(LSTR(...)) → cm.get_lstr）=====

# 源 createStrenButton:902/1013 按钮标签走 LSTR（ENCHANTING/ONECLICK_ENCHANTING）
func test_stren_button_labels_use_lstr() -> void:
	var root := Node.new()
	add_child(root)
	var hero := HeroInstance.new(1, 1, 1)
	var panel := EquipStrengthenPanel.new("equipstrengthen", {})
	panel.setup_panel(hero, cm)
	panel.show_window(root)
	var enchant_text := panel._stren_btn.text
	var oneclick_text := panel._faststren_btn.text
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
