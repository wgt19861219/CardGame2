extends RefCounted

## Luna（月骑）英雄 hook（Logic 层）— 照源 battle/heroes/Luna.lua（49 行）。
## Luna_atk3.createProjectile：enableJump(4) + enableTrack；
##   power：basefunc ×percents[jumps]（跳跃衰减，首跳满 1.0 末跳 0.65）。
## Luna_ult.start：纯 View（eff_moon/night），Logic=basefunc。
## 注：源 :33-36 定义 skill_atk3_takeEffectOn 但 init_hero（:37-47）未 override（latent bug），照源不挂。

const LUNA_JUMPS: int = 4  # 源 :18 enableJump(4)
# 源 :22-27 跳跃衰减系数（jumps=4 首跳满 1.0，递减到 jumps=1 末跳 0.65）
const LUNA_PERCENTS: Array = [0.65, 0.75, 0.85, 1.0]


func apply(hero: Variant) -> void:
	var skillult: Variant = hero.skills.get("Luna_ult")
	if skillult:
		skillult.hero_hooks["start"] = Callable(self, "_ult_start")  # Logic=basefunc，View eff Phase 4
	var skill_atk3: Variant = hero.skills.get("Luna_atk3")
	if skill_atk3:
		skill_atk3.hero_hooks["createProjectile"] = Callable(self, "_atk3_create_projectile")
		skill_atk3.hero_hooks["power"] = Callable(self, "_atk3_power")


# 源 :2-15 Luna_ult.start：basefunc（playEffect moon/night View Phase 4）。
func _ult_start(skill: Variant, target: Variant) -> void:
	skill._start_default(target)
	# playEffect（View）Phase 4


# 源 :16-21 createProjectile：basefunc 后 enableJump(4) + enableTrack(target)。
func _atk3_create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = BattleProjectile.new(skill)  # basefunc
	projectile.enable_jump(LUNA_JUMPS)
	projectile.enable_track(skill.target)
	return projectile


# 源 :28-32 power：basefunc ×percents[jumps]（首跳 jumps=4 满，末跳 jumps=1 衰减），返 [power×percent, crit_mod]。
# 源 :29 local ret = basefunc(skill) 只取首返回值（crit_mod 丢失→nil），GDScript 保留 base[1] 修正（源 latent bug）。
func _atk3_power(skill: Variant, source: Variant, _target: Variant) -> Array:
	var base: Array = BattleSkillEffect.power(skill, source)  # basefunc
	var jumps: int = int(source.jumps)
	var idx: int = clamp(jumps - 1, 0, LUNA_PERCENTS.size() - 1)
	return [base[0] * float(LUNA_PERCENTS[idx]), base[1]]
