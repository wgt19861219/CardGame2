extends RefCounted

## 泰坦巨神（TitanHead）— 照源 TitanHead.lua 翻译（Boss，6 技能）。
## atk 弹道追踪 / atk2 power=target.HP×atk2damage / atk3 召唤随机英雄×2 / atk4 takeDamage 累计 skill4damage>maxDamage finish /
## atk5 护盾 buff 40000+onRemoved 破盾 / atk6 finish dps_mod×1.5+enterActionStageFromOneStage(5)。init createNpc×2+randomHeros 随机 10。
## 复用续8 召唤模式 + 续6 power 双值 + 新 takeDamage/create_npc/enter_action_stage/BattleNpc.onActionFinished 基础设施。

const SHIELD_VALUE: float = 40000.0
const ATK3_LEVEL: int = 85
const SKILL2_CRIT: int = 1
const NEW_HERO_DURATION: float = 15.0
const NEW_HERO_MP: int = 900
const NEW_HERO_HP_MOD: float = 0.8
const NEW_HERO_DPS_MOD: float = 0.8
const NEW_HERO_SIZE_MOD: float = 1.1
const SHIELD_BREAK_BUFF: int = 123
const SHIELD_BREAK_MP_HEAL: float = 500.0
const SHIELD_BREAK_HP_HEAL: float = 99999.0
const MAX_DAMAGE_ENRAGE: float = 150000.0
const STAGE_ENRAGE: int = 2
const STAGE_FINAL: int = 5
const PROJECTILE_TRACK_V: float = 800.0
const NORM_POWER: float = -0.5
const ATK3_LOC1_X: float = -80.0
const ATK3_LOC1_Y: float = 30.0
const ATK3_LOC2_X: float = -90.0
const ATK3_LOC2_Y: float = -20.0
const ATK6_DPS_MULT: float = 1.5
const ATK6_ATK2_RATIO: float = 0.16
const INIT_ATK2_RATIO: float = 0.3
const INIT_MAX_DAMAGE: float = 50000.0
const INIT_HERO_INDEX: int = -1
const RANDOM_HERO_COUNT: int = 10
const RANDOM_HERO_RANGE: int = 49
const RANDOM_HERO_EXCLUDE: int = 33
const BUFF_MIRROR: int = 89
const BUFF_111: int = 111
const ATK3_SUMMON_COUNTER: int = 2  # 源 :95 attack_counter==2 召唤随机英雄
const HEROINDEX_STEP: int = 2  # 源 :118 heroindex 步进 +2
const NPC_UP_ID: int = 1
const NPC_DOWN_ID: int = 2

var _random_heros: Array[int] = []  # 源 :5 randomHeros（init 随机填 10 英雄 tid）


# 源 :189-195 takeDamage：basefunc dmg + skill4damage 累计（atk4 期间）。
func _take_damage(unit: Variant, params: Dictionary) -> float:
	var dmg: float = unit._take_damage_default(params)
	if unit.custom_data.get("skill4damage", null) != null:
		unit.custom_data["skill4damage"] = float(unit.custom_data["skill4damage"]) + dmg
	return dmg


# 源 :6-9 atk2 power：返 [target.HP × caster.atk2damage, 1]（百分比生命伤害）。
func _atk2_power(skill: Variant, _src: Variant, target: Variant) -> Array:
	var caster: Variant = skill.caster
	return [float(target.attribs.get("HP", 0)) * float(caster.custom_data.get("atk2damage", 0)), SKILL2_CRIT]


# 源 :167-188 atk/atk4 createProjectile：basefunc + enableTrack + 3D 追踪速度增益 +800。
func _create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = skill._create_projectile_default()
	var target: Variant = projectile.skill.target
	if target == null:
		return null
	projectile.enable_track(target)
	var targetxy: Vector2 = target.position - projectile.position
	var targetz: float = -float(projectile.height)
	var u: float = pow(targetxy.x * targetxy.x + targetxy.y * targetxy.y + targetz * targetz, NORM_POWER)
	var vel: Vector2 = projectile.velocity
	vel.x += u * targetxy.x * PROJECTILE_TRACK_V
	vel.y += u * targetxy.y * PROJECTILE_TRACK_V
	projectile.velocity = vel
	projectile.z_speed = float(projectile.z_speed) + u * targetz * PROJECTILE_TRACK_V
	return projectile


