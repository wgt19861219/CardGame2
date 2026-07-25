class_name BattleEngineQuery
extends RefCounted

## 战斗引擎单位查询（Logic 层 mixin）— 从 BattleEngine 拆出控 ≤250 行。
## static 方法第一参 engine，照 battle_engine_result/waves mixin 范式。
## foreachAliveUnit:1665 / foreachNpc:1675 / foreachEntity:1685 / getUnitByIndex:1748 / getUnitNum:1755。


static func alive_units(engine: Variant, camp: int) -> Array:
	return engine._alive_list(camp).duplicate()


static func npcs(engine: Variant) -> Array:
	return engine.npc_list.duplicate()


static func entities(engine: Variant) -> Array:
	var all: Array = []
	all.append_array(engine.unit_list)
	all.append_array(engine.projectile_list)
	all.append_array(engine.npc_list)
	return all


static func find_monster(engine: Variant, id_or_name: Variant) -> Variant:
	var found: Array = []
	for unit in engine.unit_list:
		if int(unit.camp) == BattleEngine.CAMP_ENEMY and ((id_or_name is int and unit.tid == id_or_name) or (id_or_name is String and unit.name == id_or_name)):
			found.append(unit)
	return found[0] if found.size() == 1 else null


static func find_boss(engine: Variant) -> Variant:
	for unit in engine.unit_list:
		if int(unit.camp) == BattleEngine.CAMP_ENEMY and bool(unit.config.get("is_boss", false)):
			return unit
	return null


static func find_hero(engine: Variant, id_or_name: Variant) -> Variant:
	for unit in engine.unit_list:
		if int(unit.camp) == BattleEngine.CAMP_PLAYER and ((id_or_name is int and unit.tid == id_or_name) or (id_or_name is String and unit.name == id_or_name)):
			return unit
	return null


static func unit_by_index(engine: Variant, index: int, camp: int) -> Variant:
	var list: Array = engine._alive_list(camp)
	if index >= 0 and index < list.size():
		return list[index]
	return null


static func unit_num(engine: Variant, camp: int) -> int:
	return engine._alive_list(camp).size()
