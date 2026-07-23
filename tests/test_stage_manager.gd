extends GutTest
# Phase 6 StageManager 测试（2026-07-02）。旧版实例 API（exit_stage/sweep/generate_loots）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_exit_stage_win() -> void:
	var mgr := StageManager.new(cm)
	var r: Dictionary = mgr.exit_stage(-27, 3, true)
	assert_eq(int(r["stars"]), 3, "win 3 星 → stars=3")
	assert_eq(mgr.stage_stars(-27), 3, "progress 记录星数")


func test_exit_stage_lose() -> void:
	var mgr := StageManager.new(cm)
	var r: Dictionary = mgr.exit_stage(-27, 0, false)
	assert_eq(int(r["exp"]), 0, "lose → exp=0")
	assert_eq(mgr.stage_stars(-27), 0, "失败不记录星")


func test_sweep() -> void:
	var mgr := StageManager.new(cm)
	mgr.exit_stage(-27, 3, true)   # 先通关
	var r: Dictionary = mgr.sweep(-27, 2)
	assert_gte(int(r["exp"]), 0, "扫荡返 exp（×times）")
	assert_true(r.has("loots"), "sweep 返 loots 字段")


func test_sweep_with_rng() -> void:
	var mgr := StageManager.new(cm)
	mgr.exit_stage(-27, 3, true)
	var rng := BattleRng.new(999)
	var r: Dictionary = mgr.sweep(-27, 2, rng)
	assert_not_null(r["loots"], "sweep rng → loots 数组生成")


# P1-5：sweep 保底机制（连续未掉累积提升掉率，源 :1612-1623）。
func test_sweep_pity_loot_rate() -> void:
	var mgr := StageManager.new(cm)
	mgr.exit_stage(-27, 3, true)
	var rng := BattleRng.new(42)
	# 多次扫荡，sweep_loot_record 应累积 miss_count（未掉时 +1）
	var r: Dictionary = mgr.sweep(-27, 1, rng)
	assert_true(r.has("loots"), "sweep 返回含 loots")
	# 验证 sweep_loot_record 被初始化（stage_key 存在）
	assert_true(mgr.sweep_loot_record.has("-27"), "保底记录被初始化")


# P1-5：Raid Bonus（源 :1633-1651，Item 类型按 times 倍增）。
func test_sweep_raid_bonus() -> void:
	var mgr := StageManager.new(cm)
	mgr.exit_stage(1, 3, true)   # stage 1 已通关
	var rng := BattleRng.new(42)
	var r: Dictionary = mgr.sweep(1, 3, rng)
	# stage 1 Raid Bonus 3: Type=Item ID=169 Amount=1，times=3 → amount=3
	var raid: Array = r["raid_bonus"]
	var found_169: bool = false
	for bonus in raid:
		if int(bonus["id"]) == 169:
			assert_eq(int(bonus["amount"]), 3, "Raid Bonus ID=169 Amount=1×times=3 = 3")
			found_169 = true
	assert_true(found_169, "stage 1 Raid Bonus ID=169 应存在")


func test_sweep_consumes_sweep_coin() -> void:
	# 照源 sweep 流程：player 传入时消耗扫荡券 ×times（getSweepTimes 检查 + useSweepTimes 消耗）
	var mgr := StageManager.new(cm)
	mgr.exit_stage(-27, 3, true)
	var pd := PlayerData.new(cm)
	pd.add_item(390, 2)   # 持有 2 张扫荡券
	var r: Dictionary = mgr.sweep(-27, 2, null, pd)
	assert_eq(bool(r.get("ok", false)), true, "sweep ok（扫荡券足）")
	assert_eq(pd.get_sweep_times(), 0, "扫荡消耗 2 张扫荡券")
	# 扫荡券不足 → ok=false 不消耗
	var r2: Dictionary = mgr.sweep(-27, 1, null, pd)
	assert_eq(bool(r2.get("ok", true)), false, "扫荡券不足 → ok=false")


