extends RefCounted

## TA（圣堂刺客）英雄 hook（Logic 层）— 照源 battle/heroes/TA.lua（170 行）。
## 单位级 handleUnitDieEvent：击杀重置 TA_atk2 cd。
## TA_ult：selectTarget（counter>1 复用；否则 basefunc + 找 maxHP 可杀目标）/ takeEffectAt（counter 1 冲撞 2 回原 target 3 AOE 回原位）/ start（记 origposition + addBuff 120 + 移除 buff 106）/ power（源恒返 base，死代码分支等价）。
## TA_atk2.createBuff：refraction 折射护盾（onDamaged 抵伤+回 mp+次数递减；onRemoved 清零）。
## TA_atk4.power：target != skill.target 时 ×Script Arg2/100。

const SKILL4_RATIO_DENOM: float = 100.0
const ULT_BUFF_ID: int = 120
const REMOVE_BUFF_ID: int = 106
const CHARGE_DISTANCE: float = 120.0
const SHIELD_ALL: String = "all"
const DMS_MULT: float = 2.0
const ULT_RETURN_COUNTER: int = 2


func apply(hero: Variant) -> void:
	hero.hero_hooks["handleUnitDieEvent"] = Callable(self, "_handle_unit_die_event")
	var skillult: Variant = hero.skills.get("TA_ult")
	if skillult:
		skillult.hero_hooks["selectTarget"] = Callable(self, "_ult_select_target")
		skillult.hero_hooks["takeEffectAt"] = Callable(self, "_ult_take_effect_at")
		skillult.hero_hooks["start"] = Callable(self, "_ult_start")
		skillult.hero_hooks["power"] = Callable(self, "_ult_power")
	var skillatk2: Variant = hero.skills.get("TA_atk2")
	if skillatk2:
		skillatk2.hero_hooks["createBuff"] = Callable(self, "_atk2_create_buff")
	var skillatk4: Variant = hero.skills.get("TA_atk4")
	if skillatk4:
		skillatk4.hero_hooks["power"] = Callable(self, "_skill4_power")


func _handle_unit_die_event(hero: Variant, unit: Variant, killer: Variant) -> void:
	if killer == hero:
		var skillatk2: Variant = hero.skills.get("TA_atk2")
		if skillatk2:
			skillatk2.cd_remaining = 0.0


func _ult_select_target(skill: Variant, default_t: Variant) -> Variant:
	if skill.attack_counter > 1:
		return skill.target
	var target: Variant = skill._select_target_default(default_t)  # basefunc
	var caster: Variant = skill.caster
	var dmg: float = (float(skill.info.get("Basic Num", 0.0)) + float(skill.info.get("Plus Ratio", 0.0)) * float(caster.attribs.get(String(skill.info.get("Plus Attr", "")), 0.0))) * DMS_MULT
	var target_hp: float = float(target.hp) if target != null else 0.0
	var max_hp_target: Variant = target
	if dmg > target_hp:
		for unit in caster.engine.foreach_alive_unit(-int(caster.camp)):
			if target_hp < float(unit.hp) and dmg >= float(unit.hp):
				max_hp_target = unit
				target_hp = float(unit.hp)
	skill.target = max_hp_target
	return max_hp_target


func _ult_power(skill: Variant, src: Variant, _target: Variant) -> Array:
	return BattleSkillEffect.power(skill, src)


func _ult_take_effect_at(skill: Variant, _location: Vector2, source: Variant) -> void:
	var caster: Variant = skill.caster
	var counter: int = skill.attack_counter
	if counter == 1:
		skill.custom_data["origtarget"] = skill.target
		var target: Variant = skill.target
		if target != null:
			caster.position = Vector2(float(target.position.x) + float(caster.direction) * CHARGE_DISTANCE, float(target.position.y))
			caster.direction = -caster.direction
	elif counter == ULT_RETURN_COUNTER:
		skill.target = skill.custom_data.get("origtarget", null)
		BattleSkillEffect.take_effect_at(skill, skill.target.position, source)  # basefunc
	else:
		var originfo: Dictionary = skill.info
		var wrapped: Dictionary = originfo.duplicate()
		wrapped["AOE Origin"] = "target"
		wrapped["Point Effect"] = false
		skill.info = wrapped
		BattleSkillEffect.take_effect_at(skill, skill.target.position, source)  # basefunc
		skill.info = originfo
		caster.position = caster.custom_data["origposition"]


