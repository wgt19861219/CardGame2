class_name BattleUnitRebuild
extends RefCounted

## 单位属性 rebuild（Logic 层）— 照源 unit.lua:418-524 rebuild 翻译（Phase 2.2续-E，2026-07-01）。
## 从 battle_unit.gd 拆出（≤300 行铁律）。全静态，u 为 BattleUnit（duck-type：attribs/orig_attribs/info/
##   config/stars/level/rank/rank_ratio/equips/passive_skill_list/aura_skill_list/
##   effect_enemy_aura_skill_list/buff_list/buff_effects/engine/camp/focamp/current_skill/action_name/hp/mp/gs）。
## 续-E 补全：装备(452-460)/被动(461-465)/光环(466-482)/buff(483-497) 段（前仅基础属性 + attrib_trans + Main + gs）。
## const 经 BattleUnit.* 访问（同 battle_skill.gd 用 BattleUnit.State 模式）。

const MONSTER_STAR_BASE: float = 0.875
const MONSTER_STAR_STEP: float = 0.125
const GS_DIVISOR: int = 100
const DEFAULT_HP_MOD: float = 1.0


static func rebuild(u: Variant) -> void:
	u.attribs = {}
	var attribs: Dictionary = u.attribs
	var orig: Dictionary = u.orig_attribs
	orig.clear()
	var unit_info: Dictionary = u.info
	var estimate_rank: bool = bool(u.config.get("estimate_rank", false))
	var attr_names: Array = BattleUnit.ATTRIB_NAMES
	var lvl: int = int(u.level)
	var stars: int = int(u.stars)
	var rank_ratio: float = float(u.rank_ratio)
	for attr_name in attr_names:
		var growth: float = float(unit_info.get("+" + String(attr_name) + str(stars), 0))
		var value: float = float(unit_info.get(attr_name, 0)) + growth * lvl
		var field: String = ("E." + String(attr_name)) if estimate_rank else String(attr_name)
		var rank_value: float = float(unit_info.get("rankInfo", {}).get(field, 0))
		var next_value: float = float(unit_info.get("nextRankInfo", {}).get(field, rank_value))
		value += rank_value * (1.0 - rank_ratio) + next_value * rank_ratio
		attribs[attr_name] = value
		orig[attr_name] = value
	attribs["PDM"] = 1.0
	attribs["TDM"] = 1.0
	if stars > 1 and String(unit_info.get("Unit Type", "")) == "Monster":
		var scale: float = MONSTER_STAR_BASE + MONSTER_STAR_STEP * stars
		for attr_name in BattleUnit.MONSTER_ATTRIBS:
			attribs[attr_name] = float(attribs[attr_name]) * scale
			orig[attr_name] = float(orig[attr_name]) * scale
	for equip in u.equips:
		var equip_lv: float = float(equip.get("level", 0))
		for attr_name in attr_names:
			var ev: float = float(equip.get(attr_name, 0)) + float(equip.get("+" + String(attr_name), 0)) * equip_lv
			attribs[attr_name] = float(attribs[attr_name]) + ev
	for skill_info in u.passive_skill_list:
		_add_passive_attrib(attribs, skill_info)
	if u.engine != null and bool(u.engine.enabled):
		for unit in u.engine.foreach_alive_unit(int(u.camp)):
			for skill_info in unit.aura_skill_list:
				_add_passive_attrib(attribs, skill_info)
		var foe_camp: int = BattleEngine.CAMP_ENEMY if int(u.camp) == BattleEngine.CAMP_PLAYER else BattleEngine.CAMP_PLAYER
		for unit in u.engine.foreach_alive_unit(foe_camp):
			for skill_info in unit.effect_enemy_aura_skill_list:
				_add_passive_attrib(attribs, skill_info)
	u.buff_effects = {}
	var buff_effects: Dictionary = u.buff_effects
	for buff in u.buff_list:
		buff.apply()
	if bool(buff_effects.get("immoblilize", false)) and String(u.action_name) == "Move":
		u.idle()
	var skill: Variant = u.current_skill
	if bool(buff_effects.get("stun", false)):
		u.hurt()
	elif skill != null:
		var sdt: String = String(skill.info.get("Damage Type", ""))
		if (sdt == "AD" and bool(buff_effects.get("disarm", false))) or (sdt != "AD" and bool(buff_effects.get("silence", false))):
			skill.interrupt()
	u.focamp = int(u.camp) if bool(buff_effects.get("enchanted", false)) else -int(u.camp)
	for attr1 in BattleUnit.ATTRIB_TRANS:
		var val: float = float(attribs.get(attr1, 0))
		var orig_val: float = float(orig.get(attr1, 0))
		for attr2 in BattleUnit.ATTRIB_TRANS[attr1]:
			var ratio: float = float(BattleUnit.ATTRIB_TRANS[attr1][attr2])
			attribs[attr2] = float(attribs.get(attr2, 0)) + val * ratio
			orig[attr2] = float(orig.get(attr2, 0)) + orig_val * ratio
	attribs["HP"] = float(attribs["HP"]) * float(u.config.get("hp_mod", DEFAULT_HP_MOD))
	attribs["PDM"] = float(u.config.get("dps_mod", DEFAULT_HP_MOD))
	var main_attrib: String = String(unit_info.get("Main Attrib", ""))
	if main_attrib != "" and attribs.has(main_attrib):
		attribs["AD"] = float(attribs["AD"]) + float(attribs[main_attrib])
		orig["AD"] = float(orig["AD"]) + float(orig[main_attrib])
	var total_gs: float = 0.0
	for attr in BattleUnit.ATTRIB_GS:
		total_gs += float(attribs.get(attr, 0)) * float(BattleUnit.ATTRIB_GS[attr])
	u.gs = total_gs / GS_DIVISOR
	if int(u.hp) > int(attribs["HP"]):
		u.hp = int(attribs["HP"])
	if int(u.mp) > int(attribs["MP"]):
		u.mp = int(attribs["MP"])


# 被动/光环属性加成（源 :462-464 / :469-471 / :477-479）：Passive Attr += Basic Num
static func _add_passive_attrib(attribs: Dictionary, skill_info: Variant) -> void:
	var aname: String = String(skill_info.get("Passive Attr", ""))
	if aname != "":
		attribs[aname] = float(attribs.get(aname, 0)) + float(skill_info.get("Basic Num", 0))
