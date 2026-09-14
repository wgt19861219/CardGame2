extends GutTest
# Phase 6 equipdetail 查询测试（2026-07-05 第 26 段）。
# 照源 equipdetail.lua getEquipData :85-134 + createDetail 获取途径段 :234-294。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 找一个有 Drop 1 的装备 id（get_way 非空场景）。
func _find_equip_with_drop() -> int:
	var raw: Dictionary = cm.get_raw_table(&"Equip")
	for tid_str in raw:
		if int(raw[tid_str].get("Drop 1", 0)) > 0:
			return int(tid_str)
	return 0


# 找一个作为 Equipcraft Component 的装备 id（equip_list 非空场景）。
func _find_equip_in_component() -> int:
	var craft: Dictionary = cm.get_raw_table(&"Equipcraft")
	var equip: Dictionary = cm.get_raw_table(&"Equip")
	for tid_str in craft:
		var row: Dictionary = craft[tid_str]
		for i in range(1, 5):
			var comp: int = int(row.get("Component" + str(i), 0))
			if comp > 0 and not bool(equip.get(str(comp), {}).get("Hide", false)):
				return comp
	return 0


func test_query_returns_four_fields() -> void:
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_with_drop()
	assert_gt(eid, 0, "存在有 Drop 的装备")
	var result: Dictionary = EquipdetailQuery.query(eid, cm, pd)
	assert_true(result.has("equip_list"), "有 equip_list")
	assert_true(result.has("hero_list"), "有 hero_list")
	assert_true(result.has("get_way"), "有 get_way")
	assert_true(result.has("how_to_get"), "有 how_to_get")


func test_get_way_from_drop() -> void:
	var eid: int = _find_equip_with_drop()
	assert_gt(eid, 0, "存在有 Drop 的装备")
	var pd := PlayerData.new(cm)
	var result: Dictionary = EquipdetailQuery.query(eid, cm, pd)
	var get_way: Array = result["get_way"]
	assert_true(get_way.size() > 0, "Drop 1 → get_way 非空")
	var first: Dictionary = get_way[0]
	assert_true(first.has("id") and first.has("name"), "get_way item 含 {id, name}")


func test_get_way_filters_overmax_chapter() -> void:
	# 所有返回的 get_way，其 Stage Chapter ID 必须 <= MaxChapter（源 :239 Hide Stage > MaxChapter）。
	var pd := PlayerData.new(cm)
	var stage: Dictionary = cm.get_raw_table(&"Stage")
	var max_chapter: int = int(cm.get_raw_table(&"GameConfig").get("MaxChapter", 13))
	var eid: int = _find_equip_with_drop()
	var result: Dictionary = EquipdetailQuery.query(eid, cm, pd)
	for way in result["get_way"]:
		var drop_id: int = int((way as Dictionary)["id"])
		var chapter: int = int(stage.get(str(drop_id), {}).get("Chapter ID", 0))
		assert_lte(chapter, max_chapter, "get_way Chapter <= MaxChapter")


func test_equip_compose_list_from_component() -> void:
	var comp_id: int = _find_equip_in_component()
	assert_gt(comp_id, 0, "存在 Equipcraft Component 装备")
	var pd := PlayerData.new(cm)
	var result: Dictionary = EquipdetailQuery.query(comp_id, cm, pd)
	assert_true((result["equip_list"] as Array).size() > 0, "Component 装备 → equip_list 非空")


func test_hero_list_subset_of_owned() -> void:
	# hero_list 中所有英雄都应在已召唤英雄集合（单机化简化：仅已召唤）。
	var pd := PlayerData.new(cm)
	var eid: int = _find_equip_with_drop()
	var result: Dictionary = EquipdetailQuery.query(eid, cm, pd)
	var hero_list: Array = result["hero_list"]
	if hero_list.is_empty():
		assert_true(true, "该装备无 drop 英雄（hero_list 空，跳过子集校验）")
	for hero in hero_list:
		var hero_dict: Dictionary = hero
		assert_true(pd.hero_manager.heroes.has(int(hero_dict["id"])), "hero_list 英雄都在已召唤集合")


