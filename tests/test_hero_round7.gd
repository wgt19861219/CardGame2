extends GutTest
# 第七轮 P0 修复回归（SF skill5_power + CM skill3 死代码激活，照源不挂让走默认）。
# 源 init_hero 未 override 的顶层函数=死代码，目标此前误激活，第七轮删注册让走框架默认。
# 陷阱族 [[source-dead-code-activation]]（同根源不同形于第五轮 Phoenix if 块 local 提升）。


class MockSkill:
	extends RefCounted
	var info: Dictionary = {}
	var hero_hooks: Dictionary = {}
	var caster: Variant = null
	var custom_data: Dictionary = {}


class MockHero:
	extends RefCounted
	var skills: Dictionary = {}
	var hero_hooks: Dictionary = {}
	var custom_data: Dictionary = {}


# SF P0：源 skill5_power（SF.lua:25-32）是死代码（init_hero :49-58 未 override），照源不挂 SF_ult.power。
# 此前目标 hero_sf.gd:19-21 激活 _ult_power 借 SF_atk2.info 改伤害公式 → 删注册走默认。
func test_sf_ult_no_power_hook() -> void:
	var hero := MockHero.new()
	var skillult := MockSkill.new()
	var skill2 := MockSkill.new()
	hero.skills["SF_ult"] = skillult
	hero.skills["SF_atk2"] = skill2
	BattleHeroScripts.apply("battle/heroes/SF", hero)
	assert_false(skillult.hero_hooks.has("power"), "SF P0: skill5_power 死代码不挂 → SF_ult 走默认 power")
	assert_true(skill2.hero_hooks.has("finish"), "SF_atk2 finish 仍挂（源 :55 注册）")
	assert_true(skill2.hero_hooks.has("takeEffectAt"), "SF_atk2 takeEffectAt 仍挂（源 :54 注册）")
	assert_true(hero.hero_hooks.has("update"), "SF hero.update 仍挂（源 :50 注册）")


# CM P0：源 skill3_start/takeEffectAt（CM.lua:2-53）是死代码（init_hero :54-57 dead assignment 无 override）。
# 此前目标 hero_cm.gd:20-24 激活致 CM_ult(AP) 自己冻自己 + Point Effect 频率 + origin.y 三方差异 → 删注册走默认。
func test_cm_ult_no_hook() -> void:
	var hero := MockHero.new()
	var skillult := MockSkill.new()
	hero.skills["CM_ult"] = skillult
	BattleHeroScripts.apply("battle/heroes/CM", hero)
	assert_false(skillult.hero_hooks.has("start"), "CM P0: skill3_start 死代码不挂 → CM_ult 走默认 start")
	assert_false(skillult.hero_hooks.has("takeEffectAt"), "CM P0: skill3_takeEffectAt 死代码不挂 → CM_ult 走默认 take_effect_at")
