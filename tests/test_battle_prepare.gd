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


# 源 battleprepare.lua:1700-1704 classify("prepare","position") → readhero.lua:861-868
# getAllListForPrepare → ed.orderHeroes()（tools.lua:819-857 orderHeroFunction）：
# 等级降序 → 同级星级降序 → 同级同星 rank 降序；classifyByPos 分组保序。
# 旧实现遍历 heroes 字典（获得序）未排序（2026-09-15 用户报出击列表排序问题——
# 前期英雄练度高致获得序观感"像按练度"，但同级不按星级/rank 严格排）。
# 构造刻意相反：获得序 [1,2,3] vs 等级序 tid2(30)>tid3(20)>tid1(10)。
func test_hero_list_orders_by_level_desc() -> void:
	var pd := _make_player()
	(pd.hero_manager.heroes[1] as HeroInstance).level = 10
	(pd.hero_manager.heroes[2] as HeroInstance).level = 30
	(pd.hero_manager.heroes[3] as HeroInstance).level = 20
	var panel := BattlePreparePanel.new()
	panel.setup(1, pd, null, BattleRng.new(12345), cm)
	assert_eq(panel._heroes_all[0].tid, 2, "列表首 = 最高等级（源 orderHeroes 等级降序）")
	assert_eq(panel._heroes_all[1].tid, 3, "列表次 = 次高等级")
	assert_eq(panel._heroes_all[2].tid, 1, "列表第三 = 最低等级（获得序不生效）")
	panel.queue_free()


# 同级按星级降序（源 orderHeroFunction 第二排序键 _stars）。
# 构造：获得序 [1,2] 同级 20，tid1 星 1 < tid2 星 3 → 列表首 tid2。
func test_hero_list_orders_tie_by_stars_desc() -> void:
	var pd := _make_player()
	(pd.hero_manager.heroes[1] as HeroInstance).level = 20
	(pd.hero_manager.heroes[1] as HeroInstance).stars = 1
	(pd.hero_manager.heroes[2] as HeroInstance).level = 20
	(pd.hero_manager.heroes[2] as HeroInstance).stars = 3
	var panel := BattlePreparePanel.new()
	panel.setup(1, pd, null, BattleRng.new(12345), cm)
	assert_eq(panel._heroes_all[0].tid, 2, "同级按星级降序（源 orderHeroFunction 第二键）")
	panel.queue_free()


# tab 分组保序（源 classifyByPos 在 orderHeroes 排序后分组）：front tab 内部同为等级降序。
# 构造：tid1/tid5 均 FRONT_ROW，tid5(40) > tid1(30) → front tab 首个 tid5。
func test_hero_list_tab_filter_keeps_level_order() -> void:
	var pd := _make_player()
	(pd.hero_manager.heroes[1] as HeroInstance).level = 30
	(pd.hero_manager.heroes[5] as HeroInstance).level = 40
	var panel := BattlePreparePanel.new()
	panel.setup(1, pd, null, BattleRng.new(12345), cm)
	panel._current_tab = "front"
	panel._refresh_list()
	assert_true(panel._heroes_filtered.size() >= 2, "front tab 至少含 tid1/tid5")
	assert_eq(panel._heroes_filtered[0].tid, 5, "front tab 内部保持等级降序（分组保序）")
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
	# 照源 battleprepare.lua:2252-2279 gs_title（COMBAT 标题）+ gs（数值）两行，拆成 GsTitleLabel + GsLabel。
	assert_not_null(panel._gs_title_label, "gs 标题 Label 应装配")
	assert_eq(panel._gs_title_label.text, cm.get_lstr("BATTLEPREPARE.COMBAT"), "GsTitleLabel 应为战斗力标题")
	assert_true(panel._gs_label.text.is_valid_int(), "GsLabel 应为战斗力数值（整数）")
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


# ── 布局守卫（2026-08-30 三修：列表竖滚 / tab 不被列表盖 / 头像进框）──

