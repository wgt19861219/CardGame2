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
const SCALE_VALUE: float = 1.2  # 源 :15 startScalingAction(1.2, 0.8)
const SCALE_DURATION: float = 0.8  # 源 :15 duration=0.8


# 源 :17-37 atk3 takeEffectOn：counter==1 冲撞（walk_v 朝 target，扣除 collideis）/ counter==2 Buff98 + walk_v=0 + basefunc。
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


# 源 :54-69 atk3 finish：basefunc + atk info Global CD=0/CD=0.5 + atk2 同。
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


# 源 :2-9 skill6 start：加 Buff 56 + basefunc。
func _skill6_start(skill: Variant, target: Variant) -> void:
	var binfo: Variant = skill.caster.cm.lookup(&"Buff", "", ULT_BUFF_ID)
	skill.caster.add_buff(binfo, skill.caster)
	skill._start_default(null)  # 源 :9 basefunc(skill) 不传 target（AncientTreant 同模式）


# 源 :11-16 skill6 onAttackFrame：basefunc + startScalingAction(1.2, 0.8)（Logic 层缩放标志）。
func _skill6_on_attack_frame(skill: Variant) -> void:
	skill._on_attack_frame_default()
	skill.caster.start_scaling_action(SCALE_VALUE, SCALE_DURATION)


# 源 :38-53 skill6 finish：basefunc + enterActionStageFromOneStage(2) + dps×1.6 + atk3 info Plus Attr=AD/CD=10 + endScalingAction（Logic 层标志）。
func _skill6_finish(skill: Variant) -> void:
	skill._finish_default()
	var caster: Variant = skill.caster
	if caster != null:
		caster.enter_action_stage_from_one_stage(NEXT_STAGE)  # 源 :41-43 if caster 守卫（防御性，照源）
	# 源 :45 Lua truthy：dps_mod and dps_mod*1.6（nil 不改，0/负也×MULT；勿 >0 守卫，[[lua-truthy-falsy-gdscript-pitfall]]）
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
	caster.end_scaling_action()  # 源 :52 endScalingAction


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
