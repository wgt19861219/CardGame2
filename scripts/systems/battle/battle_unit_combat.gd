class_name BattleUnitCombat
extends RefCounted

## 单位战斗结算（Logic 层）— 照源 unit.lua 伤害/死亡/受击/动作段翻译（Phase 2.2续-A，2026-07-01）。
## 从 unit.lua 拆出（源是一体，Godot ≤300 行铁律强制拆分，合规引擎适配，先例 battle_skill_effect）。
## 全静态方法，第一参 u 为 BattleUnit（duck-type：attribs/buff_list/buff_effects/hp/mp/info/level/camp/
##   state/current_skill/engine/dmg_statistics/dPSStatisticsRatio/isDeathWithEffect/puppet_stack/
##   set_hp/set_mp/is_alive/unfreeze_actor/remove_signed_buffer）。
## View 副作用（PopupCreate/showMonsterLoots/playEffect/actor.*）剥离为 Logic 桩（Phase 4 battle_scene 接）。

# —— takeDamage 公式常量（源 :1276-1299, :1248, :1338 裸数值，lint 禁魔法数字，照源值提 const）——
const DEF_COEFF_AD_DD: float = 8.0
const DEF_COEFF_AD_DC: float = 8.0
const DEF_COEFF_AP_DD: float = 12.0
const DEF_COEFF_AP_DC: float = 2.5
const CRIT_DENOM: float = 100.0
const CRIT_MULTIPLIER: float = 2.0
const IMMUNITY_FULL: float = 100.0
const IMMUNITY_DENOM: float = 100.0
const IMMUNITY_MIN_LOSS: int = 1
const INTERRUPT_HP_RATIO_DEFAULT: float = 0.08


# 返回 lost（实际扣减前的不抗免损失；源 :1375 return lost）。
static func take_damage(u: Variant, params: Dictionary) -> float:
	var dt: String = str(params.get("damage_type", ""))
	var field: String = str(params.get("field", "hp"))
	var source: Variant = params.get("source", null)
	var coefficient: float = float(params.get("coefficient", 1.0))
	var crit_mod: float = float(params.get("crit_mod", 1.0))
	var amount: float = float(params.get("amount", 0.0))
	if not bool(u.is_alive()):
		return 0.0
	var defence: float = 0.0
	var dd: float = 0.0
	var dc: float = 0.0
	var immunity: float = 0.0
	var crit: float = 0.0
	if dt == "AD":
		defence = max(0.0, float(u.attribs.get("ARM", 0.0)) - float(source.attribs.get("ARMP", 0.0)))
		crit = float(source.attribs.get("CRIT", 0.0))
		immunity = float(u.attribs.get("PIMU", 0.0))
		dd = defence * DEF_COEFF_AD_DD
		dc = defence * DEF_COEFF_AD_DC
	elif dt == "AP":
		defence = max(0.0, float(u.attribs.get("MR", 0.0)) - float(source.attribs.get("MRI", 0.0)))
		crit = float(source.attribs.get("MCRIT", 0.0))
		immunity = float(u.attribs.get("MIMU", 0.0))
		dd = defence * DEF_COEFF_AP_DD
		dc = defence * DEF_COEFF_AP_DC
	elif dt == "Holy":
		pass
	var crit_prob: float = crit / (CRIT_DENOM + dc) * crit_mod
	var b_crit: bool = crit_prob > float(u.engine.rng.randf())
	var crit_multiplier: float = CRIT_MULTIPLIER if b_crit else 1.0
	amount = max(0.0, amount)
	var damage: float = amount * amount / (amount + dd * coefficient)
	damage = damage * crit_multiplier * float(source.attribs.get("PDM", 1.0))
	if immunity >= IMMUNITY_FULL:
		_show_immune_popup(u)
		return 0.0
	for buff in u.buff_list:
		damage = float(buff.on_damaged(damage, dt))
	if damage <= 0.0:
		return 0.0
	var hh: Variant = u.get("hero_hooks")
	var gh: Callable = hh.get("getLostHPAfterImmunity", Callable()) if hh is Dictionary else Callable()
	var lost: float = float(gh.call(u, damage, immunity)) if gh.is_valid() else get_lost_hp_after_immunity(damage, immunity)
	var dmg: float = min(float(u.hp), lost)
	dmg = dmg * float(u.dPSStatisticsRatio)
	if source != u:
		source.dmg_statistics = float(source.dmg_statistics) + dmg
	if field == "hp":
		u.set_hp(int(float(u.hp) - lost))
		if int(u.hp) == 0:
			die(u, source)
		else:
			_try_hurt(u, lost)
			var mp_gain: float = lost * float(u.info.get("MP Gain Rate", 0.0)) / float(u.attribs.get("HP", 1.0))
			u.set_mp(int(float(u.mp) + mp_gain * float(u.engine.mp_bonus)))
	elif field == "mp":
		u.set_mp(int(float(u.mp) - lost))
	u.unfreeze_actor()
	_show_damage_popup(u, lost, field, b_crit)
	return lost


