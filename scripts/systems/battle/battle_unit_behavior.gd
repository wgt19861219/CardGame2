class_name BattleUnitBehavior
extends RefCounted

## 单位行为方法（Logic 层）— 照源 unit.lua 行为段翻译（Phase 2.2续-B，2026-07-01）。
## 从 unit.lua 拆出（≤300 行铁律，先例 battle_skill_effect/battle_unit_combat）。
## 全静态，第一参 u 为 BattleUnit（duck-type：is_alive/state/walk_v/walk_speed_multiplier/position/
##   info/set_action/push/current_skill）。源 edpSub/edpNormalize/edpMult → Godot Vector2 运算。

# 源 idle（unit.lua:1039-1050）：IDLE 早返 → 置状态 + walk_v=0 + Idle/Move 动作（push 时 Move）。
static func idle(u: Variant) -> void:
	if not bool(u.is_alive()):
		return
	if u.state == BattleUnit.State.IDLE:
		return
	u.state = BattleUnit.State.IDLE
	u.walk_v = Vector2.ZERO
	u.set_action("Move" if bool(u.push) else "Idle", true)


# 源 walkTowards（unit.lua:1053-1073）：WALK 状态 + 方向×abs 分量 normalize × base_speed×multiplier。
static func walk_towards(u: Variant, dest: Vector2) -> void:
	if not bool(u.is_alive()):
		return
	if u.state != BattleUnit.State.WALK:
		u.state = BattleUnit.State.WALK
		u.set_action("Move", true)
	var base_speed: float = float(u.info.get("Walk Speed", 0.0))
	var dir: Vector2 = dest - u.position  # 源 edpSub(dest, position)
	if dir.x == 0.0 and dir.y == 0.0:
		u.walk_v = Vector2.ZERO
	else:
		# 源 :1066-1069 direction 各分量 ×abs(分量)，再 normalize × speed（非匀速：轴向距离越大分量越大）
		var scaled: Vector2 = Vector2(dir.x * abs(dir.x), dir.y * abs(dir.y))
		u.walk_v = scaled.normalized() * (base_speed * float(u.walk_speed_multiplier))


# 源 summon（unit.lua:1075-1083）：BIRTH 状态 + 出生动作（born_action_name 缺省 "Birth"，Phase 4 Puppet 对照）。
static func summon(u: Variant, born_action_name: String = "") -> void:
	u.state = BattleUnit.State.BIRTH
	u.walk_v = Vector2.ZERO
	var action: String = born_action_name
	if action == "":
		action = "Birth"  # 源 ed.state_to_string[emUnitState_Birth]
	u.set_action(action)


# 源 castSkill（unit.lua:1085-1094）：ATTACK 状态 + walk_v=0 + skill.start(target) + current_skill=skill。
static func cast_skill(u: Variant, skill: Variant, target: Variant) -> void:
	if not bool(u.is_alive()):
		return
	u.state = BattleUnit.State.ATTACK
	u.walk_v = Vector2.ZERO
	skill.start(target)
	u.current_skill = skill


# 源 castManualSkill（unit.lua:1096-1120）：大招（trigger 分支 / canCastWithTarget 校验 / castSkill + freeze）
static func cast_manual_skill(u: Variant) -> void:
	if not bool(u.is_alive()):
		return
	if bool(u.manual_skill.can_trigger()):
		u.manual_skill.trigger()
		return
	var res: Dictionary = u.manual_skill.can_cast_with_target(u.ai.target)
	if not bool(res.get("ok", false)):  # 源 :1104 返 bool（Lua 多值首），我 dict 适配取 ok
		return
	if u.current_skill != null:
		u.current_skill.interrupt()
	cast_skill(u, u.manual_skill, u.ai.target)
	# 源 :1111-1114 大招音效 ed.playEffect("sound/<NAME>_ULT.mp3")（Logic→actor View 桥）
	var ult_name: String = String(u.name).to_upper()
	var ult_actor: Variant = u.get("actor")
	if ult_name != "" and ult_actor != null and ult_actor.has_method("play_voice"):
		ult_actor.play_voice(ult_name, "_ULT")
	u.manually_casting = true
	u.engine.freeze()
	u.unfreeze()
	u.can_cast_tick = -1
