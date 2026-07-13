extends RefCounted

## ExSilverDragon（照源 ExSilverDragon.lua，SilverDragon 冰系增强 Boss）。
## update dyingTimer 6s 倒计触发 frozen takeEffectAt + uncontroll Buff 152 + atk3_ice/atk2_ice/atk_ice 冰系 createBuff/takeEffectAt + frozen takeEffectOn Buff 151。

const DYING_TIMER: float = 6.0
const DYING_TIMER_RESET: float = 1.0
const UNCONTROLL_BUFF: int = 152
const ICE_MARK_BUFF: int = 5
const FROZEN_BUFF: int = 151
const DPS_LOW_RATIO: float = 0.1
const DPS_LOW_DIV: float = 2.0


# 源 :1-10 atk3_ice takeEffectAt：basefunc + counter==1 特效（View 跳过）。
func _atk3_ice_take_effect_at(skill: Variant, location: Vector2, src: Variant) -> void:
	BattleSkillEffect.take_effect_at(skill, location, src)


# 源 :13-26 atk2_ice/atk_ice createBuff：frozen → ice_mark takeEffectAt + CanFly removeAllBuffs + BuffCreate 5 / else basefunc。
func _ice_create_buff(skill: Variant, target: Variant) -> Variant:
	var caster: Variant = skill.caster
	if bool(target.buff_effects.get("frozen", false)):
		var ice_mark: Variant = caster.skills.get("ExSilverDragon_ice_mark")
		if ice_mark:
			ice_mark.take_effect_at(target.position)
		if bool(target.info.get("Can Fly", false)):
			target.remove_all_buffs()
		var binfo: Variant = caster.cm.lookup(&"Buff", "", ICE_MARK_BUFF)
		return BattleBuff.new(binfo, target, caster)
	return skill._create_buff_default(target)


# 源 :27-50 update：dyingTimer 倒计触发 frozen takeEffectAt + uncontroll Buff 152（首次）+ basefunc（View ice 跳过）。
func _update(unit: Variant, dt: float) -> void:
	if not unit.custom_data.has("dyingTimer"):
		unit.custom_data["dyingTimer"] = DYING_TIMER
	var timer: float = float(unit.custom_data.get("dyingTimer", DYING_TIMER)) - dt
	unit.custom_data["dyingTimer"] = timer
	if timer <= 0.0:
		unit.custom_data["dyingTimer"] = DYING_TIMER_RESET
		var frozen: Variant = unit.skills.get("ExSilverDragon_frozen")
		if frozen:
			frozen.take_effect_at(unit.position)
	if not bool(unit.custom_data.get("uncontroll", false)):
		unit.custom_data["uncontroll"] = true
		var binfo: Variant = unit.cm.lookup(&"Buff", "", UNCONTROLL_BUFF)
		unit.add_buff(binfo, unit)
	unit._update_default(dt)


# 源 :51-66 frozen takeEffectOn：非 Can Fly 时查 buff_list 无 151 则 addBuff 151 + basefunc。
func _frozen_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	if not bool(target.info.get("Can Fly", false)):
		var has_151: bool = false
		for b: Variant in target.buff_list:
			if int(b.info.get("ID", 0)) == FROZEN_BUFF:
				has_151 = true
		if not has_151:
			var binfo: Variant = skill.caster.cm.lookup(&"Buff", "", FROZEN_BUFF)
			target.add_buff(binfo, target)
	return BattleSkillEffect.take_effect_on(skill, target, src)


func apply(hero: Variant) -> void:
	hero.set_disapear_when_die(false)  # 源 :72
	hero.hero_hooks["update"] = Callable(self, "_update")
	var s1: Variant = hero.skills.get("ExSilverDragon_atk3_ice")
	if s1:
		s1.hero_hooks["takeEffectAt"] = Callable(self, "_atk3_ice_take_effect_at")
	var s2: Variant = hero.skills.get("ExSilverDragon_atk2_ice")
	if s2:
		s2.hero_hooks["createBuff"] = Callable(self, "_ice_create_buff")
	var s3: Variant = hero.skills.get("ExSilverDragon_atk_ice")
	if s3:
		s3.hero_hooks["createBuff"] = Callable(self, "_ice_create_buff")
	var sf: Variant = hero.skills.get("ExSilverDragon_frozen")
	if sf:
		sf.hero_hooks["takeEffectOn"] = Callable(self, "_frozen_take_effect_on")
	# 源 :78-81 低血 dps_mod/2
	var ratio: float = float(hero.hp) / float(hero.attribs.get("HP", 1))
	if ratio <= DPS_LOW_RATIO:
		hero.config["dps_mod"] = float(hero.config.get("dps_mod", 0)) / DPS_LOW_DIV
