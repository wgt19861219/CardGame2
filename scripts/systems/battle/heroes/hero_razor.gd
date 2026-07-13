extends RefCounted

## Razor 英雄 hook（Logic 层）— 照源 battle/heroes/Razor.lua（18 行）。
## Razor_atk3.takeEffectOn：basefunc → 查 Buff（Script Arg1）→ AD=-buff_info.AD → addBuff（自残减攻）。

func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Razor_atk3")
	if skill:
		skill.hero_hooks["takeEffectOn"] = Callable(self, "_take_effect_on")


# 源 :2-10 skillatk3_takeEffectOn（basefunc → 查 Buff → AD 取负 → addBuff）。
func _take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var r: Array = BattleSkillEffect.take_effect_on(skill, target, src)  # basefunc [succ, dmg]
	var caster: Variant = skill.caster
	var info: Dictionary = skill.info
	var bid: int = int(info.get("Script Arg1", 0))
	var binfo: Dictionary = caster.cm.lookup(&"Buff", "", bid)  # ed.lookupDataTable
	# 源 :8 binfo.AD = -info.buff_info.AD（直接改共享表，GDScript 字典引用故 duplicate 避污染）
	binfo = binfo.duplicate()
	var buff_info: Dictionary = info.get("buff_info", {})
	binfo["AD"] = -float(buff_info.get("AD", 0.0))
	caster.add_buff(binfo, caster)
	return r  # 透传（源 local succ 未用于判断）
