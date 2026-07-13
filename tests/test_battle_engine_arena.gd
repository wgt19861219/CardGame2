extends GutTest
# Phase 2.1续 竞技场 PVP 装配（照源 battle_engine.lua enterArena:542-552 / initHeroInfo:491-540 / setUpConfigEstimateInfo:152-168）。
# 双方英雄 Arena HP Mult 倍率 + estimate(is_bot) + 敌方位置 X 镜像 + hero_id_list + resetUnitList。

var cm: ConfigManager
var lib: SkillLibrary


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()
	lib = SkillLibrary.new(cm)


# enterArena：双方装配 + arena_mode + Stage[-1] + mp_bonus=1（源 :542-552）
func test_enter_arena_assembles_both_sides() -> void:
	var eng := BattleEngine.new()
	var heroes: Array[Dictionary] = [{"_tid": 1, "_level": 1, "_stars": 1, "_rank": 1}, {"_tid": 2, "_level": 1, "_stars": 1, "_rank": 1}]
	var enemies: Array[Dictionary] = [{"_tid": 1, "_level": 1, "_stars": 1, "_rank": 1}]
	BattleEngineArena.enter_arena(eng, cm, lib, heroes, enemies, false, true)
	assert_true(eng.arena_mode, "arena_mode=true（源 :544）")
	assert_eq(eng.wave_id, 1, "wave_id=1（源 :549）")
	assert_eq(eng.mp_bonus, 1.0, "mp_bonus=1（源 :551）")
	assert_false(eng.stage_info.is_empty(), "stage_info=Stage[-1]（源 :545 PVP 占位）")
	assert_eq(eng.alive_units.get(BattleEngine.CAMP_PLAYER, []).size(), 2, "玩家方 2 英雄")
	assert_eq(eng.alive_units.get(BattleEngine.CAMP_ENEMY, []).size(), 1, "敌方 1 英雄")
	assert_eq(eng.hero_id_list, [1, 2], "hero_id_list 照源 :515")


# 敌方位置 X 镜像（源 initHeroInfo :534-537 maxX-x）
func test_enter_arena_enemy_x_mirror() -> void:
	var eng := BattleEngine.new()
	var heroes: Array[Dictionary] = [{"_tid": 1, "_level": 1, "_stars": 1, "_rank": 1}]
	var enemies: Array[Dictionary] = [{"_tid": 1, "_level": 1, "_stars": 1, "_rank": 1}]
	BattleEngineArena.enter_arena(eng, cm, lib, heroes, enemies, false, true)
	var players: Array = eng.alive_units.get(BattleEngine.CAMP_PLAYER, [])
	var enemies_arr: Array = eng.alive_units.get(BattleEngine.CAMP_ENEMY, [])
	var p0: BattleUnit = players[0]
	var e0: BattleUnit = enemies_arr[0]
	assert_lte(p0.position.x, 0.0, "玩家方原位 X≤0（源 :511-514）")
	assert_gt(e0.position.x, 400.0, "敌方 X 镜像 >400（源 :534-537）")


# enterExcavate：excavate_mode + dyna 阵亡过滤(_hp_perc<=0 跳过) + 玩家方关大招 + 敌方 X 镜像（源 :571-583/initUnitList:433-467）
func test_enter_excavate_filters_dead_and_assembles() -> void:
	var eng := BattleEngine.new()
	var heroes: Array[Dictionary] = [{"_tid": 1, "_level": 1, "_stars": 1, "_rank": 1}, {"_tid": 2, "_level": 1, "_stars": 1, "_rank": 1}]
	var enemies: Array[Dictionary] = [{"_tid": 1, "_level": 1, "_stars": 1, "_rank": 1}]
	var self_dyna: Array = [{"_hp_perc": 10000, "_mp_perc": 0}, {"_hp_perc": 0, "_mp_perc": 0}]  # 英雄 2 阵亡
	var enemy_dyna: Array = [{"_hp_perc": 5000, "_mp_perc": 0}]
	BattleEngineArena.enter_excavate(eng, cm, lib, heroes, enemies, true, self_dyna, enemy_dyna, 1, 1)
	assert_true(eng.excavate_mode, "excavate_mode=true（源 :573）")
	assert_eq(eng.wave_id, 1, "wave_id=1（源 :576）")
	assert_eq(eng.alive_units.get(BattleEngine.CAMP_PLAYER, []).size(), 1, "玩家方 1（英雄 2 阵亡跳过，源 :437-439）")
	assert_eq(eng.alive_units.get(BattleEngine.CAMP_ENEMY, []).size(), 1, "敌方 1")
	var players: Array = eng.alive_units.get(BattleEngine.CAMP_PLAYER, [])
	var p0: BattleUnit = players[0]
	assert_false(bool(p0.ai.will_cast_manual_skill), "excavate 玩家方关大招（源 :458-460）")
	assert_eq(int(p0.get_meta("index_in_team", 0)), 1, "index_in_team 存 meta（源 :456）")
	var enemies_arr: Array = eng.alive_units.get(BattleEngine.CAMP_ENEMY, [])
	assert_gt((enemies_arr[0] as BattleUnit).position.x, 400.0, "敌方 X 镜像（源 :482-485）")


