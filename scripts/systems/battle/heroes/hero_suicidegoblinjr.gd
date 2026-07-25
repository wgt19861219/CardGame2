extends RefCounted

## SuicideGoblinjr（自爆地精 jr）英雄 hook（Logic 层）— 照源 battle/heroes/SuicideGoblinjr.lua（20 行）。
## SuicideGoblinjr_atk.start：basefunc 前 caster.addBuff(Buff 56, self)（自爆 buff 先挂）；
##   takeEffectAt：basefunc 后 caster.die(source)（命中即自爆身亡）。

const SELF_BUFF_ID: int = 56


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("SuicideGoblinjr_atk")
	if skill:
		skill.hero_hooks["start"] = Callable(self, "_start")
		skill.hero_hooks["takeEffectAt"] = Callable(self, "_take_effect_at")


func _start(skill: Variant, target: Variant) -> void:
	var caster: Variant = skill.caster
	var binfo: Variant = caster.cm.lookup(&"Buff", "", SELF_BUFF_ID)
	caster.add_buff(binfo, caster)
	skill._start_default(target)


func _take_effect_at(skill: Variant, location: Vector2, source: Variant) -> void:
	BattleSkillEffect.take_effect_at(skill, location, source)  # basefunc（静态，无递归）
	skill.caster.die(source)
