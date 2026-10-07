extends GutTest
# 魂匣百抽三选一测试（2026-10-07 自创功能，源无对应物；免费赠送+全英雄池产出——用户拍板；
# 千抽→百抽同日再拍板（102 格连弹真机过载减量），断言随 COMBO_GROUPS=10 缩放）。
# 覆盖：免费语义（不扣钻+任务进度）、3 组 roll 结构（全池广度）与独立性、选定结算
# （新英雄整卡+余量碎片/已拥有全碎片/魂石进包守恒）、弹窗聚合排序与页签交互、
# panel 百抽按钮绑定与全流程。

const COMBO_GROUPS: int = TavernThousandData.COMBO_GROUPS   # 10（百抽=10 组十连，单一来源）
const HERO_ID_MAX: int = 100

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _roll_groups(seed: int) -> Array:
	return TavernThousandData.roll_thousand_groups(BattleRng.new(seed), cm)


# ---- 免费语义（2026-10-07 用户拍板「赠送不消耗钻石」；千抽→百抽同日再拍板）----

func test_thousand_free_no_diamond_cost() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 50000
	TavernThousandData.record_thousand_use(pd, cm)
	assert_eq(pd.diamond, 50000, "百抽免费不扣钻石")


func test_thousand_free_records_task_progress() -> void:
	var job_id: int = 0
	var todolist: Dictionary = cm.get_raw_table("Todolist")
	for jid_str in todolist:
		if String(todolist[jid_str].get("Task Progress Type", "")) == "TavernGroupUse":
			job_id = int(jid_str)
			break
	if job_id == 0:
		return   # 表无该类型任务（数据防御，正常不达）
	var pd := PlayerData.new(cm)
	var before: int = pd.task_manager.get_dailyjob_count(job_id)
	TavernThousandData.record_thousand_use(pd, cm)
	assert_eq(pd.task_manager.get_dailyjob_count(job_id) - before, COMBO_GROUPS,
		"任务进度按 10 组十连计（TavernGroupUse）")


# ---- roll 结构与独立性 ----

func test_roll_groups_structure() -> void:
	var groups: Array = _roll_groups(12345)
	assert_eq(groups.size(), 3, "三组候选结果")
	for g in groups:
		var hero_cnt: int = 0
		var soul_cnt: int = 0
		var soul_ids: Dictionary = {}
		var hero_ids_seen: Dictionary = {}
		for loot in g:
			if int(loot["id"]) < HERO_ID_MAX:
				hero_cnt += 1
				hero_ids_seen[int(loot["id"])] = true
			else:
				soul_cnt += 1
				soul_ids[int(loot["id"])] = true
		assert_eq(hero_cnt, COMBO_GROUPS, "每组保底整卡 10 张（每 10 抽 1 张随机英雄）")
		assert_eq(soul_cnt, COMBO_GROUPS * 10, "每组魂石位 100")
		assert_true(soul_ids.size() >= 20, "魂石覆盖全英雄池广度（实测 %d 种）" % soul_ids.size())
		assert_true(hero_ids_seen.size() >= 5, "整卡覆盖全英雄池广度（实测 %d 种）" % hero_ids_seen.size())


func test_roll_groups_independent() -> void:
	var groups: Array = _roll_groups(12345)
	assert_false(str(groups[0]) == str(groups[1]) or str(groups[0]) == str(groups[2])
			or str(groups[1]) == str(groups[2]), "三组结果互不相同（同 seed 序列连续推进）")


# ---- 选定结算 ----

func _first_hero_id(group: Array) -> int:
	for loot in group:
		if int(loot["id"]) < HERO_ID_MAX:
			return int(loot["id"])
	return 0


func _frag_id_of(tid: int) -> int:
	return int(cm.get_raw_table("Fragment").get(str(tid), {}).get("Fragment ID", 0))


func _count_loot(loots: Array, item_id: int) -> int:
	var total: int = 0
	for loot in loots:
		if int(loot["id"]) == item_id:
			total += int(loot["amount"])
	return total