func _ult_start(skill: Variant, target: Variant) -> void:
	skill._start_default(target)  # basefunc
	var caster: Variant = skill.caster
	caster.custom_data["origposition"] = caster.position
	var binfo: Variant = caster.cm.lookup(&"Buff", "", ULT_BUFF_ID)
	caster.add_buff(binfo, caster)
	var to_remove: Array = []
	for tbuff in caster.buff_list:
		if int(tbuff.info.get("ID", 0)) == REMOVE_BUFF_ID:
			to_remove.append(tbuff)
	var i: int = to_remove.size() - 1
	while i >= 0:
		caster.remove_buff(to_remove[i])
		i -= 1


func _atk2_create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)  # basefunc
	buff.custom_data["refraction"] = int(skill.info.get("Script Arg2", 0))
	buff.hero_hooks["onRemoved"] = Callable(self, "_skill2_buff_on_removed")
	buff.hero_hooks["onDamaged"] = Callable(self, "_skill2_buff_on_damaged")
	return buff


func _skill2_buff_on_removed(buff: Variant) -> void:
	buff.custom_data["refraction"] = 0
	buff._on_removed_default()  # basefunc


func _skill2_buff_on_damaged(buff: Variant, damage: float, damage_type: String) -> float:
	var owner: Variant = buff.owner
	if damage <= 0.0:
		if buff.custom_data.has("refraction") and int(buff.custom_data.get("refraction", 0)) <= 0:
			owner.remove_buff(buff)
		return 0.0
	if buff.has_shield:
		var stype: String = String(buff.info.get("Shield Type", ""))
		if stype == damage_type or stype == SHIELD_ALL:
			buff.shield = buff.shield - damage
			var temp: float = buff.shield
			var refr: int = int(buff.custom_data.get("refraction", 0)) - 1
			buff.custom_data["refraction"] = refr
			buff.shield = float(buff.info.get("Shield Value", 0.0))
			if refr <= 0:
				owner.remove_buff(buff)
			var mppower: float = float(owner.skills.get("TA_atk2").info.get("Script Arg3", 0.0))
			owner.take_heal(mppower, "mp", owner)
			_show_refract_immune_popup(owner, stype)
			if temp < 0.0:
				return -temp
			return 0.0
	return damage


# 注：源 :3 basefunc(skill, target, source) 参数顺序颠倒（源 latent bug，target 当 source 传），
# 但 power（源 skill.lua:531）忽略 source/target 仅用 skill.caster → 颠倒无害。
# 目标 power(skill, src) 传规范 source（同 Luna-2 修正模式），行为与源等价。
func _skill4_power(skill: Variant, src: Variant, target: Variant) -> Array:
	var base: Array = BattleSkillEffect.power(skill, src)
	if target != skill.target:
		return [base[0] * float(skill.info.get("Script Arg2", 0.0)) / SKILL4_RATIO_DENOM, base[1]]
	return [base[0], base[1]]


func _show_refract_immune_popup(owner_unit: Variant, stype: String) -> void:
	var actor: Variant = owner_unit.get("actor")
	if actor == null or not actor.has_method("spawn_popup"):
		return
	var color: String = "blue" if int(owner_unit.camp) == BattleEngine.CAMP_PLAYER else "red"
	var str_map: Dictionary = {"AD": "physical_immune", "AP": "magic_immune", "all": "immune"}
	actor.spawn_popup(str(str_map.get(stype, "immune")), color, false, "text")