# 表现走 BattleEvent 队列（T4，headless 无消费者时静默累积），等价源 ed.run_with_scene 守卫。
static func _show_immune_popup(u: Variant) -> void:
	var color: String = "red" if int(u.camp) == BattleEngine.CAMP_ENEMY else "blue"
	var adimm: bool = float(u.attribs.get("PIMU", 0.0)) >= IMMUNITY_FULL
	var apimm: bool = float(u.attribs.get("MIMU", 0.0)) >= IMMUNITY_FULL
	var str_text: String
	if adimm and apimm:
		str_text = "immune"
	elif adimm:
		str_text = "physical_immune"
	else:
		str_text = "magic_immune"
	u.emit_popup(str_text, color, false, "text")


static func _show_damage_popup(u: Variant, lost: float, field: String, b_crit: bool) -> void:
	var str_text: String = "-" + str(int(round(lost)))
	if str_text == "-0":
		return
	var color: String
	if field == "mp":
		color = "yellow"
	elif int(u.camp) == BattleEngine.CAMP_PLAYER:
		color = "red"
	else:
		color = "orange"
	u.emit_popup(str_text, color, b_crit, "damage")


# engine.on_unit_die 调（battle_engine 超 300 行，提取至此控行数）。kill_mp_bonus 透传 engine 常量。
static func on_hero_kill(killer: Variant, kill_mp_bonus: int) -> void:
	killer.set_mp(int(killer.mp) + kill_mp_bonus)
	killer.emit_popup("kill", "blue" if int(killer.camp) == BattleEngine.CAMP_PLAYER else "red", false, "text")


static func _try_hurt(u: Variant, lost: float) -> void:
	var interrupt_ratio: float = float(u.info.get("Interrupt HP Ratio", 0.0))
	if interrupt_ratio == 0.0:
		interrupt_ratio = INTERRUPT_HP_RATIO_DEFAULT
	if lost <= float(u.attribs.get("HP", 0.0)) * interrupt_ratio:
		return
	if u.state == BattleUnit.State.BIRTH:
		return
	if u.current_skill != null and not bool(u.current_skill.info.get("Interruptable", false)):
		return
	if bool(u.buff_effects.get(BattleEffectKeys.UNCONTROLLABLE, false)):
		return
	hurt(u)


static func get_lost_hp_after_immunity(damage: float, immunity: float) -> float:
	return max(float(IMMUNITY_MIN_LOSS), damage * (IMMUNITY_DENOM - immunity) / IMMUNITY_DENOM)


static func die(u: Variant, killer: Variant) -> void:
	if not bool(u.is_alive()):
		return
	var death_name: String = String(u.name).to_upper()
	if death_name != "":
		u.emit_voice(death_name, "_DEATH")
	u.remove_signed_buffer()
	if bool(u.manually_casting):
		u.manually_casting = false
		u.engine.unfreeze()
	if u.current_skill != null:
		u.current_skill.interrupt()
	u.state = BattleUnit.State.DYING
	u.can_cast_manual = false
	u.walk_v = Vector2.ZERO
	u.hp = 0
	u.mp = 0
	if not bool(u.isDeathWithEffect):
		set_action(u, "Death", false, true)
	else:
		u.action_name = ""
		u.action_loop = false
		u.action_duration = 0.0
		u.action_elapsed = 0.0
	u.engine.on_unit_die(u, killer)
	if u.aura_skill_list.size() > 0:
		for unit in u.engine.foreach_alive_unit(int(u.camp)):
			unit.rebuild()
	if u.effect_enemy_aura_skill_list.size() > 0:
		var foe_camp: int = BattleEngine.CAMP_ENEMY if int(u.camp) == BattleEngine.CAMP_PLAYER else BattleEngine.CAMP_PLAYER
		for unit in u.engine.foreach_alive_unit(foe_camp):
			unit.rebuild()
	u.emit_gold_drop()