func _hero_inst_count(pd: PlayerData, tid: int) -> int:
	var cnt: int = 0
	for inst_id in pd.hero_manager.heroes:
		var h: Variant = pd.hero_manager.heroes[inst_id]
		if h != null and int(h.tid) == tid:
			cnt += 1
	return cnt


# 全池语义：整卡 N 张 + 魂石直出 S → 未拥有英雄得 1 整卡 + (N-1+S) 碎片（碎片与魂石同物品 id）。
func test_settle_new_hero() -> void:
	var pd := PlayerData.new(cm)
	var groups: Array = _roll_groups(12345)
	var hero_id: int = _first_hero_id(groups[0])
	assert_true(hero_id > 0, "组内应有整卡英雄")
	var frag_id: int = _frag_id_of(hero_id)
	var cards: int = _count_loot(groups[0], hero_id)
	var stones: int = _count_loot(groups[0], frag_id)
	TavernThousandData.settle_thousand_group(pd, groups[0], cm)
	assert_eq(_hero_inst_count(pd, hero_id), 1, "未拥有英雄 → 入 1 张整卡")
	if frag_id > 0:
		assert_eq(pd.hero_manager.fragment_count(frag_id), cards - 1 + stones,
			"其余整卡转碎片+魂石直出（整卡 %d-1 + 魂石 %d）" % [cards, stones])


func test_settle_owned_hero() -> void:
	var pd := PlayerData.new(cm)
	var groups: Array = _roll_groups(12345)
	var hero_id: int = _first_hero_id(groups[0])
	var frag_id: int = _frag_id_of(hero_id)
	var cards: int = _count_loot(groups[0], hero_id)
	var stones: int = _count_loot(groups[0], frag_id)
	pd.hero_manager.add_hero(hero_id)   # 预先拥有整卡
	TavernThousandData.settle_thousand_group(pd, groups[0], cm)
	assert_eq(_hero_inst_count(pd, hero_id), 1, "已拥有不重复加整卡")
	if frag_id > 0:
		assert_eq(pd.hero_manager.fragment_count(frag_id), cards + stones,
			"整卡全转碎片+魂石直出（整卡 %d + 魂石 %d）" % [cards, stones])


func test_settle_items_conserved() -> void:
	var pd := PlayerData.new(cm)
	var groups: Array = _roll_groups(12345)
	var before: Dictionary = {}
	for lid in pd.items:
		before[int(lid)] = int(pd.items[lid])
	var group: Array = groups[1]
	var expect: Dictionary = {}      # 物品 id → 预期差量
	var card_counts: Dictionary = {} # 英雄 tid → 整卡张数
	for loot in group:
		var lid: int = int(loot["id"])
		if lid >= HERO_ID_MAX:
			expect[lid] = int(expect.get(lid, 0)) + int(loot["amount"])
		else:
			card_counts[lid] = int(card_counts.get(lid, 0)) + int(loot["amount"])
	# 整卡转换碎片与魂石同物品 id（hero_manager.items 与 pd.items 同账本）：
	# 测试 PlayerData 全未拥有 → 每英雄 N 张整卡 = 1 张入卡 + (N-1) 转碎片
	for tid in card_counts:
		var frag_id: int = _frag_id_of(int(tid))
		if frag_id > 0:
			expect[frag_id] = int(expect.get(frag_id, 0)) + int(card_counts[tid]) - 1
	TavernThousandData.settle_thousand_group(pd, group, cm)
	for lid in expect:
		var delta: int = int(pd.items.get(int(lid), 0)) - int(before.get(int(lid), 0))
		assert_eq(delta, int(expect[lid]), "魂石 %d 差量守恒" % int(lid))
	for tid in card_counts:
		assert_eq(_hero_inst_count(pd, int(tid)), 1, "英雄 %d 入 1 张整卡" % int(tid))


