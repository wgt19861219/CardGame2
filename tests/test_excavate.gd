extends GutTest
# ExcavateData（Data 层表查询）+ ExcavateManager（Logic 层 search/produce/drop）。
# 照源 ui/excavate/excavate.lua getExcavateSearchCost:18 + getMaxSearchTime:596 + getProduced:462。
# 单机化：源联机 search → 本地 roll_search_type_id + 扣金 + 加 monster 矿点。


var cm: ConfigManager


func before_each() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# ---- ExcavateData ----

# search_cost times=0 取 GradientPrice[1]["Excavate Search"]=100（照 getExcavateSearchCost:30）。
func test_search_cost_first_is_100() -> void:
	assert_eq(ExcavateData.get_search_cost(cm, 0), 100, "首次搜索消耗 100 金币")


# search_cost times=37 取 gt[38]=100000（连续 >0 末值，照 getMaxCost 递归）。
func test_search_cost_at_last_tier() -> void:
	assert_eq(ExcavateData.get_search_cost(cm, 37), 100000, "第 38 档消耗 100000")


# search_cost 超表（times+1 > 38 → 0）用 maxCost=100000（照 :31 cost<=0 and maxCost）。
func test_search_cost_overflow_uses_max() -> void:
	assert_eq(ExcavateData.get_search_cost(cm, 200), 100000, "超表用 maxCost")


# max_search_time=38（连续 >0 的最大 index，照 getMaxSearchTime:596）。
func test_max_search_time_is_38() -> void:
	assert_eq(ExcavateData.get_max_search_time(cm), 38, "每日最大搜索 38 次")


# roll 返有效 type（1-9，照 ExcavateTreasure Treasure ID）。
func test_roll_returns_valid_type() -> void:
	var rng := BattleRng.new(12345)
	var tid: int = ExcavateData.roll_search_type_id(cm, rng, 99)
	assert_true(tid >= 1 and tid <= 9, "roll 返 1-9 有效 type_id")


# roll 低等级过滤（level=1 只 type4 req=1，照 Level Requirement 单机化过滤）。
func test_roll_low_level_only_type4() -> void:
	var rng := BattleRng.new(1)
	var tid: int = ExcavateData.roll_search_type_id(cm, rng, 1)
	assert_eq(tid, 4, "level 1 只能搜到 type4（Level Requirement=1）")


# picture_res 降级 name 图（源 Picture 全缺，diamond+mp1 → name_diamond_1）。
func test_picture_res_uses_name_fallback() -> void:
	assert_eq(ExcavateData.picture_res(cm, 1), "res://assets/ui/alpha/HVGA/excavate/excavate_name_diamond_1.png")


# ---- ExcavateManager ----

# search 扣金 + 加 monster 矿点 + search_times++（照 doSearchExcavateReply:306-314）。
func test_search_adds_monster_node() -> void:
	var mgr := ExcavateManager.new(cm)
	var player := _MockPlayer.new(1000000)
	var rng := BattleRng.new(7)
	var gold_before: int = player.hero_manager.gold
	var r: Dictionary = mgr.search(player, rng, 1000)
	assert_true(bool(r["ok"]), "搜索成功")
	assert_eq(String(r["owner"]), "monster", "搜到 monster 守的矿点")
	assert_eq(mgr.get_data_list().size(), 1, "矿点列表 +1")
	assert_eq(mgr.search_times, 1, "search_times +1")
	assert_eq(player.hero_manager.gold, gold_before - 100, "扣 100 金币")
	var d: Dictionary = mgr.get_searched()
	assert_eq(String(d["_owner"]), "monster", "当前搜索点 owner=monster")


# search 后 monster 矿点敌人 = 玩家英雄镜像（照源 generateWildTeam:3558-3625，player.heroes shuffle 抽5）。
func test_search_enemy_is_player_mirror() -> void:
	var mgr := ExcavateManager.new(cm)
	var player := _MockPlayer.new(1000000)
	player.add_hero(101, 10, 1, 1)
	player.add_hero(102, 20, 2, 1)
	player.add_hero(103, 30, 3, 2)
	var r: Dictionary = mgr.search(player, BattleRng.new(7), 1000)
	assert_true(bool(r["ok"]), "搜索成功")
	var enemies: Array = mgr.get_enemy_heroes(mgr.search_id)
	assert_eq(enemies.size(), 3, "敌人 = 玩家英雄数（3<5 全上）")
	for e in enemies:
		var tid: int = int(e["base"].get("_tid"))
		assert_true(tid == 101 or tid == 102 or tid == 103, "敌人 tid 来自玩家英雄镜像")


