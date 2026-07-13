class_name HeroLion
extends RefCounted

## Lion（恶魔巫师）英雄 hook（Logic 层）— 照源 battle/heroes/Lion.lua（21 行）。
## Lion_atk2.takeEffectOn：basefunc + View 地刺特效（launch_spike 在 target 位置，Phase 4）。

const DEFAULT_POINT_ZORDER: float = 0.0  # 源 :7 Point Zorder or 0


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Lion_atk2")
	if skill:
		skill.hero_hooks["takeEffectOn"] = Callable(self, "_atk2_take_effect_on")


# 源 :2-13 skill2_takeEffecOn（basefunc + View 地刺特效）。
# 源 hook 名 takeEffecOn（源拼写，缺 t）→ 项目 hook key "takeEffectOn"（接口标准名）。
func _atk2_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var r: Array = BattleSkillEffect.take_effect_on(skill, target, src)  # basefunc [succ, dmg]
	# 源 :4-12 run_with_scene → playEffectOnScene("eff_launch_spike.cha", target.position, {direction,1}, nil, effect_z)
	# View 段 Phase 4
	var caster: Variant = skill.caster
	if caster != null and caster.actor != null and caster.actor.has_method("play_effect"):
		var effect_z: float = float(skill.info.get("Point Zorder", DEFAULT_POINT_ZORDER))
		var scale_x: float = float(caster.direction)
		# 源 scale {direction,1}：play_effect scale=float 只取 direction，height=0(源 nil)，zorder=effect_z（5 参匹配签名；P0 修复去多余 1.0）
		caster.actor.play_effect("effect/eff_launch_spike", target.position, scale_x, 0.0, int(effect_z))
	return r  # 透传 [succ, dmg]
