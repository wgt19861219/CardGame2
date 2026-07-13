class_name BattleUnitInit
extends RefCounted

## 战斗单位初始化辅助（Logic 层 mixin）— 从 BattleUnit 拆出控 ≤250 行。
## static 方法第一参 unit（BattleUnit 实例）/ cm，照 battle_unit_rebuild/equip mixin 范式。
## 源 unit.lua getUnitInfo:23 / getMaxRankLevel:527 / initHpMpInfo:54。


# 源 getUnitInfo（unit.lua:23-37）：Unit 表 + hero_equip/UnitRank rank 信息
static func get_unit_info(cm: ConfigManager, unit_id: int, unit_rank: int) -> Dictionary:
	var uinfo: Dictionary = cm.get_raw_table(&"Unit").get(str(unit_id), {})
	var info: Dictionary = {}
	for k in uinfo:
		info[k] = uinfo[k]
	var unit_db_id: int = int(info.get("ID", unit_id))
	info["equipInfo"] = cm.get_raw_table(&"hero_equip").get(str(unit_db_id), {}).get(str(unit_rank), {})
	info["rankInfo"] = cm.get_raw_table(&"UnitRank").get(str(unit_db_id), {}).get(str(unit_rank), {})
	info["nextRankInfo"] = cm.get_raw_table(&"UnitRank").get(str(unit_db_id), {}).get(str(unit_rank + 1), {})
	return info


# 源 getMaxRankLevel（unit.lua:527-542）：遍历 hero_equip LvReq 找最高 rank
static func get_max_rank_level(unit: Variant, cm: ConfigManager) -> int:
	var max_rank: int = BattleUnit.RANK_MAX
	var result: int = 0
	var unit_db_id: int = int(cm.get_raw_table(&"Unit").get(str(unit.tid), {}).get("ID", unit.tid))
	var hero_equips: Dictionary = cm.get_raw_table(&"hero_equip").get(str(unit_db_id), {})
	for rank_level in range(1, max_rank + 1):
		var lv_req: int = int(hero_equips.get(str(rank_level), {}).get("LvReq", BattleUnit.LV_REQ_UNREACHABLE))
		if lv_req <= unit.level:
			result = rank_level if rank_level < max_rank else max_rank
	return result


# 源 initHpMpInfo（unit.lua:54-73）
static func init_hp_mp(unit: Variant) -> void:
	var hp_perc: float = 1.0
	var mp_perc: float = 0.0
	if not unit.dyna_data.is_empty():
		hp_perc = float(unit.dyna_data.get("_hp_perc", BattleUnit.PERC_DENOM)) / float(BattleUnit.PERC_DENOM) if int(unit.dyna_data.get("_hp_perc", 0)) != 0 else 1.0
		mp_perc = float(unit.dyna_data.get("_mp_perc", 0)) / float(BattleUnit.PERC_DENOM)
		unit.custom_data = unit.dyna_data.get("_custom_data", {})
	unit.hp = int(unit.attribs.get("HP", 0) * hp_perc)
	if unit.monster_idx == 0:
		unit.mp = int(unit.attribs.get("MP", 0) * mp_perc)


# 源 _init config 处理段（unit.lua:86-100）：hp_mod/dps_mod/size_mod/money 规范化
static func normalize_config(cfg: Dictionary) -> Dictionary:
	cfg["hp_mod"] = float(cfg.get("hp_mod", BattleUnit.DEFAULT_HP_MOD))
	cfg["dps_mod"] = float(cfg.get("dps_mod", BattleUnit.DEFAULT_HP_MOD))
	cfg["size_mod"] = float(cfg.get("size_mod", BattleUnit.DEFAULT_HP_MOD))
	cfg["money"] = int(cfg.get("money", 0))
	return cfg


# 源 _init info 字段提取段（unit.lua:205-207）：name/hp_layer/boss_icon/radius/focamp/equips
static func apply_info_fields(unit: Variant) -> void:
	unit.name = String(unit.info.get("Name", ""))
	unit.hp_layer = int(unit.info.get("HP Layers", 0))
	unit.boss_icon_name = String(unit.info.get("Boss Portrait", ""))
	unit.focamp = -unit.camp
	unit.radius = float(unit.info.get("Collide Radius", 0)) * float(unit.config["size_mod"])
	unit.equips = []


# 源 _init rank 计算段（unit.lua:127-140）：estimate_rank/estimate_max_rank/直接取 + RANK_MAX 截断
static func calc_rank(unit: Variant, cm: ConfigManager) -> void:
	var cfg: Dictionary = unit.config
	if bool(cfg.get("estimate_rank", false)):
		unit.rank = int((unit.level + BattleUnit.RANK_EST_OFFSET) / BattleUnit.RANK_EST_DIVISOR)
		unit.rank_ratio = float((unit.level - 1) % BattleUnit.RANK_EST_DIVISOR) / float(BattleUnit.RANK_EST_DIVISOR)
	elif bool(cfg.get("estimate_max_rank", false)):
		unit.rank = get_max_rank_level(unit, cm)
		unit.rank_ratio = 0.0
	else:
		unit.rank = int(unit.proto.get("_rank", 1))
		unit.rank_ratio = 0.0
	if unit.rank > BattleUnit.RANK_MAX:
		unit.rank = BattleUnit.RANK_MAX
		unit.rank_ratio = 0.0
