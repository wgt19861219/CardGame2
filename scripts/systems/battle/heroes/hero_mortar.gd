extends RefCounted

## Mortar 英雄 hook（Logic 层）— 照源 battle/heroes/Mortar.lua（24 行）。
## Mortar_atk.createProjectile：basefunc 建弹射物 → 抛物线求飞行时间 t → velocity 朝 target.position。
## return projectile（调用方 _on_attack_frame_default add_projectile）。
## 源 override 机制 → skill.hero_hooks["createProjectile"]（Phase 2.7 hook 基础设施）。

# 抛物线求飞行时间（源 :7-11：A=0.5g, B=v, C=h, Δ=B²-4AC, t=(-B-√Δ)/2A；照源重复，各英雄独立）
const G_HALF: float = 0.5
const DISC_K: float = 4.0
const DEN_K: float = 2.0


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Mortar_atk")
	if skill:
		skill.hero_hooks["createProjectile"] = Callable(self, "_create_projectile")


# 源 :2-15 skillatk3_createProjectile（basefunc → 抛物线 velocity → return projectile）。
func _create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = BattleProjectile.new(skill)  # basefunc = ed.ProjectileCreate
	var h: float = float(projectile.height)
	var v: float = float(projectile.z_speed)
	var a: float = float(skill.info.get("Tile Gravity", 0.0))
	var qa: float = G_HALF * a  # 源 A = 0.5 * a
	var qb: float = v  # 源 B = v
	var qc: float = h  # 源 C = h
	var delta: float = qb * qb - DISC_K * qa * qc
	var t: float = (-qb - sqrt(delta)) / (DEN_K * qa)
	var distance: Vector2 = skill.target.position - skill.caster.position  # edpSub
	projectile.velocity = distance * (1.0 / t)  # edpMult
	return projectile
