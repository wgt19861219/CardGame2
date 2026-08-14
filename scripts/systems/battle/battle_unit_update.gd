class_name BattleUnitUpdate
extends RefCounted

## 单位 tick 主驱动（Logic 层）— 照源 unit.lua:878 update（142 行）/1022 onActionFinished 翻译（Phase 2.2续-C，2026-07-01）。
## engine.tick → entity.update(tick_interval) → 本静态。MSPD speeder + action 推进 + 移动 + direction 翻转 +
##   knockup 递减 + skill cd/global_cd + AI 调度 + 碰撞推移 + buff update + regen + hp_low。
## 全静态，u 为 BattleUnit（duck-type）。ActionStage 系列（Boss 多阶段，源 :545-641 Period+Puppet）本轮桩；
##   action_end（源 :951 upvalue 恒 nil）跳过——onPhaseFinished 经 onActionFinished ATTACK 分支触发。

const SPEEDER_DENOM: float = 100.0
const STAGE_BOUNDARY_MARGIN: float = 50.0
const COLLIDE_PUSH: float = 30.0
const HP_LOW_RATIO: float = 0.2


static func update(u: Variant, dt: float) -> void:
	var attribs: Dictionary = u.attribs
	var mspd: float = float(attribs.get("MSPD", 0.0))
	if bool(u.manually_casting) or (u.current_skill != null and bool(u.current_skill.info.get("No Speeder", false))):
		mspd = 0.0
	var speeder: float = (mspd + SPEEDER_DENOM) / SPEEDER_DENOM if mspd >= 0.0 else SPEEDER_DENOM / (SPEEDER_DENOM - mspd)
	u.speeder = speeder
	var dt_action: float = dt * speeder
	u.dt_action = dt_action
	if u.action_name != "" and not u.action_loop:
		var elapsed: float = float(u.action_elapsed) + dt_action
		var duration: float = float(u.action_duration)
		if duration > 0.0 and elapsed > duration:
			elapsed = elapsed - duration
			u.on_action_finished()
		u.action_elapsed = elapsed
	if not bool(u.is_alive()):
		return
	var movable: bool = not bool(u.buff_effects.get(BattleEffectKeys.IMMOBILIZE, false))
	var pos: Vector2 = u.position
	u.previous_position = pos
	var v1: Vector2 = u.walk_v if movable else Vector2.ZERO
	var v2: Vector2 = u.knockup_v
	var vel: Vector2 = Vector2(v1.x + v2.x, v1.y + v2.y)
	u.velocity = vel
	if bool(u.buff_effects.get(BattleEffectKeys.FIX, false)):
		u.direction = 1 if int(u.camp) == BattleEngine.CAMP_PLAYER else -1
	else:
		var dir_sign: float = 0.0
		if movable and v1.x != 0.0:
			dir_sign = v1.x
		elif u.current_skill != null and u.current_skill.target != null:
			dir_sign = float(u.current_skill.target.position.x) - pos.x
		if 0.0 > dir_sign * float(u.direction):
			u.direction = int(u.direction) * -1
	if float(u.knockup_time) > 0.0:
		u.knockup_time = float(u.knockup_time) - dt
		if float(u.knockup_time) <= 0.0:
			u.knockup_v = Vector2.ZERO
	var stage_rect: Dictionary = u.engine.stage_rect
	var max_x: float = float(stage_rect["maxX"])
	var min_x: float = float(stage_rect["minX"])
	if pos.x > max_x - STAGE_BOUNDARY_MARGIN and vel.x > 0.0:
		vel.x = 0.0
	if pos.x < min_x + STAGE_BOUNDARY_MARGIN and vel.x < 0.0:
		vel.x = 0.0
	u.position = Vector2(pos.x + vel.x * dt_action, pos.y + vel.y * dt_action)
	var hast: float = float(attribs.get("HAST", 0.0))
	var dt_cd: float = dt * ((hast + SPEEDER_DENOM) / SPEEDER_DENOM if hast > 0.0 else SPEEDER_DENOM / (SPEEDER_DENOM - hast))
	u.global_cd = float(u.global_cd) - dt_cd
	for skill in u.skill_list:
		skill.update(dt_action, dt_cd)
	var buff_effects: Dictionary = u.buff_effects
	var enable_ai: bool = u.state == BattleUnit.State.IDLE or u.state == BattleUnit.State.WALK
	var sc_hooks: Variant = u.get("hero_hooks")
	if sc_hooks is Dictionary and (sc_hooks as Dictionary).has("specialCheckEnableAi") and bool((sc_hooks as Dictionary)["specialCheckEnableAi"].call(u)):
		enable_ai = true
	enable_ai = enable_ai and not bool(buff_effects.get(BattleEffectKeys.DISABLE_AI, false))
	enable_ai = enable_ai and int(u.engine.freeze_level) == 0
	if enable_ai and u.ai != null:
		u.ai.update(dt)
	var is_walking: bool = u.state == BattleUnit.State.WALK
	var is_idle: bool = u.state == BattleUnit.State.IDLE
	var is_building: bool = bool(buff_effects.get(BattleEffectKeys.BUILDING, false))
	if movable and (is_walking or is_idle):
		var push_velocity: float = 0.0
		for unit in u.engine.foreach_alive_unit(int(u.camp)):
			if u != unit and _collides(u, unit):
				var dy: float = u.position.y - float(unit.position.y)
				if not is_building:
					push_velocity = push_velocity + (COLLIDE_PUSH if dy > 0.0 else -COLLIDE_PUSH)
		if u.position.y > float(stage_rect["maxY"]) and push_velocity > 0.0:
			push_velocity = 0.0
		if u.position.y < float(stage_rect["minY"]) and push_velocity < 0.0:
			push_velocity = 0.0
		if push_velocity != 0.0:
			u.push = true
			u.position = Vector2(u.position.x, u.position.y + push_velocity * dt)
			if is_idle:
				u.set_action("Move", true)
		else:
			u.push = false
			if is_idle:
				u.set_action("Idle", true)
	for buff in u.buff_list:
		buff.update(dt)
	var mp_regen: float = float(attribs.get("MPR", 0.0))
	u.set_mp(int(float(u.mp) + mp_regen * dt * float(u.engine.mp_bonus)))
	if not bool(buff_effects.get(BattleEffectKeys.NO_HPR, false)):
		var hp_regen: float = float(attribs.get("HPR", 0.0))
		if hp_regen < 0.0 or not bool(buff_effects.get(BattleEffectKeys.UNHEAL, false)):
			u.set_hp(int(float(u.hp) + hp_regen * dt))
	if int(u.hp) == 0 and bool(u.is_alive()):
		u.hp = 1
	u.hp_low = float(u.hp) / float(attribs.get("HP", 1.0)) < HP_LOW_RATIO
	if u.manual_skill != null and u.ai != null:
		u.can_cast_manual = bool(u.manual_skill.can_cast_with_target(u.ai.target).get("ok", false))


static func on_action_finished(u: Variant) -> void:
	if u.state == BattleUnit.State.DEAD:
		pass
	elif u.state == BattleUnit.State.DYING:
		u.state = BattleUnit.State.DEAD
		u.set_action("", false, false)
		if not bool(u.config.get("is_summoned", false)):
			u.hasCorpse = true
	elif u.state == BattleUnit.State.ATTACK:
		u.current_skill._on_phase_finished()
	else:
		u.idle()


# collideWith 本地实现（源调 ed.Entity.collideWith；避免 Variant→BattleEntity 形参类型摩擦）。
static func _collides(a: Variant, b: Variant) -> bool:
	var rsum: float = float(a.radius) + float(b.radius)
	return a.position.distance_squared_to(b.position) < rsum * rsum
