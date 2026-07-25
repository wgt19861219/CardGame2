extends RefCounted

## Sniper（狙击）英雄 hook（Logic 层）— 照源 battle/heroes/Sniper.lua（41 行）。
## Sniper_ult.start：basefunc 后 target.unfreezeActor + addBuff(Buff 14)；
##   Sniper.castManualSkill：basefunc 后 ult.target.unfreezeActor；
##   Sniper_atk3.createProjectile：抛物线 velocity（A=0.5g / B=zSpeed / C=height）。

const SNIPER_BUFF_ID: int = 14
# 抛物线公式系数（源 :20-24，照源重复，不抽 helper）
const G_HALF: float = 0.5
const DISC_K: float = 4.0
const DEN_K: float = 2.0


func apply(hero: Variant) -> void:
	var skillult: Variant = hero.skills.get("Sniper_ult")
	if skillult:
		skillult.hero_hooks["start"] = Callable(self, "_ult_start")
	hero.hero_hooks["castManualSkill"] = Callable(self, "_cast_manual_skill")
	var skillatk3: Variant = hero.skills.get("Sniper_atk3")
	if skillatk3:
		skillatk3.hero_hooks["createProjectile"] = Callable(self, "_create_projectile")


func _ult_start(skill: Variant, target: Variant) -> void:
	skill._start_default(target)
	skill.target.unfreeze_actor()
	var binfo: Variant = skill.caster.cm.lookup(&"Buff", "", SNIPER_BUFF_ID)
	skill.target.add_buff(binfo, skill.caster)


func _cast_manual_skill(hero: Variant) -> void:
	hero._cast_manual_skill_default()
	var ult: Variant = hero.skills.get("Sniper_ult")
	ult.target.unfreeze_actor()


func _create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = BattleProjectile.new(skill)  # basefunc（源 ProjectileCreate）
	var h: float = float(projectile.height)
	var v: float = float(projectile.z_speed)
	var a: float = float(skill.info.get("Tile Gravity", 0.0))
	var A: float = G_HALF * a
	var B: float = v
	var C: float = h
	var delta: float = B * B - DISC_K * A * C
	var t: float = (-B - sqrt(delta)) / (DEN_K * A)
	var distance: Vector2 = skill.target.position - skill.caster.position
	projectile.velocity = distance * (1.0 / t)
	return projectile
