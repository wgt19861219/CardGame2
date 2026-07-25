extends RefCounted

## 恐怖利刃（TB）— 照源 TB.lua 翻译。
## TB_ult 变身（createBuff 改 TB_atk info 变身态射程/CD/弹道 + buff.update mp 耗尽取消 + onRemoved 还原 atk）
## + TB_atk2 召唤幻象（tid 129 常态/130 变身态 + mDuration 到期 die + setDeathWithEffect）。
## TB_atk3 短暂 debuff（加 Buff 17 + basefunc + removeBuff）。canCastWithTarget ultBuff 互斥。
## 复用续3 createBuff + 续4/5 buff update/onRemoved + 续5 canCastWithTarget + 续8 召唤模式。

const TB_RANGE_INTERVAL: float = 150.0
const MIRROR_TIME: float = 25.0
const TB_ULT_ATK_CD: float = 1.5
const MIRROR_NORMAL_TID: int = 129
const MIRROR_ULT_TID: int = 130
const MIRROR_BUFF_ID: int = 89
const ULT_BUFF_ID: int = 90
const ATK3_BUFF_ID: int = 17
const MIRROR_Y_OFFSET: float = 25.0
const FINISH_X_OFFSET: float = 127.0
const ULT_MP_THRESHOLD: int = 500
const ATK_COUNTER_FIRST: int = 1
const CD_RESTORE: float = 1.0
const DEFAULT_MOD: float = 1.0


func _ult_create_buff(skill: Variant, target: Variant) -> Variant:
	var buff: Variant = skill._create_buff_default(target)
	buff.hero_hooks["update"] = Callable(self, "_ult_buff_update")
	buff.hero_hooks["onRemoved"] = Callable(self, "_ult_buff_on_removed")
	var skillatk: Variant = buff.owner.skills.get("TB_atk")
	if skillatk:
		skillatk.custom_data["originfo"] = skillatk.info
		var wrapped: Dictionary = skillatk.info.duplicate()
		wrapped["Max Range"] = float(skillatk.info.get("Max Range", 0)) + TB_RANGE_INTERVAL
		wrapped["CD"] = TB_ULT_ATK_CD
		wrapped["Global CD"] = TB_ULT_ATK_CD
		wrapped["Gain MP"] = 0
		wrapped["Track Type"] = "projectile"
		wrapped["AOE Origin"] = false
		wrapped["Impact Effect"] = "eff_impact_TB_atk.cha"
		skillatk.info = wrapped
		var max_r: float = float(wrapped.get("Max Range", 0))
		skillatk.max_range_sq = max_r * max_r
		skillatk.cd_remaining = TB_ULT_ATK_CD
	buff.owner.attack_range = float(buff.owner.attack_range) + TB_RANGE_INTERVAL
	buff.owner.global_cd = TB_ULT_ATK_CD
	buff.owner.custom_data["ultBuff"] = ATK_COUNTER_FIRST
	return buff


func _ult_buff_update(buff: Variant, dt: float) -> void:
	buff._update_default(dt)
	if int(buff.owner.mp) == 0:
		buff.owner.remove_buff(buff)


func _ult_buff_on_removed(buff: Variant) -> void:
	var owner: Variant = buff.owner
	var skillatk: Variant = owner.skills.get("TB_atk")
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
	caster.position = Vector2(caster.position.x - float(caster.direction) * FINISH_X_OFFSET, caster.position.y)


func _ult_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	if int(skill.attack_counter) == ATK_COUNTER_FIRST:
		skill._select_target(skill.caster)
		return [true, 0.0]
	return BattleSkillEffect.take_effect_on(skill, target, src)


func _ult_start(skill: Variant, target: Variant) -> void:
	var binfo: Variant = skill.caster.cm.lookup(&"Buff", "", ULT_BUFF_ID)
	skill.caster.add_buff(binfo, skill.caster)
	skill._start_default(target)


