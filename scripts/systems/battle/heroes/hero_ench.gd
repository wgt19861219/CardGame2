extends RefCounted

## Ench（魅惑魔女）英雄 hook（Logic 层）— 照源 battle/heroes/Ench.lua（14 行）。
## Ench_atk3.takeEffectOn：basefunc 后清零 target 技能 cd（basic_skill.cd_remaining + global_cd）。

func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Ench_atk3")
	if skill:
		skill.hero_hooks["takeEffectOn"] = Callable(self, "_take_effect_on")


func _take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var r: Array = BattleSkillEffect.take_effect_on(skill, target, src)  # basefunc [succ, dmg]
	target.basic_skill.cd_remaining = 0.0
	target.global_cd = 0.0
	return r  # 透传
