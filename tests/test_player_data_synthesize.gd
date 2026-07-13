extends GutTest
# 装备合成 Logic（照源 local_server:1026-1057 collectCraftChain 递归 + :1059-1115 equip_synthesis）。
# PlayerData.synthesize_equip 递归收集材料（自动合成前置）+ 扣金币+基础材料 + 产出进 items 背包。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# Equipcraft 118: Component1=114,2=104,3=106（各需1，Count0→1），Expense=300。
func test_synthesize_consumes_materials() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_money(1000)
	pd.add_item(114, 1)
	pd.add_item(104, 1)
	pd.add_item(106, 1)
	assert_eq(pd.synthesize_equip(118), true, "合成成功")
	assert_eq(int(pd.items.get(118, 0)), 1, "产出 target_id 进 items 背包")
	assert_eq(int(pd.items.get(114, 0)), 0, "基础材料消耗")
	assert_eq(pd.hero_manager.gold, 700, "扣 Expense 300 金币")


func test_synthesize_fails_without_materials() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_money(1000)
	assert_eq(pd.synthesize_equip(118), false, "缺基础材料 → false")


func test_synthesize_fails_without_gold() -> void:
	var pd := PlayerData.new(cm)
	pd.add_item(114, 1)
	pd.add_item(104, 1)
	pd.add_item(106, 1)
	assert_eq(pd.synthesize_equip(118), false, "金币不足 → false")