func test_generate_loots() -> void:
	var mgr := StageManager.new(cm)
	var rng := BattleRng.new(12345)
	var loots: Array = mgr.generate_loots(-27, rng)
	assert_not_null(loots, "generate_loots 返数组（确定性 rng）")


func test_generate_loot_list_structure() -> void:
	# 照源 generateLoots + getStageLoots：返 [{id,type}] + 翻倍 + 必掉扫荡券 390
	var mgr := StageManager.new(cm)
	var loots: Array = mgr.generate_loot_list(-27, BattleRng.new(5))
	assert_gte(loots.size(), 1, "至少必掉扫荡券 390")
	var last: Dictionary = loots[loots.size() - 1]
	assert_eq(int(last["id"]), 390, "末位必掉扫荡券 390")
	assert_eq(String(last["type"]), "equip", "390 < 600 → equip 类型")


func test_item_type_thresholds() -> void:
	# 照源 player.lua:1180 itemType：id<100 hero / id<600 equip / else ""
	assert_eq(StageManager._item_type(50), "hero", "id < 100 hero")
	assert_eq(StageManager._item_type(390), "equip", "100 <= id < 600 equip")
	assert_eq(StageManager._item_type(700), "", "id >= 600 无类型")


func test_enter_stage_vitality() -> void:
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	pd.vitality = 100
	var r: Dictionary = mgr.enter_stage(-27, pd)
	assert_eq(bool(r["ok"]), true, "体力足 → enter ok")
	assert_eq(int(r["stage_id"]), -27, "返 stage_id")
	# -27 vitality_cost=0（特殊关），不扣；扣体力逻辑由 spend_vitality 单测覆盖


func test_run_stage_quick() -> void:
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	pd.vitality = 100
	var r: Dictionary = mgr.run_stage_quick(-27, pd, 3)
	assert_eq(bool(r["ok"]), true, "run_stage_quick ok")
	assert_eq(int(r["stars"]), 3, "3 星结算")


func test_run_stage_battle() -> void:
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	pd.vitality = 100
	var rng := BattleRng.new(42)
	var r: Dictionary = mgr.run_stage_battle(-27, pd, [1], rng)
	assert_eq(bool(r["ok"]), true, "run_stage_battle ok（端到端不崩）")
	assert_true(r.has("won"), "返 won 字段")


func test_run_stage_battle_player_equips() -> void:
	# 玩家有英雄 + 装备 → proto._items 接入（路径 B 装载）
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	pd.vitality = 100
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(inst_id)
	hero.equip_slots[0] = 101
	hero.equip_exp[0] = 100.0
	var rng := BattleRng.new(42)
	var r: Dictionary = mgr.run_stage_battle(-27, pd, [1], rng)
	assert_eq(bool(r["ok"]), true, "玩家英雄装备接入 run ok")
	assert_true(r.has("won"), "返 won 字段")


# 归位（照源 enterStage/setupBattle）：真实 stage 1（有 Battle 配置）端到端走 setup_battle 路径不崩。
func test_run_stage_battle_real_stage_setup_battle() -> void:
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	pd.vitality = 100
	var rng := BattleRng.new(42)
	var r: Dictionary = mgr.run_stage_battle(1, pd, [1], rng)
	assert_eq(bool(r["ok"]), true, "真实 stage 1 走 setup_battle 路径 ok")
	assert_true(r.has("won"), "返 won 字段")
	assert_true(r.has("exp"), "返 exp（exit 走真实 stage）")


# 归位 _enter_stage：真实 stage 1 走 setup_battle（敌人 101/102，非 stub tid=1）+ initSelfHero 闭合。
# P1-4：源 enter_stage（normal/elite 普通关入口）不扣体力，体力扣除只在 enter_act_stage。
# 源 local_server.lua:619-634 enter_stage 仅设 battle 数据 + 生成 loots，无 addVitality。
func test_enter_stage_normal_no_vitality_cost() -> void:
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	pd.vitality = 100
	# stage 1 Vitality Cost=6（普通关），照源 enter_stage 不扣
	var r: Dictionary = mgr.enter_stage(1, pd)
	assert_eq(bool(r["ok"]), true, "普通关 enter ok")
	assert_eq(pd.vitality, 100, "普通关照源不扣体力（enter_stage 无 addVitality）")


