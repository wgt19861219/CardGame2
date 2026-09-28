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
	assert_eq(EquipCraftManager.synthesize_equip(pd, 118), true, "合成成功")
	assert_eq(int(pd.items.get(118, 0)), 1, "产出 target_id 进 items 背包")
	assert_eq(int(pd.items.get(114, 0)), 0, "基础材料消耗")
	assert_eq(pd.hero_manager.gold, 700, "扣 Expense 300 金币")


func test_synthesize_fails_without_materials() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_money(1000)
	assert_eq(EquipCraftManager.synthesize_equip(pd, 118), false, "缺基础材料 → false")


func test_synthesize_fails_without_gold() -> void:
	var pd := PlayerData.new(cm)
	pd.add_item(114, 1)
	pd.add_item(104, 1)
	pd.add_item(106, 1)
	assert_eq(EquipCraftManager.synthesize_equip(pd, 118), false, "金币不足 → false")


# P2-3（2026-09-28 审查）：synthesize_equip 的 pre_allocated 语义——外部已占用的
# 材料（autowear 第一遍 wear 槽计划）对合成不可见，防预检/执行两本账致穿戴段负库存。
# Equipcraft 118 需 114/104/106 各 1；114 无配方 → 占用后不可递归补足应拒单。
func test_synthesize_respects_pre_allocated() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_money(1000)
	pd.add_item(114, 1)
	pd.add_item(104, 1)
	pd.add_item(106, 1)
	assert_eq(EquipCraftManager.synthesize_equip(pd, 118, {114: 1}), false, "114 被 wear 槽占用 → 拒绝合成")
	assert_eq(int(pd.items.get(114, 0)), 1, "拒单不动材料")
	assert_eq(pd.hero_manager.gold, 1000, "拒单不扣金币")
	assert_eq(EquipCraftManager.synthesize_equip(pd, 118), true, "不占用则正常合成")
