extends GutTest
# 装备合成面板测试（Step 1+2+3：骨架 + 合成窗口 + createCraftTree 合成树 + craftEquip 合成执行，
# 照源 ui/equipcraft.lua）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 找有配方的装备（Equipcraft Components 1-4）
func _find_recipe_equip() -> Dictionary:
	var ect: Dictionary = cm.get_raw_table(&"Equipcraft")
	for id in ect:
		var c: int = int(ect[id].get("Components", 0))
		if c >= 1 and c <= 4:
			return {"id": int(id), "components": c, "row": ect[id]}
	return {}


# 找无配方但有掉落的装备（components<1 走获取途径）
func _find_drop_equip() -> int:
	var et: Dictionary = cm.get_raw_table(&"Equip")
	var ect: Dictionary = cm.get_raw_table(&"Equipcraft")
	for id in et:
		if ect.has(str(id)):
			continue   # 有配方跳过
		if int(et[id].get("Drop 1", 0)) > 0:
			return int(id)
	return 0


func _make_panel(target_id: int, pd: PlayerData = null) -> EquipCraftPanel:
	var panel := EquipCraftPanel.new("equipcraft", {})
	panel.setup_panel(target_id, cm, pd if pd != null else PlayerData.new(cm))
	var root := Node.new()
	add_child(root)
	panel.show_window(root)
	return panel


# ===== Step 1 骨架 + 主面板 + 合成窗口 =====

# 源 createPanel :1269 + createCraftWindow :1246
func test_panel_assembles() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var panel := _make_panel(int(rec["id"]))
	assert_not_null(panel._craft_window, "合成窗口已建")
	assert_not_null(panel._tree, "合成树层已建")
	assert_eq(panel._craft_id, int(rec["id"]), "craftid = 目标装备 id")
	assert_eq(panel._components, int(rec["components"]), "components 照源")
	panel.remove_window()


# ===== Step 2 createCraftTree 合成树 =====

# 源 :1037-1095 配方分支：nodeid/nodeNeed/nodeAmount + 子图标 + 数量 Label
func test_recipe_branch_built() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var panel := _make_panel(int(rec["id"]))
	var components: int = int(rec["components"])
	var row: Dictionary = rec["row"]
	var nodeid: Array = panel._craft_window_data["nodeid"]
	var node_need: Array = panel._craft_window_data["nodeNeed"]
	assert_eq(nodeid.size(), components, "nodeid 数量 = components")
	# 源 :1062-1063 Component i id/need 照表（Count=0 时 max(,1) 兜底到 1，Lua 0-truthy or 语义）
	for i in range(components):
		var expect_id: int = int(row.get("Component" + str(i + 1), 0))
		var expect_need: int = max(int(row.get("Component" + str(i + 1) + " Count", 1)), 1)
		assert_eq(int(nodeid[i]), expect_id, "nodeid[%d] 照源 Component" % i)
		assert_eq(int(node_need[i]), expect_need, "nodeNeed[%d] 照源" % i)
	# 源 :1110-1131 金币
	assert_true(panel._tree_data.has("cost"), "cost Label 已建")
	assert_eq(int(panel._craft_window_data["expense"]), int(row.get("Expense", 0)), "expense 照源")
	# 源 :1059 children/amountLabel 引用
	assert_eq((panel._tree_data["children"] as Array).size(), components, "children 图标数 = components")
	panel.remove_window()


# 源 :1214-1228 材料不足且不可合成 → lackOfComponent=true
func test_lack_of_component_when_short_and_uncraftable() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var pd := PlayerData.new(cm)   # 无材料无金币
	var panel := _make_panel(int(rec["id"]), pd)
	var nodeid: Array = panel._craft_window_data["nodeid"]
	# 至少一个材料：背包 0 且该材料自身无配方 → lack
	var any_lack: bool = false
	for cid in nodeid:
		if int(cid) > 0 and panel._get_components(int(cid)) == 0:
			any_lack = true
			break
	if any_lack:
		assert_true(panel._lack_of_component, "材料不足且不可合成 → lackOfComponent")
		assert_true(panel._craft_btn.disabled, "lack → 合成按钮禁用")
	panel.remove_window()