# 源 :66-73 atk3 start：basefunc + npc_up/down setAction atk2。
func _atk3_start(skill: Variant, target: Variant) -> void:
	skill._start_default(target)
	var caster: Variant = skill.caster
	var npc_up: Variant = caster.custom_data.get("npc_up", null)
	var npc_down: Variant = caster.custom_data.get("npc_down", null)
	if npc_up:
		npc_up.set_action("atk2", false, false)
	if npc_down:
		npc_down.set_action("atk2", false, false)


# 源 :91-165 atk3 takeEffectAt：counter==1 basefunc / counter==2 召唤随机英雄×2（tid 取 randomHeros，mDuration 15，Buff 89+111，mp=900）。
func _atk3_take_effect_at(skill: Variant, location: Vector2, src: Variant) -> void:
	var counter: int = int(skill.attack_counter)
	if counter == 1:
		BattleSkillEffect.take_effect_at(skill, location, src)
		return
	if counter != ATK3_SUMMON_COUNTER:
		return
	var caster: Variant = skill.caster
	var heroindex: int = int(caster.custom_data.get("heroindex", INIT_HERO_INDEX))
	var idx1: int = (heroindex + 1) % RANDOM_HERO_COUNT  # 源 :98 (heroindex+1)%10+1 → GD 0-based
	var idx2: int = (heroindex + HEROINDEX_STEP) % RANDOM_HERO_COUNT  # 源 :116
	caster.custom_data["heroindex"] = heroindex + HEROINDEX_STEP  # 源 :118
	var skill_levels: Dictionary = {"1": int(caster.level), "2": int(caster.level), "3": int(caster.level), "4": int(caster.level)}
	var proto1: Dictionary = {"_tid": int(_random_heros[idx1]), "_level": ATK3_LEVEL, "_stars": int(caster.stars), "_skill_levels": skill_levels, "_rank": int(caster.rank)}
	var proto2: Dictionary = {"_tid": int(_random_heros[idx2]), "_level": ATK3_LEVEL, "_stars": int(caster.stars), "_skill_levels": skill_levels, "_rank": int(caster.rank)}
	var config: Dictionary = {"is_monster": true, "hp_mod": NEW_HERO_HP_MOD, "dps_mod": NEW_HERO_DPS_MOD, "size_mod": NEW_HERO_SIZE_MOD}
	var h1: BattleUnit = BattleUnit.new(proto1, int(caster.camp), config, caster.cm, caster.engine, {}, caster.skill_lib)
	var h2: BattleUnit = BattleUnit.new(proto2, int(caster.camp), config, caster.cm, caster.engine, {}, caster.skill_lib)
	h1.custom_data["mDuration"] = NEW_HERO_DURATION
	h2.custom_data["mDuration"] = NEW_HERO_DURATION
	h1.hero_hooks["update"] = Callable(self, "_new_hero_update")
	h2.hero_hooks["update"] = Callable(self, "_new_hero_update")
	h1.isDeathWithEffect = true
	h2.isDeathWithEffect = true
	var binfo1: Variant = caster.cm.lookup(&"Buff", "", BUFF_MIRROR)
	var binfo2: Variant = caster.cm.lookup(&"Buff", "", BUFF_111)
	h1.add_buff(binfo1, caster)
	h2.add_buff(binfo1, caster)
	h1.add_buff(binfo2, caster)
	h2.add_buff(binfo2, caster)
	var loc1: Vector2 = Vector2(caster.position.x + ATK3_LOC1_X, caster.position.y + ATK3_LOC1_Y)
	var loc2: Vector2 = Vector2(caster.position.x + ATK3_LOC2_X, caster.position.y + ATK3_LOC2_Y)
	h1.mp = NEW_HERO_MP
	h2.mp = NEW_HERO_MP
	h1.direction = int(caster.direction)
	h2.direction = int(caster.direction)
	caster.engine.summon_unit(h1, loc1, caster, "Idle")
	caster.engine.summon_unit(h2, loc2, caster, "Idle")
	caster.custom_data["newHero"] = h1
	caster.custom_data["newHero2"] = h2


