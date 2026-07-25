extends RefCounted

## LOA 英雄 hook（Logic 层）— 照源 battle/heroes/LOA.lua（68 行）。
## LOA_ult.createBuff：buff.onDamaged hook（伤害转治疗：吸伤量 power=damage-remain → takeHeal）。
## LOA_atk2.takeEffectOn：敌方 → wraptable（AP + Basic Num·3 + Plus Ratio·3）。
## LOA_atk3.createBuff：buff.onRemoved hook（shield 未耗尽直接 basefunc / else AOE 爆发 + basefunc）。
## buff onDamaged 新 hook 点（on_damaged 拆 _on_damaged_default）。createBuff/onRemoved/takeEffectOn 已扩展。

const AOE_SHAPE_ARG: float = 150.0
const BASIC_NUM_MULT: int = 3
const PLUS_RATIO_MULT: int = 3


func apply(hero: Variant) -> void:
	var skill_ult: Variant = hero.skills.get("LOA_ult")
	var skill_atk2: Variant = hero.skills.get("LOA_atk2")
	var skill_atk3: Variant = hero.skills.get("LOA_atk3")
	if skill_ult:
		skill_ult.hero_hooks["createBuff"] = Callable(self, "_ult_create_buff")
	if skill_atk2:
		skill_atk2.hero_hooks["takeEffectOn"] = Callable(self, "_atk2_take_effect_on")
	if skill_atk3:
		skill_atk3.hero_hooks["createBuff"] = Callable(self, "_atk3_create_buff")


func _ult_create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)
	buff.hero_hooks["onDamaged"] = Callable(self, "_ult_buff_on_damaged")
	return buff


func _ult_buff_on_damaged(buff: Variant, damage: float, damage_type: String) -> float:
	var caster: Variant = buff.owner
	var remain: float = buff._on_damaged_default(damage, damage_type)  # basefunc
	var power: float = damage - remain
	if power > 0.0:
		caster.take_heal(power, "hp")
	return remain


func _atk2_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var orig_info: Dictionary = skill.info
	if int(target.camp) != int(skill.caster.camp):
		skill.info = orig_info.duplicate()
		skill.info["Damage Type"] = "AP"
		skill.info["Basic Num"] = int(orig_info.get("Basic Num", 0)) * BASIC_NUM_MULT
		skill.info["Plus Ratio"] = float(orig_info.get("Plus Ratio", 0.0)) * float(PLUS_RATIO_MULT)
	var r: Array = BattleSkillEffect.take_effect_on(skill, target, src)  # basefunc [succ, dmg]
	skill.info = orig_info
	return r  # 透传（源 local succ 未用于判断）


func _atk3_create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)
	buff.hero_hooks["onRemoved"] = Callable(self, "_atk3_buff_on_removed")
	return buff


func _atk3_buff_on_removed(buff: Variant) -> void:
	if buff.timer >= 0.0 and buff.shield > 0.0:
		buff._on_removed_default()  # basefunc（不爆发）
		return
	var skill: Variant = buff.caster.skills.get("LOA_atk3")
	var orig_info: Dictionary = skill.info
	skill.info = orig_info.duplicate()
	skill.info["Affected Camp"] = -1
	skill.info["AOE Origin"] = "target"
	skill.info["AOE Shape"] = "circle"
	skill.info["Shape Arg1"] = AOE_SHAPE_ARG
	skill.info["Damage Type"] = "AP"
	skill.info["Buff ID"] = 0
	skill.info["Point Effect"] = "eff_point_DR_atk3.cha"
	skill.info["Impact Effect"] = "eff_impact_LOA_atk2.cha"
	skill.take_effect_at(buff.owner.position)
	skill.info = orig_info
	buff._on_removed_default()  # basefunc
