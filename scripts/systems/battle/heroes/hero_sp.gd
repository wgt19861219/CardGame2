extends RefCounted

## SP（暗影牧师）英雄 hook（Logic 层）— 照源 battle/heroes/SP.lua（34 行）。
## SP_atk3.createBuff：创建 buff 后覆写 onDamaged——保 1 血护盾
##   （damage<=hp-1 全承；超出部分由 shield 吸收，shield 竭则 removeBuff）。

func apply(hero: Variant) -> void:
	var skill: Variant = hero.skills.get("SP_atk3")
	if skill:
		skill.hero_hooks["createBuff"] = Callable(self, "_create_buff")


func _create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)
	buff.hero_hooks["onDamaged"] = Callable(self, "_on_damaged")
	return buff


func _on_damaged(buff: Variant, damage: float, _damage_type: String) -> float:
	var max_dmg: float = float(buff.owner.hp) - 1.0
	if damage <= max_dmg:
		return damage
	var absorption: float = damage - max_dmg
	if absorption < float(buff.shield):
		buff.shield = float(buff.shield) - absorption
		_show_funeral_popup(buff.owner)
	else:
		absorption = float(buff.shield)
		buff.shield = 0.0
		buff.owner.remove_buff(buff)
	return damage - absorption


func _show_funeral_popup(owner_unit: Variant) -> void:
	var actor: Variant = owner_unit.get("actor")
	if actor == null or not actor.has_method("spawn_popup"):
		return
	var color: String = "blue" if int(owner_unit.camp) == BattleEngine.CAMP_PLAYER else "red"
	actor.spawn_popup("funeral", color, false, "text")
