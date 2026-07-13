extends RefCounted
# AV 英雄 hook（照源 battle/heroes/AV.lua，5 hook 跨 3 技能）。
# AV_ult start（记 origin + View 特效 Phase 4）/ createProjectile（height=300 + position=origin）/ willCast（!=AV_atk3）；
# AV_atk3 onAttackFrame（分段冲撞 + 查 Buff addBuff）；AV_atk2 createProjectile（enableTrack + 向量运算）。
# origin 跨 start→createProjectile 共享（源文件级 local，GDScript 实例字段等价——单例语义同源）。

const ULT_HEIGHT: float = 300.0       # 源 skillult_createProjectile projectile.height=300
const ATK2_SPEED: float = 1200.0      # 源 skillatk2_createProjectile v=1200
const ATK3_MOVE_TIME: float = 2.3     # 源 skillatk3_onAttackFrame t=2.3（冲撞时长）
const ATK3_STOP_FRAME: int = 11       # 源 skillatk3 attack_counter==11 停止（第 12 帧）
const STAGE_WIDTH: float = 800.0      # 源 skillatk3 dis=800-pos（舞台宽度，源硬编码）

var _origin: Vector2 = Vector2.ZERO   # 源文件级 local origin（_ult_start 设，_ult_create_projectile 读）


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


# 源 skillult_start（AV.lua:3-17）：origin=skill.target.position → selectTarget → playEffect → basefunc（最后）
# P1-3：origin 读 skill.target（selectTarget 之前，源 :4-7）非入参 target；P1-4：补 _select_target（源 :10）；
#   顺序照源 basefunc 最后（源 :16，原目标 basefunc 在中）。
func _ult_start(skill: Variant, target: Variant) -> void:
	_origin = skill.target.position  # 源 :4-7（_select_target 之前的 skill.target）
	skill._select_target(target)  # 源 :10 selectTarget（P1-4）
	# 源 :8-15 ed.scene:playEffectOnScene("eff_launch_AV_ult.cha", origin, nil, nil, -1)
	var caster: Variant = skill.caster
	if caster != null and caster.actor != null and caster.actor.has_method("play_effect"):
		caster.actor.play_effect("effect/eff_launch_AV_ult", _origin, 1.0, 0.0, -1)
	skill._start_default(target)  # 源 :16 basefunc（最后）


# 源 skillult_createProjectile（:18-23）：projectile.height=300 + position=origin
func _ult_create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = BattleProjectile.new(skill)  # basefunc（源 basefunc(skill)→ed.ProjectileCreate）
	projectile.height = ULT_HEIGHT
	projectile.position = _origin
	return projectile


# 源 skillult_willCast（:24-26）：basefunc and caster.current_skill != AV_atk3
func _ult_will_cast(skill: Variant) -> bool:
	var caster: Variant = skill.caster
	var atk3: Variant = caster.skills.get("AV_atk3") if caster != null else null
	return skill._will_cast_default() and caster.current_skill != atk3


# 源 skillatk3_onAttackFrame（:27-54）：attack_counter 分段冲撞 + 查 Buff addBuff + basefunc
func _atk3_on_attack_frame(skill: Variant) -> void:
	var caster: Variant = skill.caster
	var dir: int = int(caster.direction)
	var dis: float = (STAGE_WIDTH - caster.position.x) if dir == 1 else caster.position.x  # 源 direction==1 ? 800-x : x
	var v: float = dis / ATK3_MOVE_TIME
	var counter: int = int(skill.attack_counter)
	if skill.attack_counter != null and counter == 0:  # 源 :32 attack_counter and ==0（null 落 else，P2-6）
		caster.walk_v = Vector2(dir * v, 0.0)
		caster.custom_data["AVultposition"] = caster.position
		var bid: Variant = skill.info.get("Script Arg1", "")
		var binfo: Dictionary = caster.cm.lookup(&"Buff", "", bid)
		caster.add_buff(binfo, caster)
		skill._on_attack_frame_default()  # basefunc
	elif skill.attack_counter != null and counter == ATK3_STOP_FRAME:  # 源 :45（P2-6）
		caster.walk_v = Vector2.ZERO
		caster.position = caster.custom_data["AVultposition"]
	else:
		skill._on_attack_frame_default()  # basefunc


# 源 skillatk2_createProjectile（:55-76）：enableTrack + 向量运算调整 velocity/zSpeed（抛物线追目标）
func _atk2_create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = BattleProjectile.new(skill)  # basefunc
	var p_target: Variant = projectile.skill.target
	if p_target == null:
		return null  # 源 :59-61 if not target then return（nil，P2-5）
	projectile.enable_track(p_target)
	# 源 targetxyV=edpSub(targetpos,pos)；targetzV=-height；u=(|xy|²+z²)^-0.5；velocity/zSpeed += u*comp*v
	var target_xy: Vector2 = p_target.position - projectile.position
	var target_z: float = -projectile.height
	var u: float = 1.0 / sqrt(target_xy.x * target_xy.x + target_xy.y * target_xy.y + target_z * target_z)
	projectile.velocity = projectile.velocity + Vector2(u * target_xy.x, u * target_xy.y) * ATK2_SPEED
	projectile.z_speed = projectile.z_speed + u * target_z * ATK2_SPEED
	return projectile
