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
