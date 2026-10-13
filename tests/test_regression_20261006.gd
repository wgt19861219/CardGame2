extends GutTest
# 2026-10-06 用户实测九组问题回归测试（batch）：
#   ① 竞技场/远征/挖掘玩家英雄 proto 漏 _skill_levels → 只装普攻无大招（同 stage 2026-08-18 修）
#   ④ 装备进阶止步金装：can_upgrade_rank/autowear 跳过 0 配方槽（2026-10-07 方案 B 填表后
#      rank 12-23 满槽，0 槽场景改注入式构造守卫）
#   ⑤ 豪华午餐（Login 型日常）时段进度合成 + 领取 + 体力攒体入账（硬上限 9999）
#   ⑧ 觉醒失败返回 reason（View 层 Toast 用）
#   ① 体力药 TONIC_PILLS 判定（章鱼丸子 336/孜然羊肉串 217/奥尔良烤翅 289）
# View 层修复（签到拖拽/结算头像偏移/排行缩字/公会行/藏宝地穴尺寸/入场走路闭环）由
# CI import + 既有 View 测试守卫，不在此重复。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# ── ① 竞技场/远征/挖掘：玩家英雄技能装配（漏 _skill_levels 致 manual_skill=null 回归守卫）──
# 数据前提：tid=1 (Coco) SkillGroup 槽 1 → gid 10 = Coco_ult（Manual=true, Active Type=active）。

func _assert_player_units_have_manual(engine: BattleEngine, tag: String) -> void:
	var players: Array = engine.foreach_alive_unit(BattleEngine.CAMP_PLAYER)
	assert_true(players.size() > 0, tag + "：玩家单位存在")
	for u in players:
		assert_ne(u.manual_skill, null, tag + "：玩家英雄大招已装配（漏 _skill_levels 回归）")
		assert_true(u.skill_list.size() > 1, tag + "：技能列表 > 1（普攻 + 主动技）")


func test_crusade_assemble_player_has_manual_skill() -> void:
	var mgr := CrusadeManager.new(cm)
	mgr.init_crusade(BattleRng.new(12345))
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var r: Dictionary = CrusadeBattle.assemble_crusade_battle(mgr, -3, pd, [1], BattleRng.new(42))
	assert_true(bool(r.get("ok", false)), "远征装配成功")
	_assert_player_units_have_manual(r["engine"], "远征")


func test_ladder_assemble_player_has_manual_skill() -> void:
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	var lm := LadderManager.new()
	lm.handle({"_open_panel": true}, pd, cm, BattleRng.new(1), 0)
	var oppo_id: int = int(lm.pvp["enemies"][0]["user_id"])
	var r: Dictionary = LadderBattle.assemble_pvp_battle(lm, oppo_id, pd, cm, BattleRng.new(2), 0)
	assert_true(bool(r.get("ok", false)), "竞技场装配成功")
	for proto in (r["hero_list"] as Array):
		assert_true((proto as Dictionary).has("_skill_levels"), "竞技场玩家 proto 带 _skill_levels")
	_assert_player_units_have_manual(r["engine"], "竞技场")


func test_excavate_hero_list_carries_skill_levels() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var hero_list: Array[Dictionary] = ExcavateBattle._hero_list_from_player(pd, [1])
	assert_eq(hero_list.size(), 1, "挖掘玩家英雄列表 1 条")
	var proto: Dictionary = hero_list[0]
	assert_true(proto.has("_skill_levels"), "挖掘玩家 proto 带 _skill_levels")
	assert_true(proto.has("_awake"), "挖掘玩家 proto 带 _awake")


# ── ④ 装备进阶：rank 12-23 全档配方（2026-10-07 方案 B 填 2.0 基件后满槽）──
# 2026-10-06 原语义：rank 12-16/17-19/20-23 槽位递减 5/4/3（源 gen_hero_equip.py 设计），
# can_upgrade_rank/autowear 须跳过 0 配方槽；2026-10-07 方案 B 把 8 件 2.0 基件
# （442/445/448/451/454/457/460/463）轮转填满 23 空槽 → 全档 6 槽配方，「0 槽跳过」
# 逻辑保留在代码（数据防御），守卫改注入式构造（_inject_no_recipe_slot）。

func _wear_all_recipe_slots(mgr: HeroManager, inst_id: int) -> int:
	var hero := mgr.get_hero(inst_id)
	var worn: int = 0
	for slot in range(HeroManager.EQUIP_SLOT_COUNT):
		if mgr.wear_equip(inst_id, slot):
			worn += 1
	return worn