func test_how_to_get_text() -> void:
	var pd := PlayerData.new(cm)
	var raw: Dictionary = cm.get_raw_table(&"Equip")
	var eid_with_text: int = 0
	for tid_str in raw:
		if String(raw[tid_str].get("How To Get", "")) != "":
			eid_with_text = int(tid_str)
			break
	if eid_with_text > 0:
		var result: Dictionary = EquipdetailQuery.query(eid_with_text, cm, pd)
		assert_true(String(result["how_to_get"]) != "", "How To Get 文本返回")
	else:
		assert_true(true, "无 How To Get 样本")


# P2-三轮-5：GameConfig.json 曾为空 `{}`（ConfigManager._load_table 空{}早返 → 永走 fallback 13）。
# 填表后从 GameConfig 表读 MaxChapter（源 GameConfig.lua:3 =13），源值变更可跟随。
func test_gameconfig_maxchapter_from_table() -> void:
	var gc: Dictionary = cm.get_raw_table(&"GameConfig")
	assert_true(gc.has("MaxChapter"), "GameConfig 表非空含 MaxChapter（非 ConfigManager 空{}早返）")
	assert_eq(int(gc["MaxChapter"]), 13, "MaxChapter=13（源 GameConfig.lua:3）")


# P1-12：get_way 含 res（关卡图标路径 StageRes.get_stage_icon，源 :245）。
func test_get_way_has_res_icon() -> void:
	var eid: int = _find_equip_with_drop()
	assert_gt(eid, 0, "存在有 Drop 的装备")
	var pd := PlayerData.new(cm)
	var result: Dictionary = EquipdetailQuery.query(eid, cm, pd)
	var get_way: Array = result["get_way"]
	assert_true(get_way.size() > 0, "get_way 非空")
	var first: Dictionary = get_way[0]
	assert_true(first.has("res"), "get_way item 含 res（关卡图标路径）")
	var res_path: String = String(first["res"])
	assert_true(res_path.begins_with("res://assets/ui/alpha/HVGA/key_stages/stage-"), "res 是 key_stages/stage-N 路径")
	assert_true(ResourceLoader.exists(res_path), "res 资源存在（key_stages 关卡图标）")


# === plusSign/canDealTag 查询（源 heroitem.lua:218-248 + tools.lua:573-595/805-809）===
# 服务 HeroPackageItem._create_equips 空槽 + 号显示判定。

# 找一个 Hero_equip 表中某英雄 rank=1 行的 Equip1 ID（plusSign 查询典型样本）。
func _find_hero_equip_slot1() -> Dictionary:
	var hero_equip: Dictionary = cm.get_raw_table(&"Hero_equip")
	for tid_str in hero_equip:
		var rank1: Dictionary = hero_equip[tid_str].get("1", {})
		var eid: int = int(rank1.get("Equip1 ID", 0))
		if eid > 0:
			return {"tid": int(tid_str), "eid": eid}
	return {"tid": 0, "eid": 0}


# 源 heroitem.lua:219-223 — hero_equip[tid][rank]["Equip{slot} ID"]。
func test_get_slot_expected_equip_returns_id() -> void:
	var sample: Dictionary = _find_hero_equip_slot1()
	if int(sample["tid"]) == 0:
		pending("Hero_equip 表无 rank1 Equip1 样本，跳过")
		return
	var hero := HeroInstance.new(int(sample["tid"]))
	hero.rank = 1
	var eid: int = EquipdetailQuery.get_slot_expected_equip(hero, 1, cm)
	assert_eq(eid, int(sample["eid"]), "slot 1 eid 与 Hero_equip 表 rank1 Equip1 ID 一致")


