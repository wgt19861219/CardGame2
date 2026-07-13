extends GutTest
# 扣物品 Logic（照源 player.lua:1232 consumeEquip 减 equip_qunty[id]）。
# PlayerData.remove_item 纯扣物品不加金币，eatexplist 喂药消耗经验药用。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_remove_decrements_without_gold() -> void:
	var pd := PlayerData.new(cm)
	pd.add_item(101, 5)
	var removed: int = pd.remove_item(101, 2)
	assert_eq(removed, 2, "实际扣减 = count")
	assert_eq(int(pd.items.get(101, 0)), 3, "items 扣 2")
	assert_eq(pd.hero_manager.gold, 0, "不加金币（区别 sell_equip）")


func test_remove_insufficient_returns_zero() -> void:
	var pd := PlayerData.new(cm)
	pd.add_item(101, 1)
	assert_eq(pd.remove_item(101, 2), 0, "持有 < 需求 → 0")
	assert_eq(int(pd.items.get(101, 0)), 1, "不足时不扣")
	assert_eq(pd.remove_item(999, 1), 0, "无库存 → 0")


func test_remove_invalid_args_returns_zero() -> void:
	var pd := PlayerData.new(cm)
	pd.add_item(101, 3)
	assert_eq(pd.remove_item(0, 1), 0, "item_id<=0 → 0")
	assert_eq(pd.remove_item(101, 0), 0, "count<=0 → 0")
	assert_eq(pd.remove_item(-1, 1), 0, "负 id → 0")
	assert_eq(int(pd.items.get(101, 0)), 3, "无效参数不扣")


func test_remove_default_count_one() -> void:
	var pd := PlayerData.new(cm)
	pd.add_item(101, 3)
	assert_eq(pd.remove_item(101), 1, "默认 count=1")
	assert_eq(int(pd.items.get(101, 0)), 2, "扣 1")