# 内存表注入：把 Hero_equip[tid][rank] 某槽临时置 0（无配方槽），返回恢复闭包。
func _inject_no_recipe_slot(tid: int, rank: int, slot: int) -> Callable:
	var row: Dictionary = cm.get_raw_table(&"Hero_equip").get(str(tid), {}).get(str(rank), {})
	var field := "Equip" + str(slot) + " ID"
	var origin: int = int(row.get(field, 0))
	row[field] = 0
	return func() -> void: row[field] = origin


func test_rank12_six_slot_recipe_can_upgrade() -> void:
	var mgr := HeroManager.new(cm)
	var inst_id := mgr.add_hero(1)
	var hero := mgr.get_hero(inst_id)
	hero.rank = 12   # 金装：Hero_equip[1][12] = [442,417,419,398,399,422]（方案 B 填 442 后满 6 槽）
	var worn: int = _wear_all_recipe_slots(mgr, inst_id)
	assert_eq(worn, 6, "rank 12 可穿 6 槽（方案 B 填 2.0 基件 442 后槽 1 有配方）")
	assert_eq(int(hero.equip_slots[0]), 442, "槽 1 穿 442（z1 图标新装备）")
	assert_true(mgr.can_upgrade_rank(inst_id), "6 配方槽穿齐 → 可进阶（金+1）")
	assert_true(mgr.upgrade_rank(inst_id), "rank 12→13 进阶成功")
	assert_eq(hero.rank, 13, "rank 13")


func test_no_recipe_slot_still_skipped_when_injected() -> void:
	# 注入式守卫：数据层满槽后真实表无 0 配方槽，注入还原 2026-10-06 修复场景。
	var restore := _inject_no_recipe_slot(1, 12, 1)
	var mgr := HeroManager.new(cm)
	var inst_id := mgr.add_hero(1)
	var hero := mgr.get_hero(inst_id)
	hero.rank = 12
	var worn: int = _wear_all_recipe_slots(mgr, inst_id)
	assert_eq(worn, 5, "注入 0 配方槽后可穿 5 槽（槽 1 不可穿）")
	assert_eq(int(hero.equip_slots[0]), 0, "槽 1 保持空（无配方）")
	assert_true(mgr.can_upgrade_rank(inst_id), "5 配方槽穿齐 + 无配方槽跳过 → 可进阶")
	restore.call()


func test_rank12_autowear_skips_no_recipe_slot() -> void:
	var restore := _inject_no_recipe_slot(1, 12, 1)
	var pd := PlayerData.new(cm)
	var inst_id := pd.hero_manager.add_hero(1)
	var hero := pd.hero_manager.get_hero(inst_id)
	hero.rank = 12
	_wear_all_recipe_slots(pd.hero_manager, inst_id)
	# 5 配方槽全 isEquiped + 槽 1 ignore：旧实现 ignore → return -1（整单中止）；修后跳过返 0
	assert_eq(EquipCraftManager.autowear_for_upgrade(pd, inst_id), 0, "无配方槽跳过不中止（返 0=无槽可穿）")
	restore.call()


func test_rank11_full_six_slot_still_works() -> void:
	var mgr := HeroManager.new(cm)
	var inst_id := mgr.add_hero(1)
	var hero := mgr.get_hero(inst_id)
	hero.rank = 11   # 全 6 槽配方
	var worn: int = _wear_all_recipe_slots(mgr, inst_id)
	assert_eq(worn, 6, "rank 11 可穿 6 槽")
	assert_true(mgr.can_upgrade_rank(inst_id), "6 槽穿齐可进阶（原行为不回归）")
	# 缺一槽仍不可进阶（有配方槽必须穿）
	hero.equip_slots[5] = 0
	assert_false(mgr.can_upgrade_rank(inst_id), "有配方槽未穿 → 不可进阶")


# ── ⑤ 豪华午餐（Login 型日常任务，Todolist job 1，时段 12:00-14:00）──

const LUNCH_JOB_ID: int = 1
const LUNCH_START_MIN: int = 720   # 12:00
const LUNCH_END_MIN: int = 840     # 14:00

func test_login_job_count_synthesizes_in_window() -> void:
	var tm := TaskManager.new()
	var pd := PlayerData.new(cm)
	assert_eq(String(cm.get_raw_table("Todolist").get("1", {}).get("Task Progress Type", "")), "Login",
			"前提：job 1 是 Login 型")
	assert_eq(tm.get_effective_dailyjob_count(cm, LUNCH_JOB_ID, pd, LUNCH_START_MIN + 30), 1,
			"时段内（12:30）计数=target（时间到即完成，源 playertools.lua:93-126）")
	assert_eq(tm.get_effective_dailyjob_count(cm, LUNCH_JOB_ID, pd, LUNCH_START_MIN - 60), 0,
			"时段外（11:00）计数 0")
	assert_eq(tm.get_effective_dailyjob_count(cm, LUNCH_JOB_ID, pd, LUNCH_END_MIN + 60), 0,
			"时段后（15:00）计数 0")