# ---- 弹窗聚合与交互 ----

func test_aggregate_orders_hero_first() -> void:
	var loots: Array = [
		{"id": 101, "amount": 10}, {"id": 101, "amount": 5},
		{"id": 5, "amount": 1}, {"id": 102, "amount": 20},
	]
	var rows: Array = PopTavernThousand.aggregate_loots(loots)
	assert_eq(rows.size(), 3, "按 id 聚合 3 行")
	assert_eq(int(rows[0]["id"]), 5, "英雄行在前")
	assert_eq(int(rows[0]["amount"]), 1, "英雄聚合量")
	assert_eq(int(rows[1]["id"]), 102, "魂石按总量降序")
	assert_eq(int(rows[1]["amount"]), 20)
	assert_eq(int(rows[2]["id"]), 101)
	assert_eq(int(rows[2]["amount"]), 15)


func test_pick_popup_tabs_and_choose() -> void:
	var popup := PopTavernThousand.new("poptaverntousand", {})
	var groups: Array = _roll_groups(12345)
	popup.setup_pick(groups, cm)
	add_child_autofree(popup)
	watch_signals(popup)
	assert_eq(popup._tab_btns.size(), 3, "三个页签")
	popup._show_group(2)
	assert_eq(popup._current, 2, "切页签更新当前组")
	# 旧 icon queue_free 当帧不删，等一帧再数（_show_group(0) 建过一批）
	await get_tree().process_frame
	var rows: Array = PopTavernThousand.aggregate_loots(groups[2])
	assert_eq(popup._grid.get_child_count(), rows.size(), "图标网格数 = 聚合条目数")
	popup._on_choose_pressed()
	assert_signal_emitted_with_parameters(popup, "chosen", [2])


# ---- panel 集成 ----

func test_panel_thousand_button_bound() -> void:
	var pd := PlayerData.new(cm)
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(pd, BattleRng.new(12345))
	# 百抽入口在面板顶部根级（TitleBg 右侧空区）——board 内展开区被源布局排满，放 Scroll 内会被 Clip 裁剪
	var btn: TextureButton = panel._content.get_node_or_null("%ThousandBuyBtn") as TextureButton
	assert_not_null(btn, "tavern_content 根级应含百抽按钮")
	assert_eq((btn.get_node("ThousandBuyLabel") as Label).text, "百抽三选一", "按钮文案 fill")
	assert_null(panel._content.get_node_or_null("%ThousandCostLabel"),
		"百抽免费（赠送）无费用行")
	assert_null(panel._content.get_node_or_null("%ThousandIcon"), "无钻石图标")
	var btn_layout: Rect2 = (panel._content.get_node("%ThousandBuyBtn") as Control).get_global_rect()
	assert_true(btn_layout.position.y >= 0.0 and btn_layout.end.y <= 480.0,
		"百抽按钮应在屏内（y %.1f-%.1f）" % [btn_layout.position.y, btn_layout.end.y])
	panel.queue_free()


func test_panel_thousand_flow() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 50000
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(pd, BattleRng.new(12345))
	panel._on_thousand_pressed("MagicSoul")
	assert_eq(pd.diamond, 50000, "百抽免费不扣钻石（赠送，2026-10-07 用户拍板）")
	assert_eq(panel._thousand_groups.size(), 3, "百抽 roll 3 组候选")
	var before_total: int = 0
	for lid in pd.items:
		before_total += int(pd.items[lid])
	panel._on_thousand_chosen(0)
	# 集成链只断言入包总量级增（全池守恒含整卡转碎片复合账，专项由 test_settle_items_conserved 覆盖）
	var after_total: int = 0
	for lid in pd.items:
		after_total += int(pd.items[lid])
	assert_true(after_total - before_total >= COMBO_GROUPS * 10,
		"选定组全量入包（差量 %d ≥ 100 魂石位）" % (after_total - before_total))
	assert_eq(bool(TavernData.is_first_ten_draw(pd, "MagicSoul")), false, "百抽计入十连首抽标记")
	panel.queue_free()