# search 野怪镜像确定性（同 seed+player → 同 enemy tid 集合）+ 7 英雄抽 5 上限。
func test_search_enemy_deterministic_and_max_five() -> void:
	var tids_a: Array = _search_enemy_tids(7)
	var tids_b: Array = _search_enemy_tids(7)
	assert_eq(tids_a, tids_b, "同 seed 同 player → 同 enemy tid 集合")
	assert_eq(tids_a.size(), 5, "7 英雄抽 5（WILD_DEFEND_TEAM_SIZE）")


# 辅助：7 英雄 + seed 搜索 → 排序后 enemy tid 列表。
func _search_enemy_tids(seed: int) -> Array:
	var mgr := ExcavateManager.new(cm)
	var player := _MockPlayer.new(1000000)
	for tid in range(1, 8):
		player.add_hero(tid)
	mgr.search(player, BattleRng.new(seed), 1000)
	var tids: Array = []
	for e in mgr.get_enemy_heroes(mgr.search_id):
		tids.append(int(e["base"].get("_tid")))
	tids.sort()
	return tids


# search 达上限被拒（照 checkSearchTimeMax:611，times>=38 → reason max_time）。
func test_search_max_time_blocked() -> void:
	var mgr := ExcavateManager.new(cm)
	mgr.search_times = 38
	var player := _MockPlayer.new(1000000)
	var check: Dictionary = mgr.can_search(player, 1000)
	assert_false(bool(check["ok"]))
	assert_eq(String(check["reason"]), "max_time")


# 金币不足被拒（照 :299 cost>gold → reason lack_money）。
func test_search_lack_money_blocked() -> void:
	var mgr := ExcavateManager.new(cm)
	var player := _MockPlayer.new(50)   # < 100
	var r: Dictionary = mgr.search(player, BattleRng.new(1), 1000)
	assert_false(bool(r["ok"]))
	assert_eq(String(r["reason"]), "lack_money")
	assert_eq(mgr.get_data_list().size(), 0, "失败不加矿点")
	assert_eq(player.hero_manager.gold, 50, "失败不扣金")


# 重搜清旧 search_id（照 removeSearchData:226，search_id 矿点被替换不累积）。
func test_search_replaces_old_searched() -> void:
	var mgr := ExcavateManager.new(cm)
	var player := _MockPlayer.new(1000000)
	mgr.search(player, BattleRng.new(1), 1000)
	mgr.search(player, BattleRng.new(2), 2000)
	assert_eq(mgr.get_data_list().size(), 1, "重搜后仍 1 个搜索点（旧 search_id 被清）")


# monster 矿点不产出（照 getProduced owner!=mine 返 0）。
func test_produce_zero_when_monster() -> void:
	var mgr := ExcavateManager.new(cm)
	var player := _MockPlayer.new(1000000)
	mgr.search(player, BattleRng.new(3), 1000)
	var sid: int = mgr.search_id
	assert_eq(mgr.produce_amount(sid, 999999), 0, "monster 矿点不产出")


# mine 矿点时间驱动产出（照 getProduced:476 speed×elapsed_min + res_got）。
func test_produce_after_occupy() -> void:
	var mgr := ExcavateManager.new(cm)
	# 直接注入 mine 矿点（固定 speed=10/min，避 roll 随机）
	mgr.excavate_data.append({
		"_id": 1, "_type_id": 4, "_owner": "mine", "_state": "occupy",
		"_found_ts": 1, "_produce_speed": 10.0, "_storage": 1000, "_res_got": 0.0, "_wild_id": 0,
	})
	# elapsed=600s=10min → 10×10=100（found_ts 非 0，照源 calcProduced:3535 守卫）
	assert_eq(mgr.produce_amount(1, 601), 100, "10/min × 10min = 100")


