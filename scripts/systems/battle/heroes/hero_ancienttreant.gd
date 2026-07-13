extends RefCounted

## AncientTreant（远古树人）英雄 hook（Logic 层）— 照源 battle/heroes/AncientTreant.lua（66 行）。
## atk createProjectile：basefunc + enableTrack + 3D 追踪 velocity 一次性（targetV 归一×1500 加到 velocity/z_speed）。
## atk2 takeEffectAt：basefunc + startCameraShakeAnimationY（纯 View，Logic 等价默认 → Phase 4 补，本轮跳过）。
## atk6 start：caster.addBuff(Buff 56) → basefunc（源 basefunc(skill) 不传 target，selectTarget 自动）。
## atk6 finish：basefunc → dps_mod×1.5 + addBuff(Buff 97) + enterActionStageFromOneStage(2)。
## isBossCreateWithEffect=false + setDisapearWhenDie(false)。

const TRACK_SPEED: float = 1500.0  # 源 :4 v=1500（3D 追踪速度增量）
const ATK6_PRE_BUFF_ID: int = 56   # 源 :26 start addBuff(56)
const ATK6_FINISH_BUFF_ID: int = 97  # 源 :35 finish addBuff(97)
const ATK6_DPS_MOD_MULT: float = 1.5  # 源 :34 dps_mod*1.5
const ATK6_NEXT_STAGE: int = 2     # 源 :39 enterActionStageFromOneStage(2)
const DIST_INV_EXP: float = -0.5   # 源 :13 ^-0.5（三维距离倒数，归一化指数）


func apply(hero: Variant) -> void:
	hero.is_boss_create_with_effect = false  # 源 :62
	hero.set_disapear_when_die(false)  # 源 :63
	var atk: Variant = hero.skills.get("AncientTreant_atk")
	if atk:
		atk.hero_hooks["createProjectile"] = Callable(self, "_create_projectile")
	var atk2: Variant = hero.skills.get("AncientTreant_atk2")
	if atk2:
		atk2.hero_hooks["takeEffectAt"] = Callable(self, "_atk2_take_effect_at")  # 源 :53-55（P1 补占位让 hook 注册完整）
	var atk6: Variant = hero.skills.get("AncientTreant_atk6")
	if atk6:
		atk6.hero_hooks["start"] = Callable(self, "_start")
		atk6.hero_hooks["finish"] = Callable(self, "_finish")


# 源 :2-23 skillatk_createProjectile（basefunc + enableTrack + 3D velocity 一次性）。
func _create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = BattleProjectile.new(skill)  # basefunc
	var target: Variant = projectile.skill.target
	if target == null:  # 源 :6-8 not target → return nil
		return null
	projectile.enable_track(target)
	var target_pos: Vector2 = target.position
	var targetxy_v: Vector2 = target_pos - projectile.position  # 源 :11 edpSub(targetpos, projectile.position)
	var targetz_v: float = -float(projectile.height)  # 源 :12
	# 源 :13 u = (xy² + z²)^-0.5（三维距离倒数，归一用）
	var u: float = pow(targetxy_v.x * targetxy_v.x + targetxy_v.y * targetxy_v.y + targetz_v * targetz_v, DIST_INV_EXP)
	projectile.velocity += Vector2(u * targetxy_v.x, u * targetxy_v.y) * TRACK_SPEED  # 源 :19-20
	projectile.z_speed += u * targetz_v * TRACK_SPEED  # 源 :21 zSpeed
	return projectile


# 源 :53-55 atk2 takeEffectAt：basefunc + startCameraShakeAnimationY(10,0.1,10)（纯 View 相机震动，Phase 4 补）。
func _atk2_take_effect_at(skill: Variant, location: Vector2, src: Variant) -> void:
	BattleSkillEffect.take_effect_at(skill, location, src)  # basefunc
	# 源 startCameraShakeAnimationY(10, 0.1, 10)（View 相机震动）Phase 4


# 源 :24-30 skill6_start（addBuff Buff56 → basefunc；源 basefunc(skill) 不传 target，selectTarget 自动）。
func _start(skill: Variant, _target: Variant) -> void:
	var caster: Variant = skill.caster
	var binfo: Variant = caster.cm.lookup(&"Buff", "", ATK6_PRE_BUFF_ID)
	caster.add_buff(binfo, caster)
	skill._start_default(null)  # 源 :29 basefunc(skill)（不传 target → null，selectTarget 自动）


# 源 :31-41 skill6_finish（basefunc → dps_mod×1.5 + addBuff 97 + enterActionStageFromOneStage 2）。
func _finish(skill: Variant) -> void:
	skill._finish_default()  # basefunc
	var caster: Variant = skill.caster
	if caster.config.has("dps_mod"):  # 源 :34 dps_mod and dps_mod*1.5（存在则 ×1.5）
		caster.config["dps_mod"] = float(caster.config["dps_mod"]) * ATK6_DPS_MOD_MULT
	var binfo: Variant = caster.cm.lookup(&"Buff", "", ATK6_FINISH_BUFF_ID)
	caster.add_buff(binfo, caster)
	caster.enter_action_stage_from_one_stage(ATK6_NEXT_STAGE)  # 源 :39
