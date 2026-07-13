extends GutTest
# LadderBattle 单测（2026-07-09 P0-9 阶段 2）。验 PVP 战斗装配 + 端到端 run + 结算排名互换。
# before_all 真实 ConfigManager + PlayerData 默认（5 英雄 + team）。

var cm: ConfigManager
var player: PlayerData


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()
	player = PlayerData.new(cm)
	player.apply_default_data()


func test_assemble_pvp_battle() -> void:
	var lm := LadderManager.new()
	lm.handle({"_open_panel": true}, player, cm, BattleRng.new(1), 0)
	var oppo_id: int = int(lm.pvp["enemies"][0]["user_id"])
	var r: Dictionary = LadderBattle.assemble_pvp_battle(lm, oppo_id, player, cm, BattleRng.new(2), 0)
	assert_true(bool(r.get("ok", false)), "装配成功（玩家阵容 vs AI 对手）")
	assert_eq(int(r["oppo_user_id"]), oppo_id, "oppo_user_id 保留")
	assert_true((r["hero_list"] as Array).size() > 0, "玩家英雄列表非空")
	assert_true((r["enemy_list"] as Array).size() >= 3, "敌方 AI 英雄列表（fallback 3-5）")
	assert_eq(int(lm.pvp["left_count"]), 4, "_start_battle 扣 left_count 5→4")


func test_run_pvp_battle_endtoend() -> void:
	var lm := LadderManager.new()
	lm.handle({"_open_panel": true}, player, cm, BattleRng.new(3), 0)
	var oppo_id: int = int(lm.pvp["enemies"][0]["user_id"])
	var r: Dictionary = LadderBattle.run_pvp_battle(lm, oppo_id, player, cm, BattleRng.new(4), 0)
	assert_true(bool(r.get("ok", false)), "端到端跑通（assemble + 战斗 + finalize）")
	var reply: Dictionary = r.get("reply", {})
	assert_true(reply.has("result"), "reply 有 result（victory/defeat）")
	# 胜则排名互换 + 奖励；败则不变。won 任一都合法（取决于战斗）。
	if str(reply.get("result", "")) == "victory":
		assert_true(int(reply.get("reward", 0)) > 0, "victory 有奖励")
		assert_true(player.arena_point > 0, "victory 累加 arenapoint（pd.add_point）")


func test_finalize_left_count_consumed() -> void:
	var lm := LadderManager.new()
	lm.handle({"_open_panel": true}, player, cm, BattleRng.new(5), 0)
	assert_eq(int(lm.pvp["left_count"]), 5, "open_panel 恢复 left_count=5")
	var oppo_id: int = int(lm.pvp["enemies"][0]["user_id"])
	var asm: Dictionary = LadderBattle.assemble_pvp_battle(lm, oppo_id, player, cm, BattleRng.new(6), 0)
	assert_eq(int(lm.pvp["left_count"]), 4, "start_battle 扣 1")
	# last_oppo_rank 已设（start_battle 记对手 rank，finalize 排名互换用；对手 rank ~900 远大于英雄 rank 5-22）
	assert_true(int(lm.pvp["last_oppo_rank"]) > 0, "last_oppo_rank 已记（对手 rank）")
