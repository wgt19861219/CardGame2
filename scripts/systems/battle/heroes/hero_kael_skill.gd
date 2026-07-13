class_name HeroKaelSkill
extends RefCounted

## Kael 技能 hook + 投放球辅助 — 照源 Kael.lua:67-106/136-196/208-454 翻译（Phase 2.7，2026-07-01）。
## 10 技能 hook（skillshock/skillfrozen/skillfireman/skillmagnet/skillmeteor/skillswift/skillult/skillicewall/skillatk/skillskyfire）
##   + 投放球辅助（_deliver_ball/_deliver_rand_ball/_show_ball/_tap_ball/_auto_tap_ball/_special_check_enable_ai）。
## class_name 全局供 hero_kael.gd apply 调（避 preload 循环）。辅助 static 供 skill hook 同文件调。
## engine 槽位见 BattleEngineBall。View（BallCreate/playEffectOnScene/ballSlots）跳过 Phase 4。

const DEFAULT_DURATION: float = 6.0       # 源 :70 deliverBall lifetime 默认
const AUTO_PICK_INIT: float = 0.6         # 源 :77 autoPick
const AUTO_GET_INIT: float = 0.25         # 源 :78 autoGet
const BALL_NAME_LIST: Array[String] = ["ice", "fire", "lightning"]  # 源 ballName :62-66
const BALL_KEYWORDS: Dictionary = {"ice": true, "fire": true, "lightning": true}  # 源 ballKeywords :57-61
const RAND_RANGE_3: int = 3               # 源 :93 rand*3+1（deliverRandBall 选球种）
const FIREMAN_TID: int = 146              # 源 skillfireman _tid=146
const FIREMAN_SPAWN_OFFSET: int = 50      # 源 location = caster.pos + 50*direction
const METEOR_HEIGHT: int = 500            # 源 :300 projectile.height=500
const METEOR_TILE_VZ: int = -600          # 源 :288 tileVz=-600
const METEOR_FAR_THRESHOLD: int = 200     # 源 :294 distance>200 判远
const METEOR_FAR_VX: int = 200            # 源 :296 tileVx=200（远）
const METEOR_TRIGGER_DISTANCE: int = 50   # 源 :283 trigger_distance=50（tile2 步进）
const METEOR_TILE2_HEIGHT: int = 35       # 源 :356 projectile2.height=35
const METEOR_TILE_OTT_HEIGHT: int = 50    # 源 :348 Tile OTT Height（meteor 二段弹道瓦片效果高度，区别于 projectile2.height=35，P1-6）
const METEOR_TILE2_VX: int = 160          # 源 :358 velocity=160*direction
const METEOR_TILE2_STEP: int = 160        # 源 :316 tile_distance -= 160*dt
const METEOR_TILE2_MAX: int = 310         # 源 :327 distance>=310 淡出
const METEOR_TILE2_FADEOUT: float = 0.5   # 源 :330 fadeout_timer=0.5
const MAGNET_TARGET_Y: int = -30          # 源 :265 magnetorigin target 时 y=-30
const MAGNET_CASTER_Y: int = 0            # 源 :269 magnetorigin caster 时 y=0
const ICEWALL_ORIGIN_Y: int = 0           # 源 :406 icewall origin y=0
const ULT_COUNTER_MAX: int = 6            # 源 :392 skillult attack_counter<=6
const SWIFT_BUFF_CD: int = 0              # 源 :383 swiftbuff CD=0
const SWIFT_BUFF_GLOBAL_CD: int = 1       # 源 :384 swiftbuff Global CD=1
const SHOCK_BUFF_ID: int = 35             # 源 :209 skillshock bid=35
const SKYFIRE_AFFECT_INIT: int = 1        # 源 :427/452 affectnum 默认 1
const SKILLATK_PHASE_COUNT: int = 2      # 源 :411 rand*2+1（atk startPhase 随机 phase 数）
const SKILLATK_PHASE_ULT: int = 2        # 源 :419 current_phase_idx==2（atk 第二阶段投球）


