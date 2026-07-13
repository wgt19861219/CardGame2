extends RefCounted

## Lich 英雄 hook（Logic 层）— 照源 battle/heroes/Lich.lua（44 行）。
## Lich_ult.createProjectile：basefunc 建弹射物 → enableJump(4) + enableTrack(target) +
## 覆盖 findNextTaeget（自定义：targetCamp + min/max_range_sq 内取最近 source 的单位）。
## 源 skillult_start（View 特效 night/moon）定义但 init 未注册（源 :39-43 只 createProjectile），照源不翻。
## find_next_override：BattleProjectile 加英雄 hook 字段（projectile 方法覆盖机制，首个扩展点）。

const JUMPS: int = 4  # 源 :18 enableJump(4)
const HUGE: float = INF  # 源 math.huge（寻目标距离初始上限，对照 battle_skill.gd HUGE 惯例）


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Lich_ult")
	if skill:
		skill.hero_hooks["createProjectile"] = Callable(self, "_create_projectile")


# 源 :16-38 skillult_createProjectile（enableJump + enableTrack + 覆盖 findNextTaeget）。
func _create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = BattleProjectile.new(skill)  # basefunc
	projectile.enable_jump(JUMPS)
	projectile.enable_track(skill.target)
	projectile.find_next_override = Callable(self, "_find_next")
	return projectile


# 源 :20-36 projectile:findNextTaeget（targetCamp + range 内取最近 source 的单位）。
func _find_next(projectile: Variant) -> Variant:
	var min_sq: float = HUGE
	var ret: Variant = null
	var skill: Variant = projectile.skill
	var source: Variant = projectile.source
	for unit in projectile.engine.foreach_alive_unit(int(skill._target_camp())):
		if unit == source or bool(unit.buff_effects.get("untargetable", false)):
			continue
		var dist_sq: float = unit.position.distance_squared_to(source.position)  # edpDistanceSQ
		if min_sq < dist_sq:  # 源 if min < distanceSQ then（已记录更近 → skip）
			continue
		if dist_sq > skill.min_range_sq and dist_sq < skill.max_range_sq:
			ret = unit
			min_sq = dist_sq
	return ret
