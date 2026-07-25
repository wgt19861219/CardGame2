extends RefCounted

## BossHuskar（照源 BossHuskar.lua，Huskar Boss 版）。atk3 takeEffectOn（counter==1 冲撞 walk_v / ==2 Buff98+basefunc）+ atk6 阶段切换（atk3 AD/CD10 + dps×1.6）+ atk3 finish（atk/atk2 CD0.5）。
## skill6 onAttackFrame startScalingAction(1.2,0.8)/finish endScalingAction 是 Logic 层缩放标志（unit.lua:1487-1490），actor 渲染读标志。

const ULT_BUFF_ID: int = 56
const CHARGE_BUFF_ID: int = 98
const TIMEGAP: float = 0.25
const COLLIDE_DIS: float = 30.0
const ATK3_PLUS_ATTR: String = "AD"
const ATK3_CD: float = 10.0
const DPS_MULT: float = 1.6
const FAST_CD: float = 0.5
const NEXT_STAGE: int = 2
const SCALE_VALUE: float = 1.2
const SCALE_DURATION: float = 0.8


func _atk3_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var caster: Variant = skill.caster
	if int(skill.attack_counter) == 1:
		var d: Vector2 = skill.target.position - caster.position
		if d == Vector2.ZERO:
			caster.walk_v = Vector2.ZERO
		else:
			var dn: Vector2 = d.normalized()
			var offset: Vector2 = dn * COLLIDE_DIS
			var d2: Vector2 = d - offset
			caster.walk_v = d2 / TIMEGAP
		return [true, 0.0]
	var binfo: Variant = caster.cm.lookup(&"Buff", "", CHARGE_BUFF_ID)
	caster.add_buff(binfo, caster)
	caster.walk_v = Vector2.ZERO
	return BattleSkillEffect.take_effect_on(skill, target, src)


func _atk3_finish(skill: Variant) -> void:
	skill._finish_default()
	var caster: Variant = skill.caster
	for skill_name in ["BossHuskar_atk", "BossHuskar_atk2"]:
		var s: Variant = caster.skills.get(skill_name)
		if s:
			s.custom_data["originfo"] = s.info
			var wrapped: Dictionary = s.info.duplicate()
			wrapped["Global CD"] = 0.0
			wrapped["CD"] = FAST_CD
			s.info = wrapped


func _skill6_start(skill: Variant, target: Variant) -> void:
	var binfo: Variant = skill.caster.cm.lookup(&"Buff", "", ULT_BUFF_ID)
	skill.caster.add_buff(binfo, skill.caster)
	skill._start_default(null)


func _skill6_on_attack_frame(skill: Variant) -> void:
	skill._on_attack_frame_default()
	skill.caster.start_scaling_action(SCALE_VALUE, SCALE_DURATION)


func _skill6_finish(skill: Variant) -> void:
	skill._finish_default()
	var caster: Variant = skill.caster
	if caster != null:
		caster.enter_action_stage_from_one_stage(NEXT_STAGE)
	var dps_raw: Variant = caster.config.get("dps_mod", null)
	if dps_raw != null:
		caster.config["dps_mod"] = float(dps_raw) * DPS_MULT
	var skillult: Variant = caster.skills.get("BossHuskar_atk3")
	if skillult:
		skillult.custom_data["originfo"] = skillult.info
		var wrapped: Dictionary = skillult.info.duplicate()
		wrapped["Plus Attr"] = ATK3_PLUS_ATTR
		wrapped["CD"] = ATK3_CD
		skillult.info = wrapped
	caster.end_scaling_action()


func apply(hero: Variant) -> void:
	var skillult: Variant = hero.skills.get("BossHuskar_atk3")
	if skillult:
		skillult.hero_hooks["takeEffectOn"] = Callable(self, "_atk3_take_effect_on")
		skillult.hero_hooks["finish"] = Callable(self, "_atk3_finish")
	var skill6: Variant = hero.skills.get("BossHuskar_atk6")
	if skill6:
		skill6.hero_hooks["start"] = Callable(self, "_skill6_start")
		skill6.hero_hooks["onAttackFrame"] = Callable(self, "_skill6_on_attack_frame")
		skill6.hero_hooks["finish"] = Callable(self, "_skill6_finish")