# 源 :56-60 atk4 start：basefunc + skill4damage=1（累计标记）。
func _atk4_start(skill: Variant, target: Variant) -> void:
	skill._start_default(target)
	skill.caster.custom_data["skill4damage"] = 1


# 源 :74-82 atk4 update：basefunc + skill4damage>maxDamage → finish+hurt+清标记。
func _atk4_update(skill: Variant, dt_action: float, dt_cd: float) -> void:
	skill._update_default(dt_action, dt_cd)
	var caster: Variant = skill.caster
	var s4d: float = float(caster.custom_data.get("skill4damage", 0))
	var maxd: float = float(caster.custom_data.get("maxDamage", INIT_MAX_DAMAGE))
	if s4d > 0 and s4d > maxd:
		skill.finish()
		caster.hurt()
		caster.custom_data["skill4damage"] = null


# 源 :61-65 atk4 finish：basefunc + skill4damage=nil。
func _skill4_finish(skill: Variant) -> void:
	skill._finish_default()
	skill.caster.custom_data["skill4damage"] = null


# 源 :49-55 atk5 createBuff：buff.shield=40000 + onRemoved/update hook。
func _atk5_create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)
	buff.custom_data["shield"] = SHIELD_VALUE
	buff.hero_hooks["onRemoved"] = Callable(self, "_skill5_buff_on_removed")
	buff.hero_hooks["update"] = Callable(self, "_buff_update")
	return buff


# 源 :15-17 buff update：basefunc only（空包装）。
func _buff_update(buff: Variant, dt: float) -> void:
	buff._update_default(dt)


# 源 :18-44 atk5 onRemoved：shield<=0 破盾（敌方 buff123+takeHeal mp500/hp99999 + maxDamage=150000）+ enterActionStage(2) + basefunc。
func _skill5_buff_on_removed(buff: Variant) -> void:
	var caster: Variant = buff.owner
	if float(buff.custom_data.get("shield", 0)) <= 0:
		for unit in caster.engine.foreach_alive_unit(-int(caster.camp)):
			var binfo1: Variant = caster.cm.lookup(&"Buff", "", SHIELD_BREAK_BUFF)
			unit.add_buff(binfo1, unit)
			unit.take_heal(SHIELD_BREAK_MP_HEAL, "mp", unit)
			unit.take_heal(SHIELD_BREAK_HP_HEAL, "hp", unit)
		caster.custom_data["maxDamage"] = MAX_DAMAGE_ENRAGE
	caster.enter_action_stage(STAGE_ENRAGE)
	buff._on_removed_default()


# 源 :196-206 atk6 start：useskill6=true + npc_up/down setAction Idle1change2 + onActionFinished hook + basefunc。
# 源 :205 basefunc(skill) 不传 target（Boss 阶段大招无目标，AncientTreant/BossCoco/Huskar/KOTL/Sil 同模式）。
func _atk6_start(skill: Variant, _target: Variant) -> void:
	var caster: Variant = skill.caster
	caster.custom_data["useskill6"] = true
	var npc_up: Variant = caster.custom_data.get("npc_up", null)
	var npc_down: Variant = caster.custom_data.get("npc_down", null)
	if npc_up:
		npc_up.set_action("Idle1change2", false, false)
		npc_up.hero_hooks["onActionFinished"] = Callable(self, "_npc_on_action_finished")
	if npc_down:
		npc_down.set_action("Idle1change2", false, false)
		npc_down.hero_hooks["onActionFinished"] = Callable(self, "_npc_on_action_finished")
	skill._start_default(null)  # 源 :205 basefunc(skill) 不传 target（Boss 阶段大招无目标）


