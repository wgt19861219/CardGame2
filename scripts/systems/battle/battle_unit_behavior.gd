class_name BattleUnitBehavior
extends RefCounted

## 单位行为方法（Logic 层）— 照源 unit.lua 行为段翻译（Phase 2.2续-B，2026-07-01）。
## 从 unit.lua 拆出（≤300 行铁律，先例 battle_skill_effect/battle_unit_combat）。
## 全静态，第一参 u 为 BattleUnit（duck-type：is_alive/state/walk_v/walk_speed_multiplier/position/
##   info/set_action/push/current_skill）。源 edpSub/edpNormalize/edpMult → Godot Vector2 运算。

static func idle(u: Variant) -> void:
	if not bool(u.is_alive()):
		return
	if u.state == BattleUnit.State.IDLE:
		return
	u.state = BattleUnit.State.IDLE
	u.walk_v = Vector2.ZERO
	u.set_action("Move" if bool(u.push) else "Idle", true)


static func walk_towards(u: Variant, dest: Vector2) -> void:
	if not bool(u.is_alive()):
		return
	if u.state != BattleUnit.State.WALK:
		u.state = BattleUnit.State.WALK
		u.set_action("Move", true)
	var base_speed: float = float(u.info.get("Walk Speed", 0.0))
	var dir: Vector2 = dest - u.position
	if dir.x == 0.0 and dir.y == 0.0:
		u.walk_v = Vector2.ZERO
	else:
		var scaled: Vector2 = Vector2(dir.x * abs(dir.x), dir.y * abs(dir.y))
		u.walk_v = scaled.normalized() * (base_speed * float(u.walk_speed_multiplier))


static func summon(u: Variant, born_action_name: String = "") -> void:
	u.state = BattleUnit.State.BIRTH
	u.walk_v = Vector2.ZERO
	var action: String = born_action_name
	if action == "":
		action = "Birth"
	u.set_action(action)


static func cast_skill(u: Variant, skill: Variant, target: Variant) -> void:
	if not bool(u.is_alive()):
		return
	u.state = BattleUnit.State.ATTACK
	u.walk_v = Vector2.ZERO
	skill.start(target)
	u.current_skill = skill


static func cast_manual_skill(u: Variant) -> void:
	if not bool(u.is_alive()):
		return
	if bool(u.manual_skill.can_trigger()):
		u.manual_skill.trigger()
		return
	var res: Dictionary = u.manual_skill.can_cast_with_target(u.ai.target)
	if not bool(res.get("ok", false)):
		return
	if u.current_skill != null:
		u.current_skill.interrupt()
	cast_skill(u, u.manual_skill, u.ai.target)
	var ult_name: String = String(u.name).to_upper()
	if ult_name != "":
		u.emit_voice(ult_name, "_ULT")
	u.manually_casting = true
	u.engine.freeze()
	u.unfreeze()
	u.can_cast_tick = -1
