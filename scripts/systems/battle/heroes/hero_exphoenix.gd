extends RefCounted

## ExPhoenix（Ex 版凤凰）英雄 hook（Logic 层）— 照源 ExPhoenix.lua（297 行）翻译。
## Phoenix 扩展版：die 蛋形态（1 次，hp=1 + Buff162/158 shield by level + 129/126/135 + Birth + castSkill pasv）+
##   getLostHPAfterImmunity（Buff129→返1）+ atk2（createBuff wraptable AP Plus Ratio1.4 + onRemoved 还原 Ratio3）+
##   ult（onAttackFrame counter1 Buff128 HPR + hp==1 护盾 / getDamage coef0.25 / finish 移除 Buff128+163 / start 加 Buff163）+
##   atk3（Buff125 + atk2Buff 互斥）+ reset（Buff162）+ update（Buff152 uncontroll 循环检查）+ shield buff onDamaged（Buff158 shield-1）。
## 复用续17 Phoenix 蛋形态模式 + 全用已有 hook。

const BUFF_EGG_ID: int = 129
const BUFF_REVIVE_ATK3_ID: int = 126
const BUFF_EGG_EXTRA_ID: int = 135
const BUFF_ULT_HPR_ID: int = 128
const BUFF_SHIELD_CHECK_ID: int = 31
const BUFF_SHIELD_EGG_ID: int = 158
const BUFF_RESET_ID: int = 162
const BUFF_ULT_START_ID: int = 163
const BUFF_UNCONTROLL_ID: int = 152
const BUFF_ATK3_ID: int = 125
const ULT_HPR_RATIO: float = 0.15
const SHIELD_ABSORB_RATIO: float = 0.8
const ULT_COEFFICIENT: float = 0.25
const HP_MOD_DEFAULT: float = 1.0
const ATK_PLUS_RATIO_ULT: String = "1.4"
const ATK_PLUS_RATIO_NORMAL: String = "3"
const SHIELD_VAL_MAX: int = 37
const SHIELD_TABLE: Array = [[65, 12], [70, 18], [80, 24], [85, 30], [90, 30]]


func _shield_by_level(level: int) -> int:
	for entry in SHIELD_TABLE:
		if level <= int(entry[0]):
			return int(entry[1])
	return SHIELD_VAL_MAX


func _die(unit: Variant, killer: Variant) -> void:
	if not bool(unit.custom_data.get("isDandan", false)):
		unit.custom_data["isDandan"] = true
		var count: int = int(unit.custom_data.get("phoenixCount", 0))
		unit.custom_data["phoenixCount"] = count + 1 if count > 0 else 1
		unit.remove_all_buffs()
		var binfo162: Variant = unit.cm.lookup(&"Buff", "", BUFF_RESET_ID)
		unit.add_buff(binfo162, unit)
		unit.can_cast_manual = false
		unit.walk_v = Vector2.ZERO
		unit.hp = 1
		var binfo158: Variant = unit.cm.lookup(&"Buff", "", BUFF_SHIELD_EGG_ID)
		var buff158: Variant = BattleBuff.new(binfo158, unit, unit)
		buff158.shield = float(_shield_by_level(int(unit.level)))
		buff158.hero_hooks["onDamaged"] = Callable(self, "_shield_buff_on_damaged")
		unit.add_buff(buff158, unit)
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
		var pasv: Variant = unit.skills.get("ExPhoenix_pasv")
		if pasv:
			unit.cast_skill(pasv, pasv.target)
	else:
		unit.custom_data["phoenixCount"] = 0
		unit._die_default(killer)


func _egg_buff_on_removed(buff: Variant) -> void:
	var owner: Variant = buff.owner
	if bool(owner.is_alive()):
		owner.set_hp(int(float(owner.attribs.get("HP", 0)) * float(owner.config.get("hp_mod", HP_MOD_DEFAULT))))
	owner.custom_data["isDandan"] = false
	buff._on_removed_default()


func _revive_buff_on_removed(buff: Variant) -> void:
	var owner: Variant = buff.owner
	var skillatk3: Variant = owner.skills.get("ExPhoenix_atk3")
	if skillatk3:
		owner.cast_skill(skillatk3, skillatk3.target)
	buff._on_removed_default()


func _shield_buff_on_damaged(buff: Variant, damage: float, damage_type: String) -> float:
	var owner: Variant = buff.caster
	var shield_buff: Variant = null
	for b in owner.buff_list:
		if int(b.info.get("ID", 0)) == BUFF_SHIELD_EGG_ID:
			shield_buff = b
	if shield_buff != null and float(shield_buff.shield) > 0:
		shield_buff.shield = float(shield_buff.shield) - 1
		_show_egg_hurt_popup(owner)
		return 0.0
	return buff._on_damaged_default(damage, damage_type)


func _get_lost_hp_after_immunity(unit: Variant, damage: float, immunity: float) -> float:
	for buff in unit.buff_list:
		if int(buff.info.get("ID", 0)) == BUFF_EGG_ID:
			return 1.0
	return BattleUnitCombat.get_lost_hp_after_immunity(damage, immunity)


func _ult_get_damage(skill: Variant, target: Variant, power: float, dt: String, field: String, src: Variant, crit_mod: float) -> float:
	return float(target.take_damage({"amount": power, "damage_type": dt, "field": field, "source": src, "coefficient": ULT_COEFFICIENT, "crit_mod": crit_mod}))


