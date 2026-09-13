class_name BattleEngineArena
extends RefCounted

## 竞技场/远征/挖掘 PVP 装配（Logic 层）— 照源 battle_engine.lua enterArena:542-552 /
## enterCrusade:555-569 / enterExcavate:571-583 / initHeroInfo:491-540 / initUnitList:433-467 /
## initUnitInfo:469-489 / setUpConfigEstimateInfo:152-168 / sortHeroList/sortUnitList:281-300。
## 双方 Arena HP Mult 倍率 + estimate（enableMaxAttStrategy=true：Hero→max_rank / Monster→is_bot）
## + 敌方位置 X 镜像。crusade/excavate 跨波 HP/MP 经 dynaData(hp_info) 注入。
## 单机化：engine.hero_list/origin_enemy_team/excavate_type_id 省略（UI/重开机制未实现）；index_in_team 存 custom_data。

const DEFAULT_ARENA_HP_MOD: float = 1.0
const HP_PERC_FULL: int = 10000


static func enter_arena(engine: Variant, cm: ConfigManager, lib: Variant, hero_list: Array[Dictionary], enemy_list: Array[Dictionary], hero_is_bot: bool, enemy_is_bot: bool) -> void:
	engine.reset_stage()
	engine.arena_mode = true
	engine.stage_info = cm.get_raw_table(&"Stage").get(&"-1", {})
	_sort_hero_list(cm, hero_list)
	_sort_hero_list(cm, enemy_list)
	engine.wave_id = 1
	_init_hero_info(engine, cm, lib, hero_list, enemy_list, hero_is_bot, enemy_is_bot)
	engine.mp_bonus = 1.0


static func enter_crusade(engine: Variant, cm: ConfigManager, lib: Variant, hero_list: Array[Dictionary], enemy_list: Array[Dictionary], enemy_is_bot: bool, self_crusade: Variant, enemy_crusade: Variant, stage_id: int) -> void:
	engine.reset_stage()
	engine.crusade_mode = true
	var stage_info: Dictionary = cm.get_raw_table(&"Stage").get(str(stage_id), {})
	if stage_info.is_empty():
		stage_info = {&"Stage ID": stage_id, &"Waves": 1}
	engine.stage_info = stage_info
	_sort_hero_list(cm, hero_list)
	_sort_hero_list(cm, enemy_list)
	engine.wave_id = 1
	_init_hero_info(engine, cm, lib, hero_list, enemy_list, false, enemy_is_bot, self_crusade, enemy_crusade)
	engine.mp_bonus = 1.0


static func enter_excavate(engine: Variant, cm: ConfigManager, lib: Variant, hero_list: Array[Dictionary], enemy_list: Array[Dictionary], enemy_is_bot: bool, self_dyna: Variant, enemy_dyna: Variant, stage_id: int, _type_id: int) -> void:
	engine.reset_stage()
	engine.excavate_mode = true
	engine.stage_info = cm.get_raw_table(&"Stage").get(str(stage_id), {})
	engine.wave_id = 1
	var self_unit: Array = _init_unit_list(engine, cm, lib, hero_list, true, false, self_dyna)
	var enemy_unit: Array = _init_unit_list(engine, cm, lib, enemy_list, false, enemy_is_bot, enemy_dyna)
	_init_unit_info(engine, cm, self_unit, enemy_unit)
	engine.mp_bonus = 1.0


static func _init_hero_info(engine: Variant, cm: ConfigManager, lib: Variant, hero_list: Array[Dictionary], enemy_list: Array[Dictionary], hero_is_bot: bool, enemy_is_bot: bool, self_crusade: Variant = null, enemy_crusade: Variant = null) -> void:
	_assemble_side(engine, cm, lib, hero_list, BattleEngine.CAMP_PLAYER, hero_is_bot, false, self_crusade)
	_assemble_side(engine, cm, lib, enemy_list, BattleEngine.CAMP_ENEMY, enemy_is_bot, true, enemy_crusade)
	BattleEngineWaves.reset_unit_list(engine)


# + crusade hp_info(:498-502/:523-530) + crusade/excavate 玩家方关大招(:503-508)。
static func _assemble_side(engine: Variant, cm: ConfigManager, lib: Variant, protos: Array[Dictionary], camp: int, is_bot: bool, mirror_x: bool, crusade_map: Variant) -> void:
	var i: int = 1
	while i <= protos.size():
		var proto: Dictionary = protos[i - 1]
		var config: Dictionary = {"hp_mod": _arena_hp_mod(cm, proto)}
		var tid: int = int(proto.get(&"_tid", 0))
		_set_up_config_estimate_info(config, cm, tid, is_bot)
		var hp_info: Dictionary = crusade_map.get(tid, {}) if crusade_map is Dictionary else {}
		var unit: BattleUnit = BattleUnit.new(proto, camp, config, cm, engine, hp_info, lib)
		engine.add_unit(unit)
		var base: Vector2 = BattleEngine.INITIAL_POSITIONS[clampi(i - 1, 0, BattleEngine.INITIAL_POSITIONS.size() - 1)]
		if mirror_x:
			unit.position = Vector2(float(engine.stage_rect.get(&"maxX", 0.0)) - base.x, base.y)
		else:
			unit.position = base
			engine.hero_id_list.append(tid)
			if bool(engine.crusade_mode) or bool(engine.excavate_mode):
				unit.ai.will_cast_manual_skill = false
		i += 1