# 源 draglist cliprect=(130,155,510,295)（battleprepare.lua:1682）仅纵向滚动；
# icon 网格 gap 100 × 5 列（:1548-1560）→ btn 96×96 + sep 4 = 列距 100，网格宽
# 5×96+4×4=496 < 视口 510 → 无水平溢出。修复前：btn 112 + h_sep 25 → 网格宽 660 > 视口 549 左右滚。
func test_list_viewport_scrolls_vertically_only() -> void:
	var panel := _make_panel()
	var scroll: ScrollContainer = panel._list_grid.get_parent() as ScrollContainer
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED,
		"列表应禁用水平滚动（源 draglist 仅纵向）")
	var grid_min_x: float = panel._list_grid.get_combined_minimum_size().x
	assert_between(grid_min_x, 0.0, scroll.size.x + 0.5,
		"网格最小宽 %.1f ≤ 视口宽 %.1f（不产生水平溢出）" % [grid_min_x, scroll.size.x])
	assert_eq(panel._list_grid.columns, 5, "5 列照源 colNum=5（battleprepare.lua:1560）")
	assert_eq(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_SHOW_NEVER,
		"竖滚动条隐藏（2026-08-30 用户裁决：滚动仍可用但不显示滚动条）")
	assert_eq(panel._list_grid.get_theme_constant("h_separation"), 16,
		"列间距 16（GridContainer 默认；离树 min 计算不认 override，见 panel 注释）")
	var live_child: Button = null
	for k in panel._list_grid.get_children():
		if not k.is_queued_for_deletion() and k is Button:
			live_child = k
			break
	assert_ne(live_child, null, "列表应有活英雄格")
	assert_eq(live_child.custom_minimum_size, Vector2(84, 84),
		"btn 84×84 + sep 16 = icon 中心距 100（源 hero_icon_gap_x=100；84≈frame 83 令 hover 框贴图标）")
	# 首列 portrait 视觉中心照源 (189,80)（hero_icon_ori 189/400，battleprepare.lua:1548-1549）：
	# icon.position(3,-23)+portrait 中心(39,65) → 视口(147,38) 下首列 (189,80)，且与 btn 中心(42+视口)
	# 重合=hover 高亮框与头像零错位（2026-08-30 四轮用户反馈修）。
	var rh: ReadheroIcon = null
	for c in live_child.get_children():
		if c is ReadheroIcon:
			rh = c
			break
	assert_ne(rh, null, "格内应有 ReadheroIcon")
	assert_eq(rh.position, Vector2(3.0, -23.0),
		"icon.position 令 portrait 视觉中心=btn 中心（hover 零错位）+首列 (189,80) 照源")
	# 源 stage 模式无 listTitle（battleprepare.lua:1085-1119 条件创建）→ 静态标题隐藏。
	var title: Label = panel.get_node_or_null("BattlePrepareContent/ListFrame/ListTitleLabel") as Label
	if title != null:
		assert_false(title.visible, "标题 Label 应隐藏（源普通关卡无标题，迁移发明元素）")
	panel.queue_free()


# 源视口右缘 x=640 与 tab 按钮左缘 ~655.7 空间分离（列表层 zorder=20 不与 tab 交叠）。
# 修复前：视口右缘 658.3 侵入 tab 区且 ListScroll z=10 → 列表+右侧垂直滚动条盖住 tab 按钮。
func test_list_viewport_does_not_overlap_tab_buttons() -> void:
	var panel := _make_panel()
	var scroll: ScrollContainer = panel._list_grid.get_parent() as ScrollContainer
	for key in panel._tab_buttons:
		var btn: TextureButton = panel._tab_buttons[key] as TextureButton
		assert_true(scroll.position.x + scroll.size.x <= btn.position.x,
			"列表视口右缘 %.1f 应不越过 tab(%s) 左缘 %.1f" % [scroll.position.x + scroll.size.x, key, btn.position.x])
	panel.queue_free()


# 头像在桶内视觉居中（2026-08-30 用户观感裁决：源 getTeamMemberPos 锚点偏左下 ~12px
# 不采用，受控偏离——同 ladder 防守阵容「框中心对槽中心」判例）。portrait 显示 78×78，
# 视觉中心 = container 左上 + (39,65)（贴左下布局），应与 slot 中心重合。
func test_team_icon_positioned_in_bucket_slot() -> void:
	var panel := _make_panel()
	var checked: int = 0
	for slot in panel._team_slots:
		var icon_node: ReadheroIcon = null
		for c in slot.get_children():
			if c is ReadheroIcon:
				icon_node = c
				break
		if icon_node == null:
			continue   # 未上阵槽
		checked += 1
		var slot_center: Vector2 = slot.size * 0.5
		assert_almost_eq(icon_node.position.x, slot_center.x - 39.0, 0.5,
			"icon.x = slot 中心 x − 39（portrait 视觉中心水平居中）")
		assert_almost_eq(icon_node.position.y, slot_center.y - 65.0, 0.5,
			"icon.y = slot 中心 y − 65（portrait 视觉中心垂直居中，104−39）")
		var visual_center: Vector2 = icon_node.position + Vector2(39.0, 65.0)
		var d: Vector2 = visual_center - slot_center
		assert_between(d.x, -0.5, 0.5, "视觉中心 x 与 slot 中心重合（用户裁决居中，弃源锚点偏移）")
		assert_between(d.y, -0.5, 0.5, "视觉中心 y 与 slot 中心重合（用户裁决居中，弃源锚点偏移）")
	assert_gt(checked, 0, "默认队伍应至少有 1 个槽被占（验证有样本）")
	panel.queue_free()


