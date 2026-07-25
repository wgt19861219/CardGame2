class_name BattleData
extends RefCounted

## 战斗关卡静态数据（Data 层）— 照源 battle_engine.lua setupBattle（:175-240）+ enterStage（:350-366）。
## 从 Battle 表读敌人配置（两级 Battle[stage_id][wave]）。
## 敌人字段：Monster N ID / Level N / Stars N / Monster HP%·DPS% / Boss Position·HP%·DPS%·SIZE% / Money Reward N / MP N。
## 单机化：源 enterStage lookupDataTable("Battle", nil, stageId, wave) → cm.get_raw_table 两级取。

const MONSTER_SLOT_COUNT: int = 5
const PERC_DENOM: float = 100.0
const MOD_DEFAULT: float = 100.0
const BOSS_SIZE_DEFAULT: float = 120.0
const DEFAULT_WAVE: int = 1
const DEFAULT_STARS: int = 1

var stage_id: int = 0
var wave_id: int = DEFAULT_WAVE
var battle_info: Dictionary = {}  # 原始 Battle[stage_id][wave] 字段字典


static func _modify(old: float, modifier: float, default: float = MOD_DEFAULT) -> float:
	var mod_val: float = modifier if modifier != 0.0 else default
	return old * mod_val / PERC_DENOM


static func from_config(cm: ConfigManager, sid: int, wave: int = DEFAULT_WAVE) -> BattleData:
	var data := BattleData.new()
	data.stage_id = sid
	data.wave_id = wave
	var raw: Dictionary = cm.get_raw_table(&"Battle")
	var stage_rows: Dictionary = raw.get(str(sid), {})
	data.battle_info = stage_rows.get(str(wave), {})
	return data


func has_monsters() -> bool:
	return not battle_info.is_empty()


## 返回 Array[{tid, level, stars, hp_mod, dps_mod, is_boss, size_mod, money, mp}]。
func get_monsters() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if battle_info.is_empty():
		return out
	var boss_idx: int = int(battle_info.get(&"Boss Position", 0))
	var hp_pct: float = float(battle_info.get(&"Monster HP%", 0))
	var dps_pct: float = float(battle_info.get(&"Monster DPS%", 0))
	var boss_hp: float = float(battle_info.get(&"Boss HP%", 0))
	var boss_dps: float = float(battle_info.get(&"Boss DPS%", 0))
	var boss_size: float = float(battle_info.get(&"BOSS SIZE%", 0))
	var i: int = 1
	while i <= MONSTER_SLOT_COUNT:
		var id: int = int(battle_info.get(StringName("Monster " + str(i) + " ID"), 0))
		if id > 0:
			var level: int = int(battle_info.get(StringName("Level " + str(i)), 0))
			var stars: int = int(battle_info.get(StringName("Stars " + str(i)), DEFAULT_STARS))
			var hp_mod: float = _modify(1.0, hp_pct)
			var dps_mod: float = _modify(1.0, dps_pct)
			var size_mod: float = 1.0
			var is_boss: bool = (i == boss_idx)
			if is_boss:
				hp_mod = _modify(hp_mod, boss_hp)
				dps_mod = _modify(dps_mod, boss_dps)
				size_mod = _modify(size_mod, boss_size, BOSS_SIZE_DEFAULT)
			out.append({
				"tid": id,
				"level": level,
				"stars": stars,
				"hp_mod": hp_mod,
				"dps_mod": dps_mod,
				"is_boss": is_boss,
				"size_mod": size_mod,
				"money": int(battle_info.get(StringName("Money Reward " + str(i)), 0)),
				"mp": int(battle_info.get(StringName("MP " + str(i)), 0)),
			})
		i += 1
	return out
