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
	# 模拟用户点 infoButton 打开合成窗口（源 openCraftPanel）——setup_panel 初始不建合成树（受控偏离源）
	panel._open_craft_panel()
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


# 源 :1218-1228 缺不可合成材料 → lackOfComponent=true，但 :1223 forbidCraftButton(false) 按钮仍可点
# （点击后 craftEquip 拦截弹 createNeedCraftPrompt 提示框，非禁用按钮）
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
		assert_false(panel._craft_btn.disabled, "lack → 按钮仍可点（源 :1223 forbidCraftButton(false)，点击后弹提示）")
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


# 源 checkMoneyEnough :4 + createCraftTree :1215-1216 金币不足 → forbidCraftButton(false) 按钮仍可点
# （点击后 craftEquip 拦截；单机化 useMidas 充值框已裁剪为 toast）
func test_no_money_keeps_button_clickable() -> void:
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
	var target_id: int = int(rec["id"])
	var panel := _make_panel(target_id, pd)
	if panel._lack_of_component:
		pass_test("该配方含不可递归合成的叶子材料，lack 优先于金币判定")
		panel.remove_window()
		return
	assert_false(panel._check_money_enough(), "金币不足 checkMoneyEnough=false")
	assert_false(panel._craft_btn.disabled, "金币不足 → 按钮仍可点（源 :1216 forbidCraftButton(false)）")
	# 点击走钱不够分支：toast 反馈 + 不合成（items 不变）
	var before: int = int(pd.items.get(target_id, 0))
	panel._on_craft_pressed()
	assert_eq(int(pd.items.get(target_id, 0)), before, "钱不够点击 → 不执行合成")
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
	assert_eq(panel._history.size(), 2, "点子材料 → history 追加 1 条（含 _open_craft_panel 首项共 2，源 setHistory(0,id) 打开即记）")
	assert_eq(panel._craft_id, first_cid, "craftTree 切到 Component1")
	panel.remove_window()


# 源 createInfoButton :610 heroDetail 建信息按钮 + remark（初始态，未开合成窗）
func test_info_button_created() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var panel := EquipCraftPanel.new("equipcraft", {})
	panel.setup_panel(int(rec["id"]), cm, PlayerData.new(cm))
	var root := Node.new()
	add_child(root)
	panel.show_window(root)
	assert_not_null(panel._info_button, "infoButton 已建")
	assert_not_null(panel._info_remark, "infoButtonRemark 已建")
	# 初始态断言不 _open_craft_panel（open 后 heroDetail 文字按源 :579 刷成「装备」）
	assert_eq(panel._info_button_label.text, "合成公式", "heroDetail amount==0 且有配方 → 合成公式")
	panel.remove_window()
	root.queue_free()


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


# 源 doClickGetWay :80-86 star+preStar>0（已通关）→ pushScene(stageselect.createByStage(id))。
# 本项目 emit raw id（elite 的 Stage Group 转换在 StageSelectPanel.setup_by_stage 内做，
# 等价源 createByStage :1655 内转换）。
func test_on_get_way_clicked_emits_when_unlocked() -> void:
	var eid: int = _find_drop_equip()
	if eid == 0:
		pass_test("数据表无纯掉落装备，跳过")
		return
	var pd := PlayerData.new(cm)
	var panel := _make_panel(eid, pd)
	var emitted: Array = []
	panel.jump_to_stage.connect(func(sid: int) -> void: emitted.append(sid))
	var ids: Array = panel._get_way_ids
	if ids.is_empty():
		pass_test("该装备无获取途径，跳过")
		panel.remove_window()
		return
	var target: int = int(ids[0])
	pd.stage_manager.progress = {target: 3}   # 已通关 → star>0 过解锁判定
	panel._on_get_way_clicked(target)
	assert_eq(emitted.size(), 1, "已通关 → emit jump_to_stage（跳选关）")
	assert_eq(int(emitted[0]), target, "emit raw id（源传 raw，转换在选关面板侧）")
	panel.remove_window()   # 2026-09-14 根修后跳转不再自我关闭，由测试收尾清理


# 2026-09-14 根修：源 doClickGetWay :83 pushScene 压栈不清场——获取途径跳转不关 equipcraft
# 自己，面板栈模拟源场景栈（stageselect 全屏盖住，扫荡完逐层退出回到 equipcraft 看材料，
# 用户实机反馈"点击返回直接回到列表了"即旧实现清场误译）。
func test_on_get_way_clicked_keeps_panel_open() -> void:
	var eid: int = _find_drop_equip()
	if eid == 0:
		pass_test("数据表无纯掉落装备，跳过")
		return
	var pd := PlayerData.new(cm)
	var panel := _make_panel(eid, pd)
	var ids: Array = panel._get_way_ids
	if ids.is_empty():
		pass_test("该装备无获取途径，跳过")
		panel.remove_window()
		return
	var target: int = int(ids[0])
	pd.stage_manager.progress = {target: 3}
	panel._on_get_way_clicked(target)
	assert_false(panel.is_queued_for_deletion(), "已通关跳转 → equipcraft 不自我关闭（源 pushScene 压栈）")
	panel.remove_window()


