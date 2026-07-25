extends RefCounted

## Tiny（小小）英雄 hook（Logic 层）— 照源 battle/heroes/Tiny.lua（31 行）。
## Tiny_ult.onAttackFrame：basefunc 后记录 thrownUnit（=target）。
## Tiny_ult.update：basefunc 后 thrownUnit 击退结束（knockup_time<=0）→ wraptable 改 AOE AP 伤害 → takeEffectAt。


func apply(hero: Variant) -> void:
	var skillult: Variant = hero.skills.get("Tiny_ult")
	if skillult:
		skillult.hero_hooks["onAttackFrame"] = Callable(self, "_on_attack_frame")
		skillult.hero_hooks["update"] = Callable(self, "_update")


func _on_attack_frame(skill: Variant) -> void:
	skill._on_attack_frame_default()
	skill.custom_data["thrown_unit"] = skill.target


func _update(skill: Variant, dt_action: float, dt_cd: float) -> void:
	skill._update_default(dt_action, dt_cd)
	var thrown: Variant = skill.custom_data.get("thrown_unit", null)
	if thrown != null and float(thrown.knockup_time) <= 0.0:
		skill.custom_data.erase("thrown_unit")
		var info: Dictionary = skill.info
		var wrapped: Dictionary = info.duplicate()
		wrapped["Damage Type"] = "AP"
		wrapped["Basic Num"] = info.get("Script Arg1", 0)
		wrapped["Plus Ratio"] = info.get("Script Arg2", 0)
		wrapped["AOE Origin"] = "target"
		wrapped["Knock Up"] = 0
		wrapped["Knock Back"] = 0
		wrapped["Buff ID"] = 0
		skill.info = wrapped
		skill.take_effect_at(thrown.position)
		skill.info = info  # 还原
