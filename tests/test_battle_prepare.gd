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


# P1-B3（2026-07-23）：源 crusade.lua:434-438 start() 传 mode=crusade + heroLimit level=20。
# battleprepare.lua:7 min_crusade_level=20 + :1154 getAllListWithLimit + :962 上阵校验双保险。
func _make_crusade_panel(min_level: int = 20) -> BattlePreparePanel:
	var pd := _make_player()
	# 把部分英雄设 <20 级（验证过滤）
	var keys: Array = pd.hero_manager.heroes.keys()
	for i in range(keys.size()):
		var h: HeroInstance = pd.hero_manager.heroes[keys[i]]
		h.level = 10 if i < 2 else 25   # 前 2 个 <20，后 4 个 ≥20
	var rng := BattleRng.new(12345)
	var panel := BattlePreparePanel.new()
	panel.setup(-3, pd, null, rng, cm, "crusade", min_level)   # stage_id=-3（crusade 标识）
	return panel


func test_crusade_mode_loads_panel_state() -> void:
	var panel := _make_crusade_panel()
	assert_eq(panel.mode, "crusade", "mode=crusade（源 crusade.lua:435）")
	assert_eq(panel.min_level, 20, "min_level=20（源 :436 heroLimit detail）")
	assert_eq(panel.stage_id, -3, "stage_id 透传（crusade 负标识）")
	panel.queue_free()


# 源 :1154 getAllListWithLimit（crusade 模式 heroLimit level=20 过滤列表）+ :962 上阵校验双保险。
func test_crusade_mode_filters_low_level_heroes() -> void:
	var panel := _make_crusade_panel(20)
	# 6 英雄：前 2 级 10（过滤），后 4 级 25（保留）→ 列表 4 个
	assert_eq(panel._heroes_all.size(), 4, "crusade 模式 _heroes_all 过滤 <level 20（源 :1154）")
	for h in panel._heroes_all:
		var hero = panel.player.hero_manager.heroes[h.inst_id]
		assert_true(int(hero.level) >= 20, "列表英雄均 ≥20 级（源 heroLimit level=20）")
	panel.queue_free()


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
	# GoBtn conform text 照源 battleprepare.lua:1788-1791 仅 isSpecialgb（pvp defend/excavateChange）时 visible。
	# 本项目单机化已裁剪这两模式（grep 零匹配 isSpecialgb）→ text 始终空，由 prepare_go_battle 贴图表达语义。
	assert_eq(panel._go_button.text, "", "GoBtn conform text 隐藏（源仅 isSpecialgb 显示，本项目已裁剪）")
	panel.queue_free()
