extends RefCounted

## KOTL（光之守卫）英雄 hook（Logic 层）— 照源 battle/heroes/KOTL.lua（42 行）。
## KOTL_ult 大招流程（蓄力）：canTrigger（current_skill + attack_counter==1）/ onAttackFrame（counter 0→1 记 ultbegin；1→算 ultcharge + basefunc）/ trigger（onAttackFrame + gotoEventIdx 2）/ interrupt（onAttackFrame + basefunc）/ power（basefunc×ultcharge, 1）。
## init：info["No Speeder"]=true（蓄力期间不推进 action）。

const ULT_CHARGE_MAX: float = 5.0  # 源 :15 math.min(5, charge)/5
const ULT_EVENT_IDX: int = 2       # 源 :23 gotoEventIdx(2)
const CRIT_MOD_FIXED: float = 1.0  # 源 :30 power 返 crit_mod=1


func apply(hero: Variant) -> void:
	var skillult: Variant = hero.skills.get("KOTL_ult")
	if skillult:
		skillult.info["No Speeder"] = true  # 源 :34
		skillult.hero_hooks["canTrigger"] = Callable(self, "_can_trigger")
		skillult.hero_hooks["onAttackFrame"] = Callable(self, "_on_attack_frame")
		skillult.hero_hooks["trigger"] = Callable(self, "_trigger")
		skillult.hero_hooks["interrupt"] = Callable(self, "_interrupt")
		skillult.hero_hooks["power"] = Callable(self, "_power")


# 源 :1-3 canTrigger：当前大招且第一段（attack_counter==1）才触发。
func _can_trigger(skill: Variant) -> bool:
	return skill == skill.caster.current_skill and skill.attack_counter == 1


# 源 :4-20 onAttackFrame：counter 0→unfreeze + 记 ultbegin + counter=1；counter 1→算 ultcharge（min(5,Δ)/5）+ basefunc。
func _on_attack_frame(skill: Variant) -> void:
	if skill.attack_counter == 0:
		if bool(skill.caster.manually_casting):
			skill.caster.engine.unfreeze()
		skill.caster.manually_casting = false
		skill.custom_data["ultbegin"] = skill.current_phase_elapsed
		skill.attack_counter = 1
	elif skill.attack_counter == 1:
		var elapsed: float = skill.current_phase_elapsed - float(skill.custom_data.get("ultbegin", 0.0))
		skill.custom_data["ultcharge"] = min(ULT_CHARGE_MAX, elapsed) / ULT_CHARGE_MAX
		skill._on_attack_frame_default()  # basefunc


# 源 :21-24 trigger：onAttackFrame + gotoEventIdx(2)。
func _trigger(skill: Variant) -> void:
	skill._on_attack_frame()
	skill.goto_event_idx(ULT_EVENT_IDX)


# 源 :25-28 interrupt：onAttackFrame + basefunc。
func _interrupt(skill: Variant) -> void:
	skill._on_attack_frame()
	skill._interrupt_default()  # basefunc


# 源 :29-31 power：basefunc × ultcharge，返 [power×ultcharge, 1]。
func _power(skill: Variant, src: Variant, _target: Variant) -> Array:
	var base: Array = BattleSkillEffect.power(skill, src)
	var charge: float = float(skill.custom_data.get("ultcharge", 0.0))
	return [base[0] * charge, CRIT_MOD_FIXED]