# ---- 重选（2026-10-07 用户需求：不满意可免费重选）----

func _tavern_job_id() -> int:
	var todolist: Dictionary = cm.get_raw_table("Todolist")
	for jid_str in todolist:
		if String(todolist[jid_str].get("Task Progress Type", "")) == "TavernGroupUse":
			return int(jid_str)
	return 0


# 弹窗侧：重选按钮发 reroll_requested（不关窗）+ update_groups 回填新组回第一组重播。
func test_reroll_button_requests_and_updates() -> void:
	var popup := PopTavernThousand.new("poptaverntousand", {})
	var old_groups: Array = _roll_groups(12345)
	popup.setup_pick(old_groups, cm)
	add_child_autofree(popup)
	watch_signals(popup)
	popup._show_group(2)
	popup._on_reroll_pressed()
	assert_signal_emitted(popup, "reroll_requested", "重选按钮发 reroll_requested")
	assert_true(is_instance_valid(popup) and popup.is_inside_tree(), "重选不关窗")
	popup.update_groups(_roll_groups(67890))
	assert_eq(popup._current, 0, "重选后回第一组")
	await get_tree().process_frame
	var rows: Array = PopTavernThousand.aggregate_loots(popup._groups[0])
	assert_eq(popup._grid.get_child_count(), rows.size(), "网格重填为新组条目")


# 释放竞态回归（2026-10-07 实机 --debug 断点根修）：入场连弹进行中重选——旧 icon
# queue_free 当帧混在网格、旧 tween 链 0.14s 后触发，修复前类型化赋值/tween 回调
# 撞 freed 实例报 SCRIPT ERROR；跨过旧 tween POP_SEC 窗口无错即通过。
func test_reroll_during_pop_anim_no_freed_access() -> void:
	var popup := PopTavernThousand.new("poptaverntousand", {})
	popup.setup_pick(_roll_groups(12345), cm)
	add_child_autofree(popup)
	await get_tree().create_timer(0.2).timeout   # 连弹进行中（~第 6 个 icon）
	popup.update_groups(_roll_groups(67890))     # 重选：queue_free 旧 icon + 新连弹并起
	await get_tree().create_timer(0.6).timeout   # 跨过旧 tween POP_SEC=0.14 触发窗口
	assert_eq(popup._current, 0, "重选后弹窗存活且回第一组")


# panel 侧：重选更新候选组、不重复记任务进度、不扣钻石；chosen 结算读当前候选组
# （防重选后仍结算旧 bind 数组的回归——本次 chosen 改读 _thousand_groups 成员的锚点用例）。
func test_panel_thousand_reroll_updates_groups() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 50000
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(pd, BattleRng.new(12345))
	panel._on_thousand_pressed("MagicSoul")
	var old_groups: Array = panel._thousand_groups
	var job_id: int = _tavern_job_id()
	var task_before: int = pd.task_manager.get_dailyjob_count(job_id) if job_id > 0 else 0
	# 仿宿主真实连接链（_on_thousand_pressed 内 pick.reroll_requested → _on_thousand_reroll）
	var popup := PopTavernThousand.new("poptaverntousand", {})
	popup.setup_pick(old_groups, cm)
	add_child_autofree(popup)
	popup.reroll_requested.connect(panel._on_thousand_reroll.bind(popup))
	popup._on_reroll_pressed()
	assert_false(str(panel._thousand_groups) == str(old_groups), "重选后候选组已更新")
	assert_eq(panel._thousand_groups.size(), 3, "重选仍 3 组候选")
	assert_eq(pd.diamond, 50000, "重选免费不扣钻石")
	if job_id > 0:
		assert_eq(pd.task_manager.get_dailyjob_count(job_id) - task_before, 0,
			"重选不重复记任务进度（百抽使用只记一次）")
	panel.queue_free()


