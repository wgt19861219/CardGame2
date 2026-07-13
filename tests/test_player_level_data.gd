extends GutTest
# Phase 5.4 PlayerLevelData 战队等级查询测试（2026-07-02）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_get_level_exp() -> void:
	assert_eq(PlayerLevelData.get_level_exp(1, cm), 25, "level 1 Exp=25")


func test_get_vitality_reward() -> void:
	assert_eq(PlayerLevelData.get_vitality_reward(1, cm), 20, "level 1 Vitality Reward=20")


func test_get_level_info_missing() -> void:
	assert_eq(PlayerLevelData.get_level_info(999, cm).size(), 0, "不存在 level → 空")