func test_login_job_claim_in_window_and_once_per_day() -> void:
	var tm := TaskManager.new()
	var pd := PlayerData.new(cm)
	pd.vitality = 5
	var r: Dictionary = tm.claim_job_reward(pd, LUNCH_JOB_ID, cm, LUNCH_START_MIN + 60)
	assert_true(bool(r.get("ok", false)), "时段内（13:00）领取成功")
	assert_eq(pd.vitality, 605, "体力 +600（攒体硬上限 9999，不压 vitality_max）")
	var r2: Dictionary = tm.claim_job_reward(pd, LUNCH_JOB_ID, cm, LUNCH_START_MIN + 90)
	assert_false(bool(r2.get("ok", false)), "当日二次领取被拒")
	var r3: Dictionary = tm.claim_job_reward(pd, LUNCH_JOB_ID, cm, LUNCH_START_MIN - 100)
	assert_false(bool(r3.get("ok", false)), "时段外领取被拒（新 TaskManager 实例模拟跨日重置不适用，本例同日）")


func test_vitality_reward_caps_at_999() -> void:
	var tm := TaskManager.new()
	var pd := PlayerData.new(cm)
	pd.vitality = 995
	tm.claim_job_reward(pd, LUNCH_JOB_ID, cm, LUNCH_START_MIN + 30)
	assert_eq(pd.vitality, 999, "体力奖励硬上限 999（2026-10-12 上限统一）")


# ── ⑧ 觉醒失败 reason（View Toast 依据）──

func test_awake_hero_returns_reason_no_fragment() -> void:
	var pd := PlayerData.new(cm)
	var hero := HeroInstance.new(1, 1, 1)
	var r: Dictionary = AwakeHelper.awake_hero(pd, hero)
	assert_false(bool(r.get("ok", false)), "碎片 0 觉醒失败")
	assert_eq(String(r.get("reason", "")), "no_fragment", "失败原因=no_fragment")
	assert_eq(int(r.get("need", 0)), 50, "need=50")
	assert_eq(int(r.get("have", 0)), 0, "have=0")


func test_awake_hero_returns_reason_already_awake() -> void:
	var pd := PlayerData.new(cm)
	var hero := HeroInstance.new(1, 1, 1)
	hero.awake = true
	var r: Dictionary = AwakeHelper.awake_hero(pd, hero)
	assert_eq(String(r.get("reason", "")), "already_awake", "失败原因=already_awake")


# ── ① 体力药判定（EquipboardPanel._judge_prop_type/_is_tonic_pill）──
# View 静态判定走实例成员（cm/_cell_data），headless 直接构造实例填成员断言（不入树）。

func test_tonic_pills_judged_as_consume() -> void:
	var panel := EquipboardPanel.new("equipboard", {})
	panel.cm = cm
	for item_id in [336, 217, 289]:   # 章鱼丸子/孜然羊肉串/奥尔良烤翅
		panel._update_cell_fields({"id": item_id, "amount": 1, "type": 1})
		assert_eq(panel._judge_prop_type(), "consume", "id=%d 体力药 → consume（右按钮=使用）" % item_id)
		assert_true(panel._is_tonic_pill(), "id=%d 判定为体力药" % item_id)
	panel.free()


func test_experience_pill_still_judged_as_consume() -> void:
	var panel := EquipboardPanel.new("equipboard", {})
	panel.cm = cm
	panel._update_cell_fields({"id": 169, "amount": 1, "type": 1})   # EQUIP.EXPERIENCE_POTION
	assert_eq(panel._judge_prop_type(), "consume", "经验药仍为 consume")
	assert_false(panel._is_tonic_pill(), "经验药非体力药（走 EatexpPanel 选英雄）")
	panel.free()


# ── ① 体力药使用（VitalityManager.use_tonic_pill，2026-10-06 二轮边界修）──
# 用户实测：GM 拉满体力 9999 后吃章鱼丸子 Toast"获得体力:0"且药被白扣——
# 二轮修：满体力不消耗物品（reason=full），逻辑下沉 VitalityManager 可单测。

func test_tonic_pill_blocked_at_hard_cap() -> void:
	var pd := PlayerData.new(cm)
	pd.add_item(336, 5)
	pd.vitality = 9999   # GM 拉满（攒体硬上限）
	var r: Dictionary = VitalityManager.use_tonic_pill(pd, 336, cm)
	assert_false(bool(r["ok"]), "满体力拒绝使用")
	assert_eq(String(r["reason"]), "full", "原因=full")
	assert_eq(int(pd.items.get(336, 0)), 5, "药未被白扣（持有不变）")
	assert_eq(pd.vitality, 9999, "体力不变")