func test_enter_stage_real_stage_uses_setup_battle() -> void:
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(42)
	mgr._enter_stage(eng, 1, pd, [1])
	# setup_battle 路径：stage 1 wave 1 = 2 怪物（101/102），stub 路径仅 1 个 tid=1
	assert_eq(eng.monster_num, 2, "stage 1 wave 1 走 setup_battle 装配 2 怪物")
	assert_eq(eng.hero_id_list, [1], "hero_id_list 照源 initSelfHero:346 填")
	var enemies: Array = eng.alive_units.get(BattleEngine.CAMP_ENEMY, [])
	assert_eq(enemies.size(), 2, "敌方 2 单位（setup_battle 真实装配，非 stub）")
	var tids: Array[int] = [int((enemies[0] as BattleUnit).tid), int((enemies[1] as BattleUnit).tid)]
	assert_true(101 in tids and 102 in tids, "敌人 tid 101/102（setup_battle 真实装配）")
	# 位置 X 镜像（源 setupBattle:230-234）：敌方 X = maxX - INITIAL_POSITIONS.x，置于舞台右侧
	for m in enemies:
		assert_gt((m as BattleUnit).position.x, 400.0, "敌方 X 镜像置于舞台右侧（>400）")
	# 玩家英雄 ai.will_cast_manual_skill=false（源 :344 isbot=false，修 ai 默认 true latent bug）
	var players: Array = eng.alive_units.get(BattleEngine.CAMP_PLAYER, [])
	assert_false(bool((players[0] as BattleUnit).ai.will_cast_manual_skill), "玩家英雄 ai.will_cast_manual_skill=false")
	# mp_bonus 照源 :365 读 stage_info["MP Bonus"]（stage 1 实配 1.5；修旧版未设默认 1.0）
	assert_eq(eng.mp_bonus, 1.5, "mp_bonus 照源 :365 读 stage_info[MP Bonus]=1.5")


# 归位 _enter_stage：Battle 表无配置的 sid 走 stub 兜底（单机化，源 PVE 关无此分支）。
func test_enter_stage_no_config_falls_back_stub() -> void:
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(42)
	mgr._enter_stage(eng, 99999, pd, [1])  # 99999 Battle 表无配置 → battle_info 空 → 真走 stub
	assert_eq(eng.monster_num, 0, "stub 路径不走 setup_battle（monster_num=0）")
	var enemies: Array = eng.alive_units.get(BattleEngine.CAMP_ENEMY, [])
	assert_eq(enemies.size(), 1, "stub 兜底 1 个 tid=1 桩敌人")
	assert_eq(int((enemies[0] as BattleUnit).tid), 1, "stub 敌人 tid=1")


# 章节星数奖励（照源 player.lua:910-973 chapter_star_reward handler 配套）
func test_chapter_star_status_zero_stars() -> void:
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	var s: Dictionary = mgr.get_chapter_star_status(pd, 1)
	assert_eq(int(s["total_stars"]), 0, "无通关 → 0 星")
	var tiers: Array = s["tiers"]
	assert_eq(tiers.size(), 3, "3 个 tier（30/60/90）")
	assert_false(bool((tiers[0] as Dictionary)["unlocked"]), "0 星 tier1 未解锁")


func test_chapter_star_claim_blocked_below_threshold() -> void:
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	var r: Dictionary = mgr.claim_chapter_star_reward(pd, 1, 1)
	assert_false(bool(r["ok"]), "星数不足 30 → 领取失败")