func test_get_slot_expected_equip_invalid_slot_zero() -> void:
	var hero := HeroInstance.new(1)
	hero.rank = 1
	assert_eq(EquipdetailQuery.get_slot_expected_equip(hero, 0, cm), 0, "slot 0 越界 → 0")
	assert_eq(EquipdetailQuery.get_slot_expected_equip(hero, 7, cm), 0, "slot 7 越界 → 0（EQUIP_SLOTS=6）")


# 源 tools.lua:573-595 isEquipCraftable — eid<=0 直接 false。
func test_is_equip_craftable_zero_eid_false() -> void:
	var pd := PlayerData.new(cm)
	assert_false(EquipdetailQuery.is_equip_craftable(0, cm, pd), "eid=0 → false")
	assert_false(EquipdetailQuery.is_equip_craftable(-1, cm, pd), "eid<0 → false")


# 持有装备（pd.items[eid]>0）→ craftable=true（源 :576 has 优先）。
func test_is_equip_craftable_with_inventory_true() -> void:
	var sample: Dictionary = _find_hero_equip_slot1()
	if int(sample["eid"]) == 0:
		pending("无可用 eid 样本，跳过")
		return
	var pd := PlayerData.new(cm)
	pd.items[int(sample["eid"])] = 1
	assert_true(EquipdetailQuery.is_equip_craftable(int(sample["eid"]), cm, pd), "持有该装备 → craftable=true")


# pd=null + 配方 Components>0 → true（简化版，与 equip_craft_panel._is_craftable 对齐）。
func test_is_equip_craftable_null_pd_uses_recipe() -> void:
	var craft: Dictionary = cm.get_raw_table(&"Equipcraft")
	var eid_with_components: int = 0
	for tid_str in craft:
		if int(craft[tid_str].get("Components", 0)) > 0:
			eid_with_components = int(tid_str)
			break
	if eid_with_components == 0:
		pending("Equipcraft 表无 Components>0 样本，跳过")
		return
	assert_true(EquipdetailQuery.is_equip_craftable(eid_with_components, cm, null), "pd=null + Components>0 → true")


# 源 tools.lua:805-809 canWearEquip — hero.level >= Equip[eid]["Level Requirement"]。
func test_can_wear_equip_level_meets() -> void:
	var sample: Dictionary = _find_hero_equip_slot1()
	if int(sample["eid"]) == 0:
		pending("无可用 eid 样本，跳过")
		return
	var hero := HeroInstance.new(int(sample["tid"]))
	hero.level = 99   # 远超任何 Level Requirement
	var result: Dictionary = EquipdetailQuery.can_wear_equip(hero, int(sample["eid"]), cm)
	assert_true(bool(result["can"]), "level=99 应满足 Level Requirement")


func test_can_wear_equip_level_not_meet() -> void:
	var raw: Dictionary = cm.get_raw_table(&"Equip")
	var eid_high_level: int = 0
	var high_req: int = 50
	for tid_str in raw:
		var req: int = int(raw[tid_str].get("Level Requirement", 0))
		if req >= high_req:
			eid_high_level = int(tid_str)
			high_req = req
			break
	if eid_high_level == 0:
		pending("无 Level Requirement>=50 装备样本，跳过")
		return
	var hero := HeroInstance.new(1)
	hero.level = 1
	var result: Dictionary = EquipdetailQuery.can_wear_equip(hero, eid_high_level, cm)
	assert_false(bool(result["can"]), "level=1 < Level Requirement → can=false")


# eid<=0 兜底（can_wear_equip null hero/eid<=0 → can=false）。
func test_can_wear_equip_zero_eid_false() -> void:
	var hero := HeroInstance.new(1)
	var result: Dictionary = EquipdetailQuery.can_wear_equip(hero, 0, cm)
	assert_false(bool(result["can"]), "eid=0 → can=false")


# === 2026-09-14 根修：is_equip_craftable 补齐源 tools.lua:573-593 递归材料判定 ===
# 用户实机反馈：小鹿（tid=45）rank2 第4槽配方回复之巾（Equip 123），缺卷轴（117）装备槽仍显绿+。
# 旧实现只判配方存在（Components>0）恒 true（漏译源 getMaterials 递归）；表数据实证：
# 回复之巾 123 = 卷轴 117 + 回复戒指 111 + 树枝 101（三者皆无配方的叶子材料，各需 max(Count,1)=1）。

