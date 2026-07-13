class_name SkillGroupData
extends RefCounted

## 技能组数据（Data 层）：英雄(caster_id) -> 技能槽(slot) -> 技能组信息。
## 含技能等级成长(Growth)配置。源 Skill.lua:getSkillInfo。
## 结构来自 SkillGroup.json：caster_id -> slot -> {Skill Group ID, Growth X Field/Value, CD, Unlock, ...}

const DEFAULT_SKILL_LEVEL: int = 1

var config: ConfigManager

func _init(cm: ConfigManager) -> void:
	config = cm

## 取英雄某槽的技能组原始字段。
func get_group(caster_id: int, slot: int) -> Dictionary:
	var casters: Dictionary = config.get_raw_table(&"SkillGroup")
	var slots: Dictionary = casters.get(str(caster_id), {})
	return slots.get(str(slot), {})

## 取英雄所有技能槽（slot -> 字段字典）。
func get_all_groups(caster_id: int) -> Dictionary:
	var casters: Dictionary = config.get_raw_table(&"SkillGroup")
	return casters.get(str(caster_id), {})

## 取技能组指向的 Skill Group ID（查 Skill 表用）。
func get_skill_group_id(caster_id: int, slot: int) -> int:
	return int(get_group(caster_id, slot).get("Skill Group ID", 0))

## 英雄是否有该技能槽。
func has_slot(caster_id: int, slot: int) -> bool:
	return not get_group(caster_id, slot).is_empty()

## 取英雄所有技能信息（按 skill_levels 装配等级），slot 升序返回 info 字典列表。
## skill_levels 索引 0-3 对应 slot 1-4（与 HeroInstance.skill_levels 一致）。
## 返回 info 列表（照源 getSkillInfo）；单位 initSkill（Phase 2.2续）SkillCreate(info, self, level) 造实例。
func get_skills(caster_id: int, skill_levels: Array[int], lib: SkillLibrary) -> Array[Dictionary]:
	var groups: Dictionary = get_all_groups(caster_id)
	var slots: Array[int] = []
	for slot_key in groups:
		slots.append(int(slot_key))
	slots.sort()
	var skills: Array[Dictionary] = []
	for slot in slots:
		var gid: int = int(groups[str(slot)].get("Skill Group ID", 0))
		if gid <= 0:
			continue
		var level: int = DEFAULT_SKILL_LEVEL
		if slot - 1 < skill_levels.size():
			level = skill_levels[slot - 1]
		skills.append(lib.get_skill_info(gid, level))
	return skills

## 取英雄阵营光环技能分类（源 initSkill:397-400 aura_skill_list/effect_enemy_aura_skill_list 等价）。
## 返回 {ally=[Dictionary...], enemy=[Dictionary...]}：ally=aura（友方源作用于同阵营），
## enemy=negative_aura（敌方源作用于己）。每元素 {Passive Attr, Basic Num}，
## 与 apply_auras / apply_passive_skills 输入同构。slot→level 映射同 get_skills。
func get_aura_skills(caster_id: int, skill_levels: Array[int], lib: SkillLibrary) -> Dictionary:
	var groups: Dictionary = get_all_groups(caster_id)
	var slots: Array[int] = []
	for slot_key in groups:
		slots.append(int(slot_key))
	slots.sort()
	var ally: Array[Dictionary] = []
	var enemy: Array[Dictionary] = []
	for slot in slots:
		var gid: int = int(groups[str(slot)].get("Skill Group ID", 0))
		if gid <= 0:
			continue
		var level: int = DEFAULT_SKILL_LEVEL
		if slot - 1 < skill_levels.size():
			level = skill_levels[slot - 1]
		var aura: Dictionary = lib.get_aura_bonuses(gid, level)
		if aura.is_empty():
			continue
		var entry: Dictionary = {"Passive Attr": aura["attr"], "Basic Num": aura["num"]}
		if str(aura["type"]) == "negative_aura":
			enemy.append(entry)
		else:
			ally.append(entry)
	return {"ally": ally, "enemy": enemy}

## 取英雄被动技能的属性加成列表（源 initSkill:395 passive_skill_list + rebuild:461-465）。
## 返回 [{Passive Attr, Basic Num}, ...]，与 apply_passive_skills 输入同构。slot→level 映射同 get_skills。
func get_passive_skills(caster_id: int, skill_levels: Array[int], lib: SkillLibrary) -> Array[Dictionary]:
	var groups: Dictionary = get_all_groups(caster_id)
	var slots: Array[int] = []
	for slot_key in groups:
		slots.append(int(slot_key))
	slots.sort()
	var passive_list: Array[Dictionary] = []
	for slot in slots:
		var gid: int = int(groups[str(slot)].get("Skill Group ID", 0))
		if gid <= 0:
			continue
		var level: int = DEFAULT_SKILL_LEVEL
		if slot - 1 < skill_levels.size():
			level = skill_levels[slot - 1]
		var passive: Dictionary = lib.get_passive_bonuses(gid, level)
		if passive.is_empty():
			continue
		passive_list.append({"Passive Attr": passive["attr"], "Basic Num": passive["num"]})
	return passive_list
