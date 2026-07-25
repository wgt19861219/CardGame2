class_name SkillLibrary
extends RefCounted

## 技能库（Data 层）：照源 skill.lua:getSkillInfo（10-42）按技能组 ID + 等级构建技能信息字典。
## Skill 表：group_id -> level 0 基础字段（源只取 level 0，其余靠 Growth 算）。
## 成长公式（源 :24）：字段值 = 基础 + (skill_level - 1) × Growth Value；skill/buff 字段分别 patch。
## Buff 关联（源 :15-17）：Buff ID > 0 时查 Buff 表，附 info["buff_info"]（单位 addBuff 时 BuffCreate）。
## SkillGroup 槽字段（Growth/Unlock 等）merge 进 info（info 优先，源 setmetatable __index=group）。

const GROWTH_START: int = 1
const GROWTH_COUNT: int = 4
const BASE_LEVEL: int = 0
const LEVEL_ONE: int = 1

var config: ConfigManager
var cache: Dictionary = {}        # "group_id:level" -> info(Dictionary)
var _by_group: Dictionary = {}    # group_id(int) -> level0 基础字段
var _growth: Dictionary = {}      # group_id(int) -> Array[{field:String, value:int}]
var _group_slot: Dictionary = {}  # group_id(int) -> SkillGroup 槽字段（源 getSkillInfo 继承 group）

func _init(cm: ConfigManager) -> void:
	config = cm
	_build_index()

func _build_index() -> void:
	# Skill 表：group_id -> level 0 基础字段（源 lookupDataTable("Skill", nil, gid, 0)）
	var skill_raw: Dictionary = config.get_raw_table(&"Skill")
	for group_key in skill_raw:
		var levels: Dictionary = skill_raw[group_key]
		var base: Dictionary = levels.get(str(BASE_LEVEL), {})
		if not base.is_empty():
			_by_group[int(group_key)] = base
	# SkillGroup 表：group_id -> 槽字段（含 Growth 配置，遍历所有英雄×槽，去重）
	var sg_raw: Dictionary = config.get_raw_table(&"SkillGroup")
	for caster_key in sg_raw:
		var slots: Dictionary = sg_raw[caster_key]
		for slot_key in slots:
			var sf: Dictionary = slots[slot_key]
			var gid: int = int(sf.get("Skill Group ID", 0))
			if gid > 0 and not _growth.has(gid):
				_growth[gid] = _extract_growth(sf)
				_group_slot[gid] = sf

func _extract_growth(slot_fields: Dictionary) -> Array:
	var growth: Array = []
	var i: int = GROWTH_START
	while i <= GROWTH_COUNT:
		var field: String = str(slot_fields.get("Growth %d Field" % i, ""))
		var value: int = int(slot_fields.get("Growth %d Value" % i, 0))
		if field != "" and value != 0:
			growth.append({"field": field, "value": value})
		i += 1
	return growth

func has_skill(group_id: int) -> bool:
	return _by_group.has(group_id)

## 返回 info：Skill 基础字段 + group 槽继承 + Growth patch + buff_info（Buff 表关联）。
func get_skill_info(group_id: int, level: int = LEVEL_ONE) -> Dictionary:
	var cache_key: String = "%d:%d" % [group_id, level]
	if cache.has(cache_key):
		return cache[cache_key]
	var info: Dictionary = _by_group.get(group_id, {}).duplicate()
	info["groupId"] = group_id
	var slot: Dictionary = _group_slot.get(group_id, {})
	for k in slot:
		if not info.has(k):
			info[k] = slot[k]
	var buff_info: Dictionary = {}
	if int(info.get("Buff ID", 0)) > 0:
		buff_info = _lookup_buff(int(info["Buff ID"])).duplicate()
	var growth: Array = _growth.get(group_id, [])
	for g in growth:
		var field: String = str(g["field"])
		var delta: float = float(level - LEVEL_ONE) * float(g["value"])
		if info.has(field):
			info[field] = _add_typed(info[field], delta)
		elif buff_info.has(field):
			buff_info[field] = _add_typed(buff_info[field], delta)
	if not buff_info.is_empty():
		info["buff_info"] = buff_info
	cache[cache_key] = info
	return info

func _lookup_buff(buff_id: int) -> Dictionary:
	return config.get_raw_table(&"Buff").get(str(buff_id), {})

func _add_typed(value: Variant, delta: float) -> Variant:
	if typeof(value) == TYPE_FLOAT:
		return float(value) + delta
	return int(value) + int(delta)

## 取 aura 类技能属性加成（源 initSkill Active Type=aura/negative_aura）。
func get_aura_bonuses(group_id: int, level: int = LEVEL_ONE) -> Dictionary:
	var base: Dictionary = _by_group.get(group_id, {})
	var atype: String = str(base.get("Active Type", ""))
	if atype != "aura" and atype != "negative_aura":
		return {}
	var fields: Dictionary = base.duplicate()
	_apply_growth(fields, group_id, level)
	return {"type": atype, "attr": str(fields.get("Passive Attr", "")), "num": int(fields.get("Basic Num", 0))}

## 取被动技能属性加成（源 initSkill Active Type=passive + rebuild:461-465 attribs[Passive Attr]+=Basic Num）。
func get_passive_bonuses(group_id: int, level: int = LEVEL_ONE) -> Dictionary:
	var base: Dictionary = _by_group.get(group_id, {})
	if str(base.get("Active Type", "")) != "passive":
		return {}
	var fields: Dictionary = base.duplicate()
	_apply_growth(fields, group_id, level)
	return {"attr": str(fields.get("Passive Attr", "")), "num": int(fields.get("Basic Num", 0))}

## 取技能 Script Arg2（含 Growth 成长）。Phoenix_pasv(group 524) 蛋窗口恢复血量基础值。
func get_script_arg2(group_id: int, level: int = LEVEL_ONE) -> float:
	var base: Dictionary = _by_group.get(group_id, {})
	var fields: Dictionary = base.duplicate()
	_apply_growth(fields, group_id, level)
	return float(fields.get("Script Arg2", 0))

func _apply_growth(fields: Dictionary, group_id: int, level: int) -> void:
	if level <= LEVEL_ONE:
		return
	var growth: Array = _growth.get(group_id, [])
	for g in growth:
		var field: String = str(g["field"])
		var delta: float = float(level - LEVEL_ONE) * float(g["value"])
		var current: Variant = fields.get(field, null)
		if current == null:
			continue
		fields[field] = _add_typed(current, delta)

func is_cached(group_id: int, level: int = LEVEL_ONE) -> bool:
	return cache.has("%d:%d" % [group_id, level])
