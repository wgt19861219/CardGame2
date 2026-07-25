class_name BattleEngineResult
extends RefCounted

## 战斗结算统计（Logic 层）— 照源 battle_engine.lua getBattleResult:1319-1358 / getEnemyHpInfo:369-386。
## 收集双方 HP/MP/custom_data 百分比（crusade/excavate 跨波 + 多波进度 getStageProgress 用）。
## 从 battle_engine.gd 拆出（控 ≤300 行；照 battle_engine_waves.gd static 接首参 engine 模式）。
## 单机化：downExit/getExitMsg(:1093/:1381 联机 upmsg + bestRankReward/mercenary) 裁剪；
##   printStatistics(:1459 调试 print) 省略；下场编排已在 stage_manager.run_stage_battle + stage_done/failed scene 实现。

const PERC_DENOM: float = 10000.0
const ENEMY_SLOT_COUNT: int = 5


# 返 {self_heroes:Array, enemy_heroes:Dictionary(index_in_team→hero), mercenary:Array[bool]}（源返三值，GDScript Dictionary）。
static func get_battle_result(engine: Variant) -> Dictionary:
	var self_heroes: Array = []
	var enemy_heroes: Dictionary = {}
	var mercenary: Array = []
	for unit in engine.unit_list:
		if bool(unit.config.get(&"is_summoned", false)):
			continue
		var attribs: Dictionary = unit.attribs
		var hero: Dictionary = {
			&"_heroid": int(unit.tid),
			&"_hp_perc": int(ceil(float(unit.hp) / float(attribs.get(&"HP", 1)) * PERC_DENOM)),
			&"_mp_perc": int(ceil(float(unit.mp) / float(attribs.get(&"MP", 1)) * PERC_DENOM)),
			&"_custom_data": unit.custom_data,
		}
		if int(unit.camp) == BattleEngine.CAMP_ENEMY:
			var idx: int = int(unit.get_meta(&"index_in_team", 0))
			enemy_heroes[idx if idx > 0 else enemy_heroes.size() + 1] = hero
		elif int(unit.camp) == BattleEngine.CAMP_PLAYER:
			self_heroes.append(hero)
			mercenary.append(unit.is_mercenary())
	return {&"self_heroes": self_heroes, &"enemy_heroes": enemy_heroes, &"mercenary": mercenary}


# 返 {info:{idx:percent}, done_percent:int}（多波进度 getStageProgress:388-407 用）。
static func get_enemy_hp_info(engine: Variant) -> Dictionary:
	var info: Dictionary = {}
	var done_percent: int = 0
	for unit in engine.unit_list:
		var not_summoned: bool = not bool(unit.config.get(&"is_summoned", false))
		if not_summoned and int(unit.camp) == BattleEngine.CAMP_ENEMY and int(unit.monster_idx) > 0:
			var percent: int = int(ceil(float(unit.hp) / float(unit.attribs.get(&"HP", 1)) * PERC_DENOM))
			info[int(unit.monster_idx)] = percent
			done_percent += percent
	var i: int = 1
	while i <= ENEMY_SLOT_COUNT:
		if not info.has(i):
			info[i] = 0
		i += 1
	return {&"info": info, &"done_percent": done_percent}