# 源 init_hero 技能装配段（Kael.lua:456-500）：10 技能 hook 注册。
func apply(hero: Variant) -> void:
	var skillshock: Variant = hero.skills.get("Kael_all")
	var skillfrozen: Variant = hero.skills.get("Kael_ice3")
	var skillfireman: Variant = hero.skills.get("Kael_fire2ice")
	var skillmagnet: Variant = hero.skills.get("Kael_lightning3")
	var skillmeteor: Variant = hero.skills.get("Kael_fire2lightning")
	var skillswift: Variant = hero.skills.get("Kael_lightning2fire")
	var skillult: Variant = hero.skills.get("Kael_book")
	var skillatk: Variant = hero.skills.get("Kael_atk")
	var skillicewall: Variant = hero.skills.get("Kael_ice2fire")
	var skillskyfire: Variant = hero.skills.get("Kael_fire3")
	if skillshock:
		skillshock.hero_hooks["createBuff"] = Callable(self, "_skillshock_create_buff")
	if skillfrozen:
		skillfrozen.hero_hooks["createBuff"] = Callable(self, "_skillfrozen_create_buff")
	if skillfireman:
		skillfireman.hero_hooks["takeEffectOn"] = Callable(self, "_skillfireman_take_effect_on")
	if skillmagnet:
		skillmagnet.hero_hooks["takeEffectAt"] = Callable(self, "_skillmagnet_take_effect_at")
		skillmagnet.hero_hooks["takeEffectOn"] = Callable(self, "_skillmagnet_take_effect_on")
	if skillmeteor:
		skillmeteor.hero_hooks["createProjectile"] = Callable(self, "_skillmeteor_create_projectile")
		skillmeteor.hero_hooks["takeEffectAt"] = Callable(self, "_skillmeteor_take_effect_at")
	if skillswift:
		skillswift.hero_hooks["createBuff"] = Callable(self, "_skillswift_create_buff")
	if skillult:
		skillult.hero_hooks["onAttackFrame"] = Callable(self, "_skillult_on_attack_frame")
	if skillicewall:
		skillicewall.hero_hooks["takeEffectAt"] = Callable(self, "_skillicewall_take_effect_at")
	if skillatk:
		skillatk.hero_hooks["startPhase"] = Callable(self, "_skillatk_start_phase")
		skillatk.hero_hooks["onPhaseFinished"] = Callable(self, "_skillatk_on_phase_finished")
		skillatk.hero_hooks["onAttackFrame"] = Callable(self, "_skillatk_on_attack_frame")
	if skillskyfire:
		skillskyfire.hero_hooks["takeEffectAt"] = Callable(self, "_skillskyfire_take_effect_at")
		skillskyfire.hero_hooks["power"] = Callable(self, "_skillskyfire_power")


# ===== 投放球辅助（源 Kael.lua local 函数）=====

# 源 deliverBall（:67-89）：投放一球到 deliveredBalls + 占槽位。View BallCreate 跳过 Phase 4。
static func _deliver_ball(kael: Variant, deliverer: Variant, t: String, lifetime: float, is_manual: bool, _skill: Variant, _from_launch_point: bool) -> void:
	var engine: Variant = kael.engine
	var idx: int = BattleEngineBall.increase_ball(engine)
	var ds_idx: int = BattleEngineBall.get_manual_delivered_empty_slot(engine, float(deliverer.position.x)) if is_manual else BattleEngineBall.get_delivered_empty_slot(engine, float(deliverer.position.x))
	var duration: float = lifetime  # 源 :70 lifetime or 6（float 非 nil 总返 lifetime；0→0 照源，P2-7。调用点不传 0 无影响）
	kael.delivered_balls[idx] = {"balltype": t, "duration": duration, "idx": idx, "deliveredSlotIdx": ds_idx, "deliverer": deliverer, "autoPick": AUTO_PICK_INIT, "autoGet": AUTO_GET_INIT, "startAutoGet": false, "tapped": false, "myslotidx": 0}
	engine.used_delivered_ball_slots[ds_idx] = true