# monster 矿点 produced_total 非零产出（照 getProduced:462 无 owner 限制公开版，
# map 产量行"可以掠夺"fill 依赖；_found_ts=1 非 0 + _res_got=5 → 10×10+5=105）。
func test_produced_total_monster_nonzero() -> void:
	var mgr := ExcavateManager.new(cm)
	mgr.excavate_data.append({
		"_id": 2, "_type_id": 4, "_owner": "monster", "_state": "searched",
		"_found_ts": 1, "_produce_speed": 10.0, "_storage": 500, "_res_got": 5.0, "_wild_id": 0,
	})
	assert_eq(mgr.produced_total(2, 601), 105, "monster 也计产：10/min × 10min + res_got 5 = 105")


# produce_amount 与 produced_total 的 owner 分叉语义（前者锁 OWNER_MINE 照
# getProduced:462-473 mine 可见口径，后者不限 owner 照 :476 全量口径）。
func test_produced_total_owner_semantics() -> void:
	var mgr := ExcavateManager.new(cm)
	mgr.excavate_data.append({
		"_id": 1, "_type_id": 4, "_owner": "mine", "_state": "occupy",
		"_found_ts": 1, "_produce_speed": 10.0, "_storage": 1000, "_res_got": 0.0, "_wild_id": 0,
	})
	mgr.excavate_data.append({
		"_id": 2, "_type_id": 4, "_owner": "monster", "_state": "searched",
		"_found_ts": 1, "_produce_speed": 10.0, "_storage": 1000, "_res_got": 0.0, "_wild_id": 0,
	})
	# mine：两口径一致（同一矿点同量）
	assert_eq(mgr.produce_amount(1, 601), mgr.produced_total(1, 601), "mine：produce_amount == produced_total")
	assert_eq(mgr.produced_total(1, 601), 100, "mine：两口径均 100")
	# monster：produce_amount 恒 0（owner 锁），produced_total 照计（map 掠夺 fill 用）
	assert_eq(mgr.produce_amount(2, 601), 0, "monster：produce_amount 锁 mine 返 0")
	assert_eq(mgr.produced_total(2, 601), 100, "monster：produuted_total 不限 owner 照计 100")
	# 不存在的矿点两口径均 0
	assert_eq(mgr.produced_total(99, 601), 0, "缺矿点返 0")
	assert_eq(mgr.produce_amount(99, 601), 0, "缺矿点返 0")


# storage_remaining = storage - produced（照 getStorage:495）。
func test_storage_remaining() -> void:
	var mgr := ExcavateManager.new(cm)
	mgr.excavate_data.append({
		"_id": 1, "_type_id": 4, "_owner": "mine", "_state": "occupy",
		"_found_ts": 1, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0, "_wild_id": 0,
	})
	# produced=100（10min），storage=500 → remain=400
	assert_eq(mgr.storage_remaining(1, 601), 400)


# drop 结算产出 + 移除（照 doGiveup:681 + removeExcavate:205）。
func test_drop_removes_and_settles() -> void:
	var mgr := ExcavateManager.new(cm)
	mgr.excavate_data.append({
		"_id": 1, "_type_id": 4, "_owner": "mine", "_state": "occupy",
		"_found_ts": 1, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0, "_wild_id": 0,
	})
	var amount: int = mgr.drop(1, 601)
	assert_eq(amount, 100, "drop 返结算产出")
	assert_eq(mgr.get_data_list().size(), 0, "drop 后矿点移除")


# to_dict/from_dict 往返（存档持久化）。
func test_to_from_dict_roundtrip() -> void:
	var mgr := ExcavateManager.new(cm)
	var player := _MockPlayer.new(1000000)
	mgr.search(player, BattleRng.new(9), 1000)
	var saved: Dictionary = mgr.to_dict()
	var loaded := ExcavateManager.from_dict(saved, cm)
	assert_eq(loaded.get_data_list().size(), 1, "读档后矿点数一致")
	assert_eq(loaded.search_times, 1, "读档后 search_times 一致")
	assert_eq(loaded.search_id, mgr.search_id, "读档后 search_id 一致")


# hero_level_to_rank 照源 heroLevel2Rank（tools.lua:1021-1026）：ceil(max(1,level)/10) min 10。
# level 1-10→1 / 11-20→2 / 91-100→10。旧版整数除法（向下）+ max 5 偏离源，修。
func test_hero_level_to_rank() -> void:
	assert_eq(ExcavateData.hero_level_to_rank(1), 1, "level 1 → rank 1")
	assert_eq(ExcavateData.hero_level_to_rank(10), 1, "level 10 → rank 1（ceil(10/10)=1）")
	assert_eq(ExcavateData.hero_level_to_rank(11), 2, "level 11 → rank 2（ceil(11/10)=2，旧版整数除法误 1）")
	assert_eq(ExcavateData.hero_level_to_rank(20), 2, "level 20 → rank 2")
	assert_eq(ExcavateData.hero_level_to_rank(95), 10, "level 95 → rank 10（min(.,10)）")
	assert_eq(ExcavateData.hero_level_to_rank(0), 1, "level 0 → rank 1（max(1,0)）")


