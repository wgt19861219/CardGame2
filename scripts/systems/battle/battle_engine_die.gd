class_name BattleEngineDie
extends RefCounted

## 战斗引擎死亡/结算处理（Logic 层 mixin）— 从 BattleEngine 拆出控 ≤250 行。
## static 方法第一参 engine，照 battle_engine_result/waves mixin 范式。


static func on_unit_die(engine: Variant, unit: Variant, killer: Variant) -> void:
	var camp_list: Array = engine._alive_list(int(unit.camp))
	for i in range(camp_list.size() - 1, -1, -1):
		if camp_list[i] == unit:
			camp_list.remove_at(i)
			break
	var both: Array = engine._alive_list(BattleEngine.CAMP_BOTH)
	var die_handlers: Array = []; var die_index: int = -1
	for i in range(both.size() - 1, -1, -1):
		if both[i] == unit:
			die_index = i
		else:
			die_handlers.append(both[i])
	if die_index >= 0:
		both.remove_at(die_index)
	for u in die_handlers:
		u.handle_unit_die_event(unit, killer)
	if killer != null and bool(killer.is_hero()) and not bool(unit.config.get("is_summoned", false)):
		BattleUnitCombat.on_hero_kill(killer, BattleEngine.KILL_MP_BONUS)
	match int(unit.camp):
		BattleEngine.CAMP_PLAYER:
			engine.alive_alliance_count -= 1
			engine.dead_alliance_count += 1
		BattleEngine.CAMP_ENEMY:
			engine.alive_enemy_count -= 1
			engine.dead_enemy_count += 1


static func on_npc_die(engine: Variant, npc: Variant) -> void:
	for i in range(engine.npc_list.size()):
		if engine.npc_list[i] == npc:
			engine.npc_list.remove_at(i)
			break


static func on_battle_end(engine: Variant) -> void:
	var new_list: Array = []
	for unit in engine.unit_list:
		if bool(unit.config.get("is_summoned", false)):
			var summoner: Variant = unit.config["summoner"]
			if summoner != null:
				summoner.dmg_statistics = float(summoner.dmg_statistics) + float(unit.dmg_statistics)
		else:
			unit.remove_all_buffs()
			new_list.append(unit)
	engine.unit_list = new_list
