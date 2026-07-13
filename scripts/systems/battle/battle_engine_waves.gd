class_name BattleEngineWaves
extends RefCounted

## 战斗多波装配（Logic 层）— 照源 battle_engine.lua setupBattle:175-262 / nextBattle:624-635 / resetUnitList:170-174。
## 从 battle_engine.gd 拆出（控 ≤300 行；照 battle_unit_combat.gd static 接首参 engine 模式）。
## setup_battle 接原始 Battle[stage][wave] Dictionary 自解析 5 槽怪物+boss+位置 X 镜像。
## next_battle 复用 BattleData.from_config 两级下钻查下一波（源 lookupDataTable("Battle", nil, id, wave)）。

const MOD_DEFAULT: float = 100.0        # 源 modify default（nil/0 取此）
const PERC_DENOM: float = 100.0         # 源 modify 分母
const BOSS_SIZE_DEFAULT: float = 120.0  # 源 :216 modify(..., "BOSS SIZE%", 120)
const MONSTER_SLOT_COUNT: int = 5       # 源 for i = 1, 5
const DEFAULT_STARS: int = 1            # 源 :199 battle_info["Stars "..i] or 1


## 源 modify（:179-186）：modifier 为 0 取 default，否则 old×modifier/100。
static func _modify(old: float, modifier: float, default: float = MOD_DEFAULT) -> float:
	var mod_val: float = modifier if modifier != 0.0 else default
	return old * mod_val / PERC_DENOM


## 源 resetUnitList:170-174：遍历 unit_list 调 unit.reset()。
static func reset_unit_list(engine: Variant) -> void:
	for unit in engine.unit_list:
		unit.reset()


## 源 setupBattle:175-262。battle = 原始 Battle[stage][wave] Dictionary（= BattleData.battle_info）。
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
			# 源 :194 not hp_info or hp_info[i]._hp_perc ~= 0 才创建（_hp_perc==0 = 该怪不出现）
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
				# 源 :230-234 position X 镜像 maxX - x（敌方置于舞台右侧）
				var max_x: float = float(engine.stage_rect.get(&"maxX", 0))
				var base_pos: Vector2 = _initial_position(monster_pos_idx)
				monster.position = Vector2(max_x - base_pos.x, base_pos.y)
				engine.add_unit(monster)
				monster.monster_idx = i
		i += 1
	# 源 :241-250 英雄位置重置（玩家方 INITIAL_POSITIONS 左侧原样）
	var heroes: Array = engine.alive_units.get(BattleEngine.CAMP_PLAYER, [])
	var hi: int = 0
	while hi < heroes.size() and hi < BattleEngine.INITIAL_POSITIONS.size():
		var hero: Variant = heroes[hi]
		var hpos: Vector2 = BattleEngine.INITIAL_POSITIONS[hi]
		hero.position = Vector2(hpos.x, hpos.y)
		hero.previous_position = Vector2(hpos.x, hpos.y)
		hi += 1
	reset_unit_list(engine)
	# 源 :253-256 stage script（getStageScript(stage_id, wave_id)(self)）
	var script_cb: Callable = BattleStageScripts.get_stage_script(engine, cm, int(engine.stage_info.get(&"Stage ID", 0)), engine.wave_id)
	if script_cb.is_valid():
		script_cb.call(engine)
	# 源 :257-261 run_with_scene ListenTimer FireEvent EnterBattleStage — View 事件，本项目无 run_with_scene，
	# battle_scene View 自行处理入场（Phase 4），单机化照源不在此触发。


## 源 nextBattle:624-635。首次 battleSupply + 查下一波原始 Dictionary + setupBattle + 清空能量球投放槽。
static func next_battle(engine: Variant, cm: ConfigManager) -> void:
	if not engine.supplied:
		engine.battle_supply()
	# 源 :628 lookupId = battle_lookup_id or stage_info["Stage ID"]
	var lookup_id: int = int(engine.battle_lookup_id) if int(engine.battle_lookup_id) != 0 else int(engine.stage_info.get(&"Stage ID", 0))
	# 源 :629 lookupDataTable("Battle", nil, lookupId, wave_id+1) → BattleData.from_config 两级下钻
	var data: BattleData = BattleData.from_config(cm, lookup_id, engine.wave_id + 1)
	if data.battle_info.is_empty():
		return  # 源 :630-631 not battle return
	setup_battle(engine, cm, data.battle_info, {})
	# 源 :634 ed.engine.usedDeliveredBallSlots = {}（Kael 能量球槽跨波清空）
	engine.used_delivered_ball_slots.clear()


# 源 :230 initial_position[monsterPosIndex]（Lua 1-based）→ GDScript 0-based，防御越界。
static func _initial_position(idx_one_based: int) -> Vector2:
	var positions: Array[Vector2] = BattleEngine.INITIAL_POSITIONS
	var idx: int = clampi(idx_one_based, 1, positions.size()) - 1
	return positions[idx]
