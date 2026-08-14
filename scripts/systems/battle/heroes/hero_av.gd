extends RefCounted
# AV 英雄 hook（照源 battle/heroes/AV.lua，5 hook 跨 3 技能）。
# AV_ult start（记 origin + View 特效 Phase 4）/ createProjectile（height=300 + position=origin）/ willCast（!=AV_atk3）；
# AV_atk3 onAttackFrame（分段冲撞 + 查 Buff addBuff）；AV_atk2 createProjectile（enableTrack + 向量运算）。
# origin 跨 start→createProjectile 共享（源文件级 local，GDScript 实例字段等价——单例语义同源）。

const ULT_HEIGHT: float = 300.0
const ATK2_SPEED: float = 1200.0
const ATK3_MOVE_TIME: float = 2.3
const ATK3_STOP_FRAME: int = 11
const STAGE_WIDTH: float = 800.0

var _origin: Vector2 = Vector2.ZERO


func apply(hero: Variant) -> void:
	var skill_ult: Variant = hero.skills.get("AV_ult")
	var skill_atk3: Variant = hero.skills.get("AV_atk3")
	var skill_atk2: Variant = hero.skills.get("AV_atk2")
	if skill_ult:
		skill_ult.hero_hooks["start"] = Callable(self, "_ult_start")
		skill_ult.hero_hooks["createProjectile"] = Callable(self, "_ult_create_projectile")
		skill_ult.hero_hooks["willCast"] = Callable(self, "_ult_will_cast")
	if skill_atk3:
		skill_atk3.hero_hooks["onAttackFrame"] = Callable(self, "_atk3_on_attack_frame")
	if skill_atk2:
		skill_atk2.hero_hooks["createProjectile"] = Callable(self, "_atk2_create_projectile")


# P1-3：origin 读 skill.target（selectTarget 之前，源 :4-7）非入参 target；P1-4：补 _select_target（源 :10）；
#   顺序照源 basefunc 最后（源 :16，原目标 basefunc 在中）。
func _ult_start(skill: Variant, target: Variant) -> void:
	_origin = skill.target.position
	skill._select_target(target)
	var caster: Variant = skill.caster
	if caster != null:
		caster.emit_play_effect("effect/eff_launch_AV_ult", _origin, 1.0, 0.0, -1)
	skill._start_default(target)


func _ult_create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = BattleProjectile.new(skill)  # basefunc（源 basefunc(skill)→ed.ProjectileCreate）
	projectile.height = ULT_HEIGHT
	projectile.position = _origin
	return projectile


func _ult_will_cast(skill: Variant) -> bool:
	var caster: Variant = skill.caster
	var atk3: Variant = caster.skills.get("AV_atk3") if caster != null else null
	return skill._will_cast_default() and caster.current_skill != atk3


func _atk3_on_attack_frame(skill: Variant) -> void:
	var caster: Variant = skill.caster
	var dir: int = int(caster.direction)
	var dis: float = (STAGE_WIDTH - caster.position.x) if dir == 1 else caster.position.x
	var v: float = dis / ATK3_MOVE_TIME
	var counter: int = int(skill.attack_counter)
	if skill.attack_counter != null and counter == 0:
		caster.walk_v = Vector2(dir * v, 0.0)
		caster.custom_data["AVultposition"] = caster.position
		var bid: Variant = skill.info.get("Script Arg1", "")
		var binfo: Dictionary = caster.cm.lookup(&"Buff", "", bid)
		caster.add_buff(binfo, caster)
		skill._on_attack_frame_default()  # basefunc
	elif skill.attack_counter != null and counter == ATK3_STOP_FRAME:
		caster.walk_v = Vector2.ZERO
		caster.position = caster.custom_data["AVultposition"]
	else:
		skill._on_attack_frame_default()  # basefunc


func _atk2_create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = BattleProjectile.new(skill)  # basefunc
	var p_target: Variant = projectile.skill.target
	if p_target == null:
		return null
	projectile.enable_track(p_target)
	var target_xy: Vector2 = p_target.position - projectile.position
	var target_z: float = -projectile.height
	var u: float = 1.0 / sqrt(target_xy.x * target_xy.x + target_xy.y * target_xy.y + target_z * target_z)
	projectile.velocity = projectile.velocity + Vector2(u * target_xy.x, u * target_xy.y) * ATK2_SPEED
	projectile.z_speed = projectile.z_speed + u * target_z * ATK2_SPEED
	return projectile