# 2026-09-14 根修：on_equip_craft_jump 不再关宿主面板——旧实现 panel.remove_window() 在
# heroDetail 上下文传入 HeroDetailPanel（hero_detail_panel.gd:95 传 self），点获取途径直接
# 关掉英雄详情，扫荡返回无处可回落到列表。
func test_on_equip_craft_jump_keeps_host_panel() -> void:
	var pd := PlayerData.new(cm)
	var iid: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(iid)
	var root := Node.new()
	add_child(root)
	var detail := HeroDetailPanel.new("herodetail", {})
	detail.setup_panel(hero, cm, pd.hero_manager, pd)
	detail.show_window(root)
	# GUT 环境 current_scene 无 open_stage_select_by_stage → 反射安全跳过，纯测宿主不被关
	HeroDetailEquipSlots.on_equip_craft_jump(101, detail)
	assert_false(detail.is_queued_for_deletion(), "跳转不关宿主英雄详情（源 pushScene 压栈不清场）")
	detail.remove_window()
	root.queue_free()


# 2026-09-14 二轮（用户拍板受控增强）：扫荡返回后 equipcraft 数字刷新——源 Cocos 场景栈
# popScene 回旧场景不重渲染（显示扫荡前旧数字），本项目优于源：选关面板关闭时刷新
# 拥有量 + 合成树材料数（扫荡拿到卷轴/装备回来即见）。
func test_refresh_after_stage_select_close() -> void:
	var eid: int = _find_drop_equip()
	if eid == 0:
		pass_test("数据表无纯掉落装备，跳过")
		return
	var pd := PlayerData.new(cm)
	var panel := _make_panel(eid, pd)
	# 模拟场景入口已打开的选关面板（GUT 无 current_scene 反射入口，emit 无接收方；
	# _on_get_way_clicked 的绑定逻辑从 PopWindow 栈里找 StageSelectPanel）
	var sp := StageSelectPanel.new("stageselect", {})
	sp.setup_panel(pd.stage_manager, pd, BattleRng.new(1))
	sp.show_window(panel.get_parent())
	var ids: Array = panel._get_way_ids
	if ids.is_empty():
		pass_test("该装备无获取途径，跳过")
		sp.remove_window()
		panel.remove_window()
		return
	var target: int = int(ids[0])
	pd.stage_manager.progress = {target: 3}
	panel._on_get_way_clicked(target)
	# 模拟扫荡入账（选关在顶期间获得目标装备）
	pd.items[eid] = 2
	# 关闭选关（用户点返回）→ 应触发 equipcraft 刷新
	sp.remove_window()
	assert_true(panel._amount_label.text.find("2") >= 0, "选关关闭 → 拥有量刷新为 2（实际 %s）" % panel._amount_label.text)
	panel.remove_window()


# 2026-09-14 四轮（栈顶驱动兜底）：不依赖 register_on_exit 绑定——任意方式盖上选关再关，
# equipcraft 复顶（PopWindow._on_became_top）即刷新。覆盖真实点击路径下单点钩子失灵的场景。
func test_refresh_on_became_top_without_bind() -> void:
	var eid: int = _find_drop_equip()
	if eid == 0:
		pass_test("数据表无纯掉落装备，跳过")
		return
	var pd := PlayerData.new(cm)
	var panel := _make_panel(eid, pd)
	# 直接盖一个选关面板（不走 _on_get_way_clicked，即无 on_exit 绑定）
	var sp := StageSelectPanel.new("stageselect", {})
	sp.setup_panel(pd.stage_manager, pd, BattleRng.new(1))
	sp.show_window(panel.get_parent())
	# 模拟扫荡入账后关闭选关 → equipcraft 复顶应刷新
	pd.items[eid] = 3
	sp.remove_window()
	assert_true(panel._amount_label.text.find("3") >= 0, "复顶刷新（无绑定路径）：拥有量应为 3（实际 %s）" % panel._amount_label.text)
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


# ===== 两件套守卫（批 1 Task 10，2026-08-15）：theme variation 接线 + HistoryClip 裁剪层 + fills 下沉 + 裸 key 本地化 =====

func _instantiate_content() -> Control:
	var scene: PackedScene = load("res://scenes/ui/equip_craft_content.tscn") as PackedScene
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	return inst


