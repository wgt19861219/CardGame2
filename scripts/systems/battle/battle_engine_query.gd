class_name BattleEngineQuery
extends RefCounted

## 战斗引擎单位查询（Logic 层 mixin）— 从 BattleEngine 拆出控 ≤250 行。
## static 方法第一参 engine，照 battle_engine_result/waves mixin 范式。
## 源 battle_engine.lua findMonster:638 / findBoss:653 / findHero:662 /
## foreachAliveUnit:1665 / foreachNpc:1675 / foreachEntity:1685 / getUnitByIndex:1748 / getUnitNum:1755。


# 源 foreachAliveUnit（battle_engine.lua:1665-1672）：返回存活列表快照（迭代期间 die 安全）
static func alive_units(engine: Variant, camp: int) -> Array:
	return engine._alive_list(camp).duplicate()


# 源 foreachNpc（battle_engine.lua:1675-1682）
static func npcs(engine: Variant) -> Array:
	return engine.npc_list.duplicate()


# 源 foreachEntity（battle_engine.lua:1685-1710）：三列表合并快照
static func entities(engine: Variant) -> Array:
	var all: Array = []
	all.append_array(engine.unit_list)
	all.append_array(engine.projectile_list)
	all.append_array(engine.npc_list)
	return all


# 源 findMonster（battle_engine.lua:638-650）
static func find_monster(engine: Variant, id_or_name: Variant) -> Variant:
	var found: Array = []
	for unit in engine.unit_list:
		if int(unit.camp) == BattleEngine.CAMP_ENEMY and ((id_or_name is int and unit.tid == id_or_name) or (id_or_name is String and unit.name == id_or_name)):
			found.append(unit)
	return found[0] if found.size() == 1 else null


# 源 findBoss（battle_engine.lua:653-660）
static func find_boss(engine: Variant) -> Variant:
	for unit in engine.unit_list:
		if int(unit.camp) == BattleEngine.CAMP_ENEMY and bool(unit.config.get("is_boss", false)):
			return unit
	return null


# 源 findHero（battle_engine.lua:662-668）
static func find_hero(engine: Variant, id_or_name: Variant) -> Variant:
	for unit in engine.unit_list:
		if int(unit.camp) == BattleEngine.CAMP_PLAYER and ((id_or_name is int and unit.tid == id_or_name) or (id_or_name is String and unit.name == id_or_name)):
			return unit
	return null


# 源 getUnitByIndex（battle_engine.lua:1748-1752）
static func unit_by_index(engine: Variant, index: int, camp: int) -> Variant:
	var list: Array = engine._alive_list(camp)
	if index >= 0 and index < list.size():
		return list[index]
	return null


# 源 getUnitNum（battle_engine.lua:1755-1760）
static func unit_num(engine: Variant, camp: int) -> int:
	return engine._alive_list(camp).size()
