extends GutTest
# Phase 2.1 战斗引擎核心（照源 battle_engine.lua 重翻，2026-06-30）。
# 单位用 MockUnit（duck-type 契约：is_alive/update/die/camp/position/config/...）。
# 覆盖：add_unit 计数 / tick 推进 / 胜负判定 / foreach / freeze。

# duck-type 单位桩（Phase 2.2 翻真单位前的测试契约）
class MockUnit:
	extends RefCounted
	var camp: int
	var position: Vector2 = Vector2.ZERO
	var previous_position: Vector2 = Vector2.ZERO
	var config: Dictionary = {"is_summoned": false, "is_boss": false, "summoner": null}
	var terminated: bool = false
	var frozen_model: Variant = null
	var alive: bool = true
	var is_hero_flag: bool = true
	var hp: int = 100
	var mp: int = 0
	var dmg_statistics: float = 0.0
	var actor: Variant = null
	var index_in_engine: int = 0
	var id: int = 0
	var name: String = ""
	var update_count: int = 0
	var froze_count: int = 0
	var unfroze_count: int = 0
	var removed_buffs: bool = false
	var supplied_coef: float = -1.0
	func _init(c: int = 1) -> void:
		camp = c
	func is_alive() -> bool:
		return alive
	func is_hero() -> bool:
		return is_hero_flag
	func update(_dt: float) -> void:
		update_count += 1
	func die(_killer: Variant) -> void:
		alive = false
		terminated = true
	func freeze() -> void:
		froze_count += 1
	func unfreeze() -> void:
		unfroze_count += 1
	func remove_all_buffs() -> void:
		removed_buffs = true
	func battle_supply(coef: float) -> void:
		supplied_coef = coef
	func set_mp(v: int) -> void:
		mp = v
	func handle_unit_die_event(_u: Variant, _k: Variant) -> void:
		pass
	func summon(_action: String) -> void:
		pass

func _make_player() -> MockUnit:
	return MockUnit.new(1)  # CAMP_PLAYER=1

func _make_enemy() -> MockUnit:
	return MockUnit.new(-1)  # CAMP_ENEMY=-1

# addUnit：玩家/敌方存活计数（源 addUnit :941）
func test_add_unit_counts_alive_by_camp() -> void:
	var e := BattleEngine.new()
	e.add_unit(_make_player())
	e.add_unit(_make_enemy())
	assert_eq(e.alive_alliance_count, 1, "玩家方存活 +1")
	assert_eq(e.alive_enemy_count, 1, "敌方存活 +1")
	assert_eq(e.unit_list.size(), 2, "unit_list 含双方")

# addUnit 死亡单位计 dead（源 addUnit elseif 分支）
func test_add_unit_dead_counts_dead() -> void:
	var e := BattleEngine.new()
	var dead_p := _make_player()
	dead_p.alive = false
	e.add_unit(dead_p)
	assert_eq(e.alive_alliance_count, 0, "死亡玩家不计存活")
	assert_eq(e.dead_alliance_count, 1, "死亡玩家计 dead_alliance")

# tick：推进 unit_list 调单位 update + ticks+1（源 tick :697-720）
func test_tick_advances_units_and_ticks() -> void:
	var e := BattleEngine.new()
	var p := _make_player()
	var en := _make_enemy()
	e.add_unit(p)
	e.add_unit(en)
	e.tick()
	assert_eq(e.ticks, 1, "ticks+1")
	assert_eq(p.update_count, 1, "玩家单位被 update")
	assert_eq(en.update_count, 1, "敌方单位被 update")

# 胜负：敌方全死 → victory → exit_stage(0=WIN)（源 tick :738-741）
func test_enemy_wipe_triggers_victory() -> void:
	var e := BattleEngine.new()
	e.add_unit(_make_player())
	var en := _make_enemy()
	e.add_unit(en)
	en.alive = false  # 敌方死亡
	# 模拟 die 流程：手动减计数（真流程由单位 die→on_unit_die）
	e.alive_enemy_count = 0
	e.tick()
	assert_eq(e.last_result, BattleEngine.RESULT_WIN, "敌方全死→胜利")
	assert_true(e.stage_ended, "stage_ended")
	assert_false(e.running, "running=false")

# 胜负：玩家全死 → exit_stage(1=LOSE)（源 tick :742-749）
func test_player_wipe_triggers_lose() -> void:
	var e := BattleEngine.new()
	var p := _make_player()
	e.add_unit(p)
	e.add_unit(_make_enemy())
	p.alive = false
	e.alive_alliance_count = 0
	e.tick()
	assert_eq(e.last_result, BattleEngine.RESULT_LOSE, "玩家全死→失败")