static func hurt(u: Variant) -> void:
	if not bool(u.is_alive()):
		return
	if u.current_skill != null:
		u.current_skill.interrupt()
	set_action(u, "Damaged", false, true)
	u.state = BattleUnit.State.HURT
	u.walk_v = Vector2.ZERO


static func set_action(u: Variant, action_name: String, loop: bool, interrupt: bool) -> void:
	u.action_loop = loop
	if loop and action_name == u.action_name:
		return
	u.action_name = action_name
	if interrupt:
		u.action_elapsed = 0.0
	else:
		u.action_elapsed = max(0.0, float(u.action_elapsed) - float(u.action_duration))
	# 源 :823-833 非循环动作 → AnimDuration 表查时长（puppet 栈顶资源 + 动作名）；本轮空栈/无表 fallback 0
	if not loop and action_name != "":
		u.action_duration = _lookup_anim_duration(u, action_name)
	else:
		u.action_duration = 0.0
	u.emit_new_action(action_name, loop)


# phase 时序接入（BattleSkillPhase 同表查询）：action_duration>0 才触发 on_action_finished → on_phase_finished，skill 不卡 casting。
static func _lookup_anim_duration(u: Variant, action_name: String) -> float:
	var cm: Variant = u.get("cm")  # 安全访问（MockUnit 无 cm → null → 返 0，同 hero_hooks 范式）
	if cm == null:
		return 0.0
	var info: Variant = u.get("info")
	if info == null:
		return 0.0
	var puppet: String = str(info.get("Puppet", ""))
	if puppet == "":
		return 0.0
	var puppet_row: Dictionary = cm.get_raw_table(&"Puppet").get(puppet, {})
	var resource_short: Variant = puppet_row.get(&"Resource", null)
	if resource_short == null:
		return 0.0
	var resource_name: String = str(resource_short) + ".cha"
	var dur_row: Dictionary = cm.get_raw_table(&"AnimDuration").get(resource_name, {}).get(action_name, {})
	return float(dur_row.get(&"Duration", 0.0))


# :1231 才 false）——所有治疗默认弹飘字（含 HPS/MPS 持续回复），非参数。mp=yellow、hp=green，amount>1 守卫。
static func take_heal(u: Variant, amount: float, p_type: String, source: Variant) -> void:
	if not bool(u.is_alive()):
		return
	if p_type == "":
		p_type = "hp"
	if source != null:
		amount = amount * float(source.attribs.get("PDM", 1.0))
	var is_add_point: bool = true
	if p_type == "mp":
		u.set_mp(int(float(u.mp) + amount))
	elif not bool(u.buff_effects.get(BattleEffectKeys.UNHEAL, false)):
		u.set_hp(int(float(u.hp) + amount))
	else:
		is_add_point = false
	u.unfreeze_actor()
	if is_add_point and amount > 1.0:
		var str_text: String = "+" + str(int(round(amount)))
		var color: String = "yellow" if p_type == "mp" else "green"
		u.emit_popup(str_text, color, false, "heal")


static func knockup(u: Variant, time: float, distance: Vector2) -> void:
	if bool(u.buff_effects.get(BattleEffectKeys.STABLE, false)):
		return
	u.knockup_time = time
	u.knockup_v = Vector2(distance.x / time, distance.y / time) if time != 0.0 else Vector2.ZERO
	u.emit_launch(time)


static func start_scaling_action(u: Variant, scale_x: float, duration: float) -> void:
	u.is_scale_action_running = true
	u.scale_action_duration = duration
	u.scale_action_running_time = 0.0
	u.scale_action_scale_value = scale_x


static func end_scaling_action(u: Variant) -> void:
	u.is_scale_action_running = false
	u.scale_action_duration = 0.0
	u.scale_action_running_time = 0.0
	u.scale_action_scale_value = 0.0


# 英雄 hook basefunc（Kael 清能量球 / ExBossHuskar）。ai.will_cast_manual_skill 自赋值（源 :652）是 no-op，省略。
static func reset(u: Variant) -> void:
	if bool(u.is_alive()):
		u.state = BattleUnit.State.IDLE
	else:
		u.state = BattleUnit.State.DEAD
		u.hasCorpse = false
	u.buff_effects = {}
	u.global_cd = 0.0
	u.current_skill = null
	u.manually_casting = false
	u.action_name = ""
	u.action_duration = 0.0
	u.action_elapsed = 0.0
	u.buff_list = []
	for skill in u.skill_list:
		skill.reset()
	u.rebuild()
	u._init_hp_mp()   # 源守卫：已初始化单位保留 hp/mp（切波不清能量；重钳在 unit.reset 公共收尾）
