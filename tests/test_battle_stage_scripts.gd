extends GutTest
# Phase 2.6 BattleStageScripts（照源 stage.lua:1-172）。
# 验 get_stage_script 返正确脚本 + 执行（boss_set_mp / DR_add_mp）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


class MockBoss:
	extends RefCounted
	var mp: int = 0


class MockHero:
	extends RefCounted
	var mp: int = 0
	func set_mp(v: int) -> void:
		mp = v


class MockEng:
	extends RefCounted
	var guild_instance_mode: bool = false
	var boss: MockBoss = null
	var hero: MockHero = null
	var exited: bool = false
	func foreach_alive_unit(_camp: int) -> Array:
		return []
	func find_hero(_n: Variant) -> Variant:
		return hero
	func find_boss() -> Variant:
		return boss
	func exit_stage(_r: int) -> void:
		exited = true


func test_get_stage_script_invalid_returns_empty() -> void:
	var eng := MockEng.new()
	var c := BattleStageScripts.get_stage_script(eng, cm, 99999, 1)
	assert_false(c.is_valid(), "无脚本关卡返空 Callable")


func test_boss_set_mp_script_executes() -> void:
	var eng := MockEng.new()
	eng.boss = MockBoss.new()
	eng.boss.mp = 100
	var c := BattleStageScripts.get_stage_script(eng, cm, 6, 3)  # 源 :72 boss mp=800
	assert_true(c.is_valid(), "stage6 wave3 返 boss_set_mp 脚本")
	c.call(eng)
	assert_eq(eng.boss.mp, 800, "boss mp 设为 800")
