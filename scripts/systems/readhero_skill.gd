class_name ReadheroSkill
extends RefCounted

## 英雄技能描述查询（Logic 层）— 照源 controller.lua:68 getSkillDesc + skillstren.lua:742 description。
## 遍历 SkillGroup[slot] Growth 1-N，查 Skill[gid][0][field] or Buff[bid][field]，
## summary 的 # / ## 替换为成长值数字。供 HeroDetailPanel 技能描述弹板消费。

const NUM_DECIMAL_PRECISION: float = 0.01   # 成长值小数精度（2 位，源 Lua number 默认）


static func get_skill_description(hero: HeroInstance, slot: int, cm: ConfigManager) -> String:
	var sg: Dictionary = cm.get_raw_table(&"SkillGroup").get(str(hero.tid), {}).get(str(slot), {})
	if sg.is_empty():
		return ""
	var gid: int = int(sg.get("Skill Group ID", 0))
	var skill: Dictionary = cm.get_raw_table(&"Skill").get(str(gid), {}).get("0", {})
	# 表存 LSTR key（源中文渠道表直存中文，本项目表存 key 须查翻译；漏查=浮层显示英文 key，2026-08-30 修）
	return cm.get_lstr(String(skill.get("Description", "")))


# skill_add：升级预览加成（源 preSkillLevelAdd，默认 0）。level = 显示等级 + skill_add。
# 遍历 Growth 1-N：field/value/multiplier/summary 任一缺或 growth/multiplier==0 则停（源 :83-84）。
static func get_skill_desc(hero: HeroInstance, slot: int, cm: ConfigManager, skill_add: int = 0) -> String:
	var sg: Dictionary = cm.get_raw_table(&"SkillGroup").get(str(hero.tid), {}).get(str(slot), {})
	if sg.is_empty():
		return ""
	var gid: int = int(sg.get("Skill Group ID", 0))
	var skill: Dictionary = cm.get_raw_table(&"Skill").get(str(gid), {}).get("0", {})
	var bid: int = int(skill.get("Buff ID", 0))
	var buff: Dictionary = cm.get_raw_table(&"Buff").get(str(bid), {}) if bid > 0 else {}
	var cur_level: int = int(hero.skill_levels[slot - 1]) if slot - 1 < hero.skill_levels.size() else 1
	var init_level: int = int(sg.get("Init Level", 1))
	var level: int = cur_level - init_level + 1 + skill_add
	var text: String = ""
	var index: int = 1
	while true:
		var field: String = String(sg.get("Growth %d Field" % index, ""))
		if field.is_empty():
			break
		var growth: float = float(sg.get("Growth %d Value" % index, 0))
		var multiplier: float = float(sg.get("Growth %d Multiplier" % index, 0))
		var summary: String = String(sg.get("Growth %d Summary" % index, ""))
		if summary.is_empty() or growth == 0.0 or multiplier == 0.0:
			break
		var value: float = float(skill.get(field, buff.get(field, 0)))
		growth *= multiplier
		value *= multiplier
		# 先翻译（key 含 # 原样查表，译文含 # 占位）再数字替换——等价源中文渠道在中文文案上 gsub。
		var append: String = cm.get_lstr(summary).replace("##", _num_str(value + growth * (level - 1))).replace("#", _num_str(growth * level))
		text += append + "\n"
		index += 1
	return text


static func _num_str(n: float) -> String:
	if is_equal_approx(n, int(n)):
		return str(int(n))
	return str(snapped(n, NUM_DECIMAL_PRECISION))
