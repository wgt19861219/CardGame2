extends RefCounted

## WD（巫医）英雄 hook（Logic 层）— 照源 battle/heroes/WD.lua（118 行）。
## WD_atk3: createProjectile(enableJump5+enableTrack) + power(percents[jumps]) + getDamage(召唤物 power×2)
##   + createBuff(召唤物 BuffCreate 7)。
## WD_atk4: selectTarget（召唤物优先：chosen 召唤物时，非召唤物新目标强制覆盖）。
## WD_ult: start（basefunc + addBuff Buff 150）。
## atk3.takeEffectOn 源 :20-22 仅 return basefunc 无改（Logic 等价默认），照源跳过注册。

const JUMPS: int = 5  # 源 :4 enableJump(5)
const POWER_PERCENTS: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0]  # 源 :8-14（当前全 1，hook 等价默认；照源结构留数据驱动位）
const SUMMON_DOUBLE_MULT: float = 2.0  # 源 :25 is_summoned power×2
const SUMMON_BUFF_ID: int = 7   # 源 :93 is_summoned BuffCreate(7)
const ULT_BUFF_ID: int = 150    # 源 :85 start addBuff(150)
const HUGE: float = INF  # 源 math.huge（selector 最大值初始）


func apply(hero: Variant) -> void:
	var atk3: Variant = hero.skills.get("WD_atk3")
	if atk3:
		atk3.hero_hooks["createProjectile"] = Callable(self, "_create_projectile")
		atk3.hero_hooks["power"] = Callable(self, "_power")
		atk3.hero_hooks["getDamage"] = Callable(self, "_get_damage")
		atk3.hero_hooks["createBuff"] = Callable(self, "_create_buff")
	var atk4: Variant = hero.skills.get("WD_atk4")
	if atk4:
		atk4.hero_hooks["selectTarget"] = Callable(self, "_select_target")
	var ult: Variant = hero.skills.get("WD_ult")
	if ult:
		ult.hero_hooks["start"] = Callable(self, "_start")


# 源 :2-7 skill_atk3_createProjectile（basefunc + enableJump + enableTrack）。
func _create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = BattleProjectile.new(skill)  # basefunc
	projectile.enable_jump(JUMPS)
	projectile.enable_track(skill.target)
	return projectile


# 源 :15-19 skill_atk3_power（basefunc × percents[jumps]，返 [power×percent, crit_mod]）。
# 源 :16 local ret = basefunc(skill) 只取首返回值（crit_mod 丢失），GDScript 保留 base[1] 修正（源 latent bug）。
func _power(skill: Variant, src: Variant, _target: Variant) -> Array:
	var base: Array = BattleSkillEffect.power(skill, src)  # basefunc
	var jumps: int = int(src.jumps)
	if jumps >= 1 and jumps <= POWER_PERCENTS.size():
		return [base[0] * POWER_PERCENTS[jumps - 1], base[1]]
	return [base[0], base[1]]


# 源 :23-35 skillatk3_getDamage（is_summoned power×2 + takeDamage table，源 unit.lua:1252 解包）。
func _get_damage(skill: Variant, target: Variant, power: float, dt: String, field: String, src: Variant, crit_mod: float) -> float:
	var p_power: float = power
	if bool(target.config.get("is_summoned", false)):  # 源 :24
		p_power = p_power * SUMMON_DOUBLE_MULT
	return float(target.take_damage({  # 源 :27-34 takeDamage(table)
		"amount": p_power,
		"damage_type": dt,
		"field": field,
		"source": src,
		"crit_mod": crit_mod,
	}))


# 源 :89-98 skillatk3_createBuff（is_summoned→BuffCreate(7) else basefunc）。
func _create_buff(skill: Variant, target: Variant) -> Variant:
	if bool(target.config.get("is_summoned", false)):  # 源 :91
		var binfo: Variant = skill.caster.cm.lookup(&"Buff", "", SUMMON_BUFF_ID)
		return BattleBuff.new(binfo, target, skill.caster)
	return skill._create_buff_default(target)


# 源 :36-80 skillatk4_selectTarget（target/self/selector 三分支；selector 分支召唤物优先）。
func _select_target(skill: Variant, default_t: Variant) -> Variant:
	var ttype: String = str(skill.info.get("Target Type", ""))
	if ttype == "target":  # 源 :39-49
		if default_t != null:
			skill.target = default_t
		else:
			var res: Array = skill.caster.ai.search_target()
			if res.size() > 1 and float(res[1]) <= skill.max_range_sq:
				skill.target = res[0]
			else:
				skill.target = null
	elif ttype == "self":  # 源 :50-51
		skill.target = skill.caster
	else:  # 源 :52-75 selector 分支
		var selector: Callable = skill._target_selector()
		if selector.is_valid():
			var max_v: float = -HUGE
			var chosen: Variant = null
			var caster: Variant = skill.caster
			var enchanted: bool = bool(caster.buff_effects.get("enchanted", false))
			for unit in caster.engine.foreach_alive_unit(int(skill._target_camp())):
				if bool(unit.buff_effects.get("untargetable", false)):
					continue
				if enchanted and unit == caster:
					continue
				var dsq: float = unit.position.distance_squared_to(caster.position)
				if dsq >= skill.min_range_sq and dsq <= skill.max_range_sq:
					var v: float = float(selector.call(unit))
					# 源 :65-71：chosen 召唤物 + 新 unit 非召唤物 → 强制覆盖（非召唤物优先于召唤物）
					if not bool(unit.config.get("is_summoned", false)) and chosen != null and bool(chosen.config.get("is_summoned", false)):
						max_v = v
						chosen = unit
					elif v > max_v:
						max_v = v
						chosen = unit
			skill.target = chosen
	return skill.target


# 源 :81-88 skillult_start（basefunc + addBuff Buff 150）。
func _start(skill: Variant, target: Variant) -> void:
	skill._start_default(target)  # basefunc
	var owner: Variant = skill.caster
	var binfo: Variant = owner.cm.lookup(&"Buff", "", ULT_BUFF_ID)
	var buff: Variant = BattleBuff.new(binfo, owner, owner)
	owner.add_buff(buff, owner)