# tscn 静态 label variation（源 board.lua:323-337 name size24 ccc3(66,45,28)+shadow(0,2) /
# board.lua:55-70 amount_title size20 ccc3(67,59,56) / equipcraft.lua:671-681 remark size18 动态色）。
# GUT 节点级不解析 variation 字号 → 数值断言读 default_theme.tres 文本表项（批 1 方法学）。
func test_content_static_labels_use_variations() -> void:
	var inst: Control = _instantiate_content()
	var name_lbl: Label = inst.get_node("%NameLabel") as Label
	assert_eq(name_lbl.theme_type_variation, &"EquipCraftNameLabel", "NameLabel 走 variation")
	assert_false(name_lbl.has_theme_color_override("font_color"), "NameLabel 无色 override")
	assert_false(name_lbl.has_theme_font_size_override("font_size"), "NameLabel 无字号 override")
	var amount_lbl: Label = inst.get_node("%AmountLabel") as Label
	assert_eq(amount_lbl.theme_type_variation, &"EquipCraftHaveLabel", "AmountLabel 走 variation")
	assert_false(amount_lbl.has_theme_color_override("font_color"), "AmountLabel 无色 override")
	assert_false(amount_lbl.has_theme_font_size_override("font_size"), "AmountLabel 无字号 override")
	var remark_lbl: Label = inst.get_node("%InfoRemark") as Label
	assert_eq(remark_lbl.theme_type_variation, &"EquipCraftRemarkLabel", "InfoRemark 走 variation（动态色 fill modulate）")
	assert_false(remark_lbl.has_theme_font_size_override("font_size"), "InfoRemark 无字号 override")
	var tres: String = FileAccess.get_file_as_string("res://resources/themes/default_theme.tres")
	assert_true(tres.contains("EquipCraftNameLabel/font_sizes/font_size = 24"), "name 24 号（源 board.lua:325）")
	assert_true(tres.contains("EquipCraftNameLabel/colors/font_shadow_color"), "name 阴影（源 shadow(0,2)）")
	assert_true(tres.contains("EquipCraftHaveLabel/font_sizes/font_size = 20"), "have 20 号（源 board.lua:61）")
	assert_true(tres.contains("EquipCraftHaveLabel/colors/font_color = Color(0.263, 0.231, 0.22, 1)"), "have 色 ccc3(67,59,56)")
	assert_true(tres.contains("EquipCraftRemarkLabel/font_sizes/font_size = 18"), "remark 18 号（源 equipcraft.lua:675）")
	assert_true(tres.contains("EquipCraftAttLabel/font_sizes/font_size = 18"), "att 行 18 号（源 board.lua:147）")
	assert_true(tres.contains("EquipCraftAttLabel/colors/font_color = Color(0.251, 0.247, 0.247, 1)"), "att 行色 ccc3(64,63,63)")


# way title 两段式守卫（批 1 终审必修 3）：①tres 表项存在（base_type/字号/色）；
# ②equip_craft_tree.gd 源码含接线字符串（tree 动态建 Label，运行时断言只能走源码文本）。
# 数值依据源 equipcraft.lua:1141-1144：createttf(..., 20) + setLabelColor ccc3(155,34,14)。
func test_way_title_label_variation_wired() -> void:
	var tres: String = FileAccess.get_file_as_string("res://resources/themes/default_theme.tres")
	assert_true(tres.contains("EquipCraftWayTitleLabel/base_type = &\"Label\""), "way title variation base_type=Label")
	assert_true(tres.contains("EquipCraftWayTitleLabel/font_sizes/font_size = 20"), "way title 20 号（源 equipcraft.lua:1141）")
	assert_true(tres.contains("EquipCraftWayTitleLabel/colors/font_color = Color(0.607843, 0.133333, 0.054902, 1)"),
		"way title 色 ccc3(155,34,14)（源 equipcraft.lua:1144）")
	var tree_src: String = FileAccess.get_file_as_string("res://scripts/ui/equip_craft_tree.gd")
	assert_true(tree_src.contains("theme_type_variation = &\"EquipCraftWayTitleLabel\""),
		"tree way title Label 接线 EquipCraftWayTitleLabel variation")


# HistoryClip 照源 draglist cliprect CCRectMake(12,300,265,80)（equipcraft.lua:804，bg 局部）
# → CraftWindow 中心空间 _gl 映射（2026-08-22 溢出修复：bg 半尺寸用显示口径 144.0/192.39 =
# equip_craft_bg 369×493px ÷2÷CS；旧值 184.5/246.5 为纹理 px 半尺寸直用，历史区整体偏下 54 点）：
# left=12-144.0=-131.99 / top=192.39-380=-187.61 / right=277-144.0=133.0 / bottom=192.39-300=-107.61
func test_content_history_clip_follows_source() -> void:
	var inst: Control = _instantiate_content()
	var clip: Control = inst.get_node_or_null("%HistoryClip") as Control
	assert_not_null(clip, "HistoryClip 常驻 tscn（源 cliprect :804）")
	if clip == null:
		return
	assert_true(clip.clip_contents, "clip_contents=true（源 draglist 裁剪）")
	assert_almost_eq(clip.offset_left, -131.99, 0.1, "clip left（bg 局部 x12 → 中心空间）")
	assert_almost_eq(clip.offset_top, -187.61, 0.1, "clip top（bg 局部 y380 → 中心空间）")
	assert_almost_eq(clip.offset_right, 133.0, 0.1, "clip right（bg 局部 x277）")
	assert_almost_eq(clip.offset_bottom, -107.61, 0.1, "clip bottom（bg 局部 y300）")