func _atk2_create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)
	buff.hero_hooks["onRemoved"] = Callable(self, "_atk2_buff_on_removed")
	var skillatk: Variant = skill.caster.skills.get("ExPhoenix_atk")
	if skillatk:
		var wrapped: Dictionary = skillatk.info.duplicate()
		wrapped["Tile Art"] = "eff_tile_Phoenix_atk2.cha"
		wrapped["AOE Origin"] = "target"
		wrapped["AOE Shape"] = "circle"
		wrapped["Shape Arg1"] = "100"
		wrapped["Point Effect"] = "eff_point_burst.cha"
		wrapped["Damage Type"] = "AP"
		wrapped["Plus Attr"] = "AP"
		wrapped["Plus Ratio"] = ATK_PLUS_RATIO_ULT
		skillatk.info = wrapped
	skill.caster.custom_data["atk2Buff"] = true
	return buff


func _atk2_buff_on_removed(buff: Variant) -> void:
	var skillatk: Variant = buff.caster.skills.get("ExPhoenix_atk")
	if skillatk:
		var wrapped: Dictionary = skillatk.info.duplicate()
		wrapped["Tile Art"] = "projectile/Lina_atk_tile.png"
		wrapped["AOE Origin"] = false
		wrapped["AOE Shape"] = "circle"
		wrapped["Shape Arg1"] = "0"
		wrapped["Point Effect"] = false
		wrapped["Damage Type"] = "AD"
		wrapped["Plus Attr"] = "AD"
		wrapped["Plus Ratio"] = ATK_PLUS_RATIO_NORMAL
		skillatk.info = wrapped
	buff.caster.custom_data["atk2Buff"] = false
	buff._on_removed_default()


# P0-3 修复：与 Phoenix 同构——源 :175-186 `if buff then` 护盾抵消是 Lua 作用域死代码（buff/stype 是 :160-168
#   if 块内 local 离开不可见；:170-174 for 循环 local buff 同样不可见；:175 引用全局 nil 恒 false），源有效行为仅 :187 owner:die()。
#   原目标提升 buff128/stype 为函数级 + 实现抵消，致 counter!=1+有 shield buff 时不死。照源删抵消直接 die。
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
		var bid: int = int(buff.info.get("ID", 0))
		if bid == BUFF_ULT_HPR_ID or bid == BUFF_ULT_START_ID:
			owner.remove_buff(buff)


func _ult_start(skill: Variant, target: Variant) -> void:
	var binfo: Variant = skill.caster.cm.lookup(&"Buff", "", BUFF_ULT_START_ID)
	skill.caster.add_buff(binfo, skill.caster)
	skill._start_default(target)


func _atk3_on_attack_frame(skill: Variant) -> void:
	skill._on_attack_frame_default()
	var binfo: Variant = skill.caster.cm.lookup(&"Buff", "", BUFF_ATK3_ID)
	skill.caster.add_buff(binfo, skill.caster)


func _atk3_can_cast_with_target(skill: Variant, target: Variant) -> Dictionary:
	var base: Dictionary = skill._can_cast_with_target_default(target)
	if not bool(base.get("ok", false)) or bool(skill.caster.custom_data.get("atk2Buff", false)):
		return {"ok": false, "reason": "exphoenix atk3"}
	return base


func _reset(hero: Variant) -> void:
	hero._reset_default()
	var binfo: Variant = hero.cm.lookup(&"Buff", "", BUFF_RESET_ID)
	hero.add_buff(binfo, hero)


func _hero_update(unit: Variant, dt: float) -> void:
	var has_uncontroll: bool = false
	for b in unit.buff_list:
		if int(b.info.get("ID", 0)) == BUFF_UNCONTROLL_ID:
			has_uncontroll = true
	if not has_uncontroll:
		var binfo: Variant = unit.cm.lookup(&"Buff", "", BUFF_UNCONTROLL_ID)
		unit.add_buff(binfo, unit)
	unit._update_default(dt)


func apply(hero: Variant) -> void:
	hero.max_shield = _shield_by_level(int(hero.level))
	hero.hero_hooks["update"] = Callable(self, "_hero_update")
	var skill2: Variant = hero.skills.get("ExPhoenix_atk2")
	if skill2:
		skill2.hero_hooks["createBuff"] = Callable(self, "_atk2_create_buff")
	var skill_pasv: Variant = hero.skills.get("ExPhoenix_pasv")
	if skill_pasv:
		hero.hero_hooks["die"] = Callable(self, "_die")
		hero.hero_hooks["getLostHPAfterImmunity"] = Callable(self, "_get_lost_hp_after_immunity")
	var skillult: Variant = hero.skills.get("ExPhoenix_ult")
	if skillult:
		skillult.hero_hooks["onAttackFrame"] = Callable(self, "_ult_on_attack_frame")
		skillult.hero_hooks["getDamage"] = Callable(self, "_ult_get_damage")
		skillult.hero_hooks["finish"] = Callable(self, "_ult_finish")
		skillult.hero_hooks["start"] = Callable(self, "_ult_start")
	var skill3: Variant = hero.skills.get("ExPhoenix_atk3")
	if skill3:
		skill3.hero_hooks["onAttackFrame"] = Callable(self, "_atk3_on_attack_frame")
		skill3.hero_hooks["canCastWithTarget"] = Callable(self, "_atk3_can_cast_with_target")
	hero.hero_hooks["reset"] = Callable(self, "_reset")


func _show_egg_hurt_popup(unit: Variant) -> void:
	var actor: Variant = unit.get("actor")
	if actor == null or not actor.has_method("spawn_popup"):
		return
	actor.spawn_popup("-1", "orange", true, "damage")
