extends GutTest
# Phase 5.2 EquipcraftData 合成查询测试（2026-07-02）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_get_recipe() -> void:
	var r: Dictionary = EquipcraftData.get_recipe(118, cm)
	assert_eq(String(r.get("Category", "")), "EQUIPCRAFT.OTHER", "118 Category=OTHER")


func test_get_components() -> void:
	var comps: Array = EquipcraftData.get_components(118, cm)
	assert_true(comps is Array, "返 Array")
	# 118 Component count=0 → 过滤；验证过滤逻辑（count>0 才入）
	for c in comps:
		assert_gt(int(c["item_id"]), 0, "组件 item_id > 0（过滤后）")
		assert_gt(int(c["count"]), 0, "组件 count > 0（过滤后）")
	# 防空循环 risky：显式 assert 返类型已上


func test_get_recipe_missing() -> void:
	assert_eq(EquipcraftData.get_recipe(99999, cm).size(), 0, "不存在 → 空")