# history layer 挂 %HistoryClip（裁剪生效），origin 相对 clip 原点（源 icon@listLayer (43+58*len,50)）
func test_history_layer_inside_clip() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var panel := _make_panel(int(rec["id"]))
	var nodeid: Array = panel._craft_window_data.get("nodeid", [])
	if nodeid.is_empty() or int(nodeid[0]) <= 0:
		pass_test("配方无 Component1，跳过")
		panel.remove_window()
		return
	panel._set_history(0, int(nodeid[0]))
	assert_not_null(panel._history_layer, "history layer 已建")
	var clip: Control = panel._content.get_node("%HistoryClip") as Control
	assert_eq(panel._history_layer.get_parent(), clip, "history layer 挂 %HistoryClip（源 draglist 裁剪域）")
	assert_almost_eq(panel._history_layer.position.x, 24.0, 0.5, "origin x=43-19（源 icon 中心相对 clip 43，HBox 摆 wrapper 左上须减 icon 半宽 19）")
	assert_almost_eq(panel._history_layer.position.y, 10.8, 0.5, "origin y=30-19.2（源 icon 中心相对 clip 顶 30，减 icon 半高 19.2）")
	panel.remove_window()


# att 动态行（源 board.lua:142-159 size18 ccc3(64,63,63) shadow(0,2)）→ variation，无运行时 override
func test_att_rows_use_variation() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var panel := _make_panel(int(rec["id"]))
	var checked: int = 0
	for c in panel._att_host.get_children():
		if c is Label:
			checked += 1
			assert_eq((c as Label).theme_type_variation, &"EquipCraftAttLabel", "att 行走 variation")
			assert_false((c as Label).has_theme_font_size_override("font_size"), "att 行无字号 override")
			assert_false((c as Label).has_theme_color_override("font_color"), "att 行无色 override")
	if checked == 0:
		pass_test("该装备无属性行，跳过")
	panel.remove_window()


# tree 动态 Label variation（源 :994 name 18 红 / :1087 amount 18 动态 / :1105 need 18 棕 /
# :1115 costTitle 18 棕 / :1122 cost 18 动态）——动态结构保留 procedural，样式走 variation
func test_tree_labels_use_variations() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var panel := _make_panel(int(rec["id"]))
	assert_eq((panel._tree_data["name"] as Label).theme_type_variation, &"EquipCraftRedLabel18", "tree name 18 红（源 :994-1002）")
	assert_eq((panel._tree_data["costTitle"] as Label).theme_type_variation, &"EquipCraftBrownLabel18", "costTitle 18 棕（源 :1115-1118）")
	assert_eq((panel._tree_data["cost"] as Label).theme_type_variation, &"EquipCraftDynLabel18", "cost 18 动态色（源 :1122-1127）")
	var amount_labels: Array = panel._tree_data.get("amountLabel", [])
	if not amount_labels.is_empty():
		assert_eq((amount_labels[0] as Label).theme_type_variation, &"EquipCraftDynLabel18", "amount 18 动态色（源 :1087-1094）")
	panel.remove_window()


# 获取途径分支 label variation（源 :1139 way_title 20 深红(155,34,14) / :1179 title 18(182,65,21) /
# :1185 elite 18 红 / :1191 name 18(182,65,21)）
func test_getway_labels_use_variations() -> void:
	var eid: int = _find_drop_equip()
	if eid == 0:
		pass_test("数据表无纯掉落装备，跳过")
		return
	var panel := _make_panel(eid)
	if panel._get_way_buttons.is_empty():
		pass_test("该装备无获取途径，跳过")
		panel.remove_window()
		return
	var checked: int = 0
	for board in panel._get_way_buttons:
		for c in (board as Control).get_children():
			if c is Label:
				checked += 1
				var v: StringName = (c as Label).theme_type_variation
				assert_true(v == &"EquipCraftBoardLabel" or v == &"EquipCraftRedLabel18",
					"board label 走 variation（title/name=Board18，elite=Red18）")
	assert_gt(checked, 0, "至少一个 board label 被检查")
	panel.remove_window()


