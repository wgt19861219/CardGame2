class_name BattleUnitRebuild
extends RefCounted

## 单位属性 rebuild（Logic 层）— 照源 unit.lua:418-524 rebuild 翻译（Phase 2.2续-E，2026-07-01）。
## 从 battle_unit.gd 拆出（≤300 行铁律）。全静态，u 为 BattleUnit（duck-type：attribs/orig_attribs/info/
##   config/stars/level/rank/rank_ratio/equips/passive_skill_list/aura_skill_list/
##   effect_enemy_aura_skill_list/buff_list/buff_effects/engine/camp/focamp/current_skill/action_name/hp/mp/gs）。
## 续-E 补全：装备(452-460)/被动(461-465)/光环(466-482)/buff(483-497) 段（前仅基础属性 + attrib_trans + Main + gs）。
## const 经 BattleUnit.* 访问（同 battle_skill.gd 用 BattleUnit.State 模式）。

const MONSTER_STAR_BASE: float = 0.875  # 源 0.875 + 0.125*stars
const MONSTER_STAR_STEP: float = 0.125
const GS_DIVISOR: int = 100  # 源 gs / 100
const DEFAULT_HP_MOD: float = 1.0


# 源 rebuild（unit.lua:418-524）
static func rebuild(u: Variant) -> void:
	u.attribs = {}  # 源 :419 新建 table（P1-1：buff.caster_attribs 锁定创建时快照语义，非实时跟随 caster 属性）
	var attribs: Dictionary = u.attribs
	var orig: Dictionary = u.orig_attribs
	orig.clear()
	var unit_info: Dictionary = u.info
	var estimate_rank: bool = bool(u.config.get("estimate_rank", false))
	var attr_names: Array = BattleUnit.ATTRIB_NAMES
	var lvl: int = int(u.level)
	var stars: int = int(u.stars)
	var rank_ratio: float = float(u.rank_ratio)
	# 源 :420-441 基础属性 = info[attr] + growth×level + rank 线性插值
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
	# 源 monster 星级缩放（444-451）
	if stars > 1 and String(unit_info.get("Unit Type", "")) == "Monster":
		var scale: float = MONSTER_STAR_BASE + MONSTER_STAR_STEP * stars
		for attr_name in BattleUnit.MONSTER_ATTRIBS:
			attribs[attr_name] = float(attribs[attr_name]) * scale
			orig[attr_name] = float(orig[attr_name]) * scale
	# 源 装备（452-460）：info[attr] + +attr×lv（equips 本轮空，装备加载待续）
	for equip in u.equips:
		var equip_lv: float = float(equip.get("level", 0))
		for attr_name in attr_names:
			var ev: float = float(equip.get(attr_name, 0)) + float(equip.get("+" + String(attr_name), 0)) * equip_lv
			attribs[attr_name] = float(attribs[attr_name]) + ev
	# 源 被动技能属性（461-465）：Passive Attr + Basic Num
	for skill_info in u.passive_skill_list:
		_add_passive_attrib(attribs, skill_info)
	# 源 光环（466-482）：engine.enabled 时，同营 aura + 敌营 effect_enemy_aura
	if u.engine != null and bool(u.engine.enabled):
		for unit in u.engine.foreach_alive_unit(int(u.camp)):
			for skill_info in unit.aura_skill_list:
				_add_passive_attrib(attribs, skill_info)
		var foe_camp: int = BattleEngine.CAMP_ENEMY if int(u.camp) == BattleEngine.CAMP_PLAYER else BattleEngine.CAMP_PLAYER
		for unit in u.engine.foreach_alive_unit(foe_camp):
			for skill_info in unit.effect_enemy_aura_skill_list:
				_add_passive_attrib(attribs, skill_info)
	# 源 buff（483-497）：buff_effects 重置 + buff.apply + 控制效果蕴含 + 打断当前技能 + focamp
	u.buff_effects = {}
	var buff_effects: Dictionary = u.buff_effects
	for buff in u.buff_list:
		buff.apply()
	if bool(buff_effects.get("immoblilize", false)) and String(u.action_name) == "Move":
		u.idle()  # 源 :488-490 定身中且在移动 → idle
	var skill: Variant = u.current_skill
	if bool(buff_effects.get("stun", false)):
		u.hurt()  # 源 :492-493 眩晕 → hurt
	elif skill != null:
		var sdt: String = String(skill.info.get("Damage Type", ""))
		if (sdt == "AD" and bool(buff_effects.get("disarm", false))) or (sdt != "AD" and bool(buff_effects.get("silence", false))):
			skill.interrupt()  # 源 :494-496 缴械/沉默打断当前技能
	u.focamp = int(u.camp) if bool(buff_effects.get("enchanted", false)) else -int(u.camp)  # 源 :497 foecamp
	# 源 attrib_trans（498-505）
	for attr1 in BattleUnit.ATTRIB_TRANS:
		var val: float = float(attribs.get(attr1, 0))
		var orig_val: float = float(orig.get(attr1, 0))
		for attr2 in BattleUnit.ATTRIB_TRANS[attr1]:
			var ratio: float = float(BattleUnit.ATTRIB_TRANS[attr1][attr2])
			attribs[attr2] = float(attribs.get(attr2, 0)) + val * ratio
			orig[attr2] = float(orig.get(attr2, 0)) + orig_val * ratio
	attribs["HP"] = float(attribs["HP"]) * float(u.config.get("hp_mod", DEFAULT_HP_MOD))
	attribs["PDM"] = float(u.config.get("dps_mod", DEFAULT_HP_MOD))
	# 源 Main Attrib（508-512）：AD += 主属性
	var main_attrib: String = String(unit_info.get("Main Attrib", ""))
	if main_attrib != "" and attribs.has(main_attrib):
		attribs["AD"] = float(attribs["AD"]) + float(attribs[main_attrib])
		orig["AD"] = float(orig["AD"]) + float(orig[main_attrib])
	# 源 gs（513-517）
	var total_gs: float = 0.0
	for attr in BattleUnit.ATTRIB_GS:
		total_gs += float(attribs.get(attr, 0)) * float(BattleUnit.ATTRIB_GS[attr])
	u.gs = total_gs / GS_DIVISOR
	# 源 hp/mp cap（518-523）
	if int(u.hp) > int(attribs["HP"]):
		u.hp = int(attribs["HP"])
	if int(u.mp) > int(attribs["MP"]):
		u.mp = int(attribs["MP"])


# 被动/光环属性加成（源 :462-464 / :469-471 / :477-479）：Passive Attr += Basic Num
static func _add_passive_attrib(attribs: Dictionary, skill_info: Variant) -> void:
	var aname: String = String(skill_info.get("Passive Attr", ""))
	if aname != "":
		attribs[aname] = float(attribs.get(aname, 0)) + float(skill_info.get("Basic Num", 0))
