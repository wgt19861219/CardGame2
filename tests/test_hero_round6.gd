extends GutTest
# 第六轮复刻忠实度 P1 修复回归（照源 BossCoco/Huskar/KOTL/Sil/TB.lua + Luna.lua + ExBossSpider.lua）。
# 核心修复：4 Boss startScalingAction/endScalingAction 配对（Logic 层缩放标志，源 unit.lua:1487-1490）
#   + BossSil S1 删跨英雄泄露 is_action_stage_change_by_manual（源 BB.lua:76 非 BossSil）
#   + KOTL K4 atk2 Impact Effect（actor.add_effect 桥）+ Luna-1 删误挂 takeEffectOn（源 latent bug）
#   + ExBossSpider-1 atk4 crit_mod=0（源第 6 参，非第 5 参 coefficient=1）。
# T1(dps_mod)/T2(_level)/K3(power return) 依赖 BattleSkillEffect/BattleUnit 全流程，验收记录人工验证。


class MockSkill:
	extends RefCounted
	var info: Dictionary = {}
	var hero_hooks: Dictionary = {}
	var caster: Variant = null
	var target: Variant = null
	var attack_counter: int = 0
	var current_phase: Dictionary = {}
	var next_event: Dictionary = {}
	var current_phase_elapsed: float = 0.0
	var custom_data: Dictionary = {}
	var level: Variant = null
	func _start_default(_t: Variant) -> void: pass
	func _finish_default() -> void: pass
	func _on_attack_frame_default() -> void: pass
	func _create_buff_default(_t: Variant) -> Variant:
		var b := MockBuff.new()
		b.owner = caster
		b.caster = caster
		return b


class MockCm:
	extends RefCounted
	func lookup(_t: StringName, _c: String, _k: Variant) -> Variant:
		return {"ID": int(_k), "Name": str(_k)}


class MockActor:
	extends RefCounted
	var add_effect_calls: Array = []
	func add_effect(p_name: String, p_z: int) -> void:
		add_effect_calls.append([p_name, p_z])


class MockCaster:
	extends RefCounted
	var cm: Variant = null
	var config: Dictionary = {}
	var skills: Dictionary = {}
	var attribs: Dictionary = {"PDM": 100.0, "HP": 1000.0}
	var hp: int = 100
	var camp: int = 0
	var direction: int = 1
	var stars: int = 1
	var rank: int = 1
	var custom_data: Dictionary = {}
	var buff_list: Array = []
	var actor: Variant = null
	var start_scale_calls: Array = []
	var end_scale_calls: int = 0
	var stage_entered: int = -1
	var last_crit_mod: Variant = null
	var is_action_stage_change_by_manual: bool = false
	func add_buff(_b: Variant, _c: Variant) -> void: pass
	func start_scaling_action(p_s: float, p_d: float) -> void: start_scale_calls.append([p_s, p_d])
	func end_scaling_action() -> void: end_scale_calls += 1
	func enter_action_stage_from_one_stage(p_s: int) -> void: stage_entered = p_s
	func is_alive() -> bool: return hp > 0
	func take_damage(params: Dictionary) -> float:
		hp -= int(params.get("amount", 0))
		last_crit_mod = params.get("crit_mod", null)
		return 0.0


class MockHero:
	extends RefCounted
	var skills: Dictionary = {}
	var hero_hooks: Dictionary = {}
	var info: Dictionary = {}
	var custom_data: Dictionary = {}
	var is_action_stage_change_by_manual: bool = false


class MockBuff:
	extends RefCounted
	var info: Dictionary = {"Name": "test"}
	var owner: Variant = null
	var caster: Variant = null
	var custom_data: Dictionary = {}
	var hero_hooks: Dictionary = {}
	func _update_default(_dt: float) -> void: pass
	func _on_removed_default() -> void: pass