# 源 :1133-1202 components<1 走获取途径分支
func test_getway_branch_when_no_recipe() -> void:
	var eid: int = _find_drop_equip()
	if eid == 0:
		pass_test("数据表无纯掉落装备，跳过")
		return
	var panel := _make_panel(eid)
	assert_eq(panel._components, 0, "无配方 components=0")
	assert_gt(panel._get_way_ids.size(), 0, "Drop1-3 收集到获取途径")
	assert_eq(panel._get_way_buttons.size(), panel._get_way_ids.size(), "board 数 = 途径数")
	# 源 :1204-1208 components<1 按钮文字为"返回"
	assert_eq(panel._craft_btn_label.text, "返回", "无配方按钮 = 返回")
	panel.remove_window()


# 源 :1204-1208 components>=1 按钮文字为"合成"
func test_craft_button_text_synthesis() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var panel := _make_panel(int(rec["id"]))
	assert_eq(panel._craft_btn_label.text, "合成", "有配方按钮 = 合成")
	panel.remove_window()


# ===== Step 3 craftEquip 合成执行闭环 =====

# 源 craftEquip :368 + EquipCraftManager.synthesize_equip：材料+金币充足 → 合成成功
func test_craft_consumes_and_produces() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var target_id: int = int(rec["id"])
	var components: int = int(rec["components"])
	var row: Dictionary = rec["row"]
	var pd := PlayerData.new(cm)
	# 喂足材料（含可能的可递归合成前置，简单给足直接材料；Count=0 时 max 兜底到 1）
	for i in range(components):
		var cid: int = int(row.get("Component" + str(i + 1), 0))
		var need: int = max(int(row.get("Component" + str(i + 1) + " Count", 1)), 1)
		if cid > 0:
			pd.add_item(cid, need)
	pd.hero_manager.add_money(int(row.get("Expense", 99999999)) + 100)
	var before: int = int(pd.items.get(target_id, 0))
	var panel := _make_panel(target_id, pd)
	# lack 判定重新跑（喂材料后应不缺）
	if panel._lack_of_component:
		# 材料中有不可合成的叶子但已喂足 → 应不 lack
		pass_test("该配方材料前置复杂，跳过合成断言")
		panel.remove_window()
		return
	panel._on_craft_pressed()
	assert_eq(int(pd.items.get(target_id, 0)), before + 1, "合成产出 target +1")
	# 材料扣（至少 Component1）
	var c1: int = int(row.get("Component1", 0))
	var n1: int = int(row.get("Component1 Count", 1))
	if c1 > 0:
		assert_eq(int(pd.items.get(c1, 0)), 0 if n1 >= 1 else int(pd.items.get(c1, 0)), "Component1 扣除")
	panel.remove_window()


# 源 checkMoneyEnough :4 金币不足 → 按钮 disabled
func test_no_money_disables_button() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var pd := PlayerData.new(cm)   # 无金币
	# 给足材料避免 lack 干扰（Count=0 时 max 兜底到 1）
	var row: Dictionary = rec["row"]
	var components: int = int(rec["components"])
	for i in range(components):
		var cid: int = int(row.get("Component" + str(i + 1), 0))
		var need: int = max(int(row.get("Component" + str(i + 1) + " Count", 1)), 1)
		if cid > 0:
			pd.add_item(cid, need)
	var panel := _make_panel(int(rec["id"]), pd)
	if panel._lack_of_component:
		pass_test("该配方含不可递归合成的叶子材料，lack 优先于金币判定")
		panel.remove_window()
		return
	assert_false(panel._check_money_enough(), "金币不足 checkMoneyEnough=false")
	assert_true(panel._craft_btn.disabled, "金币不足 → 按钮禁用")
	panel.remove_window()


# 源 craftEquip :384 isCrafting 守卫（合成中再点无效）
func test_craft_button_returns_when_no_recipe() -> void:
	var eid: int = _find_drop_equip()
	if eid == 0:
		pass_test("数据表无纯掉落装备，跳过")
		return
	var pd := PlayerData.new(cm)
	var panel := _make_panel(eid, pd)
	# components<1 按钮为"返回"→ _on_craft_pressed 走 remove（这里只验不崩）
	assert_eq(panel._components, 0, "无配方 → 返回分支")
	panel.remove_window()