func _ult_can_cast_with_target(skill: Variant, target: Variant) -> Dictionary:
	var base: Dictionary = skill._can_cast_with_target_default(target)
	if not bool(base.get("ok", false)) or skill.caster.custom_data.get("ultBuff", null) != null or int(skill.caster.mp) < ULT_MP_THRESHOLD:
		return {"ok": false, "reason": "tb ult"}
	return base


func _atk2_take_effect_at(skill: Variant, location: Vector2, src: Variant) -> void:
	BattleSkillEffect.take_effect_at(skill, location, src)
	var caster: Variant = skill.caster
	var in_ult: bool = caster.custom_data.get("ultBuff", null) != null
	var tid: int = MIRROR_ULT_TID if in_ult else MIRROR_NORMAL_TID
	var proto: Dictionary = {"_tid": tid, "_level": int(skill.level), "_stars": int(caster.stars), "_rank": int(caster.rank)}
	var config: Dictionary = {"is_monster": true, "estimate_rank": true, "hp_mod": float(caster.config.get("hp_mod", DEFAULT_MOD)), "dps_mod": float(caster.config.get("dps_mod", DEFAULT_MOD))}
	var mirror: BattleUnit = BattleUnit.new(proto, int(caster.camp), config, caster.cm, caster.engine, {}, caster.skill_lib)
	var binfo: Variant = caster.cm.lookup(&"Buff", "", MIRROR_BUFF_ID)
	mirror.add_buff(binfo, caster)
	mirror.custom_data["mDuration"] = MIRROR_TIME
	mirror.hero_hooks["update"] = Callable(self, "_mirror_update")
	mirror.isDeathWithEffect = true
	mirror.direction = int(caster.direction)
	var mirror_loc: Vector2 = Vector2(location.x, location.y + MIRROR_Y_OFFSET)
	caster.position = Vector2(caster.position.x, caster.position.y - MIRROR_Y_OFFSET)
	caster.engine.summon_unit(mirror, mirror_loc, caster)
	caster.custom_data["TBMirror"] = mirror


func _mirror_update(unit: Variant, dt: float) -> void:
	var dur: float = float(unit.custom_data.get("mDuration", MIRROR_TIME)) - dt
	unit.custom_data["mDuration"] = dur
	if dur <= 0.0:
		unit.die(null)
	else:
		unit._update_default(dt)


func _atk3_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var caster: Variant = skill.caster
	var binfo: Variant = caster.cm.lookup(&"Buff", "", ATK3_BUFF_ID)
	var buff: Variant = caster.add_buff(binfo, caster)
	var r: Array = BattleSkillEffect.take_effect_on(skill, target, src)
	caster.remove_buff(buff)
	return r


func _atk3_can_cast_with_target(skill: Variant, target: Variant) -> Dictionary:
	var base: Dictionary = skill._can_cast_with_target_default(target)
	if not bool(base.get("ok", false)) or skill.caster.custom_data.get("ultBuff", null) != null:
		return {"ok": false, "reason": "tb atk3"}
	return base


func apply(hero: Variant) -> void:
	var skillult: Variant = hero.skills.get("TB_ult")
	if skillult:
		skillult.hero_hooks["createBuff"] = Callable(self, "_ult_create_buff")
		skillult.hero_hooks["canCastWithTarget"] = Callable(self, "_ult_can_cast_with_target")
		skillult.hero_hooks["finish"] = Callable(self, "_ult_finish")
		skillult.hero_hooks["start"] = Callable(self, "_ult_start")
		skillult.hero_hooks["takeEffectOn"] = Callable(self, "_ult_take_effect_on")
	var skillatk2: Variant = hero.skills.get("TB_atk2")
	if skillatk2:
		skillatk2.hero_hooks["takeEffectAt"] = Callable(self, "_atk2_take_effect_at")
	hero.info["mDuration"] = MIRROR_TIME
	var skillatk3: Variant = hero.skills.get("TB_atk3")
	if skillatk3:
		skillatk3.hero_hooks["takeEffectOn"] = Callable(self, "_atk3_take_effect_on")
		skillatk3.hero_hooks["canCastWithTarget"] = Callable(self, "_atk3_can_cast_with_target")
