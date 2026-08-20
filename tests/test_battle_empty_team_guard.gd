extends GutTest

## 空队伍进战斗边界防护（对齐源 2026-08-19 enterStage 空队拒绝语义）。
# 背景：Axmol 侧 hero_list={} 进战斗曾致"失败判定永不触发、战斗永不结束"；
# CardGame2 引擎 tick 是计数式判定（alive_alliance_count==0 首 tick 判负，不会卡死），
# 但 Logic 装配入口不拒绝空队——副本分支已先扣体力、loots 已生成、crusade 会被必败
# 污染跨关状态。View 层（battle_prepare_panel/dungeon_map_panel）已有 toast 拦截，
# 此处给 Logic 层兜底（View 缺口/新调用方直调均被拦截）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_assemble_normal_stage_empty_team_rejected() -> void:
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	var r: Dictionary = mgr.assemble_stage_battle(1, pd, [], BattleRng.new(42))
	assert_false(bool(r.get("ok", true)), "普通关空队伍装配被拒绝")
	assert_eq(String(r.get("error", "")), "empty_team", "错误码 empty_team")


func test_assemble_dungeon_empty_team_keeps_vitality() -> void:
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	pd.vitality = pd.vitality_max
	var before: int = pd.vitality
	# 50013 副本关：拒绝必须发生在 spend_vitality 之前，否则空队白扣体力
	var r: Dictionary = mgr.assemble_stage_battle(50013, pd, [], BattleRng.new(42))
	assert_false(bool(r.get("ok", true)), "副本关空队伍装配被拒绝")
	assert_eq(pd.vitality, before, "空队伍拒绝不扣体力")


func test_run_stage_battle_empty_team_short_circuits() -> void:
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	var r: Dictionary = mgr.run_stage_battle(1, pd, [], BattleRng.new(42))
	assert_false(bool(r.get("ok", true)), "端到端空队伍短路返回")
	assert_false(r.has("won"), "不进 finalize（无 won 字段）")


func test_crusade_empty_team_rejected_and_state_kept() -> void:
	var mgr := CrusadeManager.new(cm)
	mgr.init_crusade(BattleRng.new(12345))
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var r: Dictionary = mgr.run_crusade_battle(1, pd, [], BattleRng.new(42))
	assert_false(bool(r.get("ok", true)), "crusade 空队伍被拒绝")
	assert_false(r.has("won"), "不跑战斗（无 won 字段）")
	assert_false(mgr.is_stage_cleared(1), "crusade 状态未被空队污染（stage 1 未标记通关）")
	assert_eq(mgr.cur_stage, 1, "cur_stage 不变（fight 未被调用）")
