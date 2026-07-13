extends GutTest
# StageSelectMap 数据层测试（照源 stageselectres.map + stageselect.getStageRes）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func before_each() -> void:
	StageSelectMap.clear_cache()


func _zero(_sid: int) -> int:
	return 0


# 数据层：14 章齐 + stage 数 + key boss eid
func test_load_map_has_14_chapters() -> void:
	var m: Dictionary = StageSelectMap.load_map()
	for i in range(1, 15):
		assert_true(m.has("chapter" + str(i)), "chapter" + str(i) + " 存在")


func test_chapter1_stage_count_and_first() -> void:
	var stages: Array = StageSelectMap.get_stages(1)
	assert_eq(stages.size(), 18, "chapter1 18 关")
	assert_eq(int(stages[0]["id"]), 1, "stage0 id=1")
	assert_eq(int(stages[0].get("eid", 0)), 10001, "stage0 eid=10001（key boss）")


# chapter13 stage0 源 ccp(89, 317-20) → y=297（算术转换正确性）
func test_chapter13_arithmetic_pos() -> void:
	var stages: Array = StageSelectMap.get_stages(13)
	assert_eq(float(stages[0]["pos"][1]), 297.0, "chapter13 stage0 y=317-20=297")


func test_tag_and_guild_instance() -> void:
	assert_eq(StageSelectMap.get_tag(1), 1, "ch1 tag=1")
	assert_eq(StageSelectMap.get_tag(13), 6, "ch13 tag=6")
	assert_false(StageSelectMap.is_guild_instance_chapter(1), "ch1 非 guild")
	assert_true(StageSelectMap.is_guild_instance_chapter(7), "ch7 guild 章节")


func test_bg_res_path_conversion() -> void:
	var r: String = StageSelectMap.get_bg_res(1)
	assert_true(r.ends_with("stageselect_map_bg_1.jpg"), "bg res 转换")
	assert_true(r.begins_with("res://assets/ui/"), "前缀正确")


# icon 决策：normal 非 key 三态
func test_normal_nonkey_locked_skeleton() -> void:
	var info: Dictionary = {"id": 5, "pos": [100, 100], "is_key": false}
	var r: Dictionary = StageSelectMap.decide_stage_icon(info, 1, "normal", cm, _zero)
	assert_eq(r["type"], "locked", "非 key 未开 locked")
	assert_true(String(r["icon"]).ends_with("stagecircle_skeleton1.png"), "skeleton by tag")


func test_normal_nonkey_current_circle() -> void:
	# star(5)=0 但 star(4)=3 → 前置已通 → current
	var info: Dictionary = {"id": 5, "pos": [100, 100], "is_key": false}
	var star_of: Callable = func(s: int) -> int: return 3 if s == 4 else 0
	var r: Dictionary = StageSelectMap.decide_stage_icon(info, 1, "normal", cm, star_of)
	assert_eq(r["type"], "current", "前置通当前关 current")
	assert_true(String(r["icon"]).ends_with("stagecircle_current.png"))


func test_normal_nonkey_passed() -> void:
	var info: Dictionary = {"id": 5, "pos": [100, 100], "is_key": false}
	var star_of: Callable = func(_s: int) -> int: return 3
	var r: Dictionary = StageSelectMap.decide_stage_icon(info, 1, "normal", cm, star_of)
	assert_eq(r["type"], "passed", "有星 passed")


# icon 决策：normal key_stage 三态（id=1 无前置锁 → star0=current）
func test_normal_key_stage_current() -> void:
	var info: Dictionary = {"id": 1, "pos": [172, 284], "eid": 10001, "is_key": true}
	var r: Dictionary = StageSelectMap.decide_stage_icon(info, 1, "normal", cm, _zero)
	assert_eq(r["type"], "current", "key id=1 star0 → current（无前置锁）")
	assert_true(String(r["icon"]).begins_with("res://assets/ui/alpha/HVGA/key_stages/stage-"), "key boss 图")
	assert_eq(String(r["mask"]), StageSelectMap.MASK_CURRENT, "current mask")


func test_normal_key_stage_locked_with_resid() -> void:
	# id=2 key，star(2)=0 star(1)=0 → locked（resid=7 用 stage-7-locked）
	var info: Dictionary = {"id": 2, "pos": [100, 100], "is_key": true, "resid": 7}
	var r: Dictionary = StageSelectMap.decide_stage_icon(info, 1, "normal", cm, _zero)
	assert_eq(r["type"], "locked", "key 前置都无星 locked")
	assert_true(String(r["icon"]).ends_with("stage-7-locked.png"), "resid=7 key locked 图")


func test_normal_key_stage_passed() -> void:
	var info: Dictionary = {"id": 1, "pos": [172, 284], "is_key": true}
	var star_of: Callable = func(_s: int) -> int: return 3
	var r: Dictionary = StageSelectMap.decide_stage_icon(info, 1, "normal", cm, star_of)
	assert_eq(r["type"], "passed", "key 有星 passed")
	assert_eq(String(r["mask"]), StageSelectMap.MASK_PASSED)


# elite 非 key 一律 locked（源 :1011）
func test_elite_nonkey_locked() -> void:
	var info: Dictionary = {"id": 5, "pos": [100, 100], "is_key": false}
	var r: Dictionary = StageSelectMap.decide_stage_icon(info, 1, "elite", cm, _zero)
	assert_eq(r["type"], "locked", "elite 非 key locked")
	assert_true(String(r["icon"]).ends_with("stagecircle_elite.png"))
