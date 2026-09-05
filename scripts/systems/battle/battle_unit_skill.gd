class_name BattleUnitSkill
extends RefCounted

## 单位技能装配（Logic 层）— 照源 unit.lua:331 calculateSKLAttri / 351 initSkill 翻译（Phase 2.2续-D，2026-07-01）。
## 静态，u 为 BattleUnit，cm 取 SkillGroup 表，lib 为 SkillLibrary（get_skill_info）。
## lib null 时跳过装配（测试/未注入）→ skill_list 留空（AI find_skill_to_cast 总 null → 单位不主动攻击）。
## 这是"单位会主动释放技能"的最后一块——engine.tick→update→AI→find_skill_to_cast 返 skill→cast_skill→start。

const ATTACK_RANGE_OFFSET: float = 5.0


# equips 本轮空（装备加载 Phase 2.2续 装备段 148-175），仅 rankInfo 基础值。
static func calculate_skl_attri(u: Variant) -> float:
	var field: String = "SKL"
	if bool(u.config.get("estimate_rank", false)):
		field = "E.SKL"
	var skl: float = float(u.info.get("rankInfo", {}).get(field, 0.0))
	for equip in u.equips:
		var lv: float = float(equip.get("level", 0.0))
		skl += float(equip.get("SKL", 0.0)) + float(equip.get("+SKL", 0.0)) * lv
	return skl


static func init_skill(u: Variant, cm: ConfigManager, lib: Variant) -> void:
	u.manual_skill = null
	u.skill_list = []
	u.passive_skill_list = []
	u.aura_skill_list = []
	u.effect_enemy_aura_skill_list = []
	u.skills = {}
	u.attack_range = 0.0
	if lib == null:
		return  # 无 SkillLibrary（测试/未注入）→ 跳过装配
	var info: Dictionary = u.info
	var uid: int = int(info.get("ID", 0))
	var skl: int = int(calculate_skl_attri(u))
	var is_monster: bool = bool(u.config.get("is_monster", false))
	var estimate_max_rank: bool = bool(u.config.get("estimate_max_rank", false))
	var estimate_skill: bool = bool(u.config.get("estimate_skill", false))
	var has_skill_levels: bool = u.proto.has("_skill_levels")
	var skill_levels: Dictionary = u.proto.get("_skill_levels", {})
	var basic_skill_id: int = int(info.get("Basic Skill", 0))
	var skill_groups: Dictionary = cm.get_raw_table(&"SkillGroup").get(str(uid), {})
	for slot in skill_groups:
		var group: Dictionary = skill_groups[slot]
		var unlock: int = int(group.get("Unlock For Monster", 0)) if is_monster else int(group.get("Unlock", 0))
		if unlock > int(u.rank):
			continue
		var skill_level: int = 0
		if estimate_max_rank or estimate_skill:
			skill_level = int(u.level)
		elif has_skill_levels:
			skill_level = int(skill_levels.get(slot, 0)) + skl
		if int(group.get("Skill Group ID", 0)) == basic_skill_id:
			skill_level = 1
		if skill_level <= 0:
			continue
		var group_id: int = int(group.get("Skill Group ID", 0))
		var skill_info: Dictionary = lib.get_skill_info(group_id, skill_level)
		var active_type: String = str(skill_info.get("Active Type", ""))
		if active_type == "active":
			var skill: BattleSkill = BattleSkill.new(skill_info, u, skill_level)
			u.skill_list.append(skill)
			u.skills[int(skill_info.get("Skill Group ID", 0))] = skill
			u.skills[String(skill_info.get("Skill Name", ""))] = skill
			if bool(skill_info.get("Manual", false)):
				u.manual_skill = skill
		elif active_type == "passive":
			u.passive_skill_list.append(skill_info)
		elif active_type == "aura":
			u.aura_skill_list.append(skill_info)
		elif active_type == "negative_aura":
			u.effect_enemy_aura_skill_list.append(skill_info)
	u.basic_skill = _find_skill_by_group(u.skill_list, basic_skill_id)
	if u.basic_skill != null:
		u.attack_range = float(u.basic_skill.info.get("Max Range", 0.0)) - ATTACK_RANGE_OFFSET
	u.skill_list.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(a.info.get("Priority", 0)) > int(b.info.get("Priority", 0)))


static func _find_skill_by_group(skill_list: Array, group_id: int) -> Variant:
	for skill in skill_list:
		if int(skill.info.get("Skill Group ID", 0)) == group_id:
			return skill
	return null
