extends GutTest
# P0-2（2026-09-28 审查）：WL 术士 hook。
# 核心：apply 不再把 heal 加成写回 skill.info（SkillLibrary 共享缓存，
# get_skill_info 返共享引用 + GameData.skills 全局单例 → 跨单位/跨场次指数累积）；
# 加成移到 _create_buff 友军分支的局部副本上计算。


class MockSkill:
	extends RefCounted
	var info: Dictionary = {"buff_info": {"HPR": 100.0}, "Script Arg1": 20, "Script Arg2": 55}
	var hero_hooks: Dictionary = {}
	var caster: Variant = null


class MockHero:
	extends RefCounted
	var skills: Dictionary = {}
	var hero_hooks: Dictionary = {}
	var attribs: Dictionary = {"HEAL": 50}


class MockCaster:
	extends RefCounted
	var camp: int = 1
	var attribs: Dictionary = {"HEAL": 50}
	var cm: Variant = null
	var skills: Dictionary = {}


class SharedRowCm:
	extends RefCounted
	var row: Dictionary = {"Name": "wl_poison", "HPR": 0}
	func lookup(_t: StringName, _c: String, _k: Variant) -> Variant:
		return row


# apply 两次（跨场次构造两只 WL 的模拟）：共享 info 的 buff_info.HPR 必须保持原值。
# 旧实现每次 apply 乘 (1+heal/100) → 两次后 100×1.5×1.5=225 指数膨胀。
func test_apply_does_not_write_shared_skill_info() -> void:
	var script: RefCounted = load("res://scripts/systems/battle/heroes/hero_wl.gd").new()
	var shared_info: Dictionary = {"buff_info": {"HPR": 100.0}, "Script Arg1": 20, "Script Arg2": 55}
	for i in WL_APPLY_ROUNDS:
		var hero := MockHero.new()
		var atk2 := MockSkill.new()
		atk2.info = shared_info   # 模拟 SkillLibrary 返回的共享引用
		hero.skills["WL_atk2"] = atk2
		script.apply(hero)
	assert_almost_eq(float(shared_info["buff_info"]["HPR"]), 100.0, 0.001, "apply 多次后共享 info HPR 不变")


# 友军分支：buff 实例 HPR = 表值 × (1 + HEAL/100)，且不改共享 info。
func test_create_buff_ally_hpr_scaled_on_copy() -> void:
	var script: RefCounted = load("res://scripts/systems/battle/heroes/hero_wl.gd").new()
	var hero := MockHero.new()
	var atk2 := MockSkill.new()
	hero.skills["WL_atk2"] = atk2
	script.apply(hero)
	var caster := MockCaster.new()
	caster.cm = SharedRowCm.new()
	atk2.caster = caster
	var ally := MockCaster.new()
	ally.camp = 1
	var buff: Variant = script._create_buff(atk2, ally)
	assert_almost_eq(float(buff.info["HPR"]), 150.0, 0.001, "100×(1+50/100)=150 加成生效")
	assert_almost_eq(float(atk2.info["buff_info"]["HPR"]), 100.0, 0.001, "共享 info 不被写")


# 敌方分支：HPR = -Script Arg1（毒），同样不动共享 info。
func test_create_buff_enemy_hpr_negative() -> void:
	var script: RefCounted = load("res://scripts/systems/battle/heroes/hero_wl.gd").new()
	var hero := MockHero.new()
	var atk2 := MockSkill.new()
	hero.skills["WL_atk2"] = atk2
	script.apply(hero)
	var caster := MockCaster.new()
	caster.cm = SharedRowCm.new()
	atk2.caster = caster
	var enemy := MockCaster.new()
	enemy.camp = -1
	var buff: Variant = script._create_buff(atk2, enemy)
	assert_almost_eq(float(buff.info["HPR"]), -20.0, 0.001, "敌方 HPR=-ScriptArg1")
	assert_almost_eq(float((caster.cm as SharedRowCm).row["HPR"]), 0.0, 0.001, "cm 表行不被污染")


const WL_APPLY_ROUNDS: int = 2
