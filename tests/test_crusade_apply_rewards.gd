extends GutTest
# Phase 6 CrusadePoint 货币 + apply_rewards 测试（照源 local_server.lua:2553-2570 getCrusadeReward）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# CrusadePoint amount*10（源 :2561）。
func test_apply_rewards_crusade_point() -> void:
	var mgr := CrusadeManager.new(cm)
	var pd := PlayerData.new(cm)
	var slots: Array = [{"type": "CrusadePoint", "id": 0, "amount": 50}]
	mgr.apply_rewards(slots, pd, BattleRng.new(1))
	assert_eq(pd.crusade_point, 500, "CrusadePoint amount*10 累加")


# ChestBox 按 coinMap[id] 转 crusadepoint（×10）（源 :2562-2565，id=1→coin50→×10=500）。
func test_apply_rewards_chest_box() -> void:
	var mgr := CrusadeManager.new(cm)
	var pd := PlayerData.new(cm)
	var slots: Array = [{"type": "ChestBox", "id": 1, "amount": 2}]
	mgr.apply_rewards(slots, pd, BattleRng.new(42))
	assert_eq(pd.crusade_point, 500, "ChestBox id=1 → coinMap[1]=50 → ×10=500 crusadepoint")


func test_apply_rewards_item() -> void:
	var mgr := CrusadeManager.new(cm)
	var pd := PlayerData.new(cm)
	var slots: Array = [{"type": "Item", "id": 201, "amount": 3}]
	mgr.apply_rewards(slots, pd, BattleRng.new(1))
	assert_eq(int(pd.items.get(201, 0)), 3, "Item 累加到背包")


func test_apply_rewards_skips_unknown() -> void:
	var mgr := CrusadeManager.new(cm)
	var pd := PlayerData.new(cm)
	var slots: Array = [{"type": "Unknown", "id": 1, "amount": 1}, {"type": "CrusadePoint", "id": 0, "amount": 30}]
	mgr.apply_rewards(slots, pd, BattleRng.new(1))
	# Unknown 跳过，CrusadePoint amount*10=300
	assert_eq(pd.crusade_point, 300, "未知类型跳过，CrusadePoint×10")


func test_crusade_point_persistence() -> void:
	var pd := PlayerData.new(cm)
	pd.crusade_point = 100
	var d: Dictionary = pd.to_dict()
	assert_eq(int(d["crusade_point"]), 100, "crusade_point 持久化")
	var restored := PlayerData.from_dict(d, cm)
	assert_eq(restored.crusade_point, 100, "读档恢复")