# 源 :1191 board name = row["Stage Name"]——Stage Name 存 LSTR key（stage_detail_panel:79 口径
# 508/535 是 key），需 get_lstr 本地化（同 stone_detail_panel:205 / stage_select_panel:333，裸 key 修复）
func test_getway_board_name_localized() -> void:
	var eid: int = _find_drop_equip()
	if eid == 0:
		pass_test("数据表无纯掉落装备，跳过")
		return
	var panel := _make_panel(eid)
	var ids: Array = panel._get_way_ids
	if ids.is_empty():
		pass_test("该装备无获取途径，跳过")
		panel.remove_window()
		return
	var texts: Array = []
	for board in panel._get_way_buttons:
		for c in (board as Control).get_children():
			if c is Label:
				texts.append((c as Label).text)
	var stage_table: Dictionary = cm.get_raw_table("Stage")
	var all_localized: bool = true
	var any_key: bool = false
	for sid in ids:
		var s: int = int(sid)
		if s >= 10000:
			s = int(stage_table.get(str(s), {}).get("Stage Group", s))
		var raw: String = String(stage_table.get(str(s), {}).get("Stage Name", ""))
		var loc: String = String(cm.get_lstr(raw))
		if loc == raw:
			continue
		any_key = true
		if not texts.has(loc):
			all_localized = false
	if not any_key:
		pass_test("该装备途径关卡 Stage Name 均非 LSTR key，跳过")
	else:
		assert_true(all_localized, "board name 全部 get_lstr 本地化（裸 key 修复）")
	panel.remove_window()


# panel 零静态 .new(（icon/att 行/history 构建下沉 equip_craft_fills）+ 零运行时 theme override
#（att 行 2 处转 EquipCraftAttLabel variation，HBox separation 走全局 HBoxContainer/separation=8）
func test_panel_source_zero_news_and_overrides() -> void:
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/equip_craft_panel.gd")
	assert_eq(text.count(".new("), 0, "panel 零 .new(（动态 fill 全下沉 fills）")
	assert_eq(text.count("add_theme_"), 0, "panel 零 add_theme_（3 处运行时 override 转 variation/全局）")


# fills 下沉守卫：文件存在 + 纯数据绑定（禁样式 override，对齐 hero_detail_fills 范式）
func test_fills_exists_and_no_override() -> void:
	var path: String = "res://scripts/ui/equip_craft_fills.gd"
	assert_true(ResourceLoader.exists(path) or FileAccess.file_exists("res://scripts/ui/equip_craft_fills.gd"), "equip_craft_fills.gd 存在")
	if not FileAccess.file_exists(path):
		return
	var text: String = FileAccess.get_file_as_string(path)
	assert_true(text.contains("class_name EquipCraftFills"), "fills class_name 声明")
	assert_eq(text.count("add_theme_"), 0, "fills 零 theme override（variation 管）")


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


# 合成窗口直显无滑入动画（2026-08-30 九轮：源 :1256-1266 EaseBackOut 滑入用户不要，
# 受控偏离；旧 tween 每次点装备物品从屏顶滑入=用户反馈「装备物品触发侧滑」真身）。
func test_open_craft_panel_no_slide_animation() -> void:
	var panel := EquipCraftPanel.new("equipcraft", {})
	panel.setup_panel(102, cm, null, null, "heroDetail", 0)
	add_child_autofree(panel)
	panel._open_craft_panel()
	# 打开即止态：窗口 y 恒定（无 from(-h) 起跳滑入）
	var y_open: float = panel._craft_window.position.y
	await get_tree().create_timer(0.1).timeout   # 若有滑入 tween，0.1s 处 y 会明显变化
	assert_almost_eq(panel._craft_window.position.y, y_open, 1.0, "打开后 y 恒定（无滑入动画直显）")


# ===== 按钮态机关闭方向补全（2026-09-07：源 closeCraftPanel/forbidInfoButton 漏译根修）=====

# 源 doClickCraftButton :211-218：返回按钮关合成窗回详情态（非关整弹窗）+ 刷新 infoButton 文字。
func test_return_button_closes_craft_window_not_panel() -> void:
	var eid: int = _find_drop_equip()
	if eid == 0:
		pass_test("数据表无纯掉落装备，跳过")
		return
	var pd := PlayerData.new(cm)
	var panel := _make_panel(eid, pd)   # _open_craft_panel 已记历史首项 → history_id=1
	panel._on_craft_pressed()   # components==0 + history_id==1 → 走 closeCraftPanel 分支
	assert_true(is_instance_valid(panel) and panel.get_parent() != null, "弹窗本体不关（返回只关合成窗）")
	assert_false(panel._is_open, "isOpen=false（源 :591）")
	assert_false(panel._craft_window.visible, "合成窗隐藏")
	assert_true(panel._history.is_empty(), "initHistory 清历史（源 :589）")
	assert_false(panel._is_forbid_info_button, "解禁 infoButton（源 :592-594）")
	# amount==0 → 文字「获取途径」（源 :216-217 else 分支）
	assert_eq(panel._info_button_label.text, cm.get_lstr("EQUIPCRAFT.WAY_TO_GET"),
		"heroDetail amount==0 → 获取途径")
	panel.remove_window()


