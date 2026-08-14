extends RefCounted

## Panda 英雄 hook（Logic 层）— 照源 battle/heroes/Panda.lua（76 行）。
## Panda_ult.onAttackFrame：按 attack_counter 分支 wraptable 覆盖 info（Track Type/Move Forward/Knock）
## → basefunc → 恢复原 info。counter==5 额外移 target（无 stable buff）到 caster 前方。
## wraptable(originfo,{...}) = originfo 拷贝 + 覆盖字段（GDScript duplicate + 设字段）。
## View 特效（eff_point_Panda_ult.cha run_with_scene）分层 Phase 4。

const MOVE_FORWARD_TABLE: Dictionary = {
	0: 0, 1: 15, 2: 10, 3: 15, 4: 5, 5: 15, 6: 5, 7: 5, 8: 5, 9: 5
}
const KNOCK_LOW: Dictionary = {"Knock Up": 0.1, "Knock Back": 10}
const KNOCK_ULT: Dictionary = {"Knock Up": 0.6, "Knock Back": 20}
const KNOCK_HIGH: Dictionary = {"Knock Up": 0.5, "Knock Back": 5}
const ULT_FRAME: int = 5
const ULT_ORIGIN_X: float = 50.0
const ULT_ORIGIN_EXTRA: float = 20.0


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Panda_ult")
	if skill:
		skill.hero_hooks["onAttackFrame"] = Callable(self, "_on_attack_frame")


func _on_attack_frame(skill: Variant) -> void:
	var orig_info: Dictionary = skill.info
	var counter: int = int(skill.attack_counter)
	var move_forward: int = int(MOVE_FORWARD_TABLE.get(counter, 0))
	if counter == 0:
		skill.info = orig_info.duplicate()
		skill.info["Track Type"] = "projectile"
		skill.info["Buff ID"] = 0
		skill._on_attack_frame_default()
		skill.info = orig_info
	elif counter < ULT_FRAME:
		skill.info = orig_info.duplicate()
		skill.info["Move Forward"] = move_forward
		skill.info["Knock Up"] = KNOCK_LOW["Knock Up"]
		skill.info["Knock Back"] = KNOCK_LOW["Knock Back"]
		skill._on_attack_frame_default()
		skill.info = orig_info
	elif counter == ULT_FRAME:
		skill.info = orig_info.duplicate()
		skill.info["Move Forward"] = move_forward
		skill.info["Knock Up"] = KNOCK_ULT["Knock Up"]
		skill.info["Knock Back"] = KNOCK_ULT["Knock Back"]
		var origin := Vector2(
			skill.caster.position.x + ULT_ORIGIN_X * float(skill.caster.direction),
			skill.caster.position.y)
		if skill.target != null and not bool(skill.target.buff_effects.get(BattleEffectKeys.STABLE, false)):
			skill.target.position = Vector2(
				origin.x + ULT_ORIGIN_EXTRA * float(skill.caster.direction),
				origin.y)
		skill._on_attack_frame_default()
		skill.info = orig_info
	else:
		skill.info = orig_info.duplicate()
		skill.info["Move Forward"] = move_forward
		skill.info["Knock Up"] = KNOCK_HIGH["Knock Up"]
		skill.info["Knock Back"] = KNOCK_HIGH["Knock Back"]
		skill._on_attack_frame_default()
		skill.info = orig_info