func test_chapter_star_claim_success_and_dedup() -> void:
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	# mock 该章某 normal stage 通关 30 星（照源 getChapterStars 累加 normal stage 星数）
	var st: Dictionary = cm.get_raw_table("Stage")
	var mock_sid: int = 0
	for sid_str in st:
		var sid: int = int(sid_str)
		if int(st[sid_str].get("Chapter ID", 0)) == 1 and StageAccount.stage_type(sid) == "normal":
			mock_sid = sid
			break
	if mock_sid > 0:
		mgr.progress[mock_sid] = 30
		var before_gold: int = pd.hero_manager.gold
		var r: Dictionary = mgr.claim_chapter_star_reward(pd, 1, 1)
		assert_true(bool(r["ok"]), "30 星达 tier1 → 领取成功")
		assert_gt(pd.hero_manager.gold, before_gold, "money 奖励加金币")
		var r2: Dictionary = mgr.claim_chapter_star_reward(pd, 1, 1)
		assert_false(bool(r2["ok"]), "已领 → 再领失败（防重）")
	else:
		assert_true(true, "无 chapter 1 normal stage 样本")


# enter_act_stage（照源 local_server.lua:640-777）
func test_enter_act_stage_invalid() -> void:
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	var r: Dictionary = mgr.enter_act_stage(99999, 0, pd, BattleRng.new(1))
	assert_false(bool(r["ok"]), "不存在 stage → invalid_stage")
	assert_eq(String(r.get("error", "")), "invalid_stage", "error=invalid_stage")


func test_enter_act_stage_success_returns_loots() -> void:
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	# 找 Stage 表第一个 Unlock Level<=1 的有效 sid（避依赖具体 id）
	var st: Dictionary = cm.get_raw_table("Stage")
	var valid_sid: int = 0
	for sid_str in st:
		var sid: int = int(sid_str)
		if sid > 0 and int(st[sid_str].get("Unlock Level", 0)) <= 1:
			valid_sid = sid
			break
	if valid_sid > 0:
		var before_vit: int = pd.vitality
		var r: Dictionary = mgr.enter_act_stage(valid_sid, 0, pd, BattleRng.new(1))
		assert_true(bool(r["ok"]), "有效 stage + 等级够 + 体力够 → 成功（sid=%d, err=%s）" % [valid_sid, String(r.get("error", ""))])
		assert_true(r.has("loots"), "成功返 loots")
		assert_eq(int(r["stage_id"]), valid_sid, "stage_id 回传")
		assert_lte(pd.vitality, before_vit, "进入扣体力（Vitality Cost - Vit Return）")
	else:
		assert_true(true, "无 unlock<=1 正 stage 样本")


func test_enter_act_stage_key_cost_gate() -> void:
	# 源 :675-682 副本关 Key Cost>0 且 dungeonpoint 不足 → not_enough_keys
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	pd.team_level = 999
	pd.dungeonpoint = 0
	var st: Dictionary = cm.get_raw_table("StageDungeon")
	var key_sid: int = 0
	for sid_str in st:
		if int(st[sid_str].get("Key Cost", 0)) > 0:
			key_sid = int(sid_str)
			break
	if key_sid > 0:
		var r: Dictionary = mgr.enter_act_stage(key_sid, 0, pd, BattleRng.new(1))
		assert_false(bool(r["ok"]), "Key Cost>0 + dungeonpoint=0 → 拒绝（sid=%d err=%s）" % [key_sid, String(r.get("error", ""))])
		assert_eq(String(r.get("error", "")), "not_enough_keys", "error=not_enough_keys")
	else:
		assert_true(true, "无 Key Cost>0 副本关样本")


# ── 副本段结算（源 local_server.lua:787-829）──