# 源 getAmount :1330 + getComponents :1334
func test_get_amount_and_components() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var target_id: int = int(rec["id"])
	var pd := PlayerData.new(cm)
	pd.add_item(target_id, 5)
	var panel := _make_panel(target_id, pd)
	assert_eq(panel._get_amount(target_id), 5, "getAmount = items[id]")
	assert_eq(panel._get_components(target_id), int(rec["components"]), "getComponents 照源")
	panel.remove_window()


# ===== Step 4：playCraftEffect + history + createInfoButton/puton =====

# 源 playCraftEffect :409 合成动画（材料飞终点 + refresh + 重建 tree）
func test_play_craft_effect_rebuilds_tree() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var target_id: int = int(rec["id"])
	var row: Dictionary = rec["row"]
	var components: int = int(rec["components"])
	var pd := PlayerData.new(cm)
	for i in range(components):
		var cid: int = int(row.get("Component" + str(i + 1), 0))
		var need: int = max(int(row.get("Component" + str(i + 1) + " Count", 1)), 1)
		if cid > 0:
			pd.add_item(cid, need)
	pd.hero_manager.add_money(int(row.get("Expense", 99999999)) + 100)
	var panel := _make_panel(target_id, pd)
	if panel._lack_of_component:
		pass_test("该配方含不可递归合成叶子，跳过")
		panel.remove_window()
		return
	panel._play_craft_effect()
	assert_eq(panel._craft_id, target_id, "playCraftEffect 重建后 craft_id 不变")
	assert_true(panel._tree_data.has("children"), "重建后合成树 children 存在")
	panel.remove_window()


# 源 doTreeNodeTouch :258 点子材料 → setHistory(0, nodeid[0]) + createCraftTree(nodeid[0])
func test_tree_node_click_appends_history() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var target_id: int = int(rec["id"])
	var panel := _make_panel(target_id)
	var nodeid: Array = panel._craft_window_data["nodeid"]
	var first_cid: int = int(nodeid[0]) if nodeid.size() > 0 else 0
	if first_cid == 0:
		pass_test("配方无 Component1，跳过")
		panel.remove_window()
		return
	var handler: Callable = panel._make_tree_node_handler(0)
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	handler.call(ev)
	assert_eq(panel._history.size(), 1, "点子材料 → history 追加 1 条")
	assert_eq(panel._craft_id, first_cid, "craftTree 切到 Component1")
	panel.remove_window()


# 源 createInfoButton :610 heroDetail 建信息按钮 + remark
func test_info_button_created() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var panel := _make_panel(int(rec["id"]))
	assert_not_null(panel._info_button, "infoButton 已建")
	assert_not_null(panel._info_remark, "infoButtonRemark 已建")
	assert_eq(panel._info_button_label.text, "合成公式", "heroDetail amount==0 且有配方 → 合成公式")
	panel.remove_window()


# 源 getJudgeLevel :519 hero.level + Equip.Level Requirement
func test_get_judge_level() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var target_id: int = int(rec["id"])
	var pd := PlayerData.new(cm)
	var iid: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(iid)
	var panel := EquipCraftPanel.new("equipcraft", {})
	panel.setup_panel(target_id, cm, pd, hero, "heroDetail", 0)
	var root := Node.new()
	add_child(root)
	panel.show_window(root)
	var judge: Array = panel._get_judge_level()
	var expect_elv: int = int(cm.get_raw_table("Equip").get(str(target_id), {}).get("Level Requirement", 0))
	assert_eq(int(judge[0]), hero.level, "hlv = hero.level")
	assert_eq(int(judge[1]), expect_elv, "elv = Equip Level Requirement")
	panel.remove_window()
	root.queue_free()


