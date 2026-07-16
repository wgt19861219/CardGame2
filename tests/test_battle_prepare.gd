extends GutTest
# battleprepare 战前布阵面板测试：选英雄/上阵下阵/maxRange 排序/gs/tab 过滤。
# 复用 crusade_panel 测试 fixture 模式（ConfigManager + PlayerData + add_hero）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_player() -> PlayerData:
	var pd := PlayerData.new(cm)
	# 加 6 个英雄（覆盖 front/middle/back 各 2）
	pd.hero_manager.add_hero(1)   # Unit 1: FRONT_ROW
	pd.hero_manager.add_hero(2)   # Unit 2: REAR_ROW
	pd.hero_manager.add_hero(3)   # Unit 3: MIDDLE_ROW
	pd.hero_manager.add_hero(4)   # Unit 4: MIDDLE_ROW
	pd.hero_manager.add_hero(5)   # Unit 5: FRONT_ROW
	pd.hero_manager.add_hero(6)   # Unit 6
	return pd


func _make_panel() -> BattlePreparePanel:
	var pd := _make_player()
	var rng := BattleRng.new(12345)
	var panel := BattlePreparePanel.new()
	panel.setup(1, pd, null, rng, cm)
	return panel


func test_panel_assembles() -> void:
	var panel := _make_panel()
	assert_not_null(panel._list_grid, "列表 GridContainer 应装配")
	assert_eq(panel._team_slots.size(), 5, "应有 5 个上阵槽")
	assert_not_null(panel._gs_label, "gs Label 应装配")
	assert_not_null(panel._go_button, "开战按钮应装配")
	panel.queue_free()


func test_hero_list_loads() -> void:
	var panel := _make_panel()
	assert_eq(panel._heroes_all.size(), 6, "应加载 6 个英雄")
	panel.queue_free()


func test_add_team_member() -> void:
	var panel := _make_panel()
	# 先下阵一个腾出位置
	if panel._team.size() >= 5:
		panel._remove_team_member(panel._team[0].inst_id)
	var initial := panel._team.size()
	# 找一个没上阵的英雄
	var inst_id: int = 0
	for h in panel._heroes_all:
		if not panel._team.any(func(t): return t.inst_id == h.inst_id):
			inst_id = h.inst_id; break
	assert_true(inst_id > 0, "应找到未上阵英雄")
	panel._add_team_member(inst_id)
	assert_eq(panel._team.size(), initial + 1, "上阵后队伍+1")
	panel.queue_free()


func test_team_limit_5() -> void:
	var panel := _make_panel()
	# 超过 5 人时拒绝
	while panel._team.size() < 5:
		var added := false
		for h in panel._heroes_all:
			if not panel._team.any(func(t): return t.inst_id == h.inst_id):
				panel._add_team_member(h.inst_id); added = true; break
		if not added: break
	assert_eq(panel._team.size(), 5, "队伍满 5 人")
	# 尝试加第 6 个
	var inst_id: int = 0
	for h in panel._heroes_all:
		if not panel._team.any(func(t): return t.inst_id == h.inst_id):
			inst_id = h.inst_id; break
	if inst_id > 0:
		panel._add_team_member(inst_id)
		assert_eq(panel._team.size(), 5, "超 5 人应拒绝")
	panel.queue_free()


func test_remove_team_member() -> void:
	var panel := _make_panel()
	var initial := panel._team.size()
	if initial > 0:
		var inst_id: int = panel._team[0].inst_id
		panel._remove_team_member(inst_id)
		assert_eq(panel._team.size(), initial - 1, "下阵后队伍-1")
	panel.queue_free()


func test_order_by_max_range() -> void:
	var panel := _make_panel()
	# 验证 _team 按 max_range 降序排列（大的在后面）
	for i in range(panel._team.size() - 1):
		assert_true(panel._team[i].max_range <= panel._team[i + 1].max_range,
			"队伍应按 max_range 升序（位置越后 range 越大，源 orderTeam 语义）")
	panel.queue_free()


func test_gs_displayed() -> void:
	var panel := _make_panel()
	var gs_text: String = panel._gs_label.text
	# 照源 battleprepare.lua:2256 gs_title=BATTLEPREPARE.COMBAT（战斗力）
	assert_true(gs_text.begins_with(cm.get_lstr("BATTLEPREPARE.COMBAT")), "gs Label 应有战斗力前缀")
	panel.queue_free()


func test_class_tab_filter() -> void:
	var panel := _make_panel()
	# 切到 front tab
	panel._current_tab = "front"
	panel._refresh_list()
	for h in panel._heroes_filtered:
		assert_eq(h.pos_type, "front", "front tab 应只显示前排英雄")
	panel.queue_free()


# 照源 battleprepare.lua:1870/1915/1960/2005 tab 标签用 LSTR（全部/前排/中排/后排）。
func test_tab_label_uses_lstr() -> void:
	var panel := _make_panel()
	assert_eq(panel._tab_label("all"), cm.get_lstr("BATTLEPREPARE.WHOLE"), "全部 tab=LSTR.WHOLE")
	assert_eq(panel._tab_label("front"), cm.get_lstr("UNIT.FRONT_ROW"), "前排 tab=LSTR.FRONT_ROW")
	assert_eq(panel._tab_label("middle"), cm.get_lstr("UNIT.MIDDLE_ROW"), "中排 tab=LSTR.MIDDLE_ROW")
	assert_eq(panel._tab_label("back"), cm.get_lstr("UNIT.REAR_ROW"), "后排 tab=LSTR.REAR_ROW")
	# 开始战斗按钮照源 :2241 CHATCONFIG.CONFIRM（确定）
	assert_eq(panel._go_button.text, cm.get_lstr("CHATCONFIG.CONFIRM"), "开始按钮=LSTR.CONFIRM")
	panel.queue_free()
