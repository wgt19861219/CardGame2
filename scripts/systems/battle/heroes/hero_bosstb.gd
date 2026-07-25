extends RefCounted

## BossTB（Boss 版恐怖利刃）— 照源 BossTB.lua（203 行）翻译。
## 复用续8 TB 变身系 + 幻象召唤模式：BossTB_atk6（ult）createBuff 变身（改 BossTB_atk info wraptable + onRemoved 还原，
##   无 mp 耗尽 update）/ finish x偏移×1.2 / takeEffectOn counter==1 View / start 加 Buff90 +
## BossTB_atk2 takeEffectAt 召唤 4 幻象（tid 129/130 + 2 组位置 ±50x/∓100x + mDuration 倒计 die）+
## BossTB_atk3 canCastWithTarget（basefunc and ultBuff → true，正向互斥）。

const TB_RANGE_INTERVAL: float = 150.0
const MIRROR_TIME: float = 10.0
const TB_ULT_ATK_CD: float = 0.5
const MIRROR_NORMAL_TID: int = 129
const MIRROR_ULT_TID: int = 130
const MIRROR_BUFF_ID: int = 89
const ULT_BUFF_ID: int = 90
const MIRROR_X_NEAR: float = 50.0
const MIRROR_X_FAR: float = 100.0
const MIRROR_Y_NEAR_A: float = 30.0
const MIRROR_Y_NEAR_B: float = -30.0
const MIRROR_Y_FAR_A: float = 50.0
const MIRROR_Y_FAR_B: float = -50.0
const FINISH_X_OFFSET: float = 127.0
const FINISH_X_MULT: float = 1.2
const CD_RESTORE: float = 1.0
const HP_MOD: float = 0.5
const DPS_MOD_DIVISOR: float = 3.0
const DEFAULT_DPS_MOD: float = 1.0
const PLUS_RATIO: float = 0.9
const ATK_COUNTER_FIRST: int = 1


func _atk2_take_effect_at(skill: Variant, location: Vector2, src: Variant) -> void:
	BattleSkillEffect.take_effect_at(skill, location, src)
	var caster: Variant = skill.caster
	var in_ult: bool = caster.custom_data.get("ultBuff", null) != null
	var tid: int = MIRROR_ULT_TID if in_ult else MIRROR_NORMAL_TID
	var lvl: int = int(skill.level) if skill.level != null else 1
	var proto: Dictionary = {"_tid": tid, "_level": lvl, "_stars": int(caster.stars), "_rank": int(caster.rank)}
	var raw_dps: float = float(caster.config.get("dps_mod", 0.0)) / DPS_MOD_DIVISOR
	var config: Dictionary = {"is_monster": true, "estimate_rank": true, "hp_mod": HP_MOD, "dps_mod": raw_dps}
	var binfo: Variant = caster.cm.lookup(&"Buff", "", MIRROR_BUFF_ID)
	var dir: int = int(caster.direction)
	var m1: BattleUnit = _create_mirror(caster, proto, config, binfo, Vector2(location.x + MIRROR_X_NEAR * dir, location.y + MIRROR_Y_NEAR_A), dir)
	var m2: BattleUnit = _create_mirror(caster, proto, config, binfo, Vector2(location.x + MIRROR_X_NEAR * dir, location.y + MIRROR_Y_NEAR_B), dir)
	var m3: BattleUnit = _create_mirror(caster, proto, config, binfo, Vector2(location.x - MIRROR_X_FAR * dir, location.y + MIRROR_Y_FAR_A), dir)
	var m4: BattleUnit = _create_mirror(caster, proto, config, binfo, Vector2(location.x - MIRROR_X_FAR * dir, location.y + MIRROR_Y_FAR_B), dir)
	caster.custom_data["TBMirror"] = [m1, m2, m3, m4]


func _create_mirror(caster: Variant, proto: Dictionary, config: Dictionary, binfo: Variant, loc: Vector2, dir: int) -> BattleUnit:
	var mirror: BattleUnit = BattleUnit.new(proto, int(caster.camp), config, caster.cm, caster.engine, {}, caster.skill_lib)
	mirror.add_buff(binfo, caster)
	mirror.custom_data["mDuration"] = MIRROR_TIME
	mirror.hero_hooks["update"] = Callable(self, "_mirror_update")
	mirror.isDeathWithEffect = true
	mirror.direction = dir
	caster.engine.summon_unit(mirror, loc, caster)
	return mirror