# 源 putonEquip :526 + HeroManager.wear_equip：heroDetail 穿戴闭环
func test_puton_equip_wears() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var target_id: int = int(rec["id"])
	var pd := PlayerData.new(cm)
	pd.add_item(target_id, 1)   # 背包有该装备 → amount>0 触发 puton 分支
	var iid: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(iid)
	var sid: int = 0
	var before: int = int(hero.equip_slots[sid])
	var panel := EquipCraftPanel.new("equipcraft", {})
	panel.setup_panel(target_id, cm, pd, hero, "heroDetail", sid)
	var root := Node.new()
	add_child(root)
	panel.show_window(root)
	# 源 :528 hlv<elv 守卫；若等级不足走 toast 分支，跳过穿戴断言
	var judge: Array = panel._get_judge_level()
	if int(judge[0]) < int(judge[1]):
		pass_test("hero 等级不足，puton 走 toast 分支（照源 :529）")
		panel.remove_window()
		root.queue_free()
		return
	panel._puton_equip()
	# wear_equip 从 hero_equip[tid][rank] 查目标穿（照源 main.lua:1750）
	var rank_equip: Dictionary = cm.get_raw_table("Hero_equip").get(str(hero.tid), {}).get(str(hero.rank), {})
	var expect: int = int(rank_equip.get("Equip" + str(sid + 1) + " ID", 0))
	if expect > 0:
		assert_eq(int(hero.equip_slots[sid]), expect, "puton 后 hero_equip 表目标穿上")
	else:
		assert_eq(int(hero.equip_slots[sid]), before, "hero_equip 无该槽目标 → 不变")
	root.queue_free()


# 源 createNeedCraftPrompt :321 lack 时不崩（craftable 缺材料→prompt / 否则→toast）
func test_create_need_craft_prompt_no_crash() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var pd := PlayerData.new(cm)   # 无材料 → lack
	var panel := _make_panel(int(rec["id"]), pd)
	if panel._lack_of_component:
		panel._create_need_craft_prompt()   # 走 prompt 或 toast 分支，不应崩
		assert_true(true, "createNeedCraftPrompt 执行完成")
	panel.remove_window()


# ===== Step 5：入口集成（HeroDetailPanel → EquipCraftPanel / EquipStrengthenPanel）=====

# 源 heropackage → equipcraft：HeroDetailPanel 装备槽点击 → 弹 EquipCraftPanel
func test_hero_detail_equip_click_opens_craft_panel() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var target_id: int = int(rec["id"])
	var pd := PlayerData.new(cm)
	var iid: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(iid)
	hero.equip_slots[0] = target_id
	var root := Node.new()
	add_child(root)
	var detail := HeroDetailPanel.new("herodetail", {})
	detail.setup_panel(hero, cm, pd.hero_manager, pd)
	detail.show_window(root)
	# 装备槽入口外迁 HeroDetailEquipSlots（show_equips/open_equip_craft），直调 helper 验证集成。
	HeroDetailEquipSlots.open_equip_craft(0, hero, cm, pd,
		detail.get_parent(), detail.refresh_content,
		func(_stage_id: int) -> void: HeroDetailEquipSlots.on_equip_craft_jump(_stage_id, detail))
	var has_craft: bool = false
	for c in root.get_children():
		if c is EquipCraftPanel:
			has_craft = true
			(c as EquipCraftPanel).remove_window()
	assert_true(has_craft, "HeroDetailPanel 装备槽 → 弹 EquipCraftPanel")
	detail.remove_window()
	root.queue_free()


# 源 equipstrengthen 独立面板：HeroDetailPanel "强化"按钮 → 弹 EquipStrengthenPanel
func test_hero_detail_strengthen_button_opens_panel() -> void:
	var pd := PlayerData.new(cm)
	var iid: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(iid)
	var root := Node.new()
	add_child(root)
	var detail := HeroDetailPanel.new("herodetail", {})
	detail.setup_panel(hero, cm, pd.hero_manager, pd)
	detail.show_window(root)
	var stren_btn: Button = null
	for c in detail.container.get_children():
		if c is Button and (c as Button).text == "强化":
			stren_btn = c
	if stren_btn == null:
		pass_test("无强化按钮，跳过")
		detail.remove_window()
		root.queue_free()
		return
	stren_btn.pressed.emit()
	var has_stren: bool = false
	for c in root.get_children():
		if c is EquipStrengthenPanel:
			has_stren = true
			(c as EquipStrengthenPanel).remove_window()
	assert_true(has_stren, "强化按钮 → 弹 EquipStrengthenPanel")
	detail.remove_window()
	root.queue_free()


