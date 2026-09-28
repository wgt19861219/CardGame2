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
	var mp: float = 0.0
	func set_mp(v: float) -> void:
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


# ── 2026-09-28 审查回归（P0-1 / P1-2）──

class MockMonster:
	extends RefCounted
	var tid: int = 0
	var position: Vector2 = Vector2.ZERO
	var buffs: Array = []
	func add_buff(info: Variant, _c: Variant) -> Variant:
		buffs.append(info)
		return null


class MockResetEng:
	extends RefCounted
	var guild_instance_mode: bool = false
	var stage_rect: Dictionary = {"maxX": 800.0}
	var monsters: Array = []
	func foreach_alive_unit(_camp: int) -> Array:
		return monsters


# P0-1：DR 加 mp 不再 int 截断（源 unit.lua setMP 全程 float；mp_regen=0 时旧实现每 tick 抹小数致大招差 1）。
func test_dr_add_mp_keeps_fraction() -> void:
	var eng := MockEng.new()
	eng.hero = MockHero.new()
	eng.hero.mp = 100.5
	var c := BattleStageScripts.get_stage_script(eng, cm, 1, 2)  # 源 stage 1 wave2 DR +150
	assert_true(c.is_valid(), "stage1 wave2 返 DR 加 mp 脚本")
	c.call(eng)
	assert_almost_eq(eng.hero.mp, 250.5, 0.001, "100.5 + 150 = 250.5 小数保留")


# P1-2：monster_reset_pos_and_buff 由 get_stage_script 形参传 cm（原 eng.get("cm") 恒 null 致
# 40021/40049/40055 三关 unheal/Building_boss 永不施加）。真表断言 unheal 加给全部敌方怪。
func test_monster_reset_pos_applies_buffs() -> void:
	var eng := MockResetEng.new()
	var m_target := MockMonster.new()
	m_target.tid = int(BattleStageScripts.RESET_40021["tid"])
	var m_other := MockMonster.new()
	m_other.tid = 99999
	eng.monsters = [m_target, m_other]
	var c := BattleStageScripts.get_stage_script(eng, cm, 40021, 3)
	assert_true(c.is_valid(), "stage40021 wave3 返 reset_pos 脚本")
	c.call(eng)
	assert_eq(m_target.buffs.size(), 2, "目标怪加 unheal + Building_boss 两个 buff")
	assert_eq(str(m_target.buffs[0].get("Name", "")), str(cm.get_raw_table("Buff").get("unheal", {}).get("Name", "")), "首个 buff 是 unheal（真表行）")
	assert_eq(m_other.buffs.size(), 1, "非目标怪只加 unheal")
	var rect: Dictionary = eng.stage_rect
	assert_almost_eq(m_target.position.x, float(rect["maxX"]) - float(BattleStageScripts.RESET_40021["x"]), 0.001, "目标怪重定位 maxX-x")