# 源 :10-14 npc onActionFinished：Idle1change2/atk2 → setAction Idle2。
func _npc_on_action_finished(npc: Variant) -> void:
	if String(npc.action_name) == "Idle1change2" or String(npc.action_name) == "atk2":
		npc.set_action("Idle2", true, false)


# 源 :207-215 atk6 finish：basefunc + dps_mod×1.5 + atk2damage=0.16 + enterActionStageFromOneStage(5)。
func _atk6_finish(skill: Variant) -> void:
	skill._finish_default()
	var caster: Variant = skill.caster
	var dps: float = float(caster.config.get("dps_mod", 0))
	if dps > 0:
		caster.config["dps_mod"] = dps * ATK6_DPS_MULT
	caster.custom_data["atk2damage"] = ATK6_ATK2_RATIO
	caster.enter_action_stage_from_one_stage(STAGE_FINAL)


# 源 :83-90 newHero update：mDuration 倒计 ≤0 die；else basefunc。
func _new_hero_update(unit: Variant, dt: float) -> void:
	var dur: float = float(unit.custom_data.get("mDuration", NEW_HERO_DURATION)) - dt
	unit.custom_data["mDuration"] = dur
	if dur <= 0.0:
		unit.die(null)
	else:
		unit._update_default(dt)


func apply(hero: Variant) -> void:
	hero.hero_hooks["takeDamage"] = Callable(self, "_take_damage")
	hero.is_boss_create_with_effect = false  # 源 :218
	hero.set_disapear_when_die(false)  # 源 :219
	hero.custom_data["npc_up"] = hero.engine.create_npc(NPC_UP_ID, true, hero)
	hero.custom_data["npc_down"] = hero.engine.create_npc(NPC_DOWN_ID, true, hero)
	_random_heros = []
	var i: int = 0
	while i < RANDOM_HERO_COUNT:  # 源 :256-263 随机 10 英雄 tid 排除 33
		var heroid: int = int(hero.engine.rng.randf() * RANDOM_HERO_RANGE) + 1
		while heroid == RANDOM_HERO_EXCLUDE:
			heroid = int(hero.engine.rng.randf() * RANDOM_HERO_RANGE) + 1
		_random_heros.append(heroid)
		i += 1
	var skillatk: Variant = hero.skills.get("TitanHead_atk")
	if skillatk:
		skillatk.hero_hooks["createProjectile"] = Callable(self, "_create_projectile")
	var skillatk2: Variant = hero.skills.get("TitanHead_atk2")
	if skillatk2:
		skillatk2.hero_hooks["power"] = Callable(self, "_atk2_power")
	var skillatk3: Variant = hero.skills.get("TitanHead_atk3")
	if skillatk3:
		skillatk3.hero_hooks["start"] = Callable(self, "_atk3_start")
		skillatk3.hero_hooks["takeEffectAt"] = Callable(self, "_atk3_take_effect_at")
	var skillatk4: Variant = hero.skills.get("TitanHead_atk4")
	if skillatk4:
		skillatk4.hero_hooks["createProjectile"] = Callable(self, "_create_projectile")
		skillatk4.hero_hooks["start"] = Callable(self, "_atk4_start")
		skillatk4.hero_hooks["update"] = Callable(self, "_atk4_update")
		skillatk4.hero_hooks["finish"] = Callable(self, "_skill4_finish")
	var skillatk5: Variant = hero.skills.get("TitanHead_atk5")
	if skillatk5:
		skillatk5.hero_hooks["createBuff"] = Callable(self, "_atk5_create_buff")
	var skillatk6: Variant = hero.skills.get("TitanHead_atk6")
	if skillatk6:
		skillatk6.hero_hooks["start"] = Callable(self, "_atk6_start")
		skillatk6.hero_hooks["finish"] = Callable(self, "_atk6_finish")
	hero.custom_data["atk2damage"] = INIT_ATK2_RATIO
	hero.custom_data["maxDamage"] = INIT_MAX_DAMAGE
	hero.custom_data["heroindex"] = INIT_HERO_INDEX
	# 源 :262 PreloadPuppetRcsByUnitId View 跳过
