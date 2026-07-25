extends RefCounted

## Marine 英雄 hook（Logic 层）— 照源 Marine.lua（156 行）翻译。
## 医疗兵：atk2 强化态（createBuff 扣血 Cost HP + 改 Marine_atk 射程-/Gain MP+ medBuff + onRemoved 还原）+
##   ult（onPhaseFinished x-40 + takeEffectAt counter1 wraptable AOE halfcircle + takeEffectOn 加 Buff92）+
##   atk（start 完全重写 medBuff→startPhase(2) / power 0.5^(counter-1) 衰减 / onPhaseFinished→finish）+ 单位 update/castManualSkill（atk2 mp<1000 自动）+ ai.findSkillToCast（atk2 限定 arena/enemy）。
## getInitDir/getSide（源 compiled）= camp 判断；getSide=="right" 用 camp==CAMP_ENEMY 替代（enemy=right）。

const RANGE_INTERVAL: float = 150.0
const ATK2_COST_HP: int = 20
const ULT_POS_OFFSET: float = 40.0
const ULT_AOE_ARG1: float = 140.0
const ULT_KNOCK_BACK: float = 70.0
const ULT_KNOCK_UP: float = 0.2
const ULT_BASIC_NUM: float = 10.0
const ULT_PLUS_RATIO: float = 0.3
const ULT_BUFF_ID: int = 92
const ATK2_GAIN_MP: float = 30.0
const POWER_DECAY_BASE: float = 0.5
const POWER_DECAY_OFFSET: int = 1
const MP_THRESHOLD: int = 1000
const CDR_DENOM: float = 100.0
const COST_HP_DENOM: float = 100.0
const ATK_COUNTER_FIRST: int = 1
const ATK_COUNTER_SECOND: int = 2
const ATK_PHASE_NORMAL: int = 1
const ATK_PHASE_BUFFED: int = 2
const CD_RESET: float = 0.0


func _skill2_buff_on_removed(buff: Variant) -> void:
	var owner: Variant = buff.owner
	var skillatk: Variant = owner.skills.get("Marine_atk")
	if skillatk and skillatk.custom_data.has("originfo"):
		skillatk.info = skillatk.custom_data["originfo"]
		var max_r: float = float(skillatk.info.get("Max Range", 0))
		skillatk.max_range_sq = max_r * max_r
	owner.attack_range = float(owner.attack_range) + RANGE_INTERVAL
	owner.custom_data["medBuff"] = null
	buff._on_removed_default()


func _ult_on_phase_finished(skill: Variant) -> void:
	BattleSkillPhase.on_phase_finished(skill)
	var p: Vector2 = skill.caster.position
	skill.caster.position = Vector2(p.x - ULT_POS_OFFSET, p.y)


func _ult_take_effect_at(skill: Variant, location: Vector2, src: Variant) -> void:
	var originfo: Dictionary = skill.info
	if int(skill.attack_counter) == ATK_COUNTER_FIRST:
		var wrapped: Dictionary = originfo.duplicate()
		wrapped["AOE Shape"] = "halfcircle"
		wrapped["Shape Arg1"] = ULT_AOE_ARG1
		wrapped["Point Effect"] = false
		wrapped["Knock Back"] = ULT_KNOCK_BACK
		wrapped["Knock Up"] = ULT_KNOCK_UP
		wrapped["Basic Num"] = ULT_BASIC_NUM
		wrapped["Plus Ratio"] = ULT_PLUS_RATIO
		skill.info = wrapped
		BattleSkillEffect.take_effect_at(skill, location, src)
		skill.info = originfo
	elif int(skill.attack_counter) == ATK_COUNTER_SECOND:
		BattleSkillEffect.take_effect_at(skill, location, src)


func _ult_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	if int(skill.attack_counter) == ATK_COUNTER_FIRST:
		var binfo: Variant = skill.caster.cm.lookup(&"Buff", "", ULT_BUFF_ID)
		target.add_buff(binfo, skill.caster)
	return BattleSkillEffect.take_effect_on(skill, target, src)


func _atk2_create_buff(skill: Variant, target: Variant) -> Variant:
	var hpcost: float = float(target.attribs.get("HP", 0)) * float(skill.info.get("Cost HP", 0)) / COST_HP_DENOM
	target.take_damage({"amount": hpcost, "damage_type": "Holy", "field": "hp", "source": skill.caster})
	var buff: Variant = skill._create_buff_default(target)
	var caster: Variant = skill.caster
	var skillatk: Variant = caster.skills.get("Marine_atk")
	if skillatk:
		skillatk.custom_data["originfo"] = skillatk.info
		var wrapped: Dictionary = skillatk.info.duplicate()
		wrapped["Max Range"] = float(skillatk.info.get("Max Range", 0)) - RANGE_INTERVAL
		wrapped["Gain MP"] = ATK2_GAIN_MP
		skillatk.info = wrapped
		var max_r: float = float(wrapped.get("Max Range", 0))
		skillatk.max_range_sq = max_r * max_r
		skillatk.cd_remaining = CD_RESET
	caster.attack_range = float(caster.attack_range) - RANGE_INTERVAL
	caster.custom_data["medBuff"] = true
	buff.hero_hooks["onRemoved"] = Callable(self, "_skill2_buff_on_removed")
	return buff