# 源 deliverRandBall（:90-96）：随机投 N 球（rand*3+1 选球种）。
static func _deliver_rand_ball(kael: Variant, deliverer: Variant, number: int, lifetime: float, is_manual: bool, skill: Variant, from_launch_point: bool) -> void:
	var n: int = number if number > 0 else 1  # 源 :91 number or 1
	for i in range(n):
		var k: int = int(kael.engine.rng.randf() * RAND_RANGE_3) + 1  # 源 :93 rand*3+1
		_deliver_ball(kael, deliverer, BALL_NAME_LIST[k - 1], lifetime, is_manual, skill, from_launch_point)


# 源 showBall（:97-106，单位方法）：按 skill.info["Skill Tags"][eventIdx] 投球（球种不合法跳过）。
static func _show_ball(kael: Variant, deliverer: Variant, skill: Variant, event_idx: int) -> void:
	if not bool(kael.is_alive()):
		return
	var tags: Variant = skill.info.get("Skill Tags", [])
	if not tags is Array or event_idx >= (tags as Array).size():
		return
	var t: String = str((tags as Array)[event_idx])
	if not BALL_KEYWORDS.has(t):
		return
	_deliver_ball(kael, deliverer, t, -1.0, false, null, false)


# 源 tapBall（:143-158，单位方法）：startAutoGet + myslotidx（autoGet 倒计后 addEnergyBall）。View onTapped2 跳过。
static func _tap_ball(kael: Variant, ext: Array) -> void:
	var idx: int = int(ext[0])
	var my_slot_idx: int = int(ext[1])
	if not kael.delivered_balls.has(idx):
		kael.energy_ball_manager.slots[my_slot_idx - 1].occupied = false  # 源 slots[myslotidx]（Lua 1-indexed）
		return
	var ball: Dictionary = kael.delivered_balls[idx]
	ball["startAutoGet"] = true
	ball["myslotidx"] = my_slot_idx


# 源 autoTapBall（:169-190，单位方法）：aiMode/auto_combat 自动 tap（autoPick 衰减到 0）。
static func _auto_tap_ball(kael: Variant) -> void:
	if not bool(kael.ai_mode) and not bool(kael.auto_combat):
		return
	for idx in kael.delivered_balls.keys():
		if not kael.delivered_balls.has(idx):
			continue
		var ball: Dictionary = kael.delivered_balls[idx]
		if float(ball.get("autoPick", 0.0)) < BattleEnergyBallManager.EPSILON and not bool(ball.get("tapped", false)):
			var pair: Array = kael.energy_ball_manager._get_empty_slot(true)
			var s: Variant = pair[0]
			if s != null:
				s.occupied = true
				ball["tapped"] = true
				if bool(kael.ai_mode):
					_tap_ball(kael, [int(ball.get("idx", 0)), int(pair[1])])
				elif bool(kael.auto_combat):
					BattleEngineBall.manual_tap_ball(kael.engine, ball.get("deliverer"), int(ball.get("idx", 0)), int(pair[1]), true)


# ===== 技能 hook =====

# 源 skillshock_createBuff（:208-213）：Buff 35 查表 addBuff + basefunc。
func _skillshock_create_buff(skill: Variant, target: Variant) -> Variant:
	var binfo: Dictionary = skill.caster.cm.lookup(&"Buff", "", SHOCK_BUFF_ID)
	target.add_buff(binfo, skill.caster)
	return skill._create_buff_default(target)  # basefunc


# 源 skillfrozen_createBuff（:221-225）：basefunc + buff.onDamaged 注册 frozenbuff hook。
func _skillfrozen_create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)  # basefunc
	buff.hero_hooks["onDamaged"] = Callable(self, "_frozenbuff_on_damaged")
	return buff


# 源 frozenbuff_onDamaged（:214-220）：basefunc + !is_boss && !Hurt → hurt。
func _frozenbuff_on_damaged(buff: Variant, damage: float, damage_type: String) -> float:
	var dmg: float = buff._on_damaged_default(damage, damage_type)  # basefunc
	if not bool(buff.owner.config.get("is_boss", false)) and buff.owner.state != BattleUnit.State.HURT:
		buff.owner.hurt()
	return dmg


