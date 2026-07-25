extends RefCounted

## Phoenix（凤凰）英雄 hook（Logic 层）— 照源 Phoenix.lua（210 行）翻译。
## 蛋形态：单位 die（3 次蛋 1→hp4/2→hp3/3→hp2 + removeAllBuffs + 加 Buff129/126/135 + Birth + castSkill pasv，第4次真死）+
##   getLostHPAfterImmunity（有 Buff129 返1，蛋形态伤害最多扣1）+ atk2（createBuff wraptable Phoenix_atk AP 化 + onRemoved 还原 AD + atk2Buff 标记）+
##   ult（onAttackFrame counter1 加 Buff128 HPR=-HP*0.15 + hp==1 护盾抵消 / getDamage coefficient0.25 / finish 移除 Buff128）+ atk3（onAttackFrame Buff125 + canCastWithTarget atk2Buff 互斥）。

const EGG_HP_BY_COUNT: Array = [4, 3, 2]
const EGG_MAX_COUNT: int = 3
const BUFF_EGG_ID: int = 129
const BUFF_REVIVE_ATK3_ID: int = 126
const BUFF_EGG_EXTRA_ID: int = 135
const BUFF_ULT_HPR_ID: int = 128
const BUFF_SHIELD_ID: int = 31
const BUFF_ATK3_ID: int = 125
const ULT_HPR_RATIO: float = 0.15
const SHIELD_ABSORB_RATIO: float = 0.8
const ULT_COEFFICIENT: float = 0.25
const HP_MOD_DEFAULT: float = 1.0


func _die(unit: Variant, killer: Variant) -> void:
	var count: int = int(unit.custom_data.get("phoenixCount", 0))
	if not bool(unit.custom_data.get("isDandan", false)) and count != EGG_MAX_COUNT:
		unit.custom_data["isDandan"] = true
		var new_count: int = count + 1
		unit.custom_data["phoenixCount"] = new_count
		unit.remove_all_buffs()
		unit.can_cast_manual = false
		unit.walk_v = Vector2.ZERO
		unit.hp = int(EGG_HP_BY_COUNT[new_count - 1])
		unit.mp = 0
		var binfo129: Variant = unit.cm.lookup(&"Buff", "", BUFF_EGG_ID)
		var buff129: Variant = unit.add_buff(binfo129, unit)
		buff129.hero_hooks["onRemoved"] = Callable(self, "_egg_buff_on_removed")
		var binfo126: Variant = unit.cm.lookup(&"Buff", "", BUFF_REVIVE_ATK3_ID)
		var buff126: Variant = unit.add_buff(binfo126, unit)
		buff126.hero_hooks["onRemoved"] = Callable(self, "_revive_buff_on_removed")
		var binfo135: Variant = unit.cm.lookup(&"Buff", "", BUFF_EGG_EXTRA_ID)
		unit.add_buff(binfo135, unit)
		unit.state = BattleUnit.State.BIRTH
		var pasv: Variant = unit.skills.get("Phoenix_pasv")
		if pasv:
			unit.cast_skill(pasv, pasv.target)
	else:
		unit.custom_data["phoenixCount"] = 0
		unit._die_default(killer)


func _egg_buff_on_removed(buff: Variant) -> void:
	var owner: Variant = buff.owner
	var skill: Variant = owner.skills.get("Phoenix_pasv")
	if skill != null and bool(owner.is_alive()):
		var heal_hp: float = float(skill.info.get("Script Arg2", 0)) * float(owner.config.get("hp_mod", HP_MOD_DEFAULT))
		owner.set_hp(int(heal_hp))
	owner.custom_data["isDandan"] = false
	buff._on_removed_default()


func _revive_buff_on_removed(buff: Variant) -> void:
	var owner: Variant = buff.owner
	var skillatk3: Variant = owner.skills.get("Phoenix_atk3")
	if skillatk3:
		owner.cast_skill(skillatk3, skillatk3.target)
	buff._on_removed_default()


func _get_lost_hp_after_immunity(unit: Variant, damage: float, immunity: float) -> float:
	for buff in unit.buff_list:
		if int(buff.info.get("ID", 0)) == BUFF_EGG_ID:
			return 1.0
	return BattleUnitCombat.get_lost_hp_after_immunity(damage, immunity)


func _ult_get_damage(skill: Variant, target: Variant, power: float, dt: String, field: String, src: Variant, crit_mod: float) -> float:
	return float(target.take_damage({"amount": power, "damage_type": dt, "field": field, "source": src, "coefficient": ULT_COEFFICIENT, "crit_mod": crit_mod}))


