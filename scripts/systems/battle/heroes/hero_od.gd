extends RefCounted

## OD 英雄 hook（Logic 层）— 照源 battle/heroes/OD.lua（18 行）。
## OD_ult.takeEffectOn：Main Attrib == INT 的目标免疫（直接 false，源 popup "immune" View 留 P4）。

func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("OD_ult")
	if skill:
		skill.hero_hooks["takeEffectOn"] = Callable(self, "_take_effect_on")


# 源 :1-11 takeEffectOn（INT 主属性 → 免疫 false；否则 basefunc）。
func _take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	if String(target.info.get("Main Attrib", "")) == "INT":
		_show_immune_popup(target)  # 源 OD.lua:4-6 immune 飘字
		return [false, 0.0]  # 免疫
	return BattleSkillEffect.take_effect_on(skill, target, src)  # basefunc


# 源 OD.lua:4-6 INT 免疫 immune 飘字（target actor，camp enemy→red/else→blue）。
func _show_immune_popup(target: Variant) -> void:
	var actor: Variant = target.get("actor")
	if actor == null or not actor.has_method("spawn_popup"):
		return
	var color: String = "red" if int(target.camp) == BattleEngine.CAMP_ENEMY else "blue"
	actor.spawn_popup("immune", color, false, "text")
