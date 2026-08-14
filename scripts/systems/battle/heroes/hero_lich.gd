extends RefCounted

## Lich 英雄 hook（Logic 层）— 照源 battle/heroes/Lich.lua（44 行）。
## Lich_ult.createProjectile：basefunc 建弹射物 → enableJump(4) + enableTrack(target) +
## 覆盖 findNextTaeget（自定义：targetCamp + min/max_range_sq 内取最近 source 的单位）。
## find_next_override：BattleProjectile 加英雄 hook 字段（projectile 方法覆盖机制，首个扩展点）。

const JUMPS: int = 4
const HUGE: float = INF


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Lich_ult")
	if skill:
		skill.hero_hooks["createProjectile"] = Callable(self, "_create_projectile")


func _create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = BattleProjectile.new(skill)  # basefunc
	projectile.enable_jump(JUMPS)
	projectile.enable_track(skill.target)
	projectile.find_next_override = Callable(self, "_find_next")
	return projectile


func _find_next(projectile: Variant) -> Variant:
	var min_sq: float = HUGE
	var ret: Variant = null
	var skill: Variant = projectile.skill
	var source: Variant = projectile.source
	for unit in projectile.engine.foreach_alive_unit(int(skill._target_camp())):
		if unit == source or bool(unit.buff_effects.get(BattleEffectKeys.UNTARGETABLE, false)):
			continue
		var dist_sq: float = unit.position.distance_squared_to(source.position)  # edpDistanceSQ
		if min_sq < dist_sq:
			continue
		if dist_sq > skill.min_range_sq and dist_sq < skill.max_range_sq:
			ret = unit
			min_sq = dist_sq
	return ret
