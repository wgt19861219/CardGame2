extends GutTest
# Phase 5.2 readequip_data 装备查询测试（2026-07-02）。
# 验 ReadequipData.get_hero_item + get_equip_gs/attrib。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_get_hero_item_empty() -> void:
	var hero := HeroInstance.new(1, 1, 1)   # equip_slots 默认 [0,0,0,0,0,0]
	assert_eq(ReadequipData.get_hero_item(hero, 0), 0, "默认空槽 → 0")


func test_get_hero_item_set() -> void:
	var hero := HeroInstance.new(1, 1, 1)
	hero.equip_slots[0] = 100
	assert_eq(ReadequipData.get_hero_item(hero, 0), 100, "slot 0 设 item_id=100 → 100")


func test_get_hero_item_invalid_slot() -> void:
	var hero := HeroInstance.new(1, 1, 1)
	assert_eq(ReadequipData.get_hero_item(hero, 99), 0, "越界 slot → 0")
	assert_eq(ReadequipData.get_hero_item(hero, -1), 0, "负 slot → 0")


func test_get_hero_item_null() -> void:
	assert_eq(ReadequipData.get_hero_item(null, 0), 0, "hero null → 0")


func test_get_equip_gs() -> void:
	# equip id=101 +GS=2.7
	assert_almost_eq(ReadequipData.get_equip_gs(101, cm), 2.7, 0.01, "equip 101 +GS=2.7")


func test_get_equip_attrib() -> void:
	# equip id=101 +AGI=1
	assert_almost_eq(ReadequipData.get_equip_attrib(101, "+AGI", cm), 1.0, 0.01, "equip 101 +AGI=1")
	assert_eq(ReadequipData.get_equip_attrib(99999, "+AGI", cm), 0.0, "不存在 item → 0")


# 源 getEquipLevelExp :244-260 — Enhancement[Quality] le/ml。
func test_get_equip_level_exp() -> void:
	var info: Dictionary = ReadequipData.get_equip_level_exp(101, cm)
	var ml: int = int(info["ml"])
	var le: Array = info["le"]
	# equip 101 Quality=1 → Enhancement[1] Max Level=0（品质 1 不可强化，数据特性）
	assert_eq(ml, 0, "equip 101 Quality=1 → Enhancement[1] Max Level=0（品质 1 不可强化）")
	assert_eq(le.size(), ml, "le 数量 = ml")


# 源 getEquipLevel :262-278 — exp=0 → level 0；exp 大 → level ml。
func test_get_equip_level() -> void:
	var r0: Dictionary = ReadequipData.get_equip_level(101, 0.0, cm)
	assert_eq(int(r0["level"]), 0, "exp=0 → level 0（未强化）")
	var ml: int = int(ReadequipData.get_equip_level_exp(101, cm)["ml"])
	var rmax: Dictionary = ReadequipData.get_equip_level(101, 99999.0, cm)
	assert_eq(int(rmax["level"]), ml, "exp 大 → level ml")


# 源 getHeroEquipgs :50-65 — sum(+GS * level)。无装备→0；有装备未强化→0（level 0）。
func test_get_hero_equip_gs() -> void:
	var hero := HeroInstance.new(1, 1, 1)
	assert_eq(ReadequipData.get_hero_equip_gs(hero, cm), 0.0, "无装备 → 0")
	hero.equip_slots[0] = 101   # Quality=1 → ml=0 → level 0
	assert_eq(ReadequipData.get_hero_equip_gs(hero, cm), 0.0, "equip 101（品质1不可强化）→ gs 0")
	hero.equip_slots.clear()
	hero.equip_slots = []   # 测 sum 逻辑（无装备）


# hero.equip_exp → exp_map 桥接。
func test_get_exp_map_from_hero() -> void:
	var hero := HeroInstance.new(1, 1, 1)
	hero.equip_exp[0] = 50.0
	hero.equip_exp[2] = 30.0
	var m: Dictionary = ReadequipData.get_exp_map_from_hero(hero)
	assert_eq(float(m[0]), 50.0, "slot 0 exp=50")
	assert_eq(float(m[2]), 30.0, "slot 2 exp=30")
	assert_eq(float(m.get(1, -1.0)), 0.0, "slot 1 默认 0")


# 装备强化（照源 ui/equipstrengthen + local_server：材料 Enhance Value 经验 + Unit Price 金币双消耗）。
# 品质 1 装备 Enhancement[1] Max Level=0 不可强化。
func test_enhance_equip_quality1_fails() -> void:
	var pd := PlayerData.new(cm)
	var iid: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(iid)
	hero.equip_slots[0] = 101   # Quality=1 → ml=0
	assert_eq(pd.enhance_equip(iid, 0, {101: 1}), false, "品质 1 装备不可强化（ml=0）")


# 强化成功：材料 Enhance Value 经验累积 + 扣 Unit Price×exp 金币 + 扣材料（照源 local_server:1436-1443）。
func test_enhance_equip_accumulates_exp() -> void:
	var pd := PlayerData.new(cm)
	var iid: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(iid)
	var target_id := _find_enhanceable()
	hero.equip_slots[0] = target_id
	pd.hero_manager.add_money(100000)
	pd.add_item(target_id, 10)
	var exp_before := float(hero.equip_exp[0])
	assert_eq(pd.enhance_equip(iid, 0, {target_id: 1}), true, "强化成功")
	assert_true(float(hero.equip_exp[0]) > exp_before, "exp 累积增加")
	assert_eq(int(pd.items.get(target_id, 0)), 9, "材料扣 1")


