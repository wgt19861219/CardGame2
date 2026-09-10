extends GutTest
# Phase 6 package 复刻 Logic 地基：EquipmentClassifier.classify 测试（2026-07-05 第 22 段）。
# 照源 readequip.classify（readequip.lua:416-480）：双容器分流 + Category 分 tab + 碎片反查。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 从 Equip 表动态取某 Category 的一个 id（避免硬编码 id 脆弱）。
func _find_equip_id_by_category(category: String) -> int:
	var raw: Dictionary = cm.get_raw_table(&"Equip")
	for tid_str in raw:
		if String(raw[tid_str].get(&"Category", "")) == category:
			return int(tid_str)
	return 0


# 从 Fragment 表取一个英雄产物配方（key<100）：{tid, frag_id}。
func _find_hero_fragment_recipe() -> Dictionary:
	var raw: Dictionary = cm.get_raw_table(&"Fragment")
	for tid_str in raw:
		if int(tid_str) < 100:
			return {"tid": int(tid_str), "frag_id": int(raw[tid_str].get(&"Fragment ID", 0))}
	return {}


# ── prop 分流（items → Category → tab）──

func test_classify_prop_equip_parts() -> void:
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_id_by_category("EQUIP.PARTS")
	assert_gt(eid, 0, "PARTS 装备 id 存在")
	pd.add_item(eid, 3)
	var r: Dictionary = EquipmentClassifier.classify(pd, cm)
	var prop: Dictionary = r["prop"]
	assert_eq((prop["equip"] as Array).size(), 1, "PARTS → prop.equip")
	assert_eq((prop["all"] as Array).size(), 1, "PARTS → prop.all")
	var cell: Dictionary = (prop["equip"] as Array)[0]
	assert_eq(int(cell["id"]), eid, "cell.id")
	assert_eq(int(cell["amount"]), 3, "cell.amount")
	assert_eq(int(cell["type"]), 1, "type=1 prop")
	assert_eq(int(cell["makeId"]), eid, "prop makeId=id")


func test_classify_prop_reel_to_scroll() -> void:
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_id_by_category("EQUIP.REEL")
	assert_gt(eid, 0, "REEL 卷轴 id 存在")
	pd.add_item(eid, 2)
	var r: Dictionary = EquipmentClassifier.classify(pd, cm)
	assert_eq((r["prop"]["scroll"] as Array).size(), 1, "REEL → prop.scroll")
	assert_eq((r["prop"]["equip"] as Array).size(), 0, "REEL 不进 prop.equip")


func test_classify_prop_soul_stone() -> void:
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_id_by_category("EQUIP.SOUL_STONE")
	assert_gt(eid, 0, "SOUL_STONE id 存在")
	pd.add_item(eid, 1)
	var r: Dictionary = EquipmentClassifier.classify(pd, cm)
	assert_eq((r["prop"]["stone"] as Array).size(), 1, "SOUL_STONE → prop.stone")


func test_classify_prop_consumables() -> void:
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_id_by_category("EQUIP.CONSUMABLES")
	assert_gt(eid, 0, "CONSUMABLES id 存在")
	pd.add_item(eid, 5)
	var r: Dictionary = EquipmentClassifier.classify(pd, cm)
	assert_eq((r["prop"]["consume"] as Array).size(), 1, "CONSUMABLES → prop.consume")


# ── fragment 分流（fragments 反查 Fragment 表）──

func test_classify_fragment_hero() -> void:
	var pd := PlayerData.new(cm)
	var recipe: Dictionary = _find_hero_fragment_recipe()
	assert_false(recipe.is_empty(), "Fragment 表有英雄产物配方")
	var tid: int = int(recipe["tid"])
	var frag_id: int = int(recipe["frag_id"])
	assert_gt(frag_id, 0, "Fragment ID 存在")
	pd.hero_manager.add_fragment(frag_id, 5)
	var r: Dictionary = EquipmentClassifier.classify(pd, cm)
	var fragment: Dictionary = r["fragment"]
	assert_eq((fragment["hero"] as Array).size(), 1, "英雄碎片 → fragment.hero")
	assert_eq((fragment["all"] as Array).size(), 1, "碎片 → fragment.all")
	var cell: Dictionary = (fragment["hero"] as Array)[0]
	assert_eq(int(cell["id"]), frag_id, "cell.id = Fragment ID")
	assert_eq(int(cell["makeId"]), tid, "makeId = 产物 tid")
	assert_eq(String(cell["category"]), "BATTLE.HERO", "category = BATTLE.HERO（按 itemType）")
	assert_eq(int(cell["type"]), 2, "type=2 fragment")
	assert_true(int(cell["needAmount"]) > 0, "needAmount 反查 Fragment Count")


# ── 单账本分流（2026-09-09 根修：独立 fragments 容器退役，碎片计数即 pd.items）──
# 装备碎片（Category=FRAGMENT）不进 prop 页、经 Fragment 表命中进 fragment 页（源 type 语义）。

# 从 Fragment 表取一个装备产物配方（tid>=100）：{tid, frag_id}（其 Equip.Category=FRAGMENT）。
func _find_equip_fragment_recipe() -> Dictionary:
	var raw: Dictionary = cm.get_raw_table(&"Fragment")
	for tid_str in raw:
		if int(tid_str) >= 100:
			return {"tid": int(tid_str), "frag_id": int(raw[tid_str].get(&"Fragment ID", 0))}
	return {}


func test_classify_single_ledger_split() -> void:
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_id_by_category("EQUIP.PARTS")
	var recipe: Dictionary = _find_equip_fragment_recipe()
	assert_false(recipe.is_empty(), "Fragment 表有装备产物配方")
	var frag_id: int = int(recipe["frag_id"])
	pd.add_item(eid, 1)
	pd.add_item(frag_id, 1)
	var r: Dictionary = EquipmentClassifier.classify(pd, cm)
	assert_eq((r["prop"]["all"] as Array).size(), 1, "装备碎片（FRAGMENT 类）不进 prop 页，prop 只收普通物品")
	assert_eq((r["fragment"]["all"] as Array).size(), 1, "装备碎片经 Fragment 表命中 → fragment 页（同账本）")


func test_classify_filter_zero_amount() -> void:
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_id_by_category("EQUIP.PARTS")
	pd.items[eid] = 0   # amount=0（源 :462 v.amount > 0 过滤）
	var r: Dictionary = EquipmentClassifier.classify(pd, cm)
	assert_eq((r["prop"]["all"] as Array).size(), 0, "amount=0 不显")


func test_classify_empty_player() -> void:
	var pd := PlayerData.new(cm)
	var r: Dictionary = EquipmentClassifier.classify(pd, cm)
	assert_eq((r["prop"]["all"] as Array).size(), 0, "空玩家 prop.all 空")
	assert_eq((r["fragment"]["all"] as Array).size(), 0, "空玩家 fragment.all 空")