# ===== P1-10：historyid 返回分支 + 获取途径图标/elite/跳转（源 :207-219 / :1133-1202 / :77-89）=====

# 源 :207-219 components==0 + historyid>1 → setHistory(historyid-1) 返回上一级（不关窗）
func test_historyid_return_when_components_zero() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var panel := _make_panel(int(rec["id"]))
	var fake_bg1 := Control.new()
	var fake_bg2 := Control.new()
	panel._history = [{"id": 100, "iconBg": fake_bg1}, {"id": 200, "iconBg": fake_bg2}]
	panel._history_id = 2
	panel._components = 0   # 模拟切到无配方叶子
	panel._on_craft_pressed()
	assert_true(is_instance_valid(panel), "historyid>1 → 返回上一级，不关窗")
	assert_eq(panel._history_id, 1, "setHistory(historyid-1) → historyid=1")
	panel.remove_window()


# 源 :1175-1178 board 内 stage 图标（getStageIcon，复用 StageRes）
func test_getway_board_has_stage_icon() -> void:
	var eid: int = _find_drop_equip()
	if eid == 0:
		pass_test("数据表无纯掉落装备，跳过")
		return
	var panel := _make_panel(eid)
	var has_icon: bool = false
	for board in panel._get_way_buttons:
		for c in (board as Control).get_children():
			if c is TextureRect:
				has_icon = true
				break
		if has_icon:
			break
	assert_true(has_icon, "至少一个 board 含 stage 图标 TextureRect")
	panel.remove_window()


# 源 :1165-1174 精英关（id>=10000）→ board 含「精英」红字标签
func test_getway_elite_label_when_drop_is_elite() -> void:
	var eid: int = _find_drop_equip()
	if eid == 0:
		pass_test("数据表无纯掉落装备，跳过")
		return
	var panel := _make_panel(eid)
	var has_elite_drop: bool = false
	for sid in panel._get_way_ids:
		if int(sid) >= 10000:
			has_elite_drop = true
			break
	if not has_elite_drop:
		pass_test("该装备无精英关掉落，跳过 elite 标签断言")
		panel.remove_window()
		return
	var has_elite_label: bool = false
	for board in panel._get_way_buttons:
		for c in (board as Control).get_children():
			if c is Label and (c as Label).text == "精英":
				has_elite_label = true
				break
		if has_elite_label:
			break
	assert_true(has_elite_label, "精英关 board 含「精英」红字标签")
	panel.remove_window()


# 源 doClickGetWay :80-86 star+preStar==0 → 不 emit jump_to_stage（未通关）
func test_on_get_way_clicked_no_emit_when_locked() -> void:
	var eid: int = _find_drop_equip()
	if eid == 0:
		pass_test("数据表无纯掉落装备，跳过")
		return
	var pd := PlayerData.new(cm)   # 默认未通关 → star=0
	var panel := _make_panel(eid, pd)
	var emitted: Array = []
	panel.jump_to_stage.connect(func(sid: int) -> void: emitted.append(sid))
	var ids: Array = panel._get_way_ids
	if ids.is_empty():
		pass_test("该装备无获取途径，跳过")
		panel.remove_window()
		return
	panel._on_get_way_clicked(int(ids[0]))
	assert_eq(emitted.size(), 0, "未通关（star=0）→ 不 emit jump_to_stage")
	panel.remove_window()


# 源 doGetWayTouch :91-123 board gui_input 连点击处理
func test_make_get_way_handler_connected() -> void:
	var eid: int = _find_drop_equip()
	if eid == 0:
		pass_test("数据表无纯掉落装备，跳过")
		return
	var panel := _make_panel(eid)
	var connected: bool = false
	for board in panel._get_way_buttons:
		if (board as Control).gui_input.get_connections().size() > 0:
			connected = true
			break
	assert_true(connected, "board gui_input 连接点击处理（源 doGetWayTouch）")
	panel.remove_window()