func test_tonic_pill_grants_partial_at_near_cap() -> void:
	var pd := PlayerData.new(cm)
	pd.add_item(289, 1)   # 奥尔良烤翅 +30
	pd.vitality = 990     # 差 9 到顶（999 统一上限口径）
	var r: Dictionary = VitalityManager.use_tonic_pill(pd, 289, cm)
	assert_true(bool(r["ok"]), "未满可使用")
	assert_eq(int(r["gained"]), 9, "顶格截断实际获得 9")
	assert_eq(pd.vitality, 999, "体力顶格 999")
	assert_eq(int(pd.items.get(289, 0)), 0, "药已扣")


func test_tonic_pill_normal_use_and_no_item() -> void:
	var pd := PlayerData.new(cm)
	pd.add_item(217, 2)   # 孜然羊肉串 +12
	pd.vitality = 100
	var r: Dictionary = VitalityManager.use_tonic_pill(pd, 217, cm)
	assert_true(bool(r["ok"]), "正常使用成功")
	assert_eq(int(r["gained"]), 12, "获得 12 体力")
	assert_eq(int(pd.items.get(217, 0)), 1, "扣 1 个")
	var r2: Dictionary = VitalityManager.use_tonic_pill(pd, 99999, cm)
	assert_eq(String(r2["reason"]), "no_item", "未持有拒绝")


# ── ⑦ 高速空场：4x 入场走路闭环到位（开环+一次性阈值越冲回归守卫）──
# 旧缺陷：99% 单位 Walk Speed=120 ×1.75=210/s、入场距离 300 → 4x 每帧步长 14 > 阈值 5，
# 4x 稳定 60Hz 时残差 6 落入 miss 窗口 → 全员越过站位永不回头 → engine 永久冻结=空场。
# 修复：闭环步长钳制（距目标 ≤ max(步长,阈值) 即吸附）+ 超时兜底 + delta 钳制。

func _assemble_stage1() -> Dictionary:
	var lib := SkillLibrary.new(cm)
	var player := PlayerData.new(cm)
	player.vitality = 100
	for tid: int in [1, 2, 3, 4, 5]:
		player.hero_manager.add_hero(tid)
	var mgr := StageManager.new(cm)
	mgr.skill_lib = lib
	return mgr.assemble_stage_battle(1, player, [1, 2, 3, 4, 5], BattleRng.new(12345))


func test_enter_walk_completes_at_3x_speed() -> void:
	var asm := _assemble_stage1()
	assert_true(bool(asm.get("ok", false)), "装配应成功")
	var scene := BattleScene.new()
	add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED   # 手动帧驱动
	scene.setup(asm["engine"], cm, asm["battle_info"])
	scene.set_speed_state(3)   # 3x（最高速档，2026-10-06 用户拍板 4 档裁 3）
	scene._start_enter_walk()
	assert_true(scene._entering, "入场态生效")
	# 60fps 帧推进，到位即停（理论 300/(210×4)≈0.36s≈22 帧；不推进战斗避免结算切场景）
	var frames: int = 0
	while scene._entering and frames < 300:
		scene._process(1.0 / 60.0)
		frames += 1
	assert_false(scene._entering, "3x 下全员到位解冻（不冻结=不空场）")
	assert_lt(frames, 60, "远小于 1s 到位（闭环不越冲）")
	assert_false(scene.is_paused, "engine 恢复运行")
	# 全员已退出离线走路态、接回 engine interp（空场症状=永远离线走出屏外）
	for actor in scene.actor_list:
		if actor is BattleActor:
			assert_false((actor as BattleActor)._offline, "actor 已接 engine interp（不再离线走路上）")
	scene.queue_free()


func test_enter_walk_timeout_guard_force_arrives() -> void:
	# 超时兜底：人为把一个 actor 的到位信号断掉（模拟 enter_walk_finished 丢失），
	# TimeoutGuard 到时强制吸附解冻——防任何未来位移 bug 再致永久冻结。
	var asm := _assemble_stage1()
	var scene := BattleScene.new()
	add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.setup(asm["engine"], cm, asm["battle_info"])
	scene.set_speed_state(1)
	scene._start_enter_walk()
	# 篡改：断开全部到位信号（模拟丢失）
	for actor in scene.actor_list:
		if actor is BattleActor:
			for c in (actor as BattleActor).enter_walk_finished.get_connections():
				(actor as BattleActor).enter_walk_finished.disconnect(c.callable)
	# 帧推进过超时窗（1x 理论 ~1.43s × margin2 ≈ 2.9s → 推 4s 帧但守卫走真实 SceneTreeTimer：
	# process_mode DISABLED 只停 scene，GUT 测试树正常跑 → 改为直接等价触发：手动调守卫逻辑）
	await get_tree().create_timer(3.2).timeout
	assert_false(scene._entering, "超时兜底强制解冻（enter 信号丢失不再永久冻结）")
	scene.queue_free()
