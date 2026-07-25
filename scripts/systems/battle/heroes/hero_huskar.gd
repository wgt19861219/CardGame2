extends RefCounted

## Huskar 英雄 hook（Logic 层）— 照源 battle/heroes/Huskar.lua（35 行）。
## Huskar_ult.takeEffectOn：attack_counter==1 → 冲撞（walk_v 朝 target，避开 collidedis，不触发伤害）；
## else → 自残（HP*(100-Arg1)/100 + Buff 65 wrapped AD=Arg2 + walk_v=0）+ basefunc。
## cm 访问：caster.cm.lookup（Phase 2.7续 cm 访问路径）。

const TIMEGAP: float = 0.25
const COLLIDEDIS: float = 30.0
const BUFF_ID: int = 65
const HP_BASE: float = 100.0


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Huskar_ult")
	if skill:
		skill.hero_hooks["takeEffectOn"] = Callable(self, "_take_effect_on")


func _take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var caster: Variant = skill.caster
	if int(skill.attack_counter) == 1:
		var d: Vector2 = skill.target.position - caster.position  # edpSub
		if d == Vector2.ZERO:
			caster.walk_v = Vector2.ZERO
		else:
			var d2: Vector2 = d - d.normalized() * COLLIDEDIS  # edpSub(d, edpMult(edpNormalize(d), collidedis))
			caster.walk_v = Vector2(d2.x / TIMEGAP, d2.y / TIMEGAP)
		return [true, 0.0]  # counter==1 不调 basefunc（冲撞帧不触发伤害）
	var binfo: Dictionary = caster.cm.lookup(&"Buff", "", BUFF_ID)
	binfo = binfo.duplicate()
	binfo["AD"] = float(skill.info.get("Script Arg2", 0.0))
	caster.add_buff(binfo, caster)
	var perc: float = float(skill.info.get("Script Arg1", 0.0))
	caster.set_hp(int(float(caster.hp) * (HP_BASE - perc) / HP_BASE))
	caster.walk_v = Vector2.ZERO
	return BattleSkillEffect.take_effect_on(skill, target, src)  # basefunc
