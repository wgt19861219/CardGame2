class_name HeroLion
extends RefCounted

## Lion（恶魔巫师）英雄 hook（Logic 层）— 照源 battle/heroes/Lion.lua（21 行）。
## Lion_atk2.takeEffectOn：basefunc + View 地刺特效（launch_spike 在 target 位置，Phase 4）。

const DEFAULT_POINT_ZORDER: float = 0.0


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Lion_atk2")
	if skill:
		skill.hero_hooks["takeEffectOn"] = Callable(self, "_atk2_take_effect_on")


func _atk2_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var r: Array = BattleSkillEffect.take_effect_on(skill, target, src)  # basefunc [succ, dmg]
	# View 段 Phase 4
	var caster: Variant = skill.caster
	if caster != null and caster.actor != null and caster.actor.has_method("play_effect"):
		var effect_z: float = float(skill.info.get("Point Zorder", DEFAULT_POINT_ZORDER))
		var scale_x: float = float(caster.direction)
		caster.actor.play_effect("effect/eff_launch_spike", target.position, scale_x, 0.0, int(effect_z))
	return r  # 透传 [succ, dmg]