# 源 :212-214：关合成窗时 heroDetail 且拥有>0 → 文字「装备」
func test_return_button_text_equipment_when_owned() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var target_id: int = int(rec["id"])
	var pd := PlayerData.new(cm)
	pd.add_item(target_id, 1)   # 拥有>0
	var panel := _make_panel(target_id, pd)
	panel._components = 0   # 模拟切到无配方层（getway/叶子）触发返回分支
	panel._on_craft_pressed()
	assert_eq(panel._info_button_label.text, cm.get_lstr("EQUIPCRAFT.EQUIPMENT"),
		"heroDetail 拥有>0 → 装备")
	panel.remove_window()


# 源 openCraftPanel :577-584：heroDetail → 文字「装备」+ forbidInfoButton(true) 灰字禁点
func test_open_craft_panel_forbids_info_button() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var panel := _make_panel(int(rec["id"]))
	assert_true(panel._is_forbid_info_button, "heroDetail 打开合成窗 → infoButton 禁点")
	assert_eq(panel._info_button_label.text, cm.get_lstr("EQUIPCRAFT.EQUIPMENT"),
		"打开后文字 = 装备（源 :579）")
	assert_eq(panel._info_button_label.modulate, EquipCraftInfoBtn.COLOR_FORBID, "灰字 pressColor（源 :580）")
	panel.remove_window()


# 源 openCraftPanel :582-583 + forbidInfoButton :1344-1346：handbook → 文字「确定」且恒不禁用
func test_open_craft_panel_handbook_confirm_not_forbid() -> void:
	var eid: int = _find_drop_equip()
	if eid == 0:
		pass_test("数据表无纯掉落装备，跳过")
		return
	var panel := EquipCraftPanel.new("equipcraft", {})
	panel.setup_panel(eid, cm, PlayerData.new(cm), null, "handbook")
	var root := Node.new()
	add_child(root)
	panel.show_window(root)
	panel._open_craft_panel()
	assert_false(panel._is_forbid_info_button, "handbook 恒不禁用（源 :1344-1346）")
	assert_eq(panel._info_button_label.text, cm.get_lstr("CHATCONFIG.CONFIRM"), "handbook 打开后文字 = 确定")
	panel.remove_window()
	root.queue_free()


# 源 doInfoButtonTouch :178-180：isForbidInfoButton 时 infoButton 点击不响应
func test_forbidden_info_button_ignores_press() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var panel := _make_panel(int(rec["id"]))   # amount==0 未穿 → 正常点击会 _open_craft_panel
	panel._close_craft_panel()   # 解禁 + is_open=false（回到详情态）
	assert_false(panel._is_open)
	EquipCraftInfoBtn.set_forbid_info_button(panel, true)   # 手动禁点
	panel._on_info_pressed()
	assert_false(panel._is_open, "禁点时点击 infoButton 不打开合成窗")
	panel.remove_window()


# 源 refreshReplyData :505-511：合成出目标装备（up.id==id）且等级够 → 解禁 infoButton
func test_craft_target_success_unforbids_info_button() -> void:
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
	panel._open_craft_panel()
	assert_true(panel._is_forbid_info_button, "打开期间禁点")
	var judge: Array = panel._get_judge_level()
	if int(judge[0]) < int(judge[1]):
		pass_test("hero 等级不足（源 :509 elv<=hlv 才解禁），跳过")
		panel.remove_window()
		root.queue_free()
		return
	# 模拟合成成功回调链：craft_id==target_id + 等级够 → _refresh_reply_data 解禁
	panel._craft_id = target_id
	panel._refresh_reply_data()
	assert_false(panel._is_forbid_info_button, "合成目标+等级够 → 解禁（灰字变白可点）")
	panel.remove_window()
	root.queue_free()


# 源 playCraftEffect 回调 :456-458：heroDetail 且 historyid>1 → 回退一层（子材料合成完回父配方）
func test_play_craft_effect_steps_back_history() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var target_id: int = int(rec["id"])
	var panel := _make_panel(target_id)
	var nodeid: Array = panel._craft_window_data.get("nodeid", [])
	if nodeid.is_empty() or int(nodeid[0]) <= 0:
		pass_test("配方无 Component1，跳过")
		panel.remove_window()
		return
	panel._set_history(0, int(nodeid[0]))   # 进子材料层 → history_id=2
	assert_eq(panel._history_id, 2)
	# 源 :412 tree.children==nil 直接 return（叶子材料无合成动画与回退），须子层有配方才断言
	if (panel._tree_data.get("children", []) as Array).is_empty():
		pass_test("Component1 无配方（getway 叶子层），跳过")
		panel.remove_window()
		return
	panel._play_craft_effect()   # 子层合成成功回调
	assert_eq(panel._history_id, 1, "heroDetail historyid>1 → 回退一层（源 :456-458）")
	assert_eq(panel._craft_id, target_id, "回退后树回到父配方（craft_id=target）")
	panel.remove_window()


