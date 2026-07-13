class_name EquipcraftData
extends RefCounted

## 装备合成数据查询（Data 层）— 照源 Equipcraft 表翻译（Phase 5.2 续，2026-07-02）。

const COMPONENT_COUNT: int = 4  # Component1-4（源 Equipcraft 组件槽）


# 源 Equipcraft[target_id] = {Component1-4 + Count, Category, ...}。
static func get_recipe(target_id: int, cm: Variant) -> Dictionary:
	return cm.get_raw_table("Equipcraft").get(str(target_id), {})


# 合成组件列表 [{item_id, count}]（Component1-4，过滤 0/空）。
static func get_components(target_id: int, cm: Variant) -> Array:
	var recipe: Dictionary = get_recipe(target_id, cm)
	var comps: Array = []
	for i in range(1, COMPONENT_COUNT + 1):
		var item_id: int = int(recipe.get("Component" + str(i), 0))
		var count: int = int(recipe.get("Component" + str(i) + " Count", 0))
		if item_id > 0 and count > 0:
			comps.append({"item_id": item_id, "count": count})
	return comps


static func get_category(target_id: int, cm: Variant) -> String:
	return String(get_recipe(target_id, cm).get("Category", ""))
