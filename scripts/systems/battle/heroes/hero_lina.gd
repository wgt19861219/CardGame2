extends RefCounted

## Lina 英雄 hook（Logic 层）— 照源 Lina.lua（25 行）。
## atk onAttackFrame（总挂，非 protoAwake：basefunc + Lina_atk4 Script Arg1 takeHeal mp）+
##   atk takeEffectOn（protoAwake 守卫在 wrapper 内：basefunc + protoAwake→Lina_awake createBuff 加 buff）。
## onAttackFrame 当前生效；takeEffectOn 待 protoAwake Phase5 激活。

const HEAL_TYPE_MP: String = "mp"


func _atk_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var r: Array = BattleSkillEffect.take_effect_on(skill, target, src)
	var skillawake: Variant = skill.caster.skills.get("Lina_awake")
	if skillawake != null and BattleHeroRegistry.proto_awake(skill.caster.proto):
		target.add_buff(skillawake.create_buff(target), skill.caster)
	return r


func _atk_on_attack_frame(skill: Variant) -> void:
	skill._on_attack_frame_default()
	var skillatk4: Variant = skill.caster.skills.get("Lina_atk4")
	if skillatk4:
		var mp: float = float(skillatk4.info.get("Script Arg1", 0))
		skill.caster.take_heal(mp, HEAL_TYPE_MP)


func apply(hero: Variant) -> void:
	var skillatk: Variant = hero.skills.get("Lina_atk")
	if skillatk:
		skillatk.hero_hooks["onAttackFrame"] = Callable(self, "_atk_on_attack_frame")
		if BattleHeroRegistry.proto_awake(hero.proto):
			skillatk.hero_hooks["takeEffectOn"] = Callable(self, "_atk_take_effect_on")
