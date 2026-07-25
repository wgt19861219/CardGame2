extends RefCounted

## TK（修补匠）英雄 hook（Logic 层）— 照源 battle/heroes/TK.lua（96 行）。
## TK_ult.onAttackFrame：完整重写（不调 basefunc）— manually_casting 解冻 + random selectTarget +
##   counter%3 周期切 2D/3D tile 参数（Script Arg2-6）+ Track Type 分发 projectile/chain/takeEffectAt + Gain MP + Move Forward。
## TK_ult/TK_atk3.createProjectile：basefunc + 注册 projectile.update hook（3D 追踪）。
## projectile.update 新 hook 点（BattleProjectile.hero_hooks.update，拆 _update_default 当 basefunc）。

const TILE_MODE_PERIOD: int = 3
const TILE_3D_MOD: int = 2
const DV_SPEED: float = 600.0
const TRACK_GAIN: float = 8.0
const NORM_POWER: float = -0.5


func apply(hero: Variant) -> void:
	var skillult: Variant = hero.skills.get("TK_ult")
	var skillatk3: Variant = hero.skills.get("TK_atk3")
	if skillult:
		skillult.hero_hooks["onAttackFrame"] = Callable(self, "_ult_on_attack_frame")
		skillult.hero_hooks["createProjectile"] = Callable(self, "_create_projectile")
	if skillatk3:
		skillatk3.hero_hooks["createProjectile"] = Callable(self, "_create_projectile")


func _ult_on_attack_frame(skill: Variant) -> void:
	var caster: Variant = skill.caster
	if bool(caster.manually_casting):
		caster.engine.unfreeze()
		caster.manually_casting = false
	if String(skill.info.get("Target Type", "")) == "random":
		skill._select_target(skill.target)
	if skill.target == null:
		return
	var info: Dictionary = skill.info
	skill.attack_counter = int(skill.attack_counter) + 1
	var counter: int = int(skill.attack_counter)
	var ttype: String = String(info.get("Track Type", ""))
	if counter % TILE_MODE_PERIOD != TILE_3D_MOD:
		info["Tile Art"] = "projectile/TK_atk2_tile.png"
		info["Tile OTT Height"] = 0
		info["Tile XY Speed"] = info.get("Script Arg2", 0)
		info["Tile Z Speed"] = 0
	else:  # counter%3 == 2（3D 模式）
		info["Tile Art"] = "projectile/TK_atk3_tile.png"
		info["Tile OTT Height"] = info.get("Script Arg4", 0)
		info["Tile XY Speed"] = info.get("Script Arg5", 0)
		info["Tile Z Speed"] = info.get("Script Arg6", 0)
	if ttype == "projectile":
		caster.engine.add_projectile(skill._create_projectile())
	elif ttype == "chain":
		caster.engine.add_chain(skill.create_chain())
	elif ttype == "":
		skill.take_effect_at(skill.target.position)
	caster.set_mp(float(caster.mp) + float(info.get("Gain MP", 0.0)) * float(caster.engine.mp_bonus))
	var fwd: float = float(info.get("Move Forward", 0.0))
	if fwd > 0.0:
		caster.position = Vector2(caster.position.x + fwd * float(caster.direction), caster.position.y)


func _create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = skill._create_projectile_default()  # basefunc
	projectile.hero_hooks["update"] = Callable(self, "_projectile_update")
	return projectile


func _projectile_update(projectile: Variant, dt: float) -> void:
	projectile._update_default(dt)  # basefunc
	projectile.z_speed = float(projectile.z_speed) - float(projectile.skill.info.get("Tile Gravity", 0.0)) * dt
	var dv: float = DV_SPEED * dt
	var target: Variant = projectile.skill.target
	if target == null:
		return
	var tpos: Vector2 = target.position
	var targetxy: Vector2 = tpos - projectile.position
	var targetz: float = -float(projectile.height)
	var u: float = pow(targetxy.x * targetxy.x + targetxy.y * targetxy.y + targetz * targetz, NORM_POWER)
	var zs: float = float(projectile.z_speed)
	if dv < zs:
		projectile.z_speed = zs - dv
		dv = 0.0
	elif zs > 0.0:
		dv = dv - zs
		projectile.z_speed = 0.0
	var vel: Vector2 = projectile.velocity
	vel.x += u * targetxy.x * dv * TRACK_GAIN
	vel.y += u * targetxy.y * dv * TRACK_GAIN
	projectile.velocity = vel
	projectile.z_speed = float(projectile.z_speed) + u * targetz * dv * TRACK_GAIN
