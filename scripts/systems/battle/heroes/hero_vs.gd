extends RefCounted

## VS（复仇之魂）英雄 hook（Logic 层）— 照源 battle/heroes/VS.lua（46 行）。
## VS_ult.takeEffectOn：basefunc 后概率互换 caster/target 位置 + VS_atk2 追踪弹
##   （checkVSUlt rand 概率 + stable 免疫；miss 分支纯 popup View 跳过）。

const RAND_INSTANT: float = 0.3   # 源 :3 rand<0.3 立即触发
const DICE_BASE: float = 20.0     # 源 :6 dice=20
const LV_THRESHOLD: float = 30.0  # 源 :7 skillLevel<30 归一
const LV_LOW_BASE: float = 10.0   # 源 :8 10+lv/30*20
const LV_LOW_DIVISOR: float = 30.0
const LV_LOW_RANGE: float = 20.0


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("VS_ult")
	if skill:
		skill.hero_hooks["takeEffectOn"] = Callable(self, "_take_effect_on")


# 源 :2-13 checkVSUlt：rand<0.3 直过；else skillLevel<30 归一化（10+lv/30*20），dice*=rand，targetLevel<=sl+dice。
func _check_vs_ult(skill_level: float, target_level: float, rng: Variant) -> bool:
	if rng.randf() < RAND_INSTANT:
		return true
	var sl: float = skill_level
	if sl < LV_THRESHOLD:
		sl = LV_LOW_BASE + sl / LV_LOW_DIVISOR * LV_LOW_RANGE
	var dice: float = DICE_BASE * rng.randf()
	return target_level <= sl + dice


# 源 :14-40 takeEffectOn：basefunc 后 checkVSUlt 且非 stable → 互换位置 + VS_atk2 追踪弹；else miss（View）。
func _take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var r: Array = BattleSkillEffect.take_effect_on(skill, target, src)  # basefunc [succ, dmg]
	var caster: Variant = skill.caster
	var rng: Variant = caster.engine.rng
	if _check_vs_ult(float(skill.level), float(target.level), rng) and not bool(target.buff_effects.get("stable", false)):
		var target_pos: Vector2 = target.position
		var caster_pos: Vector2 = caster.position
		caster.position = target_pos
		target.position = caster_pos
		var skill2: Variant = caster.skills.get("VS_atk2")
		if skill2:
			skill2.target = target
			var projectile: Variant = skill2._create_projectile()
			projectile.enable_track(target)
			caster.engine.add_projectile(projectile)
	else:
		_show_miss_popup(target)  # 源 VS.lua:35-37 checkVSUlt 未触发或 stable → miss 飘字
	return r  # 透传


# 源 VS.lua:35-37 miss 飘字（target actor，camp enemy→red/else→blue）。
func _show_miss_popup(target: Variant) -> void:
	var actor: Variant = target.get("actor")
	if actor == null or not actor.has_method("spawn_popup"):
		return
	var color: String = "red" if int(target.camp) == BattleEngine.CAMP_ENEMY else "blue"
	actor.spawn_popup("miss", color, false, "text")