# 胜负：超时 → exit_stage(3=TIMEOUT)（源 tick :724-737）
func test_time_limit_triggers_timeout() -> void:
	var e := BattleEngine.new()
	e.add_unit(_make_player())
	e.add_unit(_make_enemy())
	e.time_limit = 0.0  # 立即超时
	e.tick()
	assert_eq(e.last_result, BattleEngine.RESULT_TIMEOUT, "超时→exit_stage(3)")

# foreach_alive_unit 按 camp 过滤（源 foreachAliveUnit :1665）
func test_foreach_alive_unit_filters_camp() -> void:
	var e := BattleEngine.new()
	e.add_unit(_make_player())
	e.add_unit(_make_player())
	e.add_unit(_make_enemy())
	assert_eq(e.foreach_alive_unit(BattleEngine.CAMP_PLAYER).size(), 2, "玩家方 2 存活")
	assert_eq(e.foreach_alive_unit(BattleEngine.CAMP_ENEMY).size(), 1, "敌方 1 存活")
	assert_eq(e.foreach_alive_unit(BattleEngine.CAMP_BOTH).size(), 3, "双方 3 存活")

# update 固定步长累加器：dt 累积触发多次 tick（源 update :671-680，确定性）
func test_update_accumulates_fixed_timestep() -> void:
	var e := BattleEngine.new()
	e.add_unit(_make_player())
	e.add_unit(_make_enemy())
	# 源 next_tick 初值 0；while next_tick<=0（含等号）：update(0.033) → 0-0.033=-0.033 → tick → 0 → tick → 0.033
	e.update(0.033)
	assert_eq(e.ticks, 2, "首次 update(0.033) 触发 2 tick（next_tick=0 边界 +1）")
	var ticks_before := e.ticks
	e.update(0.099)  # 0.033-0.099=-0.066 → 3 tick → 0.033
	assert_eq(e.ticks - ticks_before, 3, "update(0.099)=3×interval 触发 3 tick")

# freeze/unfreeze 计数（源 freeze :899 / unfreeze :918）
func test_freeze_unfreeze_level() -> void:
	var e := BattleEngine.new()
	var p := _make_player()
	e.add_unit(p)
	e.freeze()
	assert_eq(e.freeze_level, 1, "freeze_level+1")
	assert_eq(p.froze_count, 1, "单位 freeze 调用")
	e.unfreeze()
	assert_eq(e.freeze_level, 0, "unfreeze 归 0")
	assert_eq(p.unfroze_count, 1, "单位 unfreeze 调用")

# on_unit_die：计数调整 + 击杀者 MP 奖励（源 onUnitDie :989）
func test_on_unit_die_adjusts_counts_and_killer_mp() -> void:
	var e := BattleEngine.new()
	var killer := _make_player()
	killer.mp = 10
	var victim := _make_enemy()
	e.add_unit(killer)
	e.add_unit(victim)
	e.on_unit_die(victim, killer)
	assert_eq(e.alive_enemy_count, 0, "敌方存活-1")
	assert_eq(e.dead_enemy_count, 1, "敌方死亡+1")
	assert_eq(killer.mp, 10 + BattleEngine.KILL_MP_BONUS, "击杀者 +300 MP（源 setMP(mp+300)）")

# on_battle_end：召唤物伤害归召唤者（源 onBattleEnd :1217）
func test_on_battle_end_merges_summon_damage() -> void:
	var e := BattleEngine.new()
	var master := _make_player()
	e.add_unit(master)
	var clone := MockUnit.new(1)
	clone.config = {"is_summoned": true, "is_boss": false, "summoner": master}
	clone.dmg_statistics = 500
	e.add_unit(clone)
	e.on_battle_end()
	assert_eq(master.dmg_statistics, 500, "召唤物伤害归召唤者")
	assert_true(master.removed_buffs, "非召唤单位去 buff")
	assert_eq(e.unit_list.size(), 1, "召唤物从列表移除")

# 确定性：同输入两次 update 序列 → 同 ticks（D2 契约）
func test_deterministic_same_input_same_ticks() -> void:
	assert_eq(_run_ten_updates(), _run_ten_updates(), "同输入两次 ticks 一致（确定性）")

func _run_ten_updates() -> int:
	var e := BattleEngine.new()
	e.add_unit(_make_player())
	e.add_unit(_make_enemy())
	for i in range(10):
		e.update(0.033)
	return e.ticks
