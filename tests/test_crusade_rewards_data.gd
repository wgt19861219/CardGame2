extends GutTest
# Phase 6 CrusadeRewardsData 测试（2026-07-02）— 照源 CrusadeRewards 多级查表。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_get_reward_info_multilevel() -> void:
	# CrusadeRewards[1][1][0] 存在（源 lua 确认）
	var info: Dictionary = CrusadeRewardsData.get_reward_info(cm, 1, 1, false)
	assert_false(info.is_empty(), "stage 1 wave 1 非 VIP 有配置")


func test_get_gold_ratio() -> void:
	# 源 stage 1 wave 1 Gold Ratio = 1
	var ratio: float = CrusadeRewardsData.get_gold_ratio(cm, 1, 1, false)
	assert_eq(ratio, 1.0, "Gold Ratio=1")


func test_get_reward_slots() -> void:
	var slots: Array = CrusadeRewardsData.get_reward_slots(cm, 1, 1, false)
	# 源 stage 1 wave 1[0]: Type 1=CrusadePoint Amount=0(跳过), Type 2=ChestBox Amount=1 ID=1
	assert_true(slots.size() >= 1, "至少 1 奖励槽（Amount>0）")
	var has_chest_box: bool = false
	for s in slots:
		if String(s["type"]) == "ChestBox":
			has_chest_box = true
	assert_true(has_chest_box, "含 ChestBox 奖励（Amount 2=1）")


func test_missing_stage_empty() -> void:
	var info: Dictionary = CrusadeRewardsData.get_reward_info(cm, 999, 1, false)
	assert_true(info.is_empty(), "不存在 stage 返空")
