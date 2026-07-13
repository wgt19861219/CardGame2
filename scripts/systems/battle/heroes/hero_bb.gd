extends RefCounted

## BB 英雄 hook（Logic 层）— 照源 BB.lua（84 行）翻译。
## 背击免疫 + 累计伤害大招：takeDamage（ultBuff 且 source 同向=背击 → 临时 PIMU/MIMU -= ultBuff → basefunc → 还原）+
##   getLostHPAfterImmunity（累计 totalDamage，达阈值触发 atk3）+ update（totalDamage>=HP*0.2 → takeEffectAt atk3 + Gain MP）+
##   ult（createBuff 设 ultBuff=info.PIMU + onRemoved 还原 / onAttackFrame changePeriod / finish enterActionStage(2) / canCastWithTarget ultBuff 互斥）。
## 全用已有 hook（takeDamage 续4/getLostHPAfterImmunity 续17/update 续4/createBuff/canCastWithTarget/onAttackFrame/finish + enterActionStage 续5）。

const DAMAGE_PERCENT_CAST: float = 0.2       # 源 :2 totalDamage 阈值 HP*0.2
const STAGE_CHANGE_1: int = 1                # 源 :12 buffOnRemoved enterActionStage(1)
const STAGE_CHANGE_2: int = 2                # 源 :33 finish enterActionStage(2)


# 源 :3-8 ult canCastWithTarget：ultBuff → false（互斥）/ else basefunc。
func _ult_can_cast_with_target(skill: Variant, target: Variant) -> Dictionary:
	if bool(skill.caster.custom_data.get("ultBuff", false)):
		return {"ok": false, "reason": "ult"}
	return skill._can_cast_with_target_default(target)


# 源 :9-17 ult buff onRemoved：changePeriod → enterActionStage(1)+changePeriod=nil+ultBuff=false / basefunc。
func _ult_buff_on_removed(buff: Variant) -> void:
	var caster: Variant = buff.caster
	if bool(caster.custom_data.get("changePeriod", false)):
		caster.enter_action_stage_from_one_stage(STAGE_CHANGE_1)
		caster.custom_data["changePeriod"] = false
		caster.custom_data["ultBuff"] = false
	buff._on_removed_default()


# 源 :18-23 ult createBuff：basefunc + onRemoved hook + ultBuff=buff.info.PIMU（背击免疫值）。
func _ult_create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)
	buff.hero_hooks["onRemoved"] = Callable(self, "_ult_buff_on_removed")
	skill.caster.custom_data["ultBuff"] = float(buff.info.get("PIMU", 0))
	return buff


# 源 :24-28 ult onAttackFrame：basefunc + changePeriod=true。
func _ult_on_attack_frame(skill: Variant) -> void:
	skill._on_attack_frame_default()
	skill.caster.custom_data["changePeriod"] = true


# 源 :29-35 ult finish：basefunc + changePeriod → enterActionStage(2)。
func _ult_finish(skill: Variant) -> void:
	skill._finish_default()
	if bool(skill.caster.custom_data.get("changePeriod", false)):
		skill.caster.enter_action_stage_from_one_stage(STAGE_CHANGE_2)


# 源 :36-44 单位 update：basefunc + atk3 totalDamage>=HP*0.2 → takeEffectAt + Gain MP + 扣阈值。
func _hero_update(unit: Variant, dt: float) -> void:
	unit._update_default(dt)
	var skillatk3: Variant = unit.skills.get("BB_atk3")
	if skillatk3:
		var threshold: float = float(unit.attribs.get("HP", 0)) * DAMAGE_PERCENT_CAST
		var total: float = float(unit.custom_data.get("totalDamage", 0))
		if total >= threshold:
			skillatk3.take_effect_at(unit.position, unit)
			unit.set_mp(int(float(unit.mp) + float(skillatk3.info.get("Gain MP", 0)) * float(unit.engine.mp_bonus)))
			unit.custom_data["totalDamage"] = total - threshold


# 源 :45-51 getLostHPAfterImmunity（单位 hook）：atk3 存在 → totalDamage += damage / basefunc。
func _get_lost_hp_after_immunity(unit: Variant, damage: float, immunity: float) -> float:
	if unit.skills.get("BB_atk3"):
		unit.custom_data["totalDamage"] = float(unit.custom_data.get("totalDamage", 0)) + damage
	return BattleUnitCombat.get_lost_hp_after_immunity(damage, immunity)


# 源 :52-67 takeDamage（单位 hook）：ultBuff 且 source 同向（背击）→ 临时 PIMU/MIMU-=ultBuff → basefunc → 还原。
# 源 :62 MIMU 还原成 temp（PIMU 原值，源 bug 照搬，复刻铁律）。
func _take_damage(unit: Variant, params: Dictionary) -> float:
	var ult_buff: Variant = unit.custom_data.get("ultBuff", false)
	if bool(ult_buff):
		var source: Variant = params.get("source", null)
		var direct: int = int(source.direction) if source != null and source != "" else 0
		if direct == int(unit.direction):
			var temp: float = float(unit.attribs.get("PIMU", 0))
			var temp2: float = float(unit.attribs.get("MIMU", 0))
			var ub: float = float(ult_buff)
			unit.attribs["PIMU"] = temp - ub
			unit.attribs["MIMU"] = temp2 - ub
			var dmg: float = unit._take_damage_default(params)
			unit.attribs["PIMU"] = temp
			unit.attribs["MIMU"] = temp  # 源 :62 MIMU 还原成 temp（PIMU 原值，源 bug 照搬）
			return dmg
	return unit._take_damage_default(params)


# 源 :68-83 init_hero：atk3 存在→totalDamage=0 + takeDamage/getLostHPAfterImmunity/update hook + setActionStageChangeByManual + ult（createBuff/onAttackFrame/finish/canCastWithTarget）。
func apply(hero: Variant) -> void:
	if hero.skills.get("BB_atk3"):
		hero.custom_data["totalDamage"] = 0.0
	hero.hero_hooks["takeDamage"] = Callable(self, "_take_damage")
	hero.hero_hooks["getLostHPAfterImmunity"] = Callable(self, "_get_lost_hp_after_immunity")
	hero.hero_hooks["update"] = Callable(self, "_hero_update")
	hero.is_action_stage_change_by_manual = true
	var skillult: Variant = hero.skills.get("BB_ult")
	if skillult:
		skillult.hero_hooks["createBuff"] = Callable(self, "_ult_create_buff")
		skillult.hero_hooks["onAttackFrame"] = Callable(self, "_ult_on_attack_frame")
		skillult.hero_hooks["finish"] = Callable(self, "_ult_finish")
		skillult.hero_hooks["canCastWithTarget"] = Callable(self, "_ult_can_cast_with_target")