# get_stage_enemy_data 装配敌人（照 getStageEnemyData:362，Stage/Battle 表查 Monster ID/Level/Stars）。
func test_get_stage_enemy_data() -> void:
	var heroes: Array = ExcavateData.get_stage_enemy_data(cm, 30001)
	if heroes.is_empty():
		return   # 表无 30001 数据则跳过结构检查
	var h0: Dictionary = heroes[0]
	assert_true(bool(h0.has("base")), "敌人结构 base")
	assert_true(bool(h0.has("dyna")), "敌人结构 dyna")
	assert_true(int(h0["base"].get("_tid", 0)) > 0, "Monster ID 非零")


# set/get_defend_team 驻防队伍（照 addTeamData:354 + getTeamData:335，单机简化单 team）。
func test_defend_team_set_get() -> void:
	var mgr := ExcavateManager.new(cm)
	mgr.excavate_data.append({
		"_id": 1, "_type_id": 4, "_owner": "mine", "_state": "occupy",
		"_found_ts": 0, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0, "_wild_id": 0, "_team": [],
	})
	assert_eq(mgr.get_defend_team(1).size(), 0, "初始无驻防")
	mgr.set_defend_team(1, [1, 2, 3], 1000)
	assert_eq(mgr.get_defend_team(1).size(), 3, "驻防 3 英雄")


# enemy_heroes 仅 monster（mine 返空）。
func test_enemy_heroes_monster_only() -> void:
	var mgr := ExcavateManager.new(cm)
	mgr.excavate_data.append({
		"_id": 1, "_type_id": 4, "_owner": "mine", "_state": "occupy",
		"_found_ts": 0, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0, "_wild_id": 0, "_team": [],
	})
	assert_eq(mgr.get_enemy_heroes(1).size(), 0, "mine 矿点无 monster 敌人")


# draw_battle_reward 占领（occupy monster→mine + 返奖励信息）。
func test_draw_battle_reward_occupies() -> void:
	var mgr := ExcavateManager.new(cm)
	mgr.excavate_data.append({
		"_id": 1, "_type_id": 4, "_owner": "monster", "_state": "occupy",
		"_found_ts": 0, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0, "_wild_id": 1, "_team": [],
	})
	var r: Dictionary = mgr.draw_battle_reward(1, 1000)
	assert_true(bool(r["ok"]), "奖励 ok")
	assert_eq(String(mgr.get_data(1)["_owner"]), "mine", "占领后 owner=mine")


# ---- ExcavateHistory（阶段 3）----

# history.add + get_all 倒序（照 excavatehistory.lua orderData:16 按 _time 倒序）。
func test_history_add_and_get_all_ordered() -> void:
	var h := ExcavateHistory.new()
	h.add({"excavate_id": 1, "result": ExcavateHistory.RESULT_WIN, "enemy_name": "A", "_time": 100})
	h.add({"excavate_id": 2, "result": ExcavateHistory.RESULT_LOSE, "enemy_name": "B", "_time": 200})
	var all: Array = h.get_all()
	assert_eq(all.size(), 2, "2 条记录")
	assert_eq(int(all[0]["_time"]), 200, "倒序：time 大的在前")
	assert_eq(int(all[1]["_time"]), 100, "倒序：time 小的在后")


# ExcavateHistory.to/from_dict 往返（存档持久化）。
func test_history_to_from_dict_roundtrip() -> void:
	var h := ExcavateHistory.new()
	h.add({"excavate_id": 1, "result": ExcavateHistory.RESULT_WIN, "enemy_name": "A", "_time": 100})
	var loaded := ExcavateHistory.from_dict(h.to_dict())
	assert_eq(loaded.get_all().size(), 1, "读档后记录数一致")
	assert_eq(int(loaded.get_all()[0]["_time"]), 100, "读档后 time 一致")