# 源 readhero.lua:538-556 showSelectTag：已选英雄 = 黑罩(150/255) 盖 portrait + tick.png 右下
# z12。旧实现 btn.modulate 整格灰化无对勾系偏离（2026-08-30 三轮照源订正，双端截图对照）。
func test_selected_hero_has_shade_and_tick() -> void:
	var panel := _make_panel()
	var selected_icons: Array[ReadheroIcon] = []
	var plain_icons: Array[ReadheroIcon] = []
	for k in panel._list_grid.get_children():
		if k.is_queued_for_deletion() or not (k is Button):
			continue
		var rh: ReadheroIcon = null
		for c in k.get_children():
			if c is ReadheroIcon:
				rh = c
				break
		if rh == null:
			continue
		var has_tick: bool = false
		for c in rh.icon.get_children():
			if c is Sprite2D and (c as Sprite2D).texture != null \
					and String((c as Sprite2D).texture.resource_path).find("tick.png") >= 0:
				has_tick = true
		if has_tick:
			selected_icons.append(rh)
		else:
			plain_icons.append(rh)
	assert_eq(selected_icons.size(), panel._team.size(),
		"已上阵 %d 英雄均应有 tick 对勾（源 showSelectTag）" % panel._team.size())
	for rh in selected_icons:
		var shade: ColorRect = null
		for c in rh.icon.get_children():
			if c is ColorRect:
				shade = c
				break
		assert_ne(shade, null, "已选英雄应有黑罩盖 portrait（源 shade 150/255）")
		if shade != null:
			assert_almost_eq(shade.color.a, 150.0 / 255.0, 0.01, "罩透明度照源 150/255")
			assert_eq(shade.size, Vector2(78, 78), "罩尺寸=portrait 78×78")
			assert_eq(shade.position, Vector2(0, 26), "罩位置=portrait 贴 container 左下区")
	for rh in plain_icons:
		for c in rh.icon.get_children():
			assert_false(c is ColorRect, "未选英雄不应有罩")
	assert_eq(panel._team.size(), 5, "默认队伍 5 人（对勾样本前提）")
	panel.queue_free()


# ── 开战阵容写回（2026-09-15：用户报「下了宙斯换小鹿，战斗完成选下一关，小鹿变回宙斯」）──
# 源 battleprepare.lua doGo :336-344 确认开战时 setTeamData(teamData) 把当前阵容写回本地阵容记忆
# （readconfig.lua CCUserDefault 按 stageType 分 td_cm 等 key 持久化），下次进布阵 getTeamData
# :66-76 默认加载上次阵容 + prepareLoadTeam 过滤当前列表外英雄。漏译后果：换人只改面板 _team，
# 下一关 _load_default_team 再读 player.team 旧值 → 阵容回退。crusade 走源 doGoCrusade :394-404
# （无 setTeamData，仅存 cruadeTeam 会话变量）→ 远征限级阵容不污染关卡阵容记忆，照此跟进。

# Stub mgr：stage 分支装配失败（{"ok": false}）提前 return，隔离切场景副作用；写回在装配之前发生。
class StubStageMgr:
	extends RefCounted
	var config = null

	func assemble_stage_battle(_stage_id: int, _player: PlayerData, _tids: Array[int], _rng: BattleRng) -> Dictionary:
		return {"ok": false}


# Stub mgr：crusade 装配第一道容错（crusade_battle.gd:23 config==null → {"ok": false}）。
# 继承 CrusadeManager 过强类型参数关（assemble_crusade_battle(mgr: CrusadeManager)）。
class StubCrusadeMgr:
	extends CrusadeManager


func test_go_persists_team_to_player() -> void:
	var pd := _make_player()
	var panel := BattlePreparePanel.new()
	panel.setup(1, pd, StubStageMgr.new(), BattleRng.new(12345), cm)
	assert_eq(pd.team, [], "写回前 player.team 为初始空")
	# 模拟用户换人：下第 1 个上阵英雄 + 上第 6 个未上阵英雄（6 英雄默认取 5）
	var bench_id: int = int(panel._team[0].inst_id)
	panel._remove_team_member(bench_id)
	var new_id: int = 0
	for h in panel._heroes_all:
		# 排除刚下阵英雄（它在 _team 外，但换人语义要选的是另一个人）
		if int(h.inst_id) != bench_id and not panel._team.any(func(t): return t.inst_id == h.inst_id):
			new_id = int(h.inst_id)
			break
	assert_gt(new_id, 0, "应找到未上阵英雄")
	panel._add_team_member(new_id)
	panel._on_go_pressed()   # stub 装配失败提前 return；写回（源 setTeamData 位点）在装配之前
	var expected: Array[int] = []
	for t in panel._team:
		expected.append(int(t.inst_id))
	assert_eq(pd.team, expected, "开战应把当前阵容写回 player.team（源 doGo setTeamData）")
	assert_false(pd.team.has(bench_id), "被下阵英雄不应残留在 player.team")
	assert_true(pd.team.has(new_id), "新上阵英雄应写入 player.team")
	panel.queue_free()


