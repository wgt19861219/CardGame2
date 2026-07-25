class_name BattleSkillTarget
extends RefCounted

## 技能目标选择与施法判定（Logic 层 mixin）— 从 BattleSkill 拆出控 ≤250 行。
## static 方法第一参 skill，照 battle_engine_result mixin 范式。
## 操作 skill 实例状态（can_cast/target/target_selectors），skill 参数 duck-type。


static func build_target_selectors(skill: Variant) -> void:
	skill.target_selectors = {
		"random": func(_u: Variant) -> float: return skill.caster.engine.rng.randf(),
		"weakest": func(u: Variant) -> float: return -float(u.hp) / float(u.attribs.HP),
		"strongest": func(u: Variant) -> float: return float(u.hp),
		"nearest": func(u: Variant) -> float: return -u.position.distance_squared_to(skill.caster.position),
		"farthest": func(u: Variant) -> float: return u.position.distance_squared_to(skill.caster.position),
		"maxmp": func(u: Variant) -> float: return fmod(float(u.mp), BattleSkill.MP_SELECTOR_MOD),
		"minmp": func(u: Variant) -> float: return -fmod(float(u.mp), BattleSkill.MP_SELECTOR_MOD),
		"maxint": func(u: Variant) -> float: return float(u.attribs.INT),
		"minhp": func(u: Variant) -> float: return -float(u.hp),
	}


static func can_cast_with_target(skill: Variant, p_target: Variant) -> Dictionary:
	if skill.can_cast_tick == int(skill.caster.engine.ticks):
		return {"ok": skill.can_cast, "reason": "same tick"}
	skill.can_cast_tick = int(skill.caster.engine.ticks)
	skill.can_cast = false
	var dt: String = str(skill.info.get("Damage Type", ""))
	if float(skill.info.get("Cost MP", 0.0)) > float(skill.caster.mp):
		return {"ok": false, "reason": "mp"}
	if skill.cd_remaining > 0.0:
		return {"ok": false, "reason": "cd"}
	if bool(skill.caster.buff_effects.get("stun", false)):
		return {"ok": false, "reason": "stun"}
	if dt == "AD" and bool(skill.caster.buff_effects.get("disarm", false)):
		return {"ok": false, "reason": "disarm"}
	if dt != "AD" and bool(skill.caster.buff_effects.get("silence", false)):
		return {"ok": false, "reason": "silence"}
	if skill._target_selector().is_valid():
		p_target = skill._select_target(p_target)
	if p_target == null:
		return {"ok": false, "reason": "no target"}
	if bool(p_target.buff_effects.get("untargetable", false)):
		return {"ok": false, "reason": "untargetable"}
	if float(p_target.camp) * float(skill._target_camp()) < 0.0:
		return {"ok": false, "reason": "target camp"}
	var dsq: float = p_target.position.distance_squared_to(skill.caster.position)
	if dsq > skill.max_range_sq:
		return {"ok": false, "reason": "too far"}
	if dsq < skill.min_range_sq:
		return {"ok": false, "reason": "too near"}
	if not bool(skill.info.get("Outside Screen", false)) and bool(skill.caster.is_out_of_stage()):
		return {"ok": false, "reason": "outside stage"}
	skill.can_cast = true
	return {"ok": true, "reason": ""}


static func select_target_default(skill: Variant, default_t: Variant) -> Variant:
	var ttype: String = str(skill.info.get("Target Type", ""))
	var selector: Callable = skill._target_selector()
	if ttype == "target":
		if default_t != null:
			skill.target = default_t
		else:
			var res: Array = skill.caster.ai.search_target()
			if res.size() > 1 and float(res[1]) <= skill.max_range_sq:
				skill.target = res[0]
			else:
				skill.target = null
	elif ttype == "self":
		skill.target = skill.caster
	elif selector.is_valid():
		var max_v: float = -BattleSkill.HUGE
		var chosen: Variant = null
		var cpos: Vector2 = skill.caster.position
		var enchanted: bool = bool(skill.caster.buff_effects.get("enchanted", false))
		for unit in skill.caster.engine.foreach_alive_unit(skill._target_camp()):
			if bool(unit.buff_effects.get("untargetable", false)):
				continue
			if enchanted and unit == skill.caster:
				continue
			var dsq: float = unit.position.distance_squared_to(cpos)
			if dsq >= skill.min_range_sq and dsq <= skill.max_range_sq:
				var v: float = float(selector.call(unit))
				if max_v < v:
					max_v = v
					chosen = unit
		skill.target = chosen
	return skill.target