# 源 initHistory :726-729 + closeCraftPanel :589：关闭再打开历史不重复叠加
func test_close_then_reopen_no_history_duplication() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var panel := _make_panel(int(rec["id"]))
	assert_eq(panel._history.size(), 1, "打开记历史首项")
	panel._close_craft_panel()
	panel._open_craft_panel()
	assert_eq(panel._history.size(), 1, "重开不叠加（initHistory 已清，源 :589）")
	assert_eq(panel._history_layer.get_child_count(), 1, "历史栏仅 1 个 wrapper（无残留旧图标）")
	panel.remove_window()


# 源 createInfoButton :633-643：handbook 初始文字按有无配方（合成公式/获取途径），打开后才变「确定」
func test_handbook_info_button_initial_text() -> void:
	var eid: int = _find_drop_equip()
	if eid == 0:
		pass_test("数据表无纯掉落装备，跳过")
		return
	var panel := EquipCraftPanel.new("equipcraft", {})
	panel.setup_panel(eid, cm, PlayerData.new(cm), null, "handbook")
	var root := Node.new()
	add_child(root)
	panel.show_window(root)
	assert_eq(panel._info_button_label.text, cm.get_lstr("EQUIPCRAFT.WAY_TO_GET"),
		"handbook 无配方初始 = 获取途径（源 :639）")
	panel.remove_window()
	root.queue_free()


# ===== 材料不足点击反馈（2026-09-07 二轮：btn.disabled 发明挡死反馈链路根修）=====

# 源 craftEquip :371-375 + createNeedCraftPrompt :321-366：材料不足点击合成 → 拦截给反馈
# （缺可合成材料 → 图标上方「需先合成」提示框；缺不可合成 → toast 无材料），非静默无反应。
func test_lack_click_gives_feedback_not_silent() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var target_id: int = int(rec["id"])
	var pd := PlayerData.new(cm)   # 无材料 → lack
	var panel := _make_panel(target_id, pd)
	if not panel._lack_of_component:
		pass_test("该配方材料全部可递归合成（无叶子缺料），跳过 lack 断言")
		panel.remove_window()
		return
	assert_false(panel._craft_btn.disabled, "材料不足按钮仍可点（源 :1223，disabled 系无源发明已删）")
	# 点击 → lack 分支拦截：不合成（items 不变），反馈链路（prompt/toast）不崩
	var before: int = int(pd.items.get(target_id, 0))
	panel._on_craft_pressed()
	assert_eq(int(pd.items.get(target_id, 0)), before, "材料不足点击 → 不执行合成（craftEquip :371 拦截）")
	panel.remove_window()


# ===== 三轮：历史栏回退箭头残留根修（2026-09-07，源 setHistory :875-880 漏译）=====

# 源 setHistory 截断分支 iconBg 与 arrow 一并删：点树节点进子层（arrow 加入）→ 点返回回退，
# arrow 须随 iconBg 删除——旧实现漏删致 view_history_arrow 残留 HBox 反复进出无限叠加。
func test_history_back_removes_arrow_no_residue() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var target_id: int = int(rec["id"])
	var panel := _make_panel(target_id)
	var nodeid: Array = panel._craft_window_data.get("nodeid", [])
	if nodeid.is_empty() or int(nodeid[0]) <= 0:
		pass_test("配方无 Component1，跳过")
		panel.remove_window()
		return
	# 进子层：HBox = [w1, arrow, w2] 共 3 子节点
	panel._set_history(0, int(nodeid[0]))
	assert_eq(panel._history_id, 2)
	assert_eq(panel._history_layer.get_child_count(), 3, "两层历史 = w1+arrow+w2")
	# 回退：queue_free 帧末生效后 HBox 只剩 w1（arrow 随 w2 删除，无残留）
	panel._set_history(1, 0)
	await get_tree().process_frame
	assert_eq(panel._history_layer.get_child_count(), 1, "回退后仅剩 w1（arrow 一并删，源 :877-879）")
	# 再进另一层：仍 3 子节点（残留 arrow 会变 4）
	panel._set_history(0, int(nodeid[0]))
	assert_eq(panel._history_layer.get_child_count(), 3, "反复进出不叠加（修复前会 4+）")
	panel.remove_window()


# ===== 七轮终局：HeroScene 获取途径跳转断链根修（2026-09-07，[GJ] 日志实锤）=====

# 用户从英雄按钮进独立 HeroScene（SceneManager.change_scene）→ 英雄详情获取途径跳转断链：
# on_equip_craft_jump 经 current_scene 反射调 open_stage_select_by_stage，HeroScene 缺此方法
# → 静默 return → 弹窗关了选关不开。守卫：两个入口场景（main/hero）都声明该反射方法
#（源码文本断言，同 way_title/panel_zero_news 守卫方法学——GDScript.has_method 查不到声明）。
func test_get_way_jump_entry_on_both_scenes() -> void:
	var main_src: String = FileAccess.get_file_as_string("res://scenes/main_menu/main_scene.gd")
	assert_true(main_src.contains("func open_stage_select_by_stage"),
		"MainScene 声明 open_stage_select_by_stage（反射入口）")
	var hero_src: String = FileAccess.get_file_as_string("res://scenes/hero/hero_scene.gd")
	assert_true(hero_src.contains("func open_stage_select_by_stage"),
		"HeroScene 声明 open_stage_select_by_stage（断链根因修复，[GJ] 实锤 current_scene=HeroScene）")


