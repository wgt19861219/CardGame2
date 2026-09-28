extends GutTest
# BattleStatisticsCalc 单测（照源 ui/battleStatistics.lua 纯逻辑段）。
# 覆盖：calc_max_dmg / get_bar_time / get_bar_ratio / format_comma / get_number_speed / split_by_camp。

# duck-type 单位桩（照 battleStatistics.lua ipairs engineList，访问 unit.camp / unit.dmg_statistics）
class MockUnit:
	extends RefCounted
	var camp: int = 1
	var dmg_statistics: float = 0.0
	func _init(c: int = 1, dmg: float = 0.0) -> void:
		camp = c
		dmg_statistics = dmg


func test_calc_max_dmg() -> void:
	var units: Array = [MockUnit.new(1, 100.0), MockUnit.new(2, 500.0), MockUnit.new(1, 250.0)]
	assert_eq(BattleStatisticsCalc.calc_max_dmg(units), 500.0, "最大伤害 500")
	assert_eq(BattleStatisticsCalc.calc_max_dmg([]), 0.0, "空列表 max=0")


func test_get_bar_time() -> void:
	# 源 getBarTime(tdmg, cmaxdmg, maxtime) = tdmg/cmaxdmg*maxtime
	assert_eq(BattleStatisticsCalc.get_bar_time(250.0, 500.0, 0.8), 0.4, "250/500*0.8=0.4")
	assert_eq(BattleStatisticsCalc.get_bar_time(500.0, 500.0, 0.8), 0.8, "满档=0.8")
	assert_eq(BattleStatisticsCalc.get_bar_time(100.0, 0.0, 0.8), 0.0, "cmaxdmg=0 守卫返0")


func test_get_bar_ratio() -> void:
	assert_eq(BattleStatisticsCalc.get_bar_ratio(250.0, 500.0), 0.5, "250/500=0.5")
	assert_eq(BattleStatisticsCalc.get_bar_ratio(500.0, 500.0), 1.0, "满档=1.0")
	assert_eq(BattleStatisticsCalc.get_bar_ratio(100.0, 0.0), 0.0, "maxdmg=0 守卫返0")


func test_format_comma() -> void:
	# 源 setCommaForNumber：从右每3位加逗号，去首部逗号
	assert_eq(BattleStatisticsCalc.format_comma(0), "0", "0")
	assert_eq(BattleStatisticsCalc.format_comma(999), "999", "999 无逗号")
	assert_eq(BattleStatisticsCalc.format_comma(1000), "1,000", "1000")
	assert_eq(BattleStatisticsCalc.format_comma(1234567), "1,234,567", "1234567")
	assert_eq(BattleStatisticsCalc.format_comma(1000000), "1,000,000", "1000000")


func test_get_number_speed() -> void:
	# 源 numberJump speed = dmg_statistics / speedtime（speedtime==0 守卫 speed=0）
	assert_eq(BattleStatisticsCalc.get_number_speed(500.0, 0.8), 625.0, "500/0.8=625/s")
	assert_eq(BattleStatisticsCalc.get_number_speed(500.0, 0.0), 0.0, "speedtime=0 守卫返0")


func test_split_by_camp() -> void:
	# 源 showPlayBar/setCount：player/enemy 各取前5，保持顺序。
	# 敌方 camp=-1（源 emCampEnemy；Mock 曾误用 2 与实现同错，2026-09-28 审查 P1-1 一并修）。
	var units: Array = [
		MockUnit.new(1, 100.0), MockUnit.new(-1, 200.0),
		MockUnit.new(1, 300.0), MockUnit.new(-1, 400.0),
	]
	var r: Dictionary = BattleStatisticsCalc.split_by_camp(units)
	assert_eq(r["player"].size(), 2, "player 2 个")
	assert_eq(r["enemy"].size(), 2, "enemy 2 个")
	assert_eq(float((r["player"][0] as MockUnit).dmg_statistics), 100.0, "player[0]=100 保持顺序")
	assert_eq(float((r["enemy"][1] as MockUnit).dmg_statistics), 400.0, "enemy[1]=400")


func test_split_by_camp_caps_at_five() -> void:
	# 源 mCNum<=5 / eCNum<=5：每方最多5
	var units: Array = []
	for i in 7:
		units.append(MockUnit.new(1, float(i) * 10.0))
	for i in 3:
		units.append(MockUnit.new(-1, float(i) * 20.0))
	var r: Dictionary = BattleStatisticsCalc.split_by_camp(units)
	assert_eq(r["player"].size(), 5, "player 截断到5")
	assert_eq(r["enemy"].size(), 3, "enemy 3 个<5 不截断")


func test_split_by_camp_ignores_other_camps() -> void:
	# 非玩家/敌方 camp 不纳入（源 ed.emCampPlayer=1/emCampEnemy=-1 判定）。
	# camp=2 曾被实现误当敌方常量，此处锁死 2 属"其他"不入任何营。
	var units: Array = [MockUnit.new(0, 100.0), MockUnit.new(1, 50.0), MockUnit.new(2, 999.0)]
	var r: Dictionary = BattleStatisticsCalc.split_by_camp(units)
	assert_eq(r["player"].size(), 1, "camp=1 入 player")
	assert_eq(r["enemy"].size(), 0, "camp=0/2 不入任何营")
