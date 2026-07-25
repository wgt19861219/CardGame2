class_name BattleEngineWaves
extends RefCounted

## 战斗多波装配（Logic 层）— 照源 battle_engine.lua setupBattle:175-262 / nextBattle:624-635 / resetUnitList:170-174。
## 从 battle_engine.gd 拆出（控 ≤300 行；照 battle_unit_combat.gd static 接首参 engine 模式）。
## setup_battle 接原始 Battle[stage][wave] Dictionary 自解析 5 槽怪物+boss+位置 X 镜像。
## next_battle 复用 BattleData.from_config 两级下钻查下一波（源 lookupDataTable("Battle", nil, id, wave)）。

const MOD_DEFAULT: float = 100.0
const PERC_DENOM: float = 100.0
const BOSS_SIZE_DEFAULT: float = 120.0
const MONSTER_SLOT_COUNT: int = 5
const DEFAULT_STARS: int = 1


static func _modify(old: float, modifier: float, default: float = MOD_DEFAULT) -> float:
	var mod_val: float = modifier if modifier != 0.0 else default
	return old * mod_val / PERC_DENOM


static func reset_unit_list(engine: Variant) -> void:
	for unit in engine.unit_list:
		unit.reset()


## hp_info = 跨波 HP 继承 {i: {_hp_perc:..}}，空字典代表源 nil（全部按满血生成）。
static func setup_battle(engine: Variant, cm: ConfigManager, battle: Dictionary, hp_info: Dictionary = {}) -> void:
	engine.reset_battle()
	engine.wave_id = int(battle.get(&"Wave ID", engine.wave_id))
	var boss_idx: int = int(battle.get(&"Boss Position", 0))
	var monster_pos_idx: int = 0
	engine.monster_num = 0
	var has_hp_info: bool = not hp_info.is_empty()
	var i: int = 1
	while i <= MONSTER_SLOT_COUNT:
		var id: int = int(battle.get(StringName("Monster " + str(i) + " ID"), 0))
		if id > 0:
			engine.monster_num += 1
			var hp_perc_skip: bool = has_hp_info and int(hp_info.get(i, {}).get("_hp_perc", 0)) == 0
			if not hp_perc_skip:
				var level: int = int(battle.get(StringName("Level " + str(i)), 0))
				var stars: int = int(battle.get(StringName("Stars " + str(i)), DEFAULT_STARS))
				var config: Dictionary = {
					&"is_monster": true, &"is_boss": false,
					&"hp_mod": _modify(1.0, float(battle.get(&"Monster HP%", 0))),
					&"dps_mod": _modify(1.0, float(battle.get(&"Monster DPS%", 0))),
					&"size_mod": 1.0,
					&"money": int(battle.get(StringName("Money Reward " + str(i)), 0)),
					&"estimate_rank": true, &"estimate_skill": true, &"estimate_max_rank": false,
				}
				if i == boss_idx:
					config[&"is_boss"] = true
					config[&"hp_mod"] = _modify(float(config[&"hp_mod"]), float(battle.get(&"Boss HP%", 0)))
					config[&"dps_mod"] = _modify(float(config[&"dps_mod"]), float(battle.get(&"Boss DPS%", 0)))
					config[&"size_mod"] = _modify(float(config[&"size_mod"]), float(battle.get(&"BOSS SIZE%", 0)), BOSS_SIZE_DEFAULT)
				var proto: Dictionary = {&"_tid": id, &"_level": level, &"_stars": stars}
				var monster_hp_info: Dictionary = hp_info.get(i, {}) if has_hp_info else {}
				var monster: BattleUnit = BattleUnit.new(proto, BattleEngine.CAMP_ENEMY, config, cm, engine, monster_hp_info, GameData.skills)
				monster.mp = int(battle.get(StringName("MP " + str(i)), 0))
				if monster.hp != 0:
					monster_pos_idx += 1
				var max_x: float = float(engine.stage_rect.get(&"maxX", 0))
				var base_pos: Vector2 = _initial_position(monster_pos_idx)
				monster.position = Vector2(max_x - base_pos.x, base_pos.y)
				engine.add_unit(monster)
				monster.monster_idx = i
		i += 1
	var heroes: Array = engine.alive_units.get(BattleEngine.CAMP_PLAYER, [])
	var hi: int = 0
	while hi < heroes.size() and hi < BattleEngine.INITIAL_POSITIONS.size():
		var hero: Variant = heroes[hi]
		var hpos: Vector2 = BattleEngine.INITIAL_POSITIONS[hi]
		hero.position = Vector2(hpos.x, hpos.y)
		hero.previous_position = Vector2(hpos.x, hpos.y)
		hi += 1
	reset_unit_list(engine)
	var script_cb: Callable = BattleStageScripts.get_stage_script(engine, cm, int(engine.stage_info.get(&"Stage ID", 0)), engine.wave_id)
	if script_cb.is_valid():
		script_cb.call(engine)
	# battle_scene View 自行处理入场（Phase 4），单机化照源不在此触发。


static func next_battle(engine: Variant, cm: ConfigManager) -> void:
	if not engine.supplied:
		engine.battle_supply()
	var lookup_id: int = int(engine.battle_lookup_id) if int(engine.battle_lookup_id) != 0 else int(engine.stage_info.get(&"Stage ID", 0))
	var data: BattleData = BattleData.from_config(cm, lookup_id, engine.wave_id + 1)
	if data.battle_info.is_empty():
		return
	setup_battle(engine, cm, data.battle_info, {})
	engine.used_delivered_ball_slots.clear()


static func _initial_position(idx_one_based: int) -> Vector2:
	var positions: Array[Vector2] = BattleEngine.INITIAL_POSITIONS
	var idx: int = clampi(idx_one_based, 1, positions.size()) - 1
	return positions[idx]