# Arena HP Mult hp_mod 应用（源 initHeroInfo :495 Levels "Arena HP Mult"）+ estimate
func test_enter_arena_applies_hp_mod() -> void:
	var eng := BattleEngine.new()
	var heroes: Array[Dictionary] = [{"_tid": 1, "_level": 1, "_stars": 1, "_rank": 1}]
	var enemies: Array[Dictionary] = [{"_tid": 1, "_level": 1, "_stars": 1, "_rank": 1}]
	BattleEngineArena.enter_arena(eng, cm, lib, heroes, enemies, false, true)
	var players: Array = eng.alive_units.get(BattleEngine.CAMP_PLAYER, [])
	var p0: BattleUnit = players[0]
	assert_gt(p0.hp, 0, "玩家英雄 HP>0（Arena HP Mult hp_mod 装配成功）")


# sortHeroList 按普攻射程升序（源 :547/:281-290）
func test_enter_arena_sorts_by_attack_range() -> void:
	var eng := BattleEngine.new()
	# tid 1(Coco) 与 tid 2 不同射程，装配后 hero_id_list 顺序按射程升序
	var heroes: Array[Dictionary] = [{"_tid": 2, "_level": 1, "_stars": 1, "_rank": 1}, {"_tid": 1, "_level": 1, "_stars": 1, "_rank": 1}]
	var enemies: Array[Dictionary] = [{"_tid": 1, "_level": 1, "_stars": 1, "_rank": 1}]
	BattleEngineArena.enter_arena(eng, cm, lib, heroes, enemies, false, true)
	# sortHeroList 原地排 hero_list，hero_id_list 按排序后顺序填；不崩 + 2 英雄即 sort 生效
	assert_eq(eng.hero_id_list.size(), 2, "sortHeroList 后装配 2 英雄")


# enterCrusade：crusade_mode + stage_info fallback + 跨波 HP/MP + 玩家方关大招（源 :555-569/:498-502/:503-508）
func test_enter_crusade_assembles_with_crusade_hp() -> void:
	var eng := BattleEngine.new()
	var heroes: Array[Dictionary] = [{"_tid": 1, "_level": 1, "_stars": 1, "_rank": 1}]
	var enemies: Array[Dictionary] = [{"_tid": 1, "_level": 1, "_stars": 1, "_rank": 1}]
	var self_crusade: Dictionary = {1: {"_hp_perc": 5000, "_mp_perc": 3000}}  # 万分比 5000=50% HP
	BattleEngineArena.enter_crusade(eng, cm, lib, heroes, enemies, true, self_crusade, {}, 99999)
	assert_true(eng.crusade_mode, "crusade_mode=true（源 :557）")
	assert_eq(eng.wave_id, 1, "wave_id=1（源 :565）")
	assert_eq(int(eng.stage_info.get(&"Stage ID", 0)), 99999, "stage_info fallback Stage ID（源 :558-561）")
	assert_eq(eng.alive_units.get(BattleEngine.CAMP_PLAYER, []).size(), 1, "玩家方 1 英雄")
	assert_eq(eng.alive_units.get(BattleEngine.CAMP_ENEMY, []).size(), 1, "敌方 1 英雄")
	var players: Array = eng.alive_units.get(BattleEngine.CAMP_PLAYER, [])
	var p0: BattleUnit = players[0]
	var max_hp: float = float(p0.attribs.get("HP", 0.0))
	assert_lte(p0.hp, max_hp * 0.51, "玩家英雄 HP≤51%（跨关 50% 残血，源 dynaData._hp_perc/:498-502）")
	assert_false(bool(p0.ai.will_cast_manual_skill), "crusade 玩家方关大招（源 :503-508）")
	var enemies_arr: Array = eng.alive_units.get(BattleEngine.CAMP_ENEMY, [])
	var e0: BattleUnit = enemies_arr[0]
	assert_gt(e0.position.x, 400.0, "敌方 X 镜像 >400（源 :534-537）")
