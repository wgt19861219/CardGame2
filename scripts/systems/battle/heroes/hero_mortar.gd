extends RefCounted

## Mortar 英雄 hook（Logic 层）— 照源 battle/heroes/Mortar.lua（24 行）。
## Mortar_atk.createProjectile：basefunc 建弹射物 → 抛物线求飞行时间 t → velocity 朝 target.position。
## return projectile（调用方 _on_attack_frame_default add_projectile）。

# 抛物线求飞行时间（源 :7-11：A=0.5g, B=v, C=h, Δ=B²-4AC, t=(-B-√Δ)/2A；照源重复，各英雄独立）
const G_HALF: float = 0.5
const DISC_K: float = 4.0
const DEN_K: float = 2.0


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Mortar_atk")
	if skill:
		skill.hero_hooks["createProjectile"] = Callable(self, "_create_projectile")


func _create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = BattleProjectile.new(skill)  # basefunc = ed.ProjectileCreate
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
	return projectile