func test_go_crusade_does_not_persist_team() -> void:
	var pd := _make_player()
	# 全部抬到 ≥20 级，保证 crusade 默认队伍非空（空队走 NOTENOUGH 提前 return 测不到目标分支）
	var keys: Array = pd.hero_manager.heroes.keys()
	for k in keys:
		(pd.hero_manager.heroes[k] as HeroInstance).level = 25
	var panel := BattlePreparePanel.new()
	panel.setup(-3, pd, StubCrusadeMgr.new(), BattleRng.new(12345), cm, "crusade", 20)
	panel._on_go_pressed()   # stub config=null 容错 → {"ok": false} → Toast 提前 return
	assert_eq(pd.team, [], "crusade 开战不应写回 player.team（源 doGoCrusade 无 setTeamData）")
	panel.queue_free()


# ── 选人布阵扩展（2026-09-15 二轮：副本/竞技场攻守/挖矿换队进攻五入口补选人界面）──
# 源六模式对照（battleprepare.lua）：stage/dungeon=getTeamData 记忆；pvp attack=td_pp 记忆
# （本项目单字段受控偏离共用 player.team）；pvp defend=create 传 heros（当前防守阵，
# pvp.lua:154-156）；excavateChange=create 传 excavateDefendTeam（excavateteam.lua:14-16）；
# 确认分发 requestBattle:569-586（defend→set_lineup / excavateChange→set_excavate_team+回调 /
# attack 系→发战斗）。本项目=面板加 initial_tids（外部初始阵容）+ on_confirm（确认回调注入），
# View 调用方自带装配/写防守逻辑，面板不耦合 ladder/excavate。

# 外部初始阵容成为默认队（源 getLastTeam：defend/excavateChange 分支用 create 传入阵容）。
func test_initial_tids_loads_as_default_team() -> void:
	var pd := _make_player()
	# 取英雄 2/4/6 的 tid 作外部初始阵容（tid 与 inst_id 同源同值，add_hero 自增分配）
	var initial: Array[int] = [2, 4, 6]
	var panel := BattlePreparePanel.new()
	panel.setup(1, pd, StubStageMgr.new(), BattleRng.new(12345), cm, "pvp_defend", 0, initial)
	var loaded: Array[int] = []
	for t in panel._team:
		loaded.append(int(t.inst_id))
	# 加载序经 _order_team 按 maxRange 重排（源 getLastTeam resortTeam 同款），断言集合语义
	assert_eq(loaded.size(), initial.size(), "initial_tids 全部加载")
	var sorted_loaded: Array[int] = loaded.duplicate()
	sorted_loaded.sort()
	var sorted_initial: Array[int] = initial.duplicate()
	sorted_initial.sort()
	assert_eq(sorted_loaded, sorted_initial, "initial_tids 应成为默认队（序经 maxRange 重排照源 resortTeam）")
	panel.queue_free()


# 确认回调收到选中 tids（源 requestBattle 各模式分发；本项目 attack/防守系统一回调注入）。
func test_confirm_callback_receives_tids() -> void:
	var pd := _make_player()
	var received: Array[int] = []
	var panel := BattlePreparePanel.new()
	panel.setup(1, pd, null, BattleRng.new(12345), cm, "excavate_attack", 0, [],
		func(tids: Array[int]) -> void: received.assign(tids))
	panel._on_go_pressed()
	var expected: Array[int] = []
	for t in panel._team:
		expected.append(int(t.tid))
	assert_eq(received, expected, "确认应把当前队伍 tid 列表传给 on_confirm 回调")
	assert_true(panel.is_queued_for_deletion(), "回调模式确认后面板关闭（源 popScene）")
	panel.queue_free()


# 回调模式不写回 player.team（源写回集合=stage/dungeon→td_cm + pvp attack→td_pp；
# pvp attack 本项目单字段下不写回防污染关卡阵容，防守/excavate 系写各自数据，均不走 _persist_team）。
func test_confirm_callback_does_not_persist_team() -> void:
	var pd := _make_player()
	var panel := BattlePreparePanel.new()
	panel.setup(1, pd, null, BattleRng.new(12345), cm, "pvp_defend", 0, [],
		func(_tids: Array[int]) -> void: pass)
	panel._on_go_pressed()
	assert_eq(pd.team, [], "回调模式确认不应写回 player.team（写回集合照源=仅 stage 模式）")
	panel.queue_free()