# 材料不足 → false，不扣材料/金币（照源材料校验前置）。
func test_enhance_equip_insufficient_material_fails() -> void:
	var pd := PlayerData.new(cm)
	var iid: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(iid)
	var target_id := _find_enhanceable()
	hero.equip_slots[0] = target_id
	pd.hero_manager.add_money(100000)
	assert_eq(pd.enhance_equip(iid, 0, {target_id: 1}), false, "材料不足 → false")
	assert_eq(int(pd.items.get(target_id, 0)), 0, "不扣材料")


# 辅助：找 Equip 表 Quality>=2 且 Enhancement Max Level>0 的 id（可强化）。
func _find_enhanceable() -> int:
	for tid in [102, 111, 191, 242]:
		if cm.has_entry(&"Equip", tid):
			var q := int(cm.get_raw_table(&"Equip").get(str(tid), {}).get("Quality", 0))
			if q >= 2 and int(cm.get_raw_table(&"Enhancement").get(str(q), {}).get("Max Level", 0)) > 0:
				return tid
	return 102


# 装备穿戴 wear_equip（照源 main.lua:1750：从 hero_equip[tid][rank] 查应穿装备，不传 item_id/不扣背包）。
func test_wear_equip() -> void:
	var mgr := HeroManager.new(cm)
	var iid: int = mgr.add_hero(1)
	var hero: HeroInstance = mgr.get_hero(iid)
	# Coco rank1 slot0 → hero_equip[1][1]["Equip1 ID"]=102
	assert_eq(mgr.wear_equip(iid, 0), true, "slot 0 穿戴（查 hero_equip 表）")
	assert_eq(int(hero.equip_slots[0]), 102, "Coco rank1 slot0 → equip 102")
	assert_eq(mgr.wear_equip(iid, 99), false, "越界 slot → false")


# get_description（照源 readequip.getDescription:74-130）：组合属性描述行（"力量 +100"）。
func test_get_description_returns_att_rows() -> void:
	var equip_id := 0
	for tid in cm.get_raw_table(&"Equip"):
		var row: Dictionary = cm.get_raw_table(&"Equip").get(tid, {})
		if float(row.get("STR", 0)) != 0.0:
			equip_id = int(tid)
			break
	assert_gt(equip_id, 0, "有 STR 属性的装备存在")
	var rows := ReadequipData.get_description(equip_id, 0, cm)
	assert_gt(rows.size(), 0, "get_description 返属性行")
	var first := rows[0] as Dictionary
	assert_true(String(first.get("att", "")).length() > 0, "首行 att 描述非空")


# ===== 第三十四轮 Step 5 钻石一键满级（照源 getFastStrenCost:1294 + upFastStren:701）=====

# 源 getFastStrenCost:1294-1304 exp=0 → up × Σ le（当前级全部 + 后续完整级）。
func test_get_fast_stren_cost_unenchanted() -> void:
	var target_id := _find_enhanceable()
	var q := int(cm.get_raw_table(&"Equip").get(str(target_id), {}).get("Quality", 0))
	var up := float(cm.get_raw_table(&"Enhancement").get(str(q), {}).get("One-Click Unit Price", 0))
	var le: Array = ReadequipData.get_equip_level_exp(target_id, cm)["le"]
	var total: float = 0.0
	for v in le:
		total += float(v)
	var expected: int = int(up * total)
	assert_eq(ReadequipData.get_fast_stren_cost(target_id, 0.0, cm), expected, "exp=0 → up×总经验")


# 满级 exp → cost=0（me-e=0 + 后续遍历空）。
func test_get_fast_stren_cost_maxed_zero() -> void:
	var target_id := _find_enhanceable()
	assert_eq(ReadequipData.get_fast_stren_cost(target_id, 999999.0, cm), 0, "满级 → cost 0")


# enhance_equip_to_max 成功：扣钻石 + equip_exp 设满级（照源 upFastStren op_type=2）。
func test_enhance_equip_to_max_success() -> void:
	var pd := PlayerData.new(cm)
	var iid: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(iid)
	var target_id := _find_enhanceable()
	hero.equip_slots[0] = target_id
	pd.add_diamond(999999)
	var dia_before: int = pd.diamond
	assert_eq(pd.enhance_equip_to_max(iid, 0), true, "钻石满级成功")
	var le: Array = ReadequipData.get_equip_level_exp(target_id, cm)["le"]
	var total: float = 0.0
	for v in le:
		total += float(v)
	assert_eq(float(hero.equip_exp[0]), total, "equip_exp 设为满级总经验")
	assert_true(pd.diamond < dia_before, "钻石消耗")


# 钻石不足 → false（源 _rmb < rmbCost toRecharge）。
func test_enhance_equip_to_max_no_diamond() -> void:
	var pd := PlayerData.new(cm)
	var iid: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(iid)
	var target_id := _find_enhanceable()
	hero.equip_slots[0] = target_id
	assert_eq(pd.enhance_equip_to_max(iid, 0), false, "钻石 0 → false")


# 已满级 → false（源 checkMaxLevel）。
func test_enhance_equip_to_max_max_level_blocked() -> void:
	var pd := PlayerData.new(cm)
	var iid: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(iid)
	var target_id := _find_enhanceable()
	hero.equip_slots[0] = target_id
	hero.equip_exp[0] = 999999   # 满级
	pd.add_diamond(999999)
	assert_eq(pd.enhance_equip_to_max(iid, 0), false, "满级 → false")
