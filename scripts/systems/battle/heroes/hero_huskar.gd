extends RefCounted

## Huskar 英雄 hook（Logic 层）— 照源 battle/heroes/Huskar.lua（35 行）。
## Huskar_ult.takeEffectOn：attack_counter==1 → 冲撞（walk_v 朝 target，避开 collidedis，不触发伤害）；
## else → 自残（HP*(100-Arg1)/100 + Buff 65 wrapped AD=Arg2 + walk_v=0）+ basefunc。
## cm 访问：caster.cm.lookup（Phase 2.7续 cm 访问路径）。

const TIMEGAP: float = 0.25  # 源 :2 冲撞到位时间
const COLLIDEDIS: float = 30.0  # 源 :3 冲撞避撞距离
const BUFF_ID: int = 65  # 源 :18 自残 buff id
const HP_BASE: float = 100.0  # 源 :25 HP 百分比基数


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Huskar_ult")
	if skill:
		skill.hero_hooks["takeEffectOn"] = Callable(self, "_take_effect_on")


# 源 :4-29 skillult_takeEffectOn（counter==1 冲撞 / else 自残+buff+basefunc）。
func _take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var caster: Variant = skill.caster
	if int(skill.attack_counter) == 1:
		# 源 :7-16 冲撞：算朝 target 的 walk_v（终点避开 collidedis）
		var d: Vector2 = skill.target.position - caster.position  # edpSub
		if d == Vector2.ZERO:
			caster.walk_v = Vector2.ZERO
		else:
			var d2: Vector2 = d - d.normalized() * COLLIDEDIS  # edpSub(d, edpMult(edpNormalize(d), collidedis))
			caster.walk_v = Vector2(d2.x / TIMEGAP, d2.y / TIMEGAP)
		return [true, 0.0]  # counter==1 不调 basefunc（冲撞帧不触发伤害）
	# 源 :17-28 自残：查 Buff 65 + wraptable AD=Arg2 + addBuff + HP 自残 + basefunc
	var binfo: Dictionary = caster.cm.lookup(&"Buff", "", BUFF_ID)
	binfo = binfo.duplicate()  # 源 ed.wraptable(binfo, {AD=...}) 等价（拷贝 + 覆盖）
	binfo["AD"] = float(skill.info.get("Script Arg2", 0.0))
	caster.add_buff(binfo, caster)
	var perc: float = float(skill.info.get("Script Arg1", 0.0))
	caster.set_hp(int(float(caster.hp) * (HP_BASE - perc) / HP_BASE))  # 源 setHP(hp*(100-perc)/100)
	caster.walk_v = Vector2.ZERO
	return BattleSkillEffect.take_effect_on(skill, target, src)  # basefunc
