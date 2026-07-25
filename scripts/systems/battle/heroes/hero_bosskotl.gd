extends RefCounted

## BossKOTL（照源 BossKOTL.lua，KOTL Boss 版）。atk4 蓄力大招（ultcharge 缩放 power，复用续6 KOTL 模式）+ atk2 斩杀（Holy hp = (target.hp-2)/PDM + Impact Effect）+ atk6 阶段切换（dps×1.8）。
## skill6 onAttackFrame startScalingAction(1.2,duration)/finish endScalingAction 是 Logic 层缩放标志（unit.lua:1487-1490），actor 渲染读标志。

const ULT_BUFF_ID: int = 56
const DPS_MULT: float = 1.8
const NEXT_STAGE: int = 2
const ULTCHARGE_MAX: float = 5.0
const ULTCHARGE_FULL: float = 1.0
const ULTCHARGE_FULL_MULT: float = 1.5
const POWER_BASE: float = 0.3
const POWER_RETURN_CRIT: int = 1
const KILL_HP_OFFSET: float = 2.0
const ATTACK_COUNTER_ZERO: int = 0
const ATTACK_COUNTER_ONE: int = 1
const SCALE_VALUE: float = 1.2


func _atk4_on_attack_frame(skill: Variant) -> void:
	if int(skill.attack_counter) == ATTACK_COUNTER_ZERO:
		if bool(skill.caster.manually_casting):
			skill.caster.engine.unfreeze()
		skill.caster.manually_casting = false
		skill.custom_data["ultbegin"] = float(skill.current_phase_elapsed)
		skill.attack_counter = ATTACK_COUNTER_ONE
	elif int(skill.attack_counter) == ATTACK_COUNTER_ONE:
		var charge: float = float(skill.current_phase_elapsed) - float(skill.custom_data.get("ultbegin", 0.0))
		skill.custom_data["ultcharge"] = minf(ULTCHARGE_MAX, charge) / ULTCHARGE_MAX
		skill._on_attack_frame_default()


func _atk4_can_trigger(skill: Variant) -> bool:
	return skill == skill.caster.current_skill and int(skill.attack_counter) == ATTACK_COUNTER_ONE


func _atk4_trigger(skill: Variant) -> void:
	skill._on_attack_frame()
	skill.goto_event_idx(NEXT_STAGE)


func _atk4_interrupt(skill: Variant) -> void:
	skill._on_attack_frame()
	skill._interrupt_default()


func _atk4_power(skill: Variant, src: Variant, target: Variant) -> Array:
	var ultcharge: float = float(skill.custom_data.get("ultcharge", 0.0))
	var muti: float = ULTCHARGE_FULL_MULT if ultcharge >= ULTCHARGE_FULL else 1.0
	var r: Array = BattleSkillEffect.power(skill, src, target)
	var p: float = float(r[0]) * (POWER_BASE + ultcharge * muti)
	return [p, POWER_RETURN_CRIT]


func _atk2_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var caster: Variant = skill.caster
	if bool(target.is_alive()):
		var dmg: float = (float(target.hp) - KILL_HP_OFFSET) / float(caster.attribs.get("PDM", 1.0))
		target.take_damage({"amount": dmg, "damage_type": "Holy", "field": "hp", "source": caster})
	var eff_name: Variant = skill.info.get("Impact Effect", null)
	if eff_name != null and target.actor != null:
		var eff_z: int = int(skill.info.get("Impact Zorder", 0))
		target.actor.add_effect(String(eff_name), eff_z)
	return [true, 0.0]


func _skill6_start(skill: Variant, target: Variant) -> void:
	var binfo: Variant = skill.caster.cm.lookup(&"Buff", "", ULT_BUFF_ID)
	skill.caster.add_buff(binfo, skill.caster)
	skill._start_default(null)


func _skill6_on_attack_frame(skill: Variant) -> void:
	skill._on_attack_frame_default()
	var phase_dur: float = float(skill.current_phase.get("duration", 0.0))
	var event_time: float = float(skill.next_event.get("Time", 0.0))
	var duration: float = phase_dur - event_time
	skill.caster.start_scaling_action(SCALE_VALUE, duration)


func _skill6_finish(skill: Variant) -> void:
	skill._finish_default()
	var caster: Variant = skill.caster
	var dps_raw: Variant = caster.config.get("dps_mod", null)
	if dps_raw != null:
		caster.config["dps_mod"] = float(dps_raw) * DPS_MULT
	if caster != null:
		caster.enter_action_stage_from_one_stage(NEXT_STAGE)
	caster.end_scaling_action()


func apply(hero: Variant) -> void:
	var skillult: Variant = hero.skills.get("BossKOTL_atk4")
	if skillult:
		skillult.info["No Speeder"] = true
		skillult.hero_hooks["onAttackFrame"] = Callable(self, "_atk4_on_attack_frame")
		skillult.hero_hooks["canTrigger"] = Callable(self, "_atk4_can_trigger")
		skillult.hero_hooks["trigger"] = Callable(self, "_atk4_trigger")
		skillult.hero_hooks["interrupt"] = Callable(self, "_atk4_interrupt")
		skillult.hero_hooks["power"] = Callable(self, "_atk4_power")
	var skill2: Variant = hero.skills.get("BossKOTL_atk2")
	if skill2:
		skill2.hero_hooks["takeEffectOn"] = Callable(self, "_atk2_take_effect_on")
	var skill6: Variant = hero.skills.get("BossKOTL_atk6")
	if skill6:
		skill6.hero_hooks["start"] = Callable(self, "_skill6_start")
		skill6.hero_hooks["onAttackFrame"] = Callable(self, "_skill6_on_attack_frame")
		skill6.hero_hooks["finish"] = Callable(self, "_skill6_finish")
