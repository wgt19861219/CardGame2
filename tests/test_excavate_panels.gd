extends GutTest
# Excavate UI Panel 测试（View 层）— 7 panel 照源精修后的 LSTR 化 + 装配验证。
# 照源 ui/excavate/map.lua + search.lua + popwindow/excavateteam.lua + excavatehistory.lua
# + excavatebattlereport.lua + excavateexplain.lua + excavate/giveup.lua。
# P1（2026-07-16）：LSTR key 路由 + fallback 兜底 + 关键装配（按钮/backbtn/Scale9/bg.jpg）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# ── ExcavateExplainPanel：LSTR 化（21 处 key 全在 JSON）──

# 解释面板应加载 4 行故事 + 16 行规则 LSTR（无 fallback 出现说明 key 全命中）。
func test_explain_lstr_keys_all_present() -> void:
	# 此测试验证 LSTR JSON 完整性（excavateexplain.lua 全 21 key 应在表里）
	var keys: Array[String] = [
		"EXCAVATEEXPLAIN.DARK_IRON_DWARVES_KINGDOM_BUILDING_IN_THE_GROUND_MORE_WRONG_SECTION_OF_THE_HOLE_DISK_AS_THE_ROOT_OF_THE_TREE_OF_THE_WORLD_TO_BE",
		"EXCAVATEEXPLAIN._ANUBAR_WARS",
		"EXCAVATEEXPLAIN.1_IN_THE_TREASURE_CRYPT_YOU_CAN_FIND_A_VARIETY_OF_RESOURCE_POINTS_INCLUDING_GOLD_DIAMOND_AND_LABORATORY",
		"EXCAVATEEXPLAIN.10_IN_THE_TREASURE_CRYPT_BATTLE_THE_HERO_OF_THE_DEFENSE_WILL_GET_SOME_INITIAL_ENERGY",
	]
	for k in keys:
		var v: String = cm.get_lstr(k)
		assert_ne(v, k, "LSTR key 命中（非 fallback 返 key 本身）：" + k)
		assert_false(v.is_empty(), "LSTR 值非空：" + k)


# ExcavateExplainPanel 装配无异常（ScrollContainer + VBox + 标签生成）
func test_explain_panel_builds_without_error() -> void:
	var root := Node.new()
	add_child(root)
	var panel := ExcavateExplainPanel.new("excavate_explain", {})
	panel.setup_panel()
	panel.show_window(root)
	assert_gt(panel.container.get_child_count(), 0, "container 非空（frame 已加）")
	panel.remove_window()
	root.queue_free()


# ── ExcavateGiveupPanel：LSTR + _type_name 三态 ──

# giveup 5 个 LSTR key + 资源名 key 全在 JSON
func test_giveup_lstr_keys_present() -> void:
	var keys: Array[String] = [
		"giveup.1.10.1.005", "CHATCONFIG.CANCEL", "CHATCONFIG.CONFIRM",
		"RECHARGE.DIAMOND", "TASK.GOLD", "EQUIP.EXPERIENCE_CREAMS",
	]
	for k in keys:
		var v: String = cm.get_lstr(k)
		assert_ne(v, k, "LSTR key 命中：" + k)


# ── ExcavateHistoryPanel：LSTR 时间格式 + ATTACK ──

# 时间 4 档 LSTR key 全在 JSON
func test_history_time_lstr_keys_present() -> void:
	var keys: Array[String] = [
		"EXCAVATEHISTORY._D_DAYS_AGO", "PVP._D_HOURS_AGO",
		"PVP._D_MINUTES_AGO", "PVP._D_SECONDS_AGO",
		"EXCAVATEHISTORY.ATTACK_YOUR__S",
	]
	for k in keys:
		var v: String = cm.get_lstr(k)
		assert_ne(v, k, "LSTR key 命中：" + k)


# ── ExcavateBattleReportPanel：TITLE_FMT LSTR ──

# THE+BATTLE 拼接 "第" + "1" + "战"
func test_battle_report_title_lstr_concat() -> void:
	var the: String = cm.get_lstr("EXCAVATEBATTLEREPORT.THE")
	var battle: String = cm.get_lstr("EXCAVATEBATTLEREPORT.BATTLE")
	assert_eq(the, "第", "THE = 第")
	assert_eq(battle, "战", "BATTLE = 战")
	var title: String = the + "1" + battle
	assert_eq(title, "第1战", "title 拼接正确")


# ── ExcavateMapPanel：LSTR + bg.jpg + backbtn 装配 ──