# ExcavateBattle._record_history 记战斗（单机：玩家打 monster 记 history）。
func test_battle_records_history() -> void:
	var mgr := ExcavateManager.new(cm)
	mgr.excavate_data.append({
		"_id": 1, "_type_id": 4, "_owner": "monster", "_state": "occupy",
		"_found_ts": 0, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0, "_wild_id": 1, "_team": [],
	})
	var d: Dictionary = mgr.get_data(1)
	var hero_list: Array[Dictionary] = [{"_tid": 1, "_level": 1, "_stars": 1, "_rank": 1, "_items": {}}]
	var enemy_list: Array[Dictionary] = [{"_tid": 100, "_level": 1, "_rank": 1, "_stars": 1, "_exp": 0, "_gs": 0, "_skill_levels": {}, "_items": {}}]
	ExcavateBattle._record_history(mgr, cm, d, hero_list, enemy_list, true, 1000)
	var all: Array = mgr.history.get_all()
	assert_eq(all.size(), 1, "战斗后 history +1")
	assert_eq(String(all[0]["result"]), ExcavateHistory.RESULT_WIN, "记 win")
	assert_eq(int(all[0]["_vatility"]), 0, "单机裁 vit=0")


# ---- ExcavateBattle assemble/finalize（阶段 2b，View 接入拆分）----

# assemble 拒绝 mine 矿点（owner 非 monster，照源 monster 守才可攻击）。
func test_assemble_rejects_mine_owner() -> void:
	var mgr := ExcavateManager.new(cm)
	mgr.excavate_data.append({
		"_id": 1, "_type_id": 4, "_owner": "mine", "_state": "occupy",
		"_found_ts": 0, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0, "_wild_id": 0, "_team": [],
	})
	var pd := PlayerData.new(cm)
	var r: Dictionary = ExcavateBattle.assemble_excavate_battle(mgr, 1, pd, BattleRng.new(1))
	assert_false(bool(r.get("ok", false)), "mine 矿点拒绝装配")


# assemble 拒绝空英雄（玩家无上场英雄）。
func test_assemble_rejects_empty_team() -> void:
	var mgr := ExcavateManager.new(cm)
	mgr.excavate_data.append({
		"_id": 1, "_type_id": 4, "_owner": "monster", "_state": "occupy",
		"_found_ts": 0, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0, "_wild_id": 30001, "_team": [],
	})
	var pd := PlayerData.new(cm)
	pd.team.clear()   # 无上场英雄
	var r: Dictionary = ExcavateBattle.assemble_excavate_battle(mgr, 1, pd, BattleRng.new(1))
	assert_false(bool(r.get("ok", false)), "空英雄/无敌人拒绝装配")


# finalize 胜利占领 + 记历史（enemy 全灭 → won + draw_battle_reward + history）。
func test_finalize_wins_occupies() -> void:
	var mgr := ExcavateManager.new(cm)
	mgr.excavate_data.append({
		"_id": 1, "_type_id": 4, "_owner": "monster", "_state": "occupy",
		"_found_ts": 0, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0, "_wild_id": 1, "_team": [],
	})
	var eng := _MockEngine.new(true)   # enemy 全灭
	var hero_list: Array[Dictionary] = [{"_tid": 1}]
	var enemy_list: Array[Dictionary] = [{"_tid": 100}]
	var r: Dictionary = ExcavateBattle.finalize_excavate_battle(mgr, eng, 1, hero_list, enemy_list, 1000)
	assert_true(bool(r["ok"]), "finalize ok")
	assert_true(bool(r["won"]), "胜利")
	assert_eq(String(mgr.get_data(1)["_owner"]), "mine", "占领后 owner=mine")
	assert_eq(mgr.history.get_all().size(), 1, "history +1")


# finalize 失败不占领（enemy 存活 → won=false，owner 保持 monster）。
func test_finalize_loses_no_occupy() -> void:
	var mgr := ExcavateManager.new(cm)
	mgr.excavate_data.append({
		"_id": 1, "_type_id": 4, "_owner": "monster", "_state": "occupy",
		"_found_ts": 0, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0, "_wild_id": 1, "_team": [],
	})
	var eng := _MockEngine.new(false)   # enemy 存活
	var r: Dictionary = ExcavateBattle.finalize_excavate_battle(mgr, eng, 1, [{"_tid": 1}], [{"_tid": 100}], 1000)
	assert_true(bool(r["ok"]))
	assert_false(bool(r["won"]), "失败")
	assert_eq(String(mgr.get_data(1)["_owner"]), "monster", "未占领")


