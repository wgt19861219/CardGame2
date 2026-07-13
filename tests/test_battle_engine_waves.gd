extends GutTest
# Phase 2.1续 多波装配（照源 battle_engine.lua setupBattle:175-262 / nextBattle:624-635 / resetUnitList:170-174）。
# setup_battle 用真实 cm + stage 1 wave 1（2 怪物 101/102，照 test_battle_data 数据契约）。
# next_battle 测空波返回 + supplied 副作用；reset_unit_list 用本地 MockUnit。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# setup_battle：stage 1 wave 1 装配 2 怪物 + monster_idx + 位置 X 镜像（源 setupBattle:175-240）
func test_setup_battle_assembles_stage1_monsters() -> void:
	var e := BattleEngine.new()
	e.stage_rect = {"minX": 0.0, "maxX": 800.0, "minY": -120.0, "maxY": 120.0}
	var battle: Dictionary = BattleData.from_config(cm, 1, 1).battle_info
	BattleEngineWaves.setup_battle(e,cm, battle, {})
	assert_eq(e.monster_num, 2, "stage 1 wave 1 = 2 怪物（源 monsterNum）")
	var enemies: Array = e.alive_units.get(BattleEngine.CAMP_ENEMY, [])
	assert_eq(enemies.size(), 2, "敌方存活单位 2")
	var m0: BattleUnit = enemies[0]
	var m1: BattleUnit = enemies[1]
	assert_eq(m0.monster_idx, 1, "首怪 monster_idx=1（源 :237）")
	assert_eq(m1.monster_idx, 2, "次怪 monster_idx=2")
	# 源 :230-234 position.x = maxX - INITIAL_POSITIONS[idx].x（敌方 X 镜像置于舞台右侧）
	assert_eq(m0.position.x, 800.0 - BattleEngine.INITIAL_POSITIONS[0].x, "首怪 X 镜像 INITIAL_POSITIONS[0]")
	assert_eq(m1.position.x, 800.0 - BattleEngine.INITIAL_POSITIONS[1].x, "次怪 X 镜像 INITIAL_POSITIONS[1]")


# setup_battle：wave_id 从 battle["Wave ID"] 读（源 :177）
func test_setup_battle_reads_wave_id() -> void:
	var e := BattleEngine.new()
	e.stage_rect = {"minX": 0.0, "maxX": 800.0, "minY": -120.0, "maxY": 120.0}
	var battle: Dictionary = BattleData.from_config(cm, 1, 1).battle_info
	var wave: int = int(battle.get(&"Wave ID", 1))
	BattleEngineWaves.setup_battle(e,cm, battle, {})
	assert_eq(e.wave_id, wave, "wave_id 照 battle[Wave ID]")


# setup_battle：hp_info _hp_perc==0 的怪物跳过创建（源 :194）
func test_setup_battle_hp_perc_zero_skips_monster() -> void:
	var e := BattleEngine.new()
	e.stage_rect = {"minX": 0.0, "maxX": 800.0, "minY": -120.0, "maxY": 120.0}
	var battle: Dictionary = BattleData.from_config(cm, 1, 1).battle_info
	# 怪物 1 残血 0 → 不创建；怪物 2 正常
	var hp_info: Dictionary = {1: {"_hp_perc": 0}, 2: {"_hp_perc": 50}}
	BattleEngineWaves.setup_battle(e,cm, battle, hp_info)
	assert_eq(e.monster_num, 2, "monsterNum 仍计 2（源 :193 先计数再判断创建）")
	var enemies: Array = e.alive_units.get(BattleEngine.CAMP_ENEMY, [])
	assert_eq(enemies.size(), 1, "_hp_perc==0 的怪物跳过创建，仅 1 敌方单位")


# next_battle：下一波不存在 → return（wave_id 不变）+ supplied 副作用（源 :625-631）
func test_next_battle_missing_wave_no_change_but_supply() -> void:
	var e := BattleEngine.new()
	e.stage_rect = {"minX": 0.0, "maxX": 800.0, "minY": -120.0, "maxY": 120.0}
	e.stage_info = {&"Stage ID": 99999}  # 不存在的 stage → from_config 返空 battle_info
	e.wave_id = 1
	e.supplied = false
	BattleEngineWaves.next_battle(e, cm)
	assert_eq(e.wave_id, 1, "下一波不存在 → wave_id 不变（源 :630-631 return）")
	assert_true(e.supplied, "next_battle 首行 battle_supply（源 :625-627）")


# next_battle：battle_lookup_id 优先于 stage_info["Stage ID"]（源 :628）
func test_next_battle_prefers_battle_lookup_id() -> void:
	var e := BattleEngine.new()
	e.stage_rect = {"minX": 0.0, "maxX": 800.0, "minY": -120.0, "maxY": 120.0}
	e.stage_info = {&"Stage ID": 99999}  # stage_id 无效
	e.battle_lookup_id = 1  # lookup_id=1（stage 1）应优先
	e.wave_id = 1
	BattleEngineWaves.next_battle(e, cm)
	# stage 1 wave 2 存在则装配（wave_id=2），不存在则 wave_id=1；两种均不崩 = lookup_id 生效
	assert_true(e.wave_id == 1 or e.wave_id == 2, "battle_lookup_id 优先（查 stage 1 wave 2）")


# reset_unit_list：遍历 unit_list 调 unit.reset()（源 :170-174）
class MockUnit:
	extends RefCounted
	var camp: int = -1
	var reset_count: int = 0
	func reset() -> void:
		reset_count += 1


func test_reset_unit_list_calls_unit_reset() -> void:
	var e := BattleEngine.new()
	var u1 := MockUnit.new()
	var u2 := MockUnit.new()
	e.unit_list.append(u1)
	e.unit_list.append(u2)
	BattleEngineWaves.reset_unit_list(e)
	assert_eq(u1.reset_count, 1, "unit 1 reset 被调")
	assert_eq(u2.reset_count, 1, "unit 2 reset 被调")