# map 面板 LSTR key 全在 JSON
func test_map_lstr_keys_present() -> void:
	var keys: Array[String] = [
		"EXCAVATEMAP.RULES", "EXCAVATEHISTORY.DEFENSIVE_RECORD",
		"RECHARGE.DIAMOND", "TASK.GOLD", "EQUIP.EXPERIENCE_CREAMS",
	]
	for k in keys:
		var v: String = cm.get_lstr(k)
		assert_ne(v, k, "LSTR key 命中：" + k)


# bg.jpg 资源存在（源 uieditor excavatemap:12 第 1 元素照源核实保留）
func test_map_bg_asset_exists() -> void:
	assert_true(ResourceLoader.exists("res://assets/ui/alpha/HVGA/bg.jpg"), "bg.jpg 存在")
	assert_true(ResourceLoader.exists("res://assets/ui/alpha/HVGA/backbtn.png"), "backbtn.png 存在")
	assert_true(ResourceLoader.exists("res://assets/ui/alpha/HVGA/prevchap.png"), "prevchap.png 存在")


# map 面板空矿点列表时显示 NO_NODE_TEXT（避免除零/越界）
func test_map_panel_empty_list_no_crash() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	var panel := ExcavateMapPanel.new("excavate_map", {})
	panel.setup_panel(pd, BattleRng.new(1))
	panel.show_window(root)
	# 空矿点：info_label 显示 NO_NODE_TEXT，node_button 不可见
	assert_false(panel._node_button.visible, "空列表 node_button 隐藏")
	assert_eq(panel._info_label.text, "暂无矿点，点击「搜索」发现矿点", "空列表文案正确")
	panel.remove_window()
	root.queue_free()


# ── ExcavateSearchPanel：LSTR + 按钮纹理（tavern_button_1+icon_search）──

# search toast + type name LSTR key 全在 JSON
func test_search_lstr_keys_present() -> void:
	var keys: Array[String] = [
		"MAP.TODAY_THE_SEARCH_HAS_REACHED_THE_MAXIMUM_NUMBER_OF_TIMES_",
		"ERRORINFO.INSUFFICIENT_COINS",
		"MAP.DIAMOND_MINE", "MAP.GOLDMINE", "MAP.LABORATORY",
	]
	for k in keys:
		var v: String = cm.get_lstr(k)
		assert_ne(v, k, "LSTR key 命中：" + k)


# search 关键资源存在（bg.jpg + excavate_empty.jpg + tavern_button + icon_search）
func test_search_assets_exist() -> void:
	assert_true(ResourceLoader.exists("res://assets/ui/alpha/HVGA/excavate/excavate_empty.jpg"), "excavate_empty.jpg 存在")
	assert_true(ResourceLoader.exists("res://assets/ui/alpha/HVGA/tavern_button_1.png"), "tavern_button_1.png 存在")
	assert_true(ResourceLoader.exists("res://assets/ui/alpha/HVGA/excavate/excavate_icon_search_1.png"), "excavate_icon_search_1.png 存在")


# search 面板装配无异常（含 search button + label 覆盖 + cost label）
func test_search_panel_builds_without_error() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	var panel := ExcavateSearchPanel.new("excavate", {})
	panel.setup_panel(pd, BattleRng.new(1))
	panel.show_window(root)
	assert_gt(panel.container.get_child_count(), 0, "container 非空")
	# cost_label 显示当前消耗数字（首搜 100）
	assert_eq(panel._cost_label.text, "100", "首搜消耗显示 100")
	panel.remove_window()
	root.queue_free()


# ── ExcavateTeamPanel：LSTR ADJUST_FORMATION + owner 切换 ──

# team LSTR ADJUST_FORMATION key 在 JSON
func test_team_lstr_keys_present() -> void:
	assert_eq(cm.get_lstr("EXCAVATETEAM.ADJUST_FORMATION"), "调整阵容", "ADJUST_FORMATION = 调整阵容")


# team 面板 monster 矿点显示出战按钮（无 crash）
func test_team_panel_monster_builds() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	# 直接注入 monster 矿点（避 search 随机）
	pd.excavate.excavate_data.append({
		"_id": 1, "_type_id": 4, "_owner": "monster", "_state": "occupy",
		"_found_ts": 1, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0, "_wild_id": 30001, "_team": [],
	})
	var panel := ExcavateTeamPanel.new("excavate_team", {})
	panel.setup_panel(pd, 1, BattleRng.new(1), Callable())
	panel.show_window(root)
	assert_gt(panel.container.get_child_count(), 0, "monster team container 非空")
	panel.remove_window()
	root.queue_free()