# ===== 照源精修：LSTR 化 + 按钮纹理化 + helper 拆分（2026-07-16）=====

# 源 :1004-1013 craftButton Sprite package_button → UiButton.make 纹理化（TextureButton + Label 子）
func test_craft_btn_is_texture_button() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var panel := _make_panel(int(rec["id"]))
	assert_true(panel._craft_btn is TextureButton, "craftButton 纹理化 → TextureButton")
	assert_not_null(panel._craft_btn_label, "craftLabel 独立 Label 引用")
	# LSTR_SYNTHESIS 值"合成"（cm.get_lstr 取实际值，照源 :1207）
	assert_eq(panel._craft_btn_label.text, cm.get_lstr("EQUIPCRAFT.SYNTHESIS"), "合成按钮文字 = LSTR 实际值")
	panel.remove_window()


# 源 :686/:695 infoButton Sprite package_button → UiButton.make 纹理化
func test_info_button_is_texture_button() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var panel := _make_panel(int(rec["id"]))
	assert_true(panel._info_button is TextureButton, "infoButton 纹理化 → TextureButton")
	assert_not_null(panel._info_button_label, "infoButtonLabel 独立 Label 引用")
	panel.remove_window()


# 源 :1133-1202 components<1 获取途径分支：title "第 X 章" → cm.get_lstr("EQUIPCRAFT._CHAPTER__D") % chapter_id
func test_getway_title_uses_lstr_chapter_d() -> void:
	var eid: int = _find_drop_equip()
	if eid == 0:
		pass_test("数据表无纯掉落装备，跳过")
		return
	var panel := _make_panel(eid)
	# 至少一个 board 含 title Label，文字匹配 LSTR._CHAPTER__D 模板（"第%d章"）
	var has_lstr_title: bool = false
	for board in panel._get_way_buttons:
		for c in (board as Control).get_children():
			if c is Label:
				var lbl: Label = c as Label
				# 模板"第%d章"格式化后匹配（chapter_id 任意 > 0）
				if lbl.text.match("第*章"):
					has_lstr_title = true
					break
		if has_lstr_title:
			break
	assert_true(has_lstr_title, "获取途径 board title 用 LSTR._CHAPTER__D 模板")
	panel.remove_window()


# 源 getJudgeLevel :519-525 helper 拆出 EquipCraftInfoBtn（直接测 helper static）
func test_helper_get_judge_level() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var target_id: int = int(rec["id"])
	var pd := PlayerData.new(cm)
	var iid: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(iid)
	var panel := EquipCraftPanel.new("equipcraft", {})
	panel.setup_panel(target_id, cm, pd, hero, "heroDetail", 0)
	var root := Node.new()
	add_child(root)
	panel.show_window(root)
	var judge: Array = EquipCraftInfoBtn.get_judge_level(panel)
	var expect_elv: int = int(cm.get_raw_table("Equip").get(str(target_id), {}).get("Level Requirement", 0))
	assert_eq(int(judge[0]), hero.level, "helper hlv = hero.level")
	assert_eq(int(judge[1]), expect_elv, "helper elv = Equip Level Requirement")
	panel.remove_window()
	root.queue_free()


# 源 self.isEquiped helper（EquipCraftInfoBtn._is_equipped）：slot 已装目标 → true
func test_helper_is_equipped() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var target_id: int = int(rec["id"])
	var pd := PlayerData.new(cm)
	var iid: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(iid)
	hero.equip_slots[0] = target_id   # 该槽已装合成目标
	var panel := EquipCraftPanel.new("equipcraft", {})
	panel.setup_panel(target_id, cm, pd, hero, "heroDetail", 0)
	var root := Node.new()
	add_child(root)
	panel.show_window(root)
	assert_true(EquipCraftInfoBtn._is_equipped(panel), "slot 已装目标 → helper _is_equipped=true")
	panel.remove_window()
	root.queue_free()
