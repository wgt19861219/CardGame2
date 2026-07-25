extends RefCounted

## Footman 英雄 hook（Logic 层）— 照源 battle/heroes/Footman.lua（30 行）。
## Footman_atk2.createBuff：basefunc 建 buff → 设 buff.onRemoved hook。
## buff onRemoved（移除时爆发）：wraptable skill.info（AOE halfcircle）+ global_cd=3 + takeEffectAt(owner) + 恢复 + basefunc。
## createBuff/buff onRemoved 是新 hook 点（battle_skill create_buff 分发 + BattleBuff on_removed 分发）。

const GLOBAL_CD_ON_REMOVE: float = 3.0
const AOE_SHAPE_ARG: float = 150.0


func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("Footman_atk2")
	if skill:
		skill.hero_hooks["createBuff"] = Callable(self, "_create_buff")


func _create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)  # basefunc = BuffCreate
	buff.hero_hooks["onRemoved"] = Callable(self, "_buff_on_removed")
	return buff


func _buff_on_removed(buff: Variant) -> void:
	var skill: Variant = buff.caster.skills.get("Footman_atk2")
	var orig_info: Dictionary = skill.info
	skill.info = orig_info.duplicate()
	skill.info["Affected Camp"] = -1
	skill.info["AOE Origin"] = "target"
	skill.info["AOE Shape"] = "halfcircle"
	skill.info["Shape Arg1"] = AOE_SHAPE_ARG
	skill.info["Damage Type"] = "AP"
	skill.info["Buff ID"] = 0
	skill.info["Point Effect"] = "eff_point_DR_atk3.cha"
	skill.info["Impact Effect"] = "eff_impact_LOA_atk2.cha"
	buff.caster.global_cd = GLOBAL_CD_ON_REMOVE
	skill.take_effect_at(buff.owner.position)
	skill.info = orig_info
	buff._on_removed_default()  # basefunc(buff)