# ---- grant_resource_reward（照 excavatenet.lua:48-60 发放；修第十轮 P1 占领奖励丢弃 bug）----

func test_grant_gold_adds_money() -> void:
	var pd := PlayerData.new(cm)
	var before: int = pd.get_point("gold")
	ExcavateData.grant_resource_reward(pd, {"_type": "gold", "_param1": 500})
	assert_eq(pd.get_point("gold"), before + 500, "gold reward +500")


func test_grant_diamond_adds_diamond() -> void:
	var pd := PlayerData.new(cm)
	var before: int = pd.diamond
	ExcavateData.grant_resource_reward(pd, {"_type": "diamond", "_param1": 100})
	assert_eq(pd.diamond, before + 100, "diamond reward +100")


func test_grant_item_adds_item() -> void:
	var pd := PlayerData.new(cm)
	var before: int = int(pd.items.get(218, 0))
	ExcavateData.grant_resource_reward(pd, {"_type": "item", "_param1": 218, "_param2": 3})
	assert_eq(int(pd.items.get(218, 0)), before + 3, "item reward 218 ×3")


func test_grant_empty_reward_skips() -> void:
	var pd := PlayerData.new(cm)
	var before_gold: int = pd.get_point("gold")
	ExcavateData.grant_resource_reward(pd, {})
	assert_eq(pd.get_point("gold"), before_gold, "空 reward(loot=0)不发")


func test_grant_null_player_skips() -> void:
	ExcavateData.grant_resource_reward(null, {"_type": "gold", "_param1": 500})
	assert_true(true, "null player 守卫不崩")


# ---- 6 态状态机 + 跨天重置 + 占领 loot（照 local_server.lua:3542-3555 / 3628 / 3839-3868）----

# search 建矿点 state=searched + state_end_ts=now+300（照 :3723-3724）。
func test_search_sets_searched_state() -> void:
	var mgr := ExcavateManager.new(cm)
	var player := _MockPlayer.new(1000000)
	mgr.search(player, BattleRng.new(7), 1000)
	var d: Dictionary = mgr.get_searched()
	assert_eq(String(d["_state"]), "searched", "搜索点 searched 态")
	assert_eq(int(d["_state_end_ts"]), 1300, "searched 有效期 now+300")


# searched 到期→empty（照 updateMineState:3545，refresh 触发）。
func test_searched_expires_to_empty() -> void:
	var mgr := ExcavateManager.new(cm)
	mgr.excavate_data.append({"_id": 1, "_type_id": 4, "_owner": "monster", "_state": "searched",
		"_state_end_ts": 1000, "_found_ts": 700, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0, "_wild_id": 0})
	mgr.refresh(1001)
	assert_eq(String(mgr.get_data(1)["_state"]), "empty", "searched 到期转 empty")


# 占领后 state=prepare + state_end_ts=now+Prepare Time（照 :3850-3851，占领准备期非 occupy）。
func test_occupy_sets_prepare_state() -> void:
	var mgr := ExcavateManager.new(cm)
	mgr.excavate_data.append({"_id": 1, "_type_id": 4, "_owner": "monster", "_state": "searched",
		"_found_ts": 1, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0, "_wild_id": 1})
	mgr.draw_battle_reward(1, 1000)
	var d: Dictionary = mgr.get_data(1)
	assert_eq(String(d["_state"]), "prepare", "占领后 prepare 态（非 occupy）")
	assert_eq(int(d["_state_end_ts"]), 1000 + ExcavateData.prepare_time(cm, 4), "prepare_end=now+Prepare Time")


# prepare 到期→occupy 产出态（照 updateMineState:3548）。
func test_prepare_expires_to_occupy() -> void:
	var mgr := ExcavateManager.new(cm)
	mgr.excavate_data.append({"_id": 1, "_type_id": 4, "_owner": "mine", "_state": "prepare",
		"_state_end_ts": 1000, "_found_ts": 1, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0, "_wild_id": 0})
	mgr.refresh(1001)
	assert_eq(String(mgr.get_data(1)["_state"]), "occupy", "prepare 到期转 occupy")