func _atk_start(skill: Variant, target: Variant) -> void:
	var info: Dictionary = skill.info
	var caster: Variant = skill.caster
	skill.target = target
	skill._select_target(target)
	skill.cd_remaining = float(info.get("CD", 0.0))
	skill.casting = true
	skill.attack_counter = 0
	var phase: int = ATK_PHASE_BUFFED if bool(caster.custom_data.get("medBuff", false)) else ATK_PHASE_NORMAL
	skill._start_phase(phase)
	caster.global_cd = float(info.get("Global CD", 0.0))
	caster.set_mp(int(float(caster.mp) - float(info.get("Cost MP", 0.0)) * (1.0 - float(caster.attribs.get("CDR", 0.0)) / CDR_DENOM)))


func _atk_on_phase_finished(skill: Variant) -> void:
	skill.finish()


func _atk_power(skill: Variant, src: Variant, target: Variant) -> Array:
	var base: Array = BattleSkillEffect.power(skill, src, target)
	var power: float = float(base[0]) * pow(POWER_DECAY_BASE, int(skill.attack_counter) - POWER_DECAY_OFFSET)
	return [power, base[1]]


func _atk2_can_cast_with_target(skill: Variant, target: Variant) -> Dictionary:
	var caster: Variant = skill.caster
	var hpcost: float = float(caster.attribs.get("HP", 0)) * float(skill.info.get("Cost HP", 0)) / COST_HP_DENOM
	var base: Dictionary = skill._can_cast_with_target_default(target)
	if not bool(base.get("ok", false)):
		return base
	if hpcost > float(caster.hp):
		return {"ok": false, "reason": "hp"}
	var cs: Variant = caster.current_skill
	if cs != null and String(cs.info.get("Skill Name", "")) == "Marine_ult":
		return {"ok": false, "reason": "ult"}
	if bool(caster.custom_data.get("medBuff", false)):
		return {"ok": false, "reason": "medBuff"}
	return base


func _hero_update(hero: Variant, dt: float) -> void:
	hero._update_default(dt)
	var skill2: Variant = hero.skills.get("Marine_atk2")
	if skill2 != null and hero.ai != null:
		var r: Dictionary = skill2.can_cast_with_target(hero.ai.target)
		hero.can_cast_manual = bool(hero.can_cast_manual) or bool(r.get("ok", false))


func _hero_cast_manual_skill(hero: Variant) -> void:
	var skill2: Variant = hero.skills.get("Marine_atk2")
	if skill2 != null and int(hero.mp) < MP_THRESHOLD and hero.ai != null and bool(skill2.can_cast_with_target(hero.ai.target).get("ok", false)):
		hero.cast_skill(skill2, hero)
	else:
		hero._cast_manual_skill_default()


func _ai_find_skill_to_cast(ai: Variant) -> Variant:
	var skill: Variant = ai._find_skill_to_cast_default()
	if skill != null and String(skill.info.get("Skill Name", "")) == "Marine_atk2":
		var caster: Variant = skill.caster
		if bool(caster.engine.arena_mode) or int(caster.camp) == BattleEngine.CAMP_ENEMY:
			return skill
		return caster.skills.get("Marine_atk")
	return skill


func apply(hero: Variant) -> void:
	var skillult: Variant = hero.skills.get("Marine_ult")
	if skillult:
		skillult.hero_hooks["onPhaseFinished"] = Callable(self, "_ult_on_phase_finished")
		skillult.hero_hooks["takeEffectAt"] = Callable(self, "_ult_take_effect_at")
		skillult.hero_hooks["takeEffectOn"] = Callable(self, "_ult_take_effect_on")
	var skillatk2: Variant = hero.skills.get("Marine_atk2")
	if skillatk2:
		skillatk2.info["Cost HP"] = ATK2_COST_HP
		skillatk2.hero_hooks["createBuff"] = Callable(self, "_atk2_create_buff")
		skillatk2.hero_hooks["canCastWithTarget"] = Callable(self, "_atk2_can_cast_with_target")
	var skillatk: Variant = hero.skills.get("Marine_atk")
	if skillatk:
		skillatk.hero_hooks["start"] = Callable(self, "_atk_start")
		skillatk.hero_hooks["power"] = Callable(self, "_atk_power")
		skillatk.hero_hooks["onPhaseFinished"] = Callable(self, "_atk_on_phase_finished")
	hero.hero_hooks["update"] = Callable(self, "_hero_update")
	hero.hero_hooks["castManualSkill"] = Callable(self, "_hero_cast_manual_skill")
	if hero.ai != null:
		hero.ai.hero_hooks["findSkillToCast"] = Callable(self, "_ai_find_skill_to_cast")