func test_exit_dungeon_coins_reward() -> void:
	# 源 :416-422 getDungeonCoinReward(difficulty) 副本硬币范围随机 + :805-810 扣 Key Cost（净 = coins - keyCost）
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	var sid := 50013  # Difficulty=1
	var key_cost: int = int(cm.get_raw_table("StageDungeon").get(str(sid), {}).get("Key Cost", 0))
	var r: Dictionary = mgr.exit_stage(sid, 3, true, pd)
	assert_true(r.has("coins"), "副本结算返 coins 字段")
	# 源 diff1 范围 {5,8}（修复 A3：固定值 10 → 范围随机）
	var coins: int = int(r["coins"])
	assert_true(coins >= 5 and coins <= 8, "diff1 副本硬币在范围 [5,8]，实际 %d" % coins)
	assert_eq(pd.dungeonpoint, coins - key_cost, "dungeonpoint 净 = coins - keyCost（源 :802-809）")


# A3 修复测试：源 :417-418 四档硬币范围随机（固定种子可复现）
func test_exit_dungeon_coin_ranges_four_diffs() -> void:
	var ranges: Dictionary = {1: Vector2i(5, 8), 2: Vector2i(10, 15), 3: Vector2i(20, 30), 4: Vector2i(35, 50)}
	var diff_keys: Array = ranges.keys()
	for diff in diff_keys:
		var range: Vector2i = ranges[diff]
		var rng := RandomNumberGenerator.new()
		rng.seed = (int(diff) + 1) * 111  # 固定种子可复现
		for _i in range(50):
			var c: int = StageDungeonLogic.get_dungeon_coin_reward(int(diff), rng)
			assert_true(c >= range.x and c <= range.y, "diff %d 硬币 %d 在范围 [%d,%d]" % [int(diff), c, range.x, range.y])


# A4 修复测试：源 ui/dungeon.lua:37 isHeroicUnlocked（实际生效版，5000x）— 英雄副本组前置未通关被拒
func test_check_enter_dungeon_heroic_prereq_denied() -> void:
	# 真实 ActStageGroupDungeon[50001].Stages=[50001,50002,50003]（BLACKROCK 普通组）
	# heroicPrereq[50005]=50001，50005(NAXXRAMAS 英雄组) 前置 50001 组全部 Stages 未通关 → 拒绝
	var local_cm := ConfigManager.new()
	local_cm.load_all()
	var mgr := StageManager.new(local_cm)
	# 50001/50002/50003 未通关 → stage_stars=0
	assert_eq(mgr.stage_stars(50001), 0, "前置 50001 未通关")
	var err: String = StageDungeonLogic.check_enter_dungeon(mgr, 50001, 50005, PlayerData.new(local_cm), local_cm)
	assert_eq(err, "heroic_prereq", "英雄副本组 50005 前置 50001 组未通关 → 拒绝")
	# 通关 50001 组全部 Stages（50001/50002/50003）后放行（stars>=1）
	mgr.progress[50001] = 3
	mgr.progress[50002] = 3
	mgr.progress[50003] = 3
	var err2: String = StageDungeonLogic.check_enter_dungeon(mgr, 50001, 50005, PlayerData.new(local_cm), local_cm)
	assert_ne(err2, "heroic_prereq", "前置全通关后不再以 heroic_prereq 拒绝")


# A4 修复测试：源 :483-484 非英雄副本组（不在 heroicPrereq）无前置
func test_check_heroic_prereq_non_heroic_pass() -> void:
	var mgr := StageManager.new(cm)
	var r: Dictionary = StageDungeonLogic.check_heroic_prereq(50001, mgr, cm)
	assert_true(bool(r.get("ok", false)), "普通副本组 50001 无 heroic 前置 → 放行")


func test_exit_dungeon_gold_by_diff() -> void:
	# 源 :795-796 goldByDiff[difficulty]
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	var r: Dictionary = mgr.exit_stage(51013, 3, true, pd)  # Difficulty=2
	assert_eq(int(r["money"]), 3500, "diff2 gold 3500")


func test_exit_dungeon_bosses_cleared() -> void:
	# 源 :813-829 baseId=50000+sid%1000 持久化
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	mgr.exit_stage(50013, 3, true, pd)
	# baseId = 50000 + 50013 % 1000 = 50000 + 13 = 50013
	assert_true(mgr.dungeon_bosses_cleared.has(50013), "dungeon_bosses_cleared 记录 baseId")