# 两底钮成组居中守卫（2026-10-07 用户反馈「加重选后两按钮不居中」——旧实现选定居中+
# 重选右挂致整组中心偏右 ~72px；断言并集中心=面板中心，锚面板局部坐标不依赖挂树）
func test_choose_and_reroll_group_centered() -> void:
	var popup := PopTavernThousand.new("poptaverntousand", {})
	popup.setup_pick(_roll_groups(12345), cm)
	add_child_autofree(popup)
	var bw: float = PopTavernThousand.BTN_SHOW_SIZE.x
	var lo: float = minf(popup._choose_btn.position.x, popup._reroll_btn.position.x)
	var hi: float = maxf(popup._choose_btn.position.x, popup._reroll_btn.position.x) + bw
	assert_almost_eq((lo + hi) * 0.5, PopTavernThousand.PANEL_SIZE.x * 0.5, 0.5,
		"选定+重选两钮并集中心 = 面板中心（组宽 %.1f 居中）" % (bw * 2.0 + PopTavernThousand.CHOOSE_GAP))
	assert_almost_eq(popup._choose_btn.position.y, popup._reroll_btn.position.y, 0.5,
		"两钮同一水平线")


# chosen 结算当前候选组成员（手工构造可区分组：表外物品 id 9999 settle 走 add_item 直加）
func test_panel_thousand_chosen_settles_current_groups() -> void:
	var pd := PlayerData.new(cm)
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(pd, BattleRng.new(12345))
	panel._thousand_groups = [[{"id": 9999, "amount": 7}], [], []]
	panel._on_thousand_chosen(0)
	assert_eq(int(pd.items.get(9999, 0)), 7, "chosen 结算 _thousand_groups 当前组（重选后不 bind 旧数组）")
	panel.queue_free()


# ---- 一次性标记：选定后入口按钮消失（2026-10-07 用户需求「选定之后按钮要消失」）----

func test_thousand_used_flag_serde_roundtrip() -> void:
	var pd := PlayerData.new(cm)
	assert_false(TavernThousandData.is_thousand_used(pd), "新档未用")
	TavernThousandData.mark_thousand_used(pd)
	assert_true(TavernThousandData.is_thousand_used(pd), "选定置位")
	# 标记借宿 tavern_record 嵌套 dict——serde 非 dict 值会被损坏守卫跳过，须往返验证不丢
	var pd2 := PlayerDataSerde.from_dict(PlayerDataSerde.to_dict(pd), cm)
	assert_true(TavernThousandData.is_thousand_used(pd2), "存档往返标记保留（嵌套 dict 过损坏守卫）")


func test_reroll_does_not_mark_used() -> void:
	var pd := PlayerData.new(cm)
	TavernThousandData.record_thousand_use(pd, cm)
	# 重选语义：候选未选定不入包，不消耗一次性资格
	assert_false(TavernThousandData.is_thousand_used(pd), "仅开窗/重选不置位")


func test_panel_thousand_button_hidden_after_chosen() -> void:
	var pd := PlayerData.new(cm)
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(pd, BattleRng.new(12345))
	var btn: TextureButton = panel._content.get_node_or_null("%ThousandBuyBtn") as TextureButton
	assert_true(btn.visible, "未用时入口按钮可见")
	panel._thousand_groups = [[{"id": 9999, "amount": 7}], [], []]
	panel._on_thousand_chosen(0)
	assert_false(btn.visible, "选定结算后入口按钮消失")
	panel.queue_free()
	# 重开面板（新实例，读持久化标记）按钮仍隐藏——防"重开酒馆按钮复活"回归
	var panel2 := TavernPanel.new("tavern", {})
	panel2.setup_panel(pd, BattleRng.new(12345))
	var btn2: TextureButton = panel2._content.get_node_or_null("%ThousandBuyBtn") as TextureButton
	assert_false(btn2.visible, "已用档重开面板入口按钮不回（标记持久化生效）")
	panel2.queue_free()
