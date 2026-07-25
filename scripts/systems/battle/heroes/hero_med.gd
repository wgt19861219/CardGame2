extends RefCounted

## Med（美杜莎）英雄 hook（Logic 层）— 照源 battle/heroes/Med.lua（41 行）。
## Med_atk2.createProjectile：foreach affected camp（≤5 目标），每目标创建追踪弹；
##   原目标 dmg_modifier=1，其他 =Script Arg1/100（伤害衰减）；自 add，return nil。
## Med_atk2.power：返 [basefunc×dmg_modifier, dmg_modifier]（源 :19 返 power×mod, mod；mod 当 crit_mod）。
## Med_atk3.takeEffectAt：caster.addBuff(Buff 34) → basefunc → removeBuff（瞬间挂 buff 触发其 apply）。

const MED_MAX_TARGETS: int = 5
const MED_MOD_DENOM: float = 100.0
const MED_MAIN_MOD: float = 1.0
const MED_ULT_BUFF_ID: int = 34


func apply(hero: Variant) -> void:
	var skillatk2: Variant = hero.skills.get("Med_atk2")
	if skillatk2:
		skillatk2.hero_hooks["createProjectile"] = Callable(self, "_create_projectile")
		skillatk2.hero_hooks["power"] = Callable(self, "_power")
	var skillatk3: Variant = hero.skills.get("Med_atk3")
	if skillatk3:
		skillatk3.hero_hooks["takeEffectAt"] = Callable(self, "_take_effect_at")


func _create_projectile(skill: Variant) -> Variant:
	var orig_target: Variant = skill.target
	var mod: float = float(skill.info.get("Script Arg1", 0.0)) / MED_MOD_DENOM
	var counter: int = 0
	for unit in skill.caster.engine.foreach_alive_unit(skill._affected_camp()):
		if counter >= MED_MAX_TARGETS:
			break
		counter += 1
		skill.target = unit
		var projectile: Variant = skill._create_projectile_default()  # basefunc
		projectile.custom_data["dmg_modifier"] = MED_MAIN_MOD if unit == orig_target else mod
		projectile.enable_track(unit)
		skill.caster.engine.add_projectile(projectile)
	return null


func _power(skill: Variant, source: Variant, _target: Variant) -> Array:
	var base: Array = BattleSkillEffect.power(skill, source)  # basefunc
	var mod: float = float(source.custom_data.get("dmg_modifier", MED_MAIN_MOD))
	return [base[0] * mod, mod]


func _take_effect_at(skill: Variant, location: Vector2, source: Variant) -> void:
	var caster: Variant = skill.caster
	var binfo: Variant = caster.cm.lookup(&"Buff", "", MED_ULT_BUFF_ID)
	var buff: Variant = caster.add_buff(binfo, caster)
	BattleSkillEffect.take_effect_at(skill, location, source)  # basefunc（静态，无递归）
	caster.remove_buff(buff)
