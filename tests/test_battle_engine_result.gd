extends GutTest
# Phase 2.1续 战斗结算统计（照源 battle_engine.lua getBattleResult:1319-1358 / getEnemyHpInfo:369-386）。

var cm: ConfigManager
var lib: SkillLibrary


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()
	lib = SkillLibrary.new(cm)


# get_battle_result：收集双方 HP/MP/custom_data（源 :1319-1358）
func test_get_battle_result_collects_both_sides() -> void:
	var eng := BattleEngine.new()
	var p := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1, "_rank": 1}, BattleEngine.CAMP_PLAYER, {"estimate_max_rank": true}, cm, eng, {}, lib)
	eng.add_unit(p)
	var e := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1, "_rank": 1}, BattleEngine.CAMP_ENEMY, {"estimate_max_rank": true}, cm, eng, {}, lib)
	e.set_meta("index_in_team", 1)   # excavate 装配设
	eng.add_unit(e)
	var result: Dictionary = BattleEngineResult.get_battle_result(eng)
	assert_eq((result["self_heroes"] as Array).size(), 1, "玩家方 1 英雄")
	assert_eq((result["enemy_heroes"] as Dictionary).size(), 1, "敌方 1（index_in_team 键，源 :1333）")
	var sh: Dictionary = (result["self_heroes"] as Array)[0]
	assert_eq(int(sh["_heroid"]), 1, "self_hero tid=1")
	assert_gte(int(sh["_hp_perc"]), 0, "hp_perc 收集（万分比，源 :1328）")
	assert_gte(int(sh["_mp_perc"]), 0, "mp_perc 收集（源 :1329）")


# get_enemy_hp_info：敌方 HP 百分比 + 5 槽补 0（源 :369-386）
func test_get_enemy_hp_info_fills_5_slots() -> void:
	var eng := BattleEngine.new()
	var e := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1, "_rank": 1}, BattleEngine.CAMP_ENEMY, {"estimate_max_rank": true}, cm, eng, {}, lib)
	e.monster_idx = 1   # setup_battle 设（源 monster_idx）
	eng.add_unit(e)
	var result: Dictionary = BattleEngineResult.get_enemy_hp_info(eng)
	var info: Dictionary = result["info"]
	assert_eq(info.size(), 5, "5 槽（缺槽补 0，源 :379-383）")
	assert_gte(int(info[1]), 0, "slot 1 有值（monster_idx=1）")
	assert_eq(int(info[2]), 0, "slot 2 补 0")
	assert_gte(int(result["done_percent"]), 0, "done_percent 累加（源 :376）")


# get_battle_result：召唤物跳过（源 :1324 is_summoned）
func test_get_battle_result_skips_summoned() -> void:
	var eng := BattleEngine.new()
	var summon := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1, "_rank": 1}, BattleEngine.CAMP_PLAYER, {"is_summoned": true, "estimate_max_rank": true}, cm, eng, {}, lib)
	eng.add_unit(summon)
	var result: Dictionary = BattleEngineResult.get_battle_result(eng)
	assert_eq((result["self_heroes"] as Array).size(), 0, "召唤物跳过（源 :1324）")