# 源 skillfireman_takeEffectOn（:226-250）：basefunc + 召唤火人 tid=146 + summonUnit + caster.oldfireman。
func _skillfireman_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	skill._take_effect_on_default(target, src)  # basefunc
	var caster: Variant = skill.caster
	var proto: Dictionary = {"_tid": FIREMAN_TID, "_level": skill.level}
	var config: Dictionary = {"is_monster": true, "estimate_rank": true, "estimate_skill": true}
	var oldfireman: Variant = caster.custom_data.get("oldfireman")
	if oldfireman != null and bool(oldfireman.is_alive()):
		oldfireman.die(null)
	var fireman: BattleUnit = BattleUnit.new(proto, int(caster.camp), config, caster.cm, caster.engine, {}, caster.skill_lib)
	var location: Vector2 = Vector2(float(caster.position.x) + FIREMAN_SPAWN_OFFSET * float(caster.direction), float(caster.position.y))
	fireman.direction = caster.direction
	caster.engine.summon_unit(fireman, location, caster)
	caster.custom_data["oldfireman"] = fireman
	return [true, 0.0]  # 源 void → 续7 契约透传 [true, 0.0]


# 源 skillmagnet_takeEffectOn（:251-258）：succ=basefunc（源只传 target）+ succ 时 Holy mp 伤害。
func _skillmagnet_take_effect_on(skill: Variant, target: Variant, _src: Variant) -> Array:
	var r: Array = skill._take_effect_on_default(target, null)  # basefunc（源 basefunc(skill, target) 只传 2 参，source=nil）
	if bool(r[0]):
		var power: float = float(skill.info.get("Script Arg1", 0.0))
		target.take_damage({"amount": power, "damage_type": "Holy", "field": "mp", "source": skill.caster})
	return r


# 源 skillmagnet_takeEffectAt（:259-282）：counter==1 设 magnetorigin + View effect / else basefunc(magnetorigin)。
func _skillmagnet_take_effect_at(skill: Variant, _location: Vector2, src: Variant) -> void:
	if int(skill.attack_counter) == 1:
		if skill.target != null:
			skill.custom_data["magnetorigin"] = Vector2(float(skill.target.position.x), MAGNET_TARGET_Y)
		else:
			var caster: Variant = skill.caster
			skill.custom_data["magnetorigin"] = Vector2(float(caster.position.x) + float(skill.info.get("X Shift", 0.0)) * float(caster.direction), MAGNET_CASTER_Y)
		# playEffectOnScene（View）Phase 4
	else:
		BattleSkillEffect.take_effect_at(skill, Vector2(skill.custom_data.get("magnetorigin", Vector2.ZERO)), src)  # basefunc


# 源 skillmeteor_createProjectile（:284-312）：basefunc + 弹道 height/velocity/zSpeed/position + meteorDirection。
func _skillmeteor_create_projectile(skill: Variant) -> Variant:
	var projectile: Variant = skill._create_projectile_default()  # basefunc
	var caster: Variant = skill.caster
	var projectile_x: float = float(caster.position.x)
	var distance: float = abs(float(caster.position.x) - float(skill.target.position.x))
	var tile_vx: float = distance  # 源 :298-299 else 分支 tileVx = distance
	if distance > METEOR_FAR_THRESHOLD:  # 源 :294 distance > 200
		projectile_x = float(skill.target.position.x) - float(caster.direction) * METEOR_FAR_THRESHOLD
		tile_vx = METEOR_FAR_VX
	projectile.height = METEOR_HEIGHT
	projectile.velocity = Vector2(tile_vx * float(caster.direction), 0.0)
	skill.custom_data["meteorDirection"] = int(caster.direction)
	projectile.z_speed = METEOR_TILE_VZ
	projectile.position = Vector2(projectile_x, float(caster.position.y))
	return projectile