# BossCoco C2 onAttackFrame startScalingAction(1.2,1) + C3 finish endScalingAction。
func test_bosscoco_skill6_scaling_pair() -> void:
	var hero := MockHero.new()
	var ult := MockSkill.new()
	var caster := MockCaster.new()
	caster.config["dps_mod"] = 2.0
	ult.caster = caster
	var atk2 := MockSkill.new()
	atk2.info = {"CD": 5.0, "Shape Arg1": 1}
	caster.skills["BossCoco_atk2"] = atk2
	hero.skills["BossCoco_atk6"] = ult
	BattleHeroScripts.apply("battle/heroes/BossCoco", hero)
	ult.hero_hooks["onAttackFrame"].call(ult)
	assert_eq(caster.start_scale_calls.size(), 1, "C2 onAttackFrame 调 start_scaling_action")
	assert_almost_eq(caster.start_scale_calls[0][0], 1.2, 0.01, "C2 scale 值 1.2")
	assert_almost_eq(caster.start_scale_calls[0][1], 1.0, 0.01, "C2 duration 1.0（源 :13）")
	ult.hero_hooks["finish"].call(ult)
	assert_eq(caster.end_scale_calls, 1, "C3 finish 调 end_scaling_action（源 :40）")


# BossHuskar H2 startScalingAction(1.2,0.8) + H3 endScalingAction。
func test_bosshuskar_skill6_scaling_pair() -> void:
	var hero := MockHero.new()
	var ult := MockSkill.new()
	var caster := MockCaster.new()
	caster.config["dps_mod"] = 2.0
	ult.caster = caster
	var atk3 := MockSkill.new()
	atk3.info = {"Plus Attr": "AD", "CD": 5.0}
	caster.skills["BossHuskar_atk3"] = atk3
	hero.skills["BossHuskar_atk6"] = ult
	BattleHeroScripts.apply("battle/heroes/BossHuskar", hero)
	ult.hero_hooks["onAttackFrame"].call(ult)
	assert_eq(caster.start_scale_calls.size(), 1, "H2 onAttackFrame 调 start_scaling_action")
	assert_almost_eq(caster.start_scale_calls[0][1], 0.8, 0.01, "H2 duration 0.8（源 :15）")
	ult.hero_hooks["finish"].call(ult)
	assert_eq(caster.end_scale_calls, 1, "H3 finish 调 end_scaling_action（源 :52）")


# BossKOTL K1 startScalingAction(1.2, duration=phase.duration-event.Time) + K2 endScalingAction。
func test_bosskotl_skill6_scaling_duration() -> void:
	var hero := MockHero.new()
	var ult := MockSkill.new()
	var caster := MockCaster.new()
	caster.config["dps_mod"] = 2.0
	ult.caster = caster
	ult.current_phase = {"duration": 3.0}
	ult.next_event = {"Time": 1.0}
	hero.skills["BossKOTL_atk6"] = ult
	BattleHeroScripts.apply("battle/heroes/BossKOTL", hero)
	ult.hero_hooks["onAttackFrame"].call(ult)
	assert_eq(caster.start_scale_calls.size(), 1, "K1 onAttackFrame 调 start_scaling_action")
	# 源 skill.lua:164 getDurationFromAttackFrameToEnd = phase.duration - event.Time = 3.0 - 1.0
	assert_almost_eq(caster.start_scale_calls[0][1], 2.0, 0.01, "K1 duration = phase.dur - event.Time（源 skill.lua:164）")
	ult.hero_hooks["finish"].call(ult)
	assert_eq(caster.end_scale_calls, 1, "K2 finish 调 end_scaling_action（源 :22）")


# BossKOTL K4 atk2 takeEffectOn Impact Effect（actor.add_effect 桥接通）。
func test_bosskotl_atk2_impact_effect() -> void:
	var hero := MockHero.new()
	var skill2 := MockSkill.new()
	skill2.info = {"Impact Effect": "eff_test.cha", "Impact Zorder": 5}
	var caster := MockCaster.new()
	caster.attribs["PDM"] = 100.0
	skill2.caster = caster
	hero.skills["BossKOTL_atk2"] = skill2
	BattleHeroScripts.apply("battle/heroes/BossKOTL", hero)
	var target := MockCaster.new()
	target.hp = 100
	target.actor = MockActor.new()
	skill2.hero_hooks["takeEffectOn"].call(skill2, target, null)
	assert_eq(target.actor.add_effect_calls.size(), 1, "K4 Impact Effect 触发（源 :64-68）")
	assert_eq(target.actor.add_effect_calls[0][0], "eff_test.cha", "K4 effect 名")
	assert_eq(target.actor.add_effect_calls[0][1], 5, "K4 effect zorder")


