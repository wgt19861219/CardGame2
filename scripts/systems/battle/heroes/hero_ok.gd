extends RefCounted

## OK 英雄 hook（Logic 层）— 照源 OK.lua（19 行）。
## atk2 takeEffectOn（protoAwake 双守卫：apply 守卫挂 hook + wrapper 内 protoAwake 再检查→Buff137）。
## 待 protoAwake Phase5 激活（当前 proto_awake 桩 false，hook 不挂）。

const BUFF_OK_ID: int = 137  # 源 :5 protoAwake 后加 buff


# 源 :1-9 atk2 takeEffectOn：basefunc + protoAwake→加 Buff137（wrapper 内双检查）。
func _atk2_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var r: Array = BattleSkillEffect.take_effect_on(skill, target, src)
	if BattleHeroRegistry.proto_awake(skill.caster.proto):
		var binfo: Variant = skill.caster.cm.lookup(&"Buff", "", BUFF_OK_ID)
		target.add_buff(binfo, skill.caster)
	return r


# 源 :10-18 init_hero：protoAwake 守卫挂 atk2 takeEffectOn。
func apply(hero: Variant) -> void:
	if BattleHeroRegistry.proto_awake(hero.proto):
		var skill2: Variant = hero.skills.get("OK_atk2")
		if skill2:
			skill2.hero_hooks["takeEffectOn"] = Callable(self, "_atk2_take_effect_on")
