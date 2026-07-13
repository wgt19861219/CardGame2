extends GutTest
# 装备出售 Logic（照源 ofsell.lua:140 income=sellAmount×Sell Price + network.lua:929/933 sell_item 回包：
# 加金币 + 删背包；local_server:1359 net 桩无 Logic）。PlayerData.sell_equip 删 items + 加 gold。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_sell_returns_income() -> void:
	var pd := PlayerData.new(cm)
	pd.add_item(101, 5)
	var sell_price := int(cm.get_raw_table(&"Equip").get("101", {}).get("Sell Price", 0))
	var income := pd.sell_equip(101, 2)
	assert_eq(income, sell_price * 2, "收入 = Sell Price × 数量")
	assert_eq(int(pd.items.get(101, 0)), 3, "items 扣 2")
	assert_eq(pd.hero_manager.gold, sell_price * 2, "hero_manager.gold += income")


func test_sell_insufficient_fails() -> void:
	var pd := PlayerData.new(cm)
	assert_eq(pd.sell_equip(101, 1), -1, "无库存 → -1")
	assert_eq(pd.sell_equip(101, 0), -1, "count<=0 → -1")
