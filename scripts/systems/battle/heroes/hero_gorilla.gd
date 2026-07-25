extends RefCounted

## Gorilla 英雄 hook（Logic 层）— 照源 battle/heroes/Gorilla.lua（27 行）。
## Gorilla_atk2.createProjectile：basefunc 建弹射物 → 目标 X 偏移 60·direction → 抛物线 velocity
## → 自 add_projectile → return null（调用方 addProjectile(null) 被 nil 守卫 no-op，源 :1714）。

# 抛物线求飞行时间（源 :11-15；照源重复）
const G_HALF: float = 0.5
const DISC_K: float = 4.0
const DEN_K: float = 2.0
const TARGET_X_OFFSET: float = 60.0


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Gorilla_atk2")
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
	var target_pos := Vector2(
		skill.target.position.x - TARGET_X_OFFSET * float(skill.caster.direction),
		skill.target.position.y)
	var distance: Vector2 = target_pos - skill.caster.position  # edpSub
	projectile.velocity = distance * (1.0 / t)  # edpMult
	skill.caster.engine.add_projectile(projectile)  # ed.engine:addProjectile
	return null