# P0-2 修复：源 :140-151 `if buff then` 护盾抵消是 Lua 作用域死代码（buff/stype 是 :125-133 if 块内 local，
#   离开 :133 end 不可见；:135-138 for 循环 local buff 同样不可见；:140 引用全局 nil 恒 false），源有效行为仅 :152 owner:die()。
#   原目标误判"作用域泄露"提升 buff128/stype 为函数级 + 实现护盾抵消，致 counter!=1+有 shield buff 时 absorption=0<shield → return 不 die。照源删抵消直接 die。
func _ult_on_attack_frame(skill: Variant) -> void:
	skill._on_attack_frame_default()
	var owner: Variant = skill.caster
	if int(skill.attack_counter) == 1:
		var binfo: Variant = owner.cm.lookup(&"Buff", "", BUFF_ULT_HPR_ID)
		var buff128: Variant = BattleBuff.new(binfo, owner, owner)
		var stype: float = -float(owner.attribs.get("HP", 0)) * ULT_HPR_RATIO
		buff128.info["HPR"] = stype
		owner.add_buff(buff128, owner)
	if int(owner.hp) == 1:
		owner.die(null)


func _ult_finish(skill: Variant) -> void:
	skill._finish_default()
	var owner: Variant = skill.caster
	for buff in owner.buff_list:
		if int(buff.info.get("ID", 0)) == BUFF_ULT_HPR_ID:
			owner.remove_buff(buff)


func _atk2_create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)
	buff.hero_hooks["onRemoved"] = Callable(self, "_atk2_buff_on_removed")
	var skillatk: Variant = skill.caster.skills.get("Phoenix_atk")
	if skillatk:
		skillatk.custom_data["originfo"] = skillatk.info
		var wrapped: Dictionary = skillatk.info.duplicate()
		wrapped["Tile Art"] = "eff_tile_Phoenix_atk2.cha"
		wrapped["AOE Origin"] = "target"
		wrapped["AOE Shape"] = "circle"
		wrapped["Shape Arg1"] = "100"
		wrapped["Point Effect"] = "eff_point_burst.cha"
		wrapped["Damage Type"] = "AP"
		wrapped["Plus Attr"] = "AP"
		wrapped["Plus Ratio"] = "0.6"
		skillatk.info = wrapped
	skill.caster.custom_data["atk2Buff"] = true
	return buff


func _atk2_buff_on_removed(buff: Variant) -> void:
	var skillatk: Variant = buff.caster.skills.get("Phoenix_atk")
	if skillatk and skillatk.custom_data.has("originfo"):
		var wrapped: Dictionary = skillatk.custom_data["originfo"].duplicate()
		wrapped["Tile Art"] = "projectile/Lina_atk_tile.png"
		wrapped["AOE Origin"] = false
		wrapped["AOE Shape"] = "circle"
		wrapped["Shape Arg1"] = "0"
		wrapped["Point Effect"] = false
		wrapped["Damage Type"] = "AD"
		wrapped["Plus Attr"] = "AD"
		wrapped["Plus Ratio"] = "1"
		skillatk.info = wrapped
	buff.caster.custom_data["atk2Buff"] = false
	buff._on_removed_default()


func _atk3_on_attack_frame(skill: Variant) -> void:
	skill._on_attack_frame_default()
	var binfo: Variant = skill.caster.cm.lookup(&"Buff", "", BUFF_ATK3_ID)
	skill.caster.add_buff(binfo, skill.caster)


func _atk3_can_cast_with_target(skill: Variant, target: Variant) -> Dictionary:
	var base: Dictionary = skill._can_cast_with_target_default(target)
	if not bool(base.get("ok", false)) or bool(skill.caster.custom_data.get("atk2Buff", false)):
		return {"ok": false, "reason": "atk2Buff"}
	return base


func apply(hero: Variant) -> void:
	var skill2: Variant = hero.skills.get("Phoenix_atk2")
	if skill2:
		skill2.hero_hooks["createBuff"] = Callable(self, "_atk2_create_buff")
	var skill_pasv: Variant = hero.skills.get("Phoenix_pasv")
	if skill_pasv:
		hero.hero_hooks["die"] = Callable(self, "_die")
		hero.hero_hooks["getLostHPAfterImmunity"] = Callable(self, "_get_lost_hp_after_immunity")
	var skillult: Variant = hero.skills.get("Phoenix_ult")
	if skillult:
		skillult.hero_hooks["onAttackFrame"] = Callable(self, "_ult_on_attack_frame")
		skillult.hero_hooks["getDamage"] = Callable(self, "_ult_get_damage")
		skillult.hero_hooks["finish"] = Callable(self, "_ult_finish")
	var skill3: Variant = hero.skills.get("Phoenix_atk3")
	if skill3:
		skill3.hero_hooks["onAttackFrame"] = Callable(self, "_atk3_on_attack_frame")
		skill3.hero_hooks["canCastWithTarget"] = Callable(self, "_atk3_can_cast_with_target")
