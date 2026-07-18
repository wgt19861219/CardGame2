extends GutTest
# BattleRewardPopup 战斗结算奖励弹窗测试（照源 crusade.lua showRewardResult）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_setup_rewards_mixed() -> void:
	var root := Node.new()
	add_child(root)
	var popup := BattleRewardPopup.new("battleReward", {})
	var rewards: Array = [
		{"type": "gold", "amount": 500},
		{"type": "CrusadePoint", "amount": 200},
		{"type": "Item", "id": 101, "amount": 2},
	]
	popup.setup_rewards(rewards, cm)
	popup.show_window(root)
	# .tscn 重构后：reward 挂 %RewardHost（3 reward），CloseBtn 静态进 .tscn。
	# container 下钻：container → _content → %RewardHost/%CloseBtn（坑 6 扫描深度）。
	assert_eq(popup._reward_host.get_child_count(), 3, "gold + crusadepoint + item 挂 RewardHost")
	assert_not_null(popup._content.get_node_or_null("%CloseBtn"), "CloseBtn 在 tscn")
	popup.remove_window()
	root.queue_free()


func test_currency_label() -> void:
	var popup := BattleRewardPopup.new("battleReward", {})
	assert_eq(popup._currency_label("gold", 500), "金币 x500", "gold Label")
	assert_eq(popup._currency_label("CrusadePoint", 200), "远征币 x200", "crusadepoint Label")
	popup.queue_free()