# draw_battle_reward loot = 占领前 monster 态累计产出 × Loot Ratio，<Safe→0（照 :3843-3847）。
func test_draw_battle_reward_loot_formula() -> void:
	var mgr := ExcavateManager.new(cm)
	mgr.excavate_data.append({"_id": 1, "_type_id": 4, "_owner": "monster", "_state": "searched",
		"_found_ts": 400, "_produce_speed": 100.0, "_storage": 99999, "_res_got": 0.0, "_wild_id": 1})
	var r: Dictionary = mgr.draw_battle_reward(1, 1000)   # produced=100×(600/60)=1000
	var raw_loot: int = int(1000.0 * ExcavateData.loot_ratio(cm, 4))
	var expect: int = 0 if raw_loot < ExcavateData.safe_amount(cm, 4) else raw_loot
	assert_eq(int(r["loot"]), expect, "loot=produced×ratio（<safe→0）")


# produced≈0 → loot=0 + 无 reward（照 :3846-3847 safe 保底 + :3649 amount<=0 返空）。
func test_draw_battle_reward_loot_zero() -> void:
	var mgr := ExcavateManager.new(cm)
	mgr.excavate_data.append({"_id": 1, "_type_id": 4, "_owner": "monster", "_state": "searched",
		"_found_ts": 600, "_produce_speed": 10.0, "_storage": 500, "_res_got": 0.0, "_wild_id": 1})
	var r: Dictionary = mgr.draw_battle_reward(1, 601)   # elapsed=1s, produced≈0
	assert_eq(int(r["loot"]), 0, "produced≈0→loot=0")
	assert_true(Dictionary(r["reward"]).is_empty(), "loot=0 无 reward 结构")


# 跨天重置 search_times（照 checkSearchDayReset:3628，_crossed_day 不同日→归零）。
func test_search_day_reset_cross_day() -> void:
	var mgr := ExcavateManager.new(cm)
	mgr.search_times = 5
	mgr.last_search_ts = 1000
	mgr.check_search_day_reset(1000 + 90000)   # >1 天后
	assert_eq(mgr.search_times, 0, "跨天 search_times 归零")


# build_resource_reward gold/diamond/item 结构（照 :3648-3661）。
func test_build_resource_reward_mapping() -> void:
	assert_true(ExcavateData.build_resource_reward(cm, 4, 0).is_empty(), "amount<=0 返空")
	var rw: Dictionary = ExcavateData.build_resource_reward(cm, 4, 100)
	assert_false(rw.is_empty(), "amount>0 返非空")
	var rtype: String = String(rw["_type"])
	assert_true(["gold", "diamond", "item"].has(rtype), "reward_type 合法")
	if rtype == "item":
		assert_eq(int(rw["_param2"]), 100, "item param2=amount")
	else:
		assert_eq(int(rw["_param1"]), 100, "gold/diamond param1=amount")


# Mock player（duck-type ExcavateManager.search 用：hero_manager.gold/add_money + team_level）。
class _MockPlayer:
	var hero_manager: _MockHeroMgr
	var team_level: int = 99   # 高等级让所有矿点 type 可 roll

	func _init(gold: int) -> void:
		hero_manager = _MockHeroMgr.new(gold)


	# 加英雄到 hero_manager.heroes（供 _generate_wild_team 生成野怪镜像）。
	func add_hero(tid: int, level: int = 1, stars: int = 1, rank: int = 1) -> void:
		var inst_id: int = hero_manager.heroes.size() + 1
		hero_manager.heroes[inst_id] = {"tid": tid, "level": level, "stars": stars, "rank": rank}


class _MockHeroMgr:
	var gold: int
	var heroes: Dictionary = {}   # inst_id → {tid,level,stars,rank}（供 _generate_wild_team 镜像）

	func _init(g: int) -> void:
		gold = g

	func add_money(amount: int) -> void:
		gold += amount


# Mock engine（finalize 只用 foreach_alive_unit(CAMP_ENEMY).is_empty() 判胜负）。
class _MockEngine:
	var _enemy_empty: bool

	func _init(enemy_empty: bool) -> void:
		_enemy_empty = enemy_empty

	func foreach_alive_unit(_camp: int) -> _MockAliveList:
		return _MockAliveList.new(_enemy_empty)


class _MockAliveList:
	var _empty: bool

	func _init(e: bool) -> void:
		_empty = e

	func is_empty() -> bool:
		return _empty
