extends RefCounted

## Pugna 英雄 hook（Logic 层）— 照源 battle/heroes/Pugna.lua（15 行）。
## Pugna_ult.takeEffectOn：加 Buff 17 → basefunc → 移除 buff（短暂 buff 仅 basefunc 期间生效）。

const BUFF_ID: int = 17

func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Pugna_ult")
	if skill:
		skill.hero_hooks["takeEffectOn"] = Callable(self, "_take_effect_on")


func _take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var caster: Variant = skill.caster
	var binfo: Variant = caster.cm.lookup(&"Buff", "", BUFF_ID)  # ed.lookupDataTable
	var buff: Variant = caster.add_buff(binfo, caster)
	var r: Array = BattleSkillEffect.take_effect_on(skill, target, src)  # basefunc [succ, dmg]
	caster.remove_buff(buff)
	return r  # 透传（源 local succ 未用于判断）
