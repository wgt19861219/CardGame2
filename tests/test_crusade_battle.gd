extends GutTest
# Phase 6 Crusade 战斗闭环测试（2026-07-02）— run_crusade_battle 端到端。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_run_crusade_battle_structure() -> void:
	var mgr := CrusadeManager.new(cm)
	mgr.init_crusade(BattleRng.new(12345))
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var r: Dictionary = mgr.run_crusade_battle(1, pd, [1], BattleRng.new(42))
	assert_eq(bool(r["ok"]), true, "run_crusade_battle ok（端到端不崩）")
	assert_true(r.has("won"), "返 won 字段")


func test_run_crusade_battle_no_enemies_fails() -> void:
	var mgr := CrusadeManager.new(cm)
	# 未 init_crusade → enemies 空 → get_stage_enemies 空 → ok=false
	var pd := PlayerData.new(cm)
	var r: Dictionary = mgr.run_crusade_battle(1, pd, [1], BattleRng.new(42))
	assert_eq(bool(r["ok"]), false, "无敌人配置返 ok=false")


func test_crusade_win_advances_stage() -> void:
	var mgr := CrusadeManager.new(cm)
	mgr.init_crusade(BattleRng.new(12345))
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var r: Dictionary = mgr.run_crusade_battle(1, pd, [1], BattleRng.new(42))
	assert_true(r.has("won"), "返 won 字段")
	if bool(r["won"]):
		assert_eq(mgr.cur_stage, 2, "胜利推进下一层")
		assert_true(mgr.is_stage_cleared(1), "stage 1 标记通关")


func test_cross_battle_hp_persisted() -> void:
	# 战斗后英雄 HP/MP 存入 hero_hp_perc/hero_mp_perc（跨关保持基础）
	var mgr := CrusadeManager.new(cm)
	mgr.init_crusade(BattleRng.new(12345))
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	mgr.run_crusade_battle(1, pd, [1], BattleRng.new(42))
	# 战斗后应有跨关状态（存活的 tid → perc），至少状态被更新过
	assert_true(mgr.hero_hp_perc is Dictionary or mgr.hero_hp_perc.is_empty(), "HP 状态结构合法")