func _mirror_update(unit: Variant, dt: float) -> void:
	var dur: float = float(unit.custom_data.get("mDuration", MIRROR_TIME)) - dt
	unit.custom_data["mDuration"] = dur
	if dur <= 0.0:
		unit.die(null)
	else:
		unit._update_default(dt)


func _ult_create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)
	buff.hero_hooks["onRemoved"] = Callable(self, "_ult_buff_on_removed")
	var skillatk: Variant = buff.owner.skills.get("BossTB_atk")
	if skillatk:
		skillatk.custom_data["originfo"] = skillatk.info
		var wrapped: Dictionary = skillatk.info.duplicate()
		wrapped["Max Range"] = float(skillatk.info.get("Max Range", 0)) + TB_RANGE_INTERVAL
		wrapped["CD"] = TB_ULT_ATK_CD
		wrapped["Global CD"] = TB_ULT_ATK_CD
		wrapped["Gain MP"] = 0
		wrapped["Track Type"] = "projectile"
		wrapped["AOE Origin"] = false
		wrapped["Plus Ratio"] = PLUS_RATIO
		wrapped["Impact Effect"] = "eff_impact_TB_atk.cha"
		skillatk.info = wrapped
		var max_r: float = float(wrapped.get("Max Range", 0))
		skillatk.max_range_sq = max_r * max_r
		skillatk.cd_remaining = TB_ULT_ATK_CD
	buff.owner.attack_range = float(buff.owner.attack_range) + TB_RANGE_INTERVAL
	buff.owner.global_cd = TB_ULT_ATK_CD
	buff.owner.custom_data["ultBuff"] = ATK_COUNTER_FIRST
	return buff


func _ult_buff_on_removed(buff: Variant) -> void:
	var owner: Variant = buff.owner
	var skillatk: Variant = owner.skills.get("BossTB_atk")
	if skillatk and skillatk.custom_data.has("originfo"):
		skillatk.info = skillatk.custom_data["originfo"]
		var max_r: float = float(skillatk.info.get("Max Range", 0))
		skillatk.max_range_sq = max_r * max_r
		skillatk.cd_remaining = CD_RESTORE
	owner.attack_range = float(owner.attack_range) - TB_RANGE_INTERVAL
	owner.custom_data["ultBuff"] = null
	buff._on_removed_default()
	owner.hurt()
	owner.set_action("Birth", false, true)


func _ult_finish(skill: Variant) -> void:
	skill._finish_default()
	var caster: Variant = skill.caster
	caster.position = Vector2(caster.position.x - float(caster.direction) * FINISH_X_OFFSET * FINISH_X_MULT, caster.position.y)


func _ult_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	if int(skill.attack_counter) == ATK_COUNTER_FIRST:
		skill._select_target(skill.caster)
		return [true, 0.0]
	return BattleSkillEffect.take_effect_on(skill, target, src)


func _ult_start(skill: Variant, target: Variant) -> void:
	var binfo: Variant = skill.caster.cm.lookup(&"Buff", "", ULT_BUFF_ID)
	skill.caster.add_buff(binfo, skill.caster)
	skill._start_default(target)


func _atk3_can_cast_with_target(skill: Variant, target: Variant) -> Dictionary:
	var base: Dictionary = skill._can_cast_with_target_default(target)
	if bool(base.get("ok", false)) and skill.caster.custom_data.get("ultBuff", null) != null:
		return base
	return {"ok": false, "reason": "bosstb atk3"}


func apply(hero: Variant) -> void:
	var skillatk2: Variant = hero.skills.get("BossTB_atk2")
	if skillatk2:
		skillatk2.hero_hooks["takeEffectAt"] = Callable(self, "_atk2_take_effect_at")
	hero.info["mDuration"] = MIRROR_TIME
	var skillult: Variant = hero.skills.get("BossTB_atk6")
	if skillult:
		skillult.hero_hooks["createBuff"] = Callable(self, "_ult_create_buff")
		skillult.hero_hooks["finish"] = Callable(self, "_ult_finish")
		skillult.hero_hooks["start"] = Callable(self, "_ult_start")
		skillult.hero_hooks["takeEffectOn"] = Callable(self, "_ult_take_effect_on")
	var skillatk3: Variant = hero.skills.get("BossTB_atk3")
	if skillatk3:
		skillatk3.hero_hooks["canCastWithTarget"] = Callable(self, "_atk3_can_cast_with_target")