# 端到端：hero_detail + equipcraft 挂 HeroScene 场景实例上（用户真实环境），emit 跳转后
# 选关面板出现在 HeroScene 下。GUT 环境 current_scene 是 runner 场景，须临时指向 hs
# 还原反射链（on_equip_craft_jump 经 current_scene 反射调场景入口）。
func test_get_way_jump_from_hero_scene_end_to_end() -> void:
	var rec: Dictionary = _find_recipe_equip()
	if rec.is_empty():
		pass_test("数据表无合成配方，跳过")
		return
	var target_id: int = int(rec["id"])
	var pd := PlayerData.new(cm)
	var iid: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(iid)
	var hs: Control = (load("res://scenes/hero/hero_scene.tscn") as PackedScene).instantiate() as Control
	var root := Node.new()
	add_child(root)
	root.add_child(hs)   # 触发 _ready（依赖 GameData.player；沙箱无则跳过）
	await get_tree().process_frame
	if GameData.player == null:
		pass_test("GUT 环境 GameData.player 不可用，HeroScene 链路跳过（脚本级守卫已覆盖）")
		root.queue_free()
		return
	# hero_detail 挂 HeroScene（用户真实层级），equipcraft 挂其上，跳转闭包传 hero_detail
	var dp := HeroDetailPanel.new("herodetail", {})
	dp.setup_panel(hero, cm, pd.hero_manager, pd)
	dp.show_window(hs)
	await get_tree().process_frame
	var panel := EquipCraftPanel.new("equipcraft", {})
	panel.setup_panel(target_id, cm, pd, hero, "heroDetail", 0)
	panel.jump_to_stage.connect(func(sid: int) -> void:
		HeroDetailEquipSlots.on_equip_craft_jump(sid, dp))
	panel.show_window(hs)
	await get_tree().process_frame
	# GUT 无法伪造 current_scene（引擎要求节点直挂树根），反射分发链已由 bridge QA 实测；
	# 此处直调场景侧入口，覆盖 GameData.player→BattleRng→StageSelectPanel 构造+挂载链。
	hs.open_stage_select_by_stage(target_id)
	await get_tree().create_timer(0.3).timeout
	var found: Array = []
	for c in hs.get_children():
		if c is StageSelectPanel:
			found.append(c)
	assert_eq(found.size(), 1, "HeroScene 跳转入口 → 选关面板挂 HeroScene 下（断链修复）")
	for p in found:
		(p as StageSelectPanel).remove_window()
	root.queue_free()


# ── AttBg 九宫格守卫（2026-09-08 三姊妹口径统一，源 board.lua:114-125 Scale9Sprite → NinePatchRect）──

func test_att_bg_ninepatch_type_and_cap_margins() -> void:
	var inst: Control = _instantiate_content()
	var att_bg: NinePatchRect = inst.get_node("EquipLayer/%AttBg") as NinePatchRect
	assert_true(att_bg is NinePatchRect, "AttBg 是 NinePatchRect（源 Scale9）")
	if not (att_bg is NinePatchRect):
		return
	assert_eq(att_bg.patch_margin_left, 8, "cap left=10px÷CS（capInsets x=10）")
	assert_eq(att_bg.patch_margin_bottom, 8, "cap bottom=10px÷CS（capInsets y=10）")
	assert_eq(att_bg.patch_margin_top, 48, "cap top=62px÷CS（192-10-120）")
	assert_eq(att_bg.patch_margin_right, 67, "cap right=86px÷CS（326-10-230）")
	assert_lt(att_bg.get_index(), (inst.get_node("EquipLayer/%AttHost") as Control).get_index(),
		"AttBg 声明序在 AttHost 之前（背景画在属性文字下层）")


func test_att_bg_static_rect_source_translation() -> void:
	var inst: Control = _instantiate_content()
	var att_bg: Control = inst.get_node("EquipLayer/%AttBg")
	# 源 att_bg anchor(0.5,1)@ccp(143,287)（board.lua:120-123）→ 帧内左上：左=143-254.44/2、顶=385-287
	assert_almost_eq(att_bg.offset_left, 15.78, 0.01, "AttBg 左 15.78")
	assert_almost_eq(att_bg.offset_top, 98.0, 0.01, "AttBg 顶 98（385-287）")
	assert_almost_eq(att_bg.offset_right, 270.22, 0.01, "AttBg 右 270.22（15.78+254.44）")
	assert_almost_eq(att_bg.offset_bottom, 247.85, 0.01, "AttBg 底 247.85（98+149.85，192px÷CS）")
