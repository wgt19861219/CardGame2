extends GutTest

## stage_account dungeon 结算分支验证（照源 stageaccount.lua:36-100 isDungeon 分支）。
# 源 :52-80：dungeon 关 exp = Exp Reward × 10 / gold = goldByDiff[difficulty] / total_exp = Exp×10 / is_key_stage false。
# 当时"照源不接"是 StageDungeon 表未接入，现已接入（expand_battle_dungeon + StageData 表分流）可补。

var _cm: ConfigManager
var _player: PlayerData


func before_each() -> void:
	_cm = GameData.config
	if not _cm.is_loaded():
		_cm.load_all()
	_player = GameData.player


func _build(sid: int, victory: bool = true) -> Dictionary:
	var param: Dictionary = {"stage_id": sid, "victory": victory, "heroes": [1], "loots": []}
	return StageAccount.build_result_param(param, _cm, _player, _player.hero_manager)


func test_dungeon_exp_x10() -> void:
	# 源 :54 dungeon exp = Exp Reward × 10
	var r: Dictionary = _build(51013)
	var data := StageData.from_config(_cm, 51013)
	assert_eq(int(r["exp"]), data.exp_reward * 10, "dungeon exp × 10")
	assert_eq(int(r["total_exp"]), data.exp_reward * 10, "dungeon total_exp × 10（源 :77）")


func test_dungeon_is_key_stage_false() -> void:
	# 源 :50 isKeyStage = not isDungeon and row["Key Stage"]（dungeon 强制 false）
	var r: Dictionary = _build(51013)
	assert_eq(bool(r["is_key_stage"]), false, "dungeon is_key_stage 强制 false")


func test_dungeon_gold_by_diff2() -> void:
	# 源 :55-56 goldByDiff[2] = 3500（51013 Difficulty=2）
	var r: Dictionary = _build(51013)
	assert_eq(int(r["gold"]), 3500, "dungeon diff2 gold 3500")


func test_dungeon_gold_by_diff4() -> void:
	# 53013 Difficulty=4 → goldByDiff[4] = 8000
	var r: Dictionary = _build(53013)
	assert_eq(int(r["gold"]), 8000, "dungeon diff4 gold 8000")


func test_dungeon_gold_by_diff1_base() -> void:
	# 50013 base Difficulty=1 → goldByDiff[1] = 2000
	var r: Dictionary = _build(50013)
	assert_eq(int(r["gold"]), 2000, "dungeon diff1 gold 2000")


func test_normal_exp_no_x10() -> void:
	# 普通关 1：源 :58 exp = Exp Reward（不 ×10）+ :59 gold = Money Reward
	var r: Dictionary = _build(1)
	var data := StageData.from_config(_cm, 1)
	assert_eq(int(r["exp"]), data.exp_reward, "普通关 exp 不 ×10")
	assert_eq(int(r["gold"]), data.money_reward, "普通关 gold = Money Reward")
	assert_eq(bool(r["is_key_stage"]), data.key_stage, "普通关 is_key_stage 读字段（非强制 false）")


func test_is_dungeon_stage_old_segment() -> void:
	# 旧段 4xxxx 兼容（StageData.is_dungeon_stage 含旧段，照源 local_server:456-461）
	assert_true(StageData.is_dungeon_stage(40001), "旧段 40001 是 dungeon")
	assert_true(StageData.is_dungeon_stage(43021), "旧段 43021 是 dungeon")
	assert_false(StageData.is_dungeon_stage(44000), "44000 非 dungeon（超出旧段）")


# ── 2026-09-19 照源回归：dungeon 胜利入账（源 battle_engine.lua:1136-1156 专属分支，不走
# takeStageReward）——旧实现四偏差根修：①金币只展示不入账 ②多发钻石 20 ③英雄经验误读
# Heroexp Reward（源=Exp×10 均分）④掉落误用 act 规则（Pro×2+扫荡券）。自建号隔离防真实档污染。──

func _make_isolated_player() -> PlayerData:
	var pd := PlayerData.new(GameData.config)
	pd.apply_default_data()
	pd.team_level = 95   # 95 级升级需求 30000 > 150 结算经验（100 会撞 MAX 99 清零 team_exp）
	pd.dungeonpoint = 500
	return pd


