extends RefCounted

## AncientTreant（远古树人）英雄 hook（Logic 层）— 照源 battle/heroes/AncientTreant.lua（66 行）。
## atk createProjectile：basefunc + enableTrack + 3D 追踪 velocity 一次性（targetV 归一×1500 加到 velocity/z_speed）。
## atk2 takeEffectAt：basefunc + startCameraShakeAnimationY(10,0.1,10)（View 相机震动，经 actor 转发 scene）。
## atk6 start：caster.addBuff(Buff 56) → basefunc（源 basefunc(skill) 不传 target，selectTarget 自动）。
## atk6 finish：basefunc → dps_mod×1.5 + addBuff(Buff 97) + enterActionStageFromOneStage(2)。
## isBossCreateWithEffect=false + setDisapearWhenDie(false)。

const TRACK_SPEED: float = 1500.0
const ATK6_PRE_BUFF_ID: int = 56
const ATK6_FINISH_BUFF_ID: int = 97
const ATK6_DPS_MOD_MULT: float = 1.5
const ATK6_NEXT_STAGE: int = 2
const DIST_INV_EXP: float = -0.5
const ATK2_SHAKE_MAX: float = 10.0
const ATK2_SHAKE_TIME: float = 0.1
const ATK2_SHAKE_NUM: int = 10


func apply(hero: Variant) -> void:
	hero.is_boss_create_with_effect = false
	hero.set_disapear_when_die(false)
	var atk: Variant = hero.skills.get("AncientTreant_atk")
	if atk:
		atk.hero_hooks["createProjectile"] = Callable(self, "_create_projectile")
	var atk2: Variant = hero.skills.get("AncientTreant_atk2")
	if atk2:
		atk2.hero_hooks["takeEffectAt"] = Callable(self, "_atk2_take_effect_at")
	var atk6: Variant = hero.skills.get("AncientTreant_atk6")
	if atk6:
		atk6.hero_hooks["start"] = Callable(self, "_start")
		atk6.hero_hooks["finish"] = Callable(self, "_finish")


func _create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = BattleProjectile.new(skill)  # basefunc
	var target: Variant = projectile.skill.target
	if target == null:
		return null
	projectile.enable_track(target)
	var target_pos: Vector2 = target.position
	var targetxy_v: Vector2 = target_pos - projectile.position
	var targetz_v: float = -float(projectile.height)
	var u: float = pow(targetxy_v.x * targetxy_v.x + targetxy_v.y * targetxy_v.y + targetz_v * targetz_v, DIST_INV_EXP)
	projectile.velocity += Vector2(u * targetxy_v.x, u * targetxy_v.y) * TRACK_SPEED
	projectile.z_speed += u * targetz_v * TRACK_SPEED
	return projectile


# 表现走 BattleEvent 队列（T4；scene==null 时静默，等价 run_with_scene 守卫）。
func _atk2_take_effect_at(skill: Variant, location: Vector2, src: Variant) -> void:
	BattleSkillEffect.take_effect_at(skill, location, src)  # basefunc
	skill.caster.emit_shake(ATK2_SHAKE_MAX, ATK2_SHAKE_TIME, ATK2_SHAKE_NUM)


func _start(skill: Variant, _target: Variant) -> void:
	var caster: Variant = skill.caster
	var binfo: Variant = caster.cm.lookup(&"Buff", "", ATK6_PRE_BUFF_ID)
	caster.add_buff(binfo, caster)
	skill._start_default(null)


func _finish(skill: Variant) -> void:
	skill._finish_default()  # basefunc
	var caster: Variant = skill.caster
	if caster.config.has("dps_mod"):
		caster.config["dps_mod"] = float(caster.config["dps_mod"]) * ATK6_DPS_MOD_MULT
	var binfo: Variant = caster.cm.lookup(&"Buff", "", ATK6_FINISH_BUFF_ID)
	caster.add_buff(binfo, caster)
	caster.enter_action_stage_from_one_stage(ATK6_NEXT_STAGE)
