extends RefCounted

## AM 英雄 hook（Logic 层）— 照源 battle/heroes/AM.lua（68 行）。
## AM_ult.takeEffectAt：counter==1 闪现到 target+70·dir（边界/stable 反向 140）/ else basefunc。
## AM_atk2：start 重写（按距离选 phase 1/2）/ takeEffectAt（phase==1 闪现 target-70·dir）/ takeEffectOn（Holy mp Script Arg2）。
## takeEffectAt 新 hook 点；start 重写=不调 _default，自实现（skill._start_phase/_select_target duck-type 调）。

const MIN_RANGE_SQ: float = 14400.0
const BLINK_OFFSET: float = 70.0
const BLINK_REVERSE: float = 140.0
const STAGE_MAX_X: float = 799.0
const CDR_DENOM: float = 100.0
const PHASE_RANGED: int = 1
const PHASE_MELEE: int = 2


func apply(hero: Variant) -> void:
	var skill_ult: Variant = hero.skills.get("AM_ult")
	var skill_atk2: Variant = hero.skills.get("AM_atk2")
	if skill_ult:
		skill_ult.hero_hooks["takeEffectAt"] = Callable(self, "_ult_take_effect_at")
	if skill_atk2:
		skill_atk2.hero_hooks["start"] = Callable(self, "_atk2_start")
		skill_atk2.hero_hooks["takeEffectAt"] = Callable(self, "_atk2_take_effect_at")
		skill_atk2.hero_hooks["takeEffectOn"] = Callable(self, "_atk2_take_effect_on")


func _atk2_start(skill: Variant, target: Variant) -> void:
	var info: Dictionary = skill.info
	skill.target = target
	skill._select_target(target)
	skill.cd_remaining = float(info.get("CD", 0.0))
	skill.casting = true
	skill.attack_counter = 0
	var caster: Variant = skill.caster
	var dx: float = float(skill.target.position.x) - float(caster.position.x)
	var dy: float = float(skill.target.position.y) - float(caster.position.y)
	if dx * dx + dy * dy > MIN_RANGE_SQ:
		skill._start_phase(PHASE_RANGED)
	else:
		skill._start_phase(PHASE_MELEE)
	caster.global_cd = float(info.get("Global CD", 0.0))
	var cdr: float = float(caster.attribs.get("CDR", 0.0)) / CDR_DENOM
	caster.set_mp(float(caster.mp) - float(info.get("Cost MP", 0.0)) * (1.0 - cdr))


func _atk2_take_effect_at(skill: Variant, location: Vector2, src: Variant) -> void:
	if int(skill.current_phase_idx) == 1:
		skill.caster.position = Vector2(
			skill.target.position.x - float(skill.caster.direction) * BLINK_OFFSET,
			skill.target.position.y)
	else:
		BattleSkillEffect.take_effect_at(skill, location, src)  # basefunc


func _atk2_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var mppower: float = float(skill.info.get("Script Arg2", 0.0))
	var r: Array = BattleSkillEffect.take_effect_on(skill, target, src)  # basefunc [succ, dmg]
	target.take_damage({"amount": mppower, "damage_type": "Holy", "field": "mp", "source": skill.caster})
	return r  # 透传（源 local succ 未用于判断）


func _ult_take_effect_at(skill: Variant, location: Vector2, src: Variant) -> void:
	var caster: Variant = skill.caster
	if int(skill.attack_counter) == 1:
		if skill.target != null:
			var pos1: float = float(skill.target.position.x) + float(caster.direction) * BLINK_OFFSET
			if bool(skill.target.buff_effects.get("stable", false)) or pos1 > STAGE_MAX_X or pos1 < 1:
				pos1 = pos1 - float(caster.direction) * BLINK_REVERSE
			caster.position = Vector2(pos1, skill.target.position.y)
	else:
		BattleSkillEffect.take_effect_at(skill, location, src)  # basefunc