func test_is_equip_craftable_missing_material_false() -> void:
	var pd := PlayerData.new(cm)
	pd.items[111] = 1
	pd.items[101] = 1   # 缺卷轴 117
	assert_false(EquipdetailQuery.is_equip_craftable(123, cm, pd), "缺卷轴 117 → false（源递归材料判定）")


func test_is_equip_craftable_all_base_materials_true() -> void:
	var pd := PlayerData.new(cm)
	pd.items[117] = 1
	pd.items[111] = 1
	pd.items[101] = 1
	assert_true(EquipdetailQuery.is_equip_craftable(123, cm, pd), "材料齐（117/111/101 各 1）→ true")


# 递归链：201 = 119(可合成) + 120(可合成)；119 = 115+103+106、120 = 105+110（全叶子）。
# 持有 0 个中间组件时按源 getMaterials 递归展开叶子需求，缺任一叶子 → false。
func test_is_equip_craftable_recursive_chain() -> void:
	var pd := PlayerData.new(cm)
	pd.items[103] = 1
	pd.items[106] = 1
	pd.items[105] = 1
	pd.items[110] = 1   # 缺叶子 115（119 的组件）
	assert_false(EquipdetailQuery.is_equip_craftable(201, cm, pd), "子链缺叶子 115 → false")
	pd.items[115] = 1
	assert_true(EquipdetailQuery.is_equip_craftable(201, cm, pd), "叶子全补齐（115/103/106/105/110）→ true")


# 持有中间组件 119 一个 → 直接消耗（源 getMaterials cs 账本），只需再补 120 链叶子。
func test_is_equip_craftable_consume_owned_component() -> void:
	var pd := PlayerData.new(cm)
	pd.items[119] = 1
	pd.items[105] = 1
	pd.items[110] = 1   # 120 铘叶子齐
	assert_true(EquipdetailQuery.is_equip_craftable(201, cm, pd), "持 119 + 120 链叶子齐 → true")


# === get_hero_equip_state 角标（源 herodetail/controller.lua:207-233 + 受控偏离）===
# 2026-09-14 受控偏离（用户拍板）：材料不足（源 notHave）源不画角标，本项目改显黄+
# （eti=cannotwear）——绿+ 只留给"持有可穿/材料齐全可合成可穿"。

# 小鹿 45 rank2 slot4（0-based=3）配方 = 回复之巾 123（Level Requirement=10）。
func _make_fawn_rank2() -> HeroInstance:
	var hero := HeroInstance.new(45)
	hero.rank = 2
	hero.level = 99   # 等级远超 10，排除 cannotwear(等级) 干扰
	return hero


func test_get_hero_equip_state_missing_materials_yellow_plus() -> void:
	var pd := PlayerData.new(cm)
	pd.items[111] = 1
	pd.items[101] = 1   # 缺卷轴 117
	var state: Dictionary = EquipdetailQuery.get_hero_equip_state(_make_fawn_rank2(), 3, cm, pd)
	assert_eq(String(state["ett"]), "notHave", "缺卷轴 → notHave")
	assert_eq(String(state["eti"]), "cannotwear", "缺材料 → 黄+（受控偏离：源不画角标，用户拍板显黄）")


func test_get_hero_equip_state_all_materials_green_plus() -> void:
	var pd := PlayerData.new(cm)
	pd.items[117] = 1
	pd.items[111] = 1
	pd.items[101] = 1
	var state: Dictionary = EquipdetailQuery.get_hero_equip_state(_make_fawn_rank2(), 3, cm, pd)
	assert_eq(String(state["ett"]), "canCraft", "材料齐 → canCraft")
	assert_eq(String(state["eti"]), "wear", "材料齐 + 等级够 → 绿+")