func test_take_dungeon_reward_credits_gold_exp_heroexp() -> void:
	# 源 :1141-1149：addMoney(goldByDiff)+addExp(Exp×10)+heroexp=floor(exp×10/#hero) 均分。
	var pd := _make_isolated_player()
	var gold_before: int = pd.hero_manager.gold
	var exp_before: int = pd.team_exp
	var hero_keys: Array = pd.hero_manager.heroes.keys()
	var hero0 = pd.hero_manager.heroes[hero_keys[0]]
	var hero_exp_before: int = hero0.exp
	var hero_level_before: int = hero0.level
	var data := StageData.from_config(_cm, 50013)   # diff1: Exp=15 → exp 150 / gold 2000
	pd.take_dungeon_reward(50013, [int(hero0.tid)], [])
	assert_eq(pd.hero_manager.gold - gold_before, 2000, "diff1 金币 2000 入账（旧实现只展示不入账）")
	assert_eq(pd.team_exp - exp_before, data.exp_reward * 10, "队伍经验 = Exp×10（level100 需求高不触升级重算）")
	var hero_after = pd.hero_manager.heroes[hero_keys[0]]
	assert_true(hero_after.exp > hero_exp_before or hero_after.level > hero_level_before,
		"英雄经验入账（升级重算下 exp/level 至少增长）")
	# 均分公式守卫（源 heroexp=floor(expReward/#hero_list)，不读 Heroexp Reward 字段——
	# 50013 Heroexp Reward=500 与 Exp×10=150 不同源值，防回潮误用）。
	var src: String = FileAccess.get_file_as_string("res://scripts/data/player_data.gd")
	assert_true(src.contains("_grant_team_and_hero_exp(exp, exp, hero_tids)"),
		"take_dungeon_reward 英雄经验与队伍经验同源 Exp×10（均分公式）")


func test_take_dungeon_reward_no_diamond() -> void:
	# 源 dungeon 不走 takeStageReward → 无 addrmb；旧实现经 take_stage_reward 多发 20 钻。
	var pd := _make_isolated_player()
	var d_before: int = pd.diamond
	pd.take_dungeon_reward(50013, [1], [])
	assert_eq(pd.diamond - d_before, 0, "dungeon 胜利不发钻石")


func test_generate_dungeon_loots_rules() -> void:
	# 源 local_server.lua:504-550：难度率掷 7 槽每件 1 个（不翻倍）+ 全空保底 1 件
	#（优先未拥有）；无扫荡券 390 必掉（那是 act 分支 generateLoots 规则）。
	var pd := _make_isolated_player()
	var mgr := StageManager.new(GameData.config)
	# 50001 掉落池实测 {312, 351} 两槽
	for seed in range(50):
		var loots: Array[Dictionary] = mgr.generate_loot_list(50001, BattleRng.new(seed), pd)
		assert_true(loots.size() >= 1, "seed %d 保底非空" % seed)
		assert_true(loots.size() <= 2, "seed %d 每槽至多 1 件不翻倍" % seed)
		for loot in loots:
			var item_id: int = int(loot["id"])
			assert_true(item_id == 312 or item_id == 351, "seed %d 掉落属 50001 池" % seed)
			assert_ne(item_id, 390, "seed %d 无扫荡券必掉" % seed)


func test_guarantee_prefers_unowned() -> void:
	# 保底选择（源 :527-543）：优先未拥有——拥有 312 时保底必给 351；全拥有则池内随机。
	var pd := _make_isolated_player()
	pd.add_item(312)   # 拥有 312，未拥有 351
	var rng := BattleRng.new(9)
	assert_eq(StageDungeonLogic._pick_guarantee([312, 351], pd, rng), 351, "优先未拥有件")
	pd.add_item(351)   # 全拥有 → 随机池内一件
	var pick: int = StageDungeonLogic._pick_guarantee([312, 351], pd, rng)
	assert_true(pick == 312 or pick == 351, "全拥有随机池内一件")


func test_finalize_routes_dungeon_reward() -> void:
	# 源码守卫：finalize 胜利分支对 dungeon 关分流 take_dungeon_reward（防回潮统一走
	# take_stage_reward——金币蒸发+多发钻石+英雄经验错源同时回归）。
	var text: String = FileAccess.get_file_as_string("res://scripts/systems/stage_manager.gd")
	assert_true(text.contains("player.take_dungeon_reward(sid, player_tids, loots)"),
		"finalize 对 dungeon 关走 take_dungeon_reward 分支")