static func _init_unit_list(engine: Variant, cm: ConfigManager, lib: Variant, protos: Array[Dictionary], is_self: bool, is_bot: bool, dyna_list: Variant) -> Array:
	var unitlist: Array = []
	var i: int = 1
	while i <= protos.size():
		var alive: bool = true
		var dyna: Dictionary = {}
		if dyna_list is Array and i - 1 < dyna_list.size():
			dyna = dyna_list[i - 1]
			if int(dyna.get(&"_hp_perc", HP_PERC_FULL)) <= 0:
				alive = false
		if alive:
			var proto: Dictionary = protos[i - 1]
			var config: Dictionary = {"hp_mod": _arena_hp_mod(cm, proto)}
			_set_up_config_estimate_info(config, cm, int(proto.get(&"_tid", 0)), is_bot)
			var camp: int = BattleEngine.CAMP_PLAYER if is_self else BattleEngine.CAMP_ENEMY
			var unit: BattleUnit = BattleUnit.new(proto, camp, config, cm, engine, dyna, lib)
			unit.set_meta(&"index_in_team", i)
			if is_self and (bool(engine.crusade_mode) or bool(engine.excavate_mode)):
				unit.ai.will_cast_manual_skill = false
			unitlist.append(unit)
		i += 1
	return unitlist


static func _init_unit_info(engine: Variant, cm: ConfigManager, self_unit: Array, enemy_unit: Array) -> void:
	self_unit.sort_custom(func(a, b): return _auto_attack_range(cm, int((a as BattleUnit).tid)) < _auto_attack_range(cm, int((b as BattleUnit).tid)))
	enemy_unit.sort_custom(func(a, b): return _auto_attack_range(cm, int((a as BattleUnit).tid)) < _auto_attack_range(cm, int((b as BattleUnit).tid)))
	var positions: Array[Vector2] = BattleEngine.INITIAL_POSITIONS
	var i: int = 1
	while i <= self_unit.size():
		var u: BattleUnit = self_unit[i - 1]
		u.position = positions[clampi(i - 1, 0, positions.size() - 1)]
		engine.hero_id_list.append(u.tid)
		engine.add_unit(u)
		i += 1
	i = 1
	while i <= enemy_unit.size():
		var u: BattleUnit = enemy_unit[i - 1]
		var base: Vector2 = positions[clampi(i - 1, 0, positions.size() - 1)]
		u.position = Vector2(float(engine.stage_rect.get(&"maxX", 0.0)) - base.x, base.y)
		engine.add_unit(u)
		i += 1
	BattleEngineWaves.reset_unit_list(engine)


## 照源 battle_engine.lua:152-168 setUpConfigEstimateInfo 的 else 分支（enableMaxAttStrategy
## 仅源 headless 测试脚本 bot.lua:6 置 true，正常游戏恒 nil/false）——estimate 三项全由 is_bot
## 决定，不分 Hero/Monster。误译 max_rank 分支曾致竞技场双方英雄走估算 rank（源 2026-09-13 排查）。
static func _set_up_config_estimate_info(config: Dictionary, _cm: ConfigManager, _tid: int, is_bot: bool) -> void:
	config[&"estimate_rank"] = is_bot
	config[&"estimate_skill"] = is_bot
	config[&"estimate_max_rank"] = false


static func _arena_hp_mod(cm: ConfigManager, proto: Dictionary) -> float:
	var row: Dictionary = cm.get_raw_table(&"Levels").get(str(int(proto.get(&"_level", 1))), {})
	return float(row.get(&"Arena HP Mult", DEFAULT_ARENA_HP_MOD))


static func _sort_hero_list(cm: ConfigManager, protos: Array[Dictionary]) -> void:
	if protos.size() <= 1:
		return
	protos.sort_custom(func(a, b): return _auto_attack_range(cm, int((a as Dictionary).get(&"_tid", 0))) < _auto_attack_range(cm, int((b as Dictionary).get(&"_tid", 0))))


static func _auto_attack_range(cm: ConfigManager, tid: int) -> float:
	var auto_attack: Variant = cm.lookup(&"Unit", &"Basic Skill", tid)
	if auto_attack == null:
		return 0.0
	var r: Variant = cm.lookup(&"Skill", &"Max Range", auto_attack)
	return float(r) if r != null else 0.0
