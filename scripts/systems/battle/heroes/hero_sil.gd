extends RefCounted

## Sil 英雄 hook（Logic 层）— 照源 battle/heroes/Sil.lua（17 行）。
## Sil_atk3.takeEffectOn：命中成功（basefunc 返回 true）后额外 Holy mp 伤害（Script Arg1）。

func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Sil_atk3")
	if skill:
		skill.hero_hooks["takeEffectOn"] = Callable(self, "_take_effect_on")


func _take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var r: Array = BattleSkillEffect.take_effect_on(skill, target, src)  # basefunc [succ, dmg]
	var succ: bool = bool(r[0])
	if succ:
		var power: float = float(skill.info.get("Script Arg1", 0))
		target.take_damage({"amount": power, "damage_type": "Holy", "field": "mp", "source": skill.caster})
	return r  # 透传 [succ, dmg]
