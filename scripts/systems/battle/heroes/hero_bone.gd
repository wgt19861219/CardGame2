extends RefCounted

## Bone 英雄 hook（Logic 层）— 照源 battle/heroes/Bone.lua（70 行）。
## Bone_awake.selectTarget：自定义选目标——**只选召唤物**（is_summoned）+ ed.rand 随机 selector。
## Bone_awake.onAttackFrame：counter==1 选目标 + die（吞噬）/ else BuffCreate+addBuff。
## selectTarget 新 hook 点（_select_target 加分发）。onAttackFrame 完全重写（不调 _default）。

const HUGE: float = INF


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Bone_awake")
	if skill:
		skill.hero_hooks["selectTarget"] = Callable(self, "_select_target")
		skill.hero_hooks["onAttackFrame"] = Callable(self, "_on_attack_frame")


func _select_target(skill: Variant, _default_t: Variant) -> Variant:
	var max_v: float = -HUGE
	var chosen: Variant = null
	var caster: Variant = skill.caster
	var cpos: Vector2 = caster.position
	var enchanted: bool = bool(caster.buff_effects.get(BattleEffectKeys.ENCHANTED, false))
	for unit in caster.engine.foreach_alive_unit(int(skill._target_camp())):
		if not bool(unit.config.get("is_summoned", false)):
			continue
		if bool(unit.buff_effects.get(BattleEffectKeys.UNTARGETABLE, false)):
			continue
		if enchanted and unit == caster:
			continue
		var dist_sq: float = unit.position.distance_squared_to(cpos)
		if dist_sq >= skill.min_range_sq and dist_sq <= skill.max_range_sq:
			var v: float = caster.engine.rng.randf()
			if max_v < v:
				max_v = v
				chosen = unit
	skill.target = chosen
	return chosen


func _on_attack_frame(skill: Variant) -> void:
	var caster: Variant = skill.caster
	skill.attack_counter = int(skill.attack_counter) + 1
	if int(skill.attack_counter) == 1:
		var target: Variant = skill._select_target(null)
		if target != null:
			_show_devour_popup(skill.caster, target)
			target.die(skill.caster)
	else:
		var binfo: Variant = skill.info.get("buff_info", {})
		caster.add_buff(binfo, caster)


func _show_devour_popup(caster: Variant, target: Variant) -> void:
	var color: String = "blue" if int(caster.camp) == BattleEngine.CAMP_PLAYER else "red"
	target.emit_popup("devour", color, false, "text")