# BossSil S1 不设 is_action_stage_change_by_manual（源 BB.lua:76 非 BossSil）+ S2 scaling 对。
func test_bosssil_no_manual_and_scaling() -> void:
	var hero := MockHero.new()
	var ult := MockSkill.new()
	var caster := MockCaster.new()
	caster.config["dps_mod"] = 2.0
	ult.caster = caster
	var atk4 := MockSkill.new()
	atk4.info = {"CD": 5.0}
	caster.skills["BossSil_atk4"] = atk4
	hero.skills["BossSil_atk6"] = ult
	BattleHeroScripts.apply("battle/heroes/BossSil", hero)
	assert_false(hero.is_action_stage_change_by_manual, "S1: BossSil 不设 manual stage（源 BossSil.lua 全文 48 行无 setActionStageChangeByManual，:76 实指 BB.lua）")
	ult.hero_hooks["onAttackFrame"].call(ult)
	assert_eq(caster.start_scale_calls.size(), 1, "S2 onAttackFrame 调 start_scaling_action（源 :21）")
	ult.hero_hooks["finish"].call(ult)
	assert_eq(caster.end_scale_calls, 1, "S2 finish 调 end_scaling_action（源 :33）")


# Luna-1：源 init_hero（:37-47）未 override takeEffectOn（latent bug），目标照源不挂。
func test_luna_atk3_no_takeEffectOn_hook() -> void:
	var hero := MockHero.new()
	var skill_atk3 := MockSkill.new()
	hero.skills["Luna_atk3"] = skill_atk3
	BattleHeroScripts.apply("battle/heroes/Luna", hero)
	assert_false(skill_atk3.hero_hooks.has("takeEffectOn"), "Luna-1: 源 init_hero 未挂 takeEffectOn（latent bug），照源不挂")
	assert_true(skill_atk3.hero_hooks.has("createProjectile"), "Luna atk3 createProjectile 仍挂（源 :44）")
	assert_true(skill_atk3.hero_hooks.has("power"), "Luna atk3 power 仍挂（源 :45）")


# ExBossSpider-1：atk4 周期 AP 伤害 crit_mod=0（源 :92 第 6 参，非第 5 参 coefficient=1）。
func test_exbossspider_atk4_crit_mod_zero() -> void:
	var hero := MockHero.new()
	var skill_atk4 := MockSkill.new()
	skill_atk4.info = {"Script Arg1": 50.0}
	var caster := MockCaster.new()
	skill_atk4.caster = caster
	hero.skills["ExBossSpider_atk4"] = skill_atk4
	BattleHeroScripts.apply("battle/heroes/ExBossSpider", hero)
	var buff: Variant = skill_atk4.hero_hooks["createBuff"].call(skill_atk4, null)
	# dt=1.0 让 timeTag(0.5) 倒计 ≤0 触发周期 take_damage
	buff.hero_hooks["update"].call(buff, 1.0)
	assert_eq(caster.last_crit_mod, 0.0, "ExBossSpider-1: atk4 crit_mod=0（源 :92 第 6 参，禁暴击）")


# BossCoco C4：dps_mod 负数照源 ×MULT（Lua 0/负 truthy，目标 >0 守卫偏离已修 != null）。
func test_bosscoco_finish_dps_mod_negative_multiplied() -> void:
	var hero := MockHero.new()
	var ult := MockSkill.new()
	var caster := MockCaster.new()
	caster.config["dps_mod"] = -5.0
	ult.caster = caster
	var atk2 := MockSkill.new()
	atk2.info = {"CD": 5.0, "Shape Arg1": 1}
	caster.skills["BossCoco_atk2"] = atk2
	hero.skills["BossCoco_atk6"] = ult
	BattleHeroScripts.apply("battle/heroes/BossCoco", hero)
	ult.hero_hooks["finish"].call(ult)
	# 源 :32 dps_mod and dps_mod*1.5：负数 truthy → -5*1.5=-7.5（旧 >0 守卫不改，偏离源）
	assert_almost_eq(float(caster.config["dps_mod"]), -7.5, 0.01, "C4: dps_mod 负数照源 ×MULT（Lua truthy，!= null 守卫非 >0）")
