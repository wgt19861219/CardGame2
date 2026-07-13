extends GutTest
# Phase 6 Crusade 远征数据层测试（2026-07-02）— 照源 initCrusade 难度曲线 + buildCrusadeHeroPools。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_stage_level_curve() -> void:
	assert_eq(CrusadeData.stage_level(1), 80, "stage 1 level=80")
	assert_eq(CrusadeData.stage_level(15), 90, "stage 15 level=90")


func test_stage_stars_curve() -> void:
	assert_eq(CrusadeData.stage_stars(1), 3, "stage 1 stars=3")
	assert_eq(CrusadeData.stage_stars(15), 5, "stage 15 stars=5（cap）")


func test_stage_rank_curve() -> void:
	assert_eq(CrusadeData.stage_rank(1), 3, "stage 1 rank=3")
	assert_eq(CrusadeData.stage_rank(15), 12, "stage 15 rank=12（cap）")


func test_build_hero_pools() -> void:
	var rng := BattleRng.new(12345)
	var pools: Dictionary = CrusadeData.build_hero_pools(cm, rng)
	# Unit 表有 Position Type（Front/Middle/Rear），三池应非空
	assert_true(pools["front"].size() > 0, "前池非空")
	assert_true(pools["middle"].size() > 0, "中池非空")
	assert_true(pools["rear"].size() > 0, "后池非空")


func test_build_pools_deterministic() -> void:
	# 同种子 → 同池（rng 注入确定性）
	var p1: Dictionary = CrusadeData.build_hero_pools(cm, BattleRng.new(777))
	var p2: Dictionary = CrusadeData.build_hero_pools(cm, BattleRng.new(777))
	assert_eq(p1["front"], p2["front"], "同种子前池一致")
