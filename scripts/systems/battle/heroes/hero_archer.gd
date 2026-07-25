extends RefCounted

## Archer 英雄 hook（Logic 层）— 照源 battle/heroes/Archer.lua（23 行）。
## Archer_atk2.createProjectile：basefunc 建弹射物 → 抛物线 velocity 朝 target → 自 add → 隐式 nil。

# 抛物线求飞行时间（源 :7-11；照源重复）
const G_HALF: float = 0.5
const DISC_K: float = 4.0
const DEN_K: float = 2.0


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Archer_atk2")
	if skill:
		skill.hero_hooks["createProjectile"] = Callable(self, "_create_projectile")


func _create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = BattleProjectile.new(skill)  # basefunc
	var h: float = float(projectile.height)
	var v: float = float(projectile.z_speed)
	var a: float = float(skill.info.get("Tile Gravity", 0.0))
	var qa: float = G_HALF * a
	var qb: float = v
	var qc: float = h
	var delta: float = qb * qb - DISC_K * qa * qc
	var t: float = (-qb - sqrt(delta)) / (DEN_K * qa)
	var distance: Vector2 = skill.target.position - skill.caster.position  # edpSub
	projectile.velocity = distance * (1.0 / t)  # edpMult
	skill.caster.engine.add_projectile(projectile)  # ed.engine:addProjectile
	return null
