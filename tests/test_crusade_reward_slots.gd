extends GutTest
# Phase 6 CrusadeManager.draw_reward_slots 奖励发放测试（2026-07-02）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_draw_reward_slots_returns_rewards() -> void:
	var mgr := CrusadeManager.new(cm)
	mgr.cleared_stages[1] = true  # 标记通关
	var slots: Array = mgr.draw_reward_slots(1, false)
	assert_true(slots.size() >= 1, "stage 1 返奖励槽")
	assert_true(mgr.is_stage_rewarded(1), "标记 rewarded")


func test_draw_reward_slots_uncleared_empty() -> void:
	var mgr := CrusadeManager.new(cm)
	var slots: Array = mgr.draw_reward_slots(1, false)
	assert_eq(slots.size(), 0, "未通关无奖励")


func test_draw_reward_slots_twice_empty() -> void:
	var mgr := CrusadeManager.new(cm)
	mgr.cleared_stages[1] = true
	mgr.draw_reward_slots(1, false)
	var slots2: Array = mgr.draw_reward_slots(1, false)  # 重复领
	assert_eq(slots2.size(), 0, "重复领无奖励")
