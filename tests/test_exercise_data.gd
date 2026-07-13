extends GutTest

## Exercise 数据层 + 查询方法验证（照源 exercise.lua:43-124/1133-1188）。
# 验证 ActStageGroupDungeon/StageDungeon 转换正确 + exercise_manager 8 查询方法。

var _cm: ConfigManager
var _mgr: ExerciseManager


func before_each() -> void:
	_cm = GameData.config
	if not _cm.is_loaded():
		_cm.load_all()
	_mgr = ExerciseManager.new()
	_mgr.setup(_cm)


# ===== 数据表转换正确性 =====

func test_actstagegroup_dungeon_loaded() -> void:
	assert_true(_cm.has_table(&"ActStageGroupDungeon"), "ActStageGroupDungeon 表加载")
	assert_true(_cm.has_entry(&"ActStageGroupDungeon", 50005), "50005 英雄副本组")
	var row: Dictionary = _cm.get_entry(&"ActStageGroupDungeon", 50005)
	assert_eq(int(row[&"DailyLimit"]), 1, "50005 DailyLimit=1")
	assert_eq(int(row[&"Difficulty"]), 2, "50005 Difficulty=2（英雄）")
	# Stages 是数组（源 {50013,50014,50015,0,0,0,0,0}）
	var stages: Array = row[&"Stages"]
	assert_eq(int(stages[0]), 50013, "50005 首关 50013")


func test_stagedungeon_84_variants() -> void:
	assert_true(_cm.has_table(&"StageDungeon"), "StageDungeon 表加载")
	assert_true(_cm.has_entry(&"StageDungeon", 50001), "静态 base 关")
	assert_true(_cm.has_entry(&"StageDungeon", 51001), "diff2 变体（+1000）")
	assert_true(_cm.has_entry(&"StageDungeon", 53001), "diff4 变体（+3000）")
	var v: Dictionary = _cm.get_entry(&"StageDungeon", 51001)
	assert_eq(int(v[&"Difficulty"]), 2, "51001 Difficulty=2")
	assert_eq(int(v[&"Vitality Cost"]), 16, "51001 Vit = 12+4（diffConfig[2].vitAdd）")
	assert_eq(int(v[&"Heroexp Reward"]), 300, "51001 Heroexp = floor(250*1.2)")


# ===== exercise_manager 查询方法 =====

func test_get_act_info_exp() -> void:
	# ActStageGroup 20001 = EXPLORE_THE_TIDAL_TEMPLE, DailyLimit=2
	var info: Dictionary = _mgr.get_act_info("exp")
	assert_eq(int(info["amount_limit"]), 2, "exp DailyLimit=2")
	assert_eq(str(info["name"]), "ACTSTAGEGROUP.EXPLORE_THE_TIDAL_TEMPLE")


func test_get_stages_exp() -> void:
	# 20001 Stages = {1:20001, 3:21001, 5:22001, 7:23001} → 4 难度，升序
	var stages: Array = _mgr.get_stages("exp")
	assert_eq(stages.size(), 4, "exp 4 难度")
	assert_eq(int(stages[0]["id"]), 20001, "升序首项 20001")
	assert_eq(int(stages[3]["id"]), 23001, "升序末项 23001")


func test_get_dungeon_stages_dg5() -> void:
	# dg5 → 50005，Stages=[50013,50014,50015] → 3 boss × 4 diff
	var bosses: Array = _mgr.get_dungeon_stages("dg5")
	assert_eq(bosses.size(), 3, "dg5 = 3 boss")
	var b0: Dictionary = bosses[0]
	assert_eq(int(b0["base_id"]), 50013, "首 boss 50013")
	var diffs: Array = b0["difficulties"]
	assert_eq(diffs.size(), 4, "4 难度")
	var d1: Dictionary = diffs[0]
	var d2: Dictionary = diffs[1]
	assert_eq(int(d2["diff"]), 2)
	assert_eq(int(d2["id"]), 51013, "diff2 id = 50013+1000")
	# vit 相对校验：diff2 = diff1 + 4（diffConfig[2].vitAdd），不依赖具体 base Vit
	assert_eq(int(d2["vit"]) - int(d1["vit"]), 4, "diff2 Vit = base + 4（diffConfig[2].vitAdd）")


func test_get_hero_limit_20005() -> void:
	# 20005 = GODDESS_SHOWDOWN, Limit Type=Gender, Limit Detail=FEMALE
	var lim: Dictionary = _mgr.get_hero_limit("str")
	assert_eq(str(lim["type"]), "Gender", "20005 Limit Type=Gender")


func test_check_unlock_and_enabled() -> void:
	assert_true(_mgr.is_enabled("exp"), "is_enabled 恒 true")
	assert_true(_mgr.check_unlock(20001, 100), "player_level 100 >= Unlock Level")