# 源 skillmeteor_takeEffectAt（:340-369）：source.tile2 时 basefunc / else wraptable 改 info + basefunc + selectTarget + ProjectileCreate tile2 + addProjectile + 还原 info。
func _skillmeteor_take_effect_at(skill: Variant, location: Vector2, src: Variant) -> void:
	var originfo: Dictionary = skill.info
	if src != null and bool(src.custom_data.get("tile2", false)):
		BattleSkillEffect.take_effect_at(skill, location, src)  # basefunc
	else:
		var new_info: Dictionary = originfo.duplicate()  # 源 ed.wraptable（续3 模式：duplicate + 覆盖）
		new_info["Point Effect"] = "eff_point_Kael_atk2_2.cha"
		new_info["Point Zorder"] = 1
		new_info["Tile OTT Height"] = METEOR_TILE_OTT_HEIGHT  # 源 :348 =50（P1-6：区别于 projectile2.height=35）
		new_info["Tile Art"] = "eff_tile_Kael_atk2.cha"
		skill.info = new_info
		BattleSkillEffect.take_effect_at(skill, location, src)  # basefunc
		skill._select_target(null)
		var projectile2: BattleProjectile = BattleProjectile.new(skill)
		projectile2.custom_data["tile2"] = true
		projectile2.hero_hooks["update"] = Callable(self, "_projectile2_update")
		projectile2.height = METEOR_TILE2_HEIGHT
		projectile2.velocity = Vector2(METEOR_TILE2_VX * float(skill.custom_data.get("meteorDirection", 1)), 0.0)
		projectile2.custom_data["tile_distance"] = METEOR_TRIGGER_DISTANCE
		projectile2.position = Vector2(float(location.x), float(location.y))
		skill.caster.engine.add_projectile(projectile2)
		skill.info = originfo


# 源 projectile2_update（:313-339，projectile.update override）：tile2 二段弹道（每 trigger_distance 距离 takeEffectAt）+ distance>=310 淡出终止。
func _projectile2_update(projectile2: Variant, dt: float) -> void:
	var skill: Variant = projectile2.skill
	var distance: float = float(projectile2.custom_data.get("tile_distance", 0.0)) - METEOR_TILE2_STEP * dt
	while distance <= 0.0:
		var location: Vector2 = Vector2(float(projectile2.position.x) - distance, float(projectile2.position.y))
		skill.take_effect_at(location, projectile2)
		distance += METEOR_TRIGGER_DISTANCE
	projectile2.custom_data["tile_distance"] = distance
	projectile2._update_default(dt)  # basefunc
	if float(projectile2.distance) >= METEOR_TILE2_MAX:
		if not projectile2.custom_data.has("fadeout_timer"):
			projectile2.velocity = Vector2.ZERO
			projectile2.custom_data["fadeout_timer"] = METEOR_TILE2_FADEOUT
		else:
			projectile2.custom_data["fadeout_timer"] = float(projectile2.custom_data["fadeout_timer"]) - dt
		if float(projectile2.custom_data.get("fadeout_timer", 0.0)) < 0.0:
			projectile2.terminate()


# 源 skillswift_createBuff（:376-388）：basic_skill CD=0/GlobalCD=1 + onRemoved 还原。
func _skillswift_create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)  # basefunc
	var target_basic_skill: Variant = buff.owner.basic_skill
	var originfo: Dictionary = target_basic_skill.info
	buff.custom_data["originfo"] = originfo
	target_basic_skill.cd_remaining = 0.0
	var new_info: Dictionary = originfo.duplicate()  # 源 ed.wraptable
	new_info["CD"] = SWIFT_BUFF_CD
	new_info["Global CD"] = SWIFT_BUFF_GLOBAL_CD
	target_basic_skill.info = new_info
	buff.hero_hooks["onRemoved"] = Callable(self, "_swiftbuff_on_removed")
	return buff


# 源 swiftbuff_onRemoved（:370-375，buff.onRemoved override）：还原 basic_skill.info + basefunc。
func _swiftbuff_on_removed(buff: Variant) -> void:
	var originfo: Variant = buff.custom_data.get("originfo")
	if originfo != null and originfo is Dictionary:
		buff.owner.basic_skill.info = originfo
	buff._on_removed_default()  # basefunc


