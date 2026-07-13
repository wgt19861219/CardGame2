extends RefCounted

## Panda 英雄 hook（Logic 层）— 照源 battle/heroes/Panda.lua（76 行）。
## Panda_ult.onAttackFrame：按 attack_counter 分支 wraptable 覆盖 info（Track Type/Move Forward/Knock）
## → basefunc → 恢复原 info。counter==5 额外移 target（无 stable buff）到 caster 前方。
## wraptable(originfo,{...}) = originfo 拷贝 + 覆盖字段（GDScript duplicate + 设字段）。
## View 特效（eff_point_Panda_ult.cha run_with_scene）分层 Phase 4。

# 源 :2-13 moveforwardtable（各帧 Move Forward 值，counter 0-9）
const MOVE_FORWARD_TABLE: Dictionary = {
	0: 0, 1: 15, 2: 10, 3: 15, 4: 5, 5: 15, 6: 5, 7: 5, 8: 5, 9: 5
}
# 源各分支 Knock Up/Back（counter 1-4 / ==5 / >5；wraptable 字段覆盖用）
const KNOCK_LOW: Dictionary = {"Knock Up": 0.1, "Knock Back": 10}   # 源 :28-29 counter<5
const KNOCK_ULT: Dictionary = {"Knock Up": 0.6, "Knock Back": 20}   # 源 :37-38 counter==5
const KNOCK_HIGH: Dictionary = {"Knock Up": 0.5, "Knock Back": 5}   # 源 :63-64 counter>5
const ULT_FRAME: int = 5  # 源 :25/34/60 大招终极帧边界（<5 低击退 / ==5 终极 / >5 高击退）
const ULT_ORIGIN_X: float = 50.0      # 源 :41 counter==5 target 移动基准 X（caster 前 50）
const ULT_ORIGIN_EXTRA: float = 20.0  # 源 :46 counter==5 target 附加 X（再前 20）


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Panda_ult")
	if skill:
		skill.hero_hooks["onAttackFrame"] = Callable(self, "_on_attack_frame")


# 源 :14-70 skillult_onAttackFrame（counter 分支 wraptable + basefunc + 恢复 info）。
func _on_attack_frame(skill: Variant) -> void:
	var orig_info: Dictionary = skill.info
	var counter: int = int(skill.attack_counter)
	var move_forward: int = int(MOVE_FORWARD_TABLE.get(counter, 0))
	if counter == 0:
		# 源 :18-24 改 projectile + Buff ID=0（那帧纯弹射无 buff）
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
		# 源 :40-49 移 target 到 caster 前方（无 stable buff 才移）
		var origin := Vector2(
			skill.caster.position.x + ULT_ORIGIN_X * float(skill.caster.direction),
			skill.caster.position.y)
		if skill.target != null and not bool(skill.target.buff_effects.get("stable", false)):
			skill.target.position = Vector2(
				origin.x + ULT_ORIGIN_EXTRA * float(skill.caster.direction),
				origin.y)
		# 源 :50-56 View 特效（run_with_scene）→ Phase 4
		skill._on_attack_frame_default()
		skill.info = orig_info
	else:  # 源 :60 counter>5
		skill.info = orig_info.duplicate()
		skill.info["Move Forward"] = move_forward
		skill.info["Knock Up"] = KNOCK_HIGH["Knock Up"]
		skill.info["Knock Back"] = KNOCK_HIGH["Knock Back"]
		skill._on_attack_frame_default()
		skill.info = orig_info
