extends RefCounted

## POM 英雄 hook（Logic 层）— 照源 battle/heroes/POM.lua（25 行）。
## POM_atk2.start：传送到 400-450·camp + walk_v（distance=240·camp / current_phase.duration）。
## POM_atk2.onAttackFrame：停 walk_v + basefunc。

const POS_X_BASE: float = 400.0
const POS_X_CAMP: float = 450.0
const CHARGE_DISTANCE: float = 240.0


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("POM_atk2")
	if skill:
		skill.hero_hooks["start"] = Callable(self, "_start")
		skill.hero_hooks["onAttackFrame"] = Callable(self, "_on_attack_frame")


func _start(skill: Variant, target: Variant) -> void:
	skill._start_default(target)  # basefunc
	var caster: Variant = skill.caster
	caster.position = Vector2(POS_X_BASE - POS_X_CAMP * float(caster.camp), caster.position.y)
	var distance: float = CHARGE_DISTANCE * float(caster.camp)
	var time: float = float(skill.current_phase.get("duration", 0.0))
	var v: float = distance / time if time != 0.0 else 0.0  # 除零保护（源 nil→NaN，GDScript 避崩溃）
	caster.walk_v = Vector2(float(caster.direction) * v, 0.0)


func _on_attack_frame(skill: Variant) -> void:
	skill.caster.walk_v = Vector2.ZERO
	skill._on_attack_frame_default()  # basefunc
