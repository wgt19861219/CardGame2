extends GutTest

## dungeon 战斗端到端冒烟（Phase 2.2 集成冒烟 dungeon 分支）。
# 验证 expand_battle_dungeon.py 注入的真实敌人能跑完整战斗闭环（装配→循环→胜负→finalize），不崩。
# bridge ACL 坑无法运行时验收，headless 端到端跑是 dungeon 战斗真实性的最强验证。
# 测试隔离（2026-08-14）：装配扣体力读的是 GameData.player 持久存档（user:// 与真实游戏共用），
# 连续重跑会把体力耗干致 no_vitality 假失败——每场战斗前重置满体力（本文件测战斗闭环，不测经济）。

func _reset_vitality() -> void:
	GameData.player.vitality = GameData.player.vitality_max
	# 2026-08-22 巡检接入每日限制/钥匙/等级检查（check_enter_dungeon）后，同"不测经济"
		# 原则预置足额条件：钥匙 500 + 等级 100（StageDungeon UnlockLevel 最高 100[53021 末关]，
	# 旧默认 level 1 会 level_lock 假失败）。
	GameData.player.dungeonpoint = 500
	GameData.player.team_level = 100

func test_dungeon_battle_e2e_51013_diff2() -> void:
	# 51013 = 50013 纳克萨玛斯首关 diff2（HP% 缩放 ×1.5）。boss=6 末日使者，m=[40,42,17]
	_reset_vitality()
	var player: PlayerData = GameData.player
	var mgr := StageManager.new(GameData.config)
	var rng := BattleRng.new(12345)
	var r: Dictionary = mgr.run_stage_battle(51013, player, [1], rng)
	assert_true(bool(r.get("ok", false)), "51013 diff2 端到端完成（装配+跑+finalize）")
	assert_true(r.has("won"), "有胜负结果")
	# diff2 boss HP% 3000（2000×1.5），玩家单英雄 tid=1 多半输，重要的是不崩 + 有结果
	assert_true(typeof(r.get("won", null)) == TYPE_BOOL, "won 是 bool")


func test_dungeon_battle_e2e_50013_base() -> void:
	_reset_vitality()
	# base 关 50013（diff1 无缩放，HP% 2000）也能跑完整闭环
	var player: PlayerData = GameData.player
	var mgr := StageManager.new(GameData.config)
	var r: Dictionary = mgr.run_stage_battle(50013, player, [1], BattleRng.new(22222))
	assert_true(bool(r.get("ok", false)), "50013 base 关端到端完成")


func test_dungeon_battle_e2e_53021_last() -> void:
	_reset_vitality()
	# 53021 = 末关 diff4（安其拉废墟，HP% ×3.0），验证极端缩放关不崩
	var player: PlayerData = GameData.player
	var mgr := StageManager.new(GameData.config)
	var r: Dictionary = mgr.run_stage_battle(53021, player, [1], BattleRng.new(33333))
	assert_true(bool(r.get("ok", false)), "53021 diff4 末关端到端完成（极端缩放不崩）")


func test_dungeon_battle_hero_hp_mp_field() -> void:
	_reset_vitality()
	# finalize_stage_battle 收集 hero_hp_mp 字段（源 stageaccount:138-139 hp=hero:hp_perc()）。
	# 存活玩家单位真实 hp/mp 百分比，死亡单位不在快照（stage_account 默认 0）。
	var player: PlayerData = GameData.player
	var mgr := StageManager.new(GameData.config)
	var r: Dictionary = mgr.run_stage_battle(50013, player, [1], BattleRng.new(44444))
	assert_true(r.has("hero_hp_mp"), "finalize 返 hero_hp_mp 字段")
	var hp_mp: Dictionary = r.get("hero_hp_mp", {})
	if bool(r.get("won", false)):
		# 胜利 → 玩家至少 1 存活 → hero_hp_mp 非空
		assert_true(hp_mp.size() > 0, "胜利时玩家存活单位 hp_mp 已收集")
		# 校验结构（如果 tid=1 存活）
		if hp_mp.has(1):
			assert_true(int(hp_mp[1].get("hp", -1)) >= 0, "hp 万分比 >= 0")
			assert_true(int(hp_mp[1].get("hp", -1)) <= 10000, "hp 万分比 <= 10000（源 _hp_perc）")
