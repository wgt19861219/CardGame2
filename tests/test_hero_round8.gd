extends GutTest
# 第八轮 P0/P1 修复回归（Lion play_effect 5 参 / Viper return null / AncientTreant atk2 补挂）。
# Lion play_effect 去 1.0（6→5 参匹配签名）+ Viper return null（照源）修复明确，门禁编译验证；
# 本测试聚焦 AncientTreant atk2 hook 注册完整（Mock 可达）。


class MockSkill:
	extends RefCounted
	var info: Dictionary = {}
	var hero_hooks: Dictionary = {}


class MockHero:
	extends RefCounted
	var skills: Dictionary = {}
	var hero_hooks: Dictionary = {}
	var is_boss_create_with_effect: bool = true  # AncientTreant apply :19 赋值
	func set_disapear_when_die(_v: bool) -> void: pass  # apply :20 调用


# AncientTreant P1：atk2.takeEffectAt 补挂（源 init_hero :53-55 挂，目标此前漏挂，补占位让 hook 注册完整）。
func test_ancienttreant_atk2_takeEffectAt_registered() -> void:
	var hero := MockHero.new()
	var atk := MockSkill.new()
	var atk2 := MockSkill.new()
	var atk6 := MockSkill.new()
	hero.skills["AncientTreant_atk"] = atk
	hero.skills["AncientTreant_atk2"] = atk2
	hero.skills["AncientTreant_atk6"] = atk6
	BattleHeroRegistry.apply("battle/heroes/AncientTreant", hero)
	assert_true(atk2.hero_hooks.has("takeEffectAt"), "AncientTreant P1: atk2 takeEffectAt 补挂（源 :53-55，hook 注册完整）")
	assert_true(atk.hero_hooks.has("createProjectile"), "atk createProjectile 仍挂")
	assert_true(atk6.hero_hooks.has("start"), "atk6 start 仍挂")
	assert_true(atk6.hero_hooks.has("finish"), "atk6 finish 仍挂")