# 源 skillult_onAttackFrame（:389-401）：counter<=6 时 deliverRandBall（counter>1）/ else deliverRandBall + basefunc。
func _skillult_on_attack_frame(skill: Variant) -> void:
	var caster: Variant = skill.caster
	var balltime: float = float(skill.info.get("Script Arg1", 0.0))
	if int(skill.attack_counter) <= ULT_COUNTER_MAX:
		skill.attack_counter = int(skill.attack_counter) + 1
		if int(skill.attack_counter) > 1:
			_deliver_rand_ball(caster, caster, 1, balltime, true, skill, true)
	else:
		_deliver_rand_ball(caster, caster, 1, balltime, true, skill, true)
		skill._on_attack_frame_default()  # basefunc


# 源 skillicewall_takeEffectAt（:402-409）：origin={location.x, 0} + basefunc。
func _skillicewall_take_effect_at(skill: Variant, location: Vector2, _src: Variant) -> void:
	var origin: Vector2 = Vector2(float(location.x), ICEWALL_ORIGIN_Y)
	BattleSkillEffect.take_effect_at(skill, origin, null)  # basefunc（源 basefunc(skill, origin) 无 source）


# 源 skillatk_startPhase（:410-413）：随机 idx 1-2 传 basefunc（对齐 math.floor(ed.rand()*2+1)）。
func _skillatk_start_phase(skill: Variant, _idx: int) -> void:
	var rand_id: int = int(skill.caster.engine.rng.randf() * SKILLATK_PHASE_COUNT) + 1
	BattleSkillPhase.start_phase(skill, rand_id)  # basefunc


# 源 skillatk_onPhaseFinished（:414-416）：finish（不推进下一 phase）。
func _skillatk_on_phase_finished(skill: Variant) -> void:
	skill.finish()


# 源 skillatk_onAttackFrame（:417-423）：current_phase_idx==2 时 deliverRandBall + basefunc。
func _skillatk_on_attack_frame(skill: Variant) -> void:
	var caster: Variant = skill.caster
	if int(skill.current_phase_idx) == SKILLATK_PHASE_ULT:
		_deliver_rand_ball(caster, caster, 1, DEFAULT_DURATION, false, skill, true)
	skill._on_attack_frame_default()  # basefunc


# 源 skillskyfire_power（:424-430）：power/affectnum + coefficient（多目标衰减）。
func _skillskyfire_power(skill: Variant, src: Variant, target: Variant) -> Array:
	var base: Array = BattleSkillEffect.power(skill, src, target)  # basefunc（源 power, coefficient = basefunc(...)）
	var affectnum: int = int(skill.custom_data.get("affectnum", SKYFIRE_AFFECT_INIT))
	return [float(base[0]) / float(affectnum), float(base[1])]


# 源 skillskyfire_takeEffectAt（:431-454）：AOE affectlist 统计 + affectnum + basefunc。
func _skillskyfire_take_effect_at(skill: Variant, location: Vector2, src: Variant) -> void:
	var info: Dictionary = skill.info
	var direction: float = float(skill.caster.direction)
	var origin: Vector2 = Vector2(float(location.x) + float(info.get("X Shift", 0.0)) * direction, float(location.y))
	var affectlist: Array = []
	var shape: String = str(info.get("AOE Shape", ""))
	var arg1: float = float(info.get("Shape Arg1", 0.0))
	var arg2: float = float(info.get("Shape Arg2", 0.0))
	var dt: String = str(info.get("Damage Type", ""))
	for unit in skill.caster.engine.foreach_alive_unit(skill._affected_camp()):
		if (dt == "AD" or dt == "AP") and unit == skill.caster:
			continue
		var p2: Vector2 = unit.position - origin
		p2 = Vector2(p2.x * direction, p2.y)
		if BattleSkillEffect.test_point_in_shape(p2, shape, arg1, arg2):
			affectlist.append(unit)
	skill.custom_data["affectnum"] = affectlist.size() if affectlist.size() > 0 else SKYFIRE_AFFECT_INIT  # 源 #affectlist or 1
	BattleSkillEffect.take_effect_at(skill, location, src)  # basefunc
