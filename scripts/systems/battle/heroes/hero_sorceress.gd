extends RefCounted

## Sorceress 英雄 hook（Logic 层）— 照源 battle/heroes/Sorceress.lua（18 行）。
## Sorceress_atk2.createBuff：飞行单位（Can Fly）→ Buff 110 / else basefunc。

const FLY_BUFF_ID: int = 110  # 源 :5 飞行单位专用 buff


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Sorceress_atk2")
	if skill:
		skill.hero_hooks["createBuff"] = Callable(self, "_create_buff")


# 源 :2-10 skill2_createBuff（飞行单位 → Buff 110 / else basefunc）。
func _create_buff(skill: Variant, target: Variant) -> Variant:
	if bool(target.info.get("Can Fly", false)):
		var binfo: Variant = skill.caster.cm.lookup(&"Buff", "", FLY_BUFF_ID)
		return BattleBuff.new(binfo, target, skill.caster)  # 源 BuffCreate(binfo, target, caster)
	return skill._create_buff_default(target)  # basefunc
