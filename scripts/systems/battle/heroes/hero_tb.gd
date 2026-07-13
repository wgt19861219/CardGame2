extends RefCounted

## 恐怖利刃（TB）— 照源 TB.lua 翻译。
## TB_ult 变身（createBuff 改 TB_atk info 变身态射程/CD/弹道 + buff.update mp 耗尽取消 + onRemoved 还原 atk）
## + TB_atk2 召唤幻象（tid 129 常态/130 变身态 + mDuration 到期 die + setDeathWithEffect）。
## TB_atk3 短暂 debuff（加 Buff 17 + basefunc + removeBuff）。canCastWithTarget ultBuff 互斥。
## 复用续3 createBuff + 续4/5 buff update/onRemoved + 续5 canCastWithTarget + 续8 召唤模式。

const TB_RANGE_INTERVAL: float = 150.0    # 源 :2 变身态 atk 射程+
const MIRROR_TIME: float = 25.0           # 源 :3 幻象持续
const TB_ULT_ATK_CD: float = 1.5          # 源 :4 变身态 atk CD
const MIRROR_NORMAL_TID: int = 129        # 源 :32 常态幻象 tid
const MIRROR_ULT_TID: int = 130           # 源 :38 变身态幻象 tid
const MIRROR_BUFF_ID: int = 89            # 源 :47 幻象 buff
const ULT_BUFF_ID: int = 90               # 源 :155 变身 buff
const ATK3_BUFF_ID: int = 17              # 源 :7 atk3 debuff
const MIRROR_Y_OFFSET: float = 25.0       # 源 :56 幻象 location y+25 / caster y-25
const FINISH_X_OFFSET: float = 127.0      # 源 :128 finish x 偏移
const ULT_MP_THRESHOLD: int = 500         # 源 :163 大招 mp 门槛
const ATK_COUNTER_FIRST: int = 1          # 源 :132 attack_counter==1
const CD_RESTORE: float = 1.0             # 源 :72 onRemoved cd_remaining=1
const DEFAULT_MOD: float = 1.0            # 源 hp_mod/dps_mod 缺省


# 源 :95-124 TB_ult createBuff：变身 buff（update mp 耗尽取消 + onRemoved 还原 atk）+ 改 TB_atk info 变身态。
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
		wrapped["AOE Origin"] = false  # 源 :107 false（变身态走 projectile 不调 takeEffectAt，false 不被读）
		wrapped["Impact Effect"] = "eff_impact_TB_atk.cha"
		skillatk.info = wrapped
		var max_r: float = float(wrapped.get("Max Range", 0))
		skillatk.max_range_sq = max_r * max_r
		skillatk.cd_remaining = TB_ULT_ATK_CD
	buff.owner.attack_range = float(buff.owner.attack_range) + TB_RANGE_INTERVAL
	buff.owner.global_cd = TB_ULT_ATK_CD
	buff.owner.custom_data["ultBuff"] = ATK_COUNTER_FIRST  # 源 :114 ultBuff=1（标记非 null）
	return buff


# 源 :62-67 buffUpdate：basefunc + mp==0 → removeBuff（耗蓝变身）。
func _ult_buff_update(buff: Variant, dt: float) -> void:
	buff._update_default(dt)
	if int(buff.owner.mp) == 0:
		buff.owner.remove_buff(buff)


# 源 :68-94 onRemoved：还原 atk info/range/cd + ultBuff=nil + hurt + setAction Birth。
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
	# 源 :79-93 ed.run_with_scene panel/scene 特效 — View 跳过


# 源 :125-129 finish：basefunc + caster.position x 偏移（反向 127）。
func _ult_finish(skill: Variant) -> void:
	skill._finish_default()
	var caster: Variant = skill.caster
	caster.position = Vector2(caster.position.x - float(caster.direction) * FINISH_X_OFFSET, caster.position.y)


# 源 :130-153 takeEffectOn：attack_counter==1 时 View 特效 + selectTarget；else basefunc。
func _ult_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	if int(skill.attack_counter) == ATK_COUNTER_FIRST:
		# 源 :137-148 全 ed.run_with_scene View（playEffectOnScene）；Logic 仅 selectTarget（:140）
		skill._select_target(skill.caster)
		return [true, 0.0]
	return BattleSkillEffect.take_effect_on(skill, target, src)


# 源 :154-160 start：加 Buff 90 + basefunc。
func _ult_start(skill: Variant, target: Variant) -> void:
	var binfo: Variant = skill.caster.cm.lookup(&"Buff", "", ULT_BUFF_ID)
	skill.caster.add_buff(binfo, skill.caster)
	skill._start_default(target)


# 源 :161-167 canCastWithTarget：basefunc false 或 ultBuff 或 mp<500 → false。
func _ult_can_cast_with_target(skill: Variant, target: Variant) -> Dictionary:
	var base: Dictionary = skill._can_cast_with_target_default(target)
	if not bool(base.get("ok", false)) or skill.caster.custom_data.get("ultBuff", null) != null or int(skill.caster.mp) < ULT_MP_THRESHOLD:
		return {"ok": false, "reason": "tb ult"}
	return base


# 源 :28-61 atk2 takeEffectAt：basefunc + 召唤幻象（tid 129/130 + mDuration + update + setDeathWithEffect + summonUnit）。
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
	mirror.isDeathWithEffect = true  # 源 :52 setDeathWithEffectOrNot(true)，字段直设（无方法）
	mirror.direction = int(caster.direction)
	var mirror_loc: Vector2 = Vector2(location.x, location.y + MIRROR_Y_OFFSET)
	caster.position = Vector2(caster.position.x, caster.position.y - MIRROR_Y_OFFSET)
	caster.engine.summon_unit(mirror, mirror_loc, caster)
	caster.custom_data["TBMirror"] = mirror


# 源 :20-27 mirror update：mDuration 倒计 ≤0 die；else basefunc。
func _mirror_update(unit: Variant, dt: float) -> void:
	var dur: float = float(unit.custom_data.get("mDuration", MIRROR_TIME)) - dt
	unit.custom_data["mDuration"] = dur
	if dur <= 0.0:
		unit.die(null)
	else:
		unit._update_default(dt)


# 源 :5-12 atk3 takeEffectOn：加 Buff 17 + basefunc + removeBuff（短暂 debuff）。
func _atk3_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	var caster: Variant = skill.caster
	var binfo: Variant = caster.cm.lookup(&"Buff", "", ATK3_BUFF_ID)
	var buff: Variant = caster.add_buff(binfo, caster)
	var r: Array = BattleSkillEffect.take_effect_on(skill, target, src)
	caster.remove_buff(buff)
	return r


# 源 :13-19 atk3 canCastWithTarget：basefunc false 或 ultBuff → false。
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
	hero.info["mDuration"] = MIRROR_TIME  # 源 :181
	var skillatk3: Variant = hero.skills.get("TB_atk3")
	if skillatk3:
		skillatk3.hero_hooks["takeEffectOn"] = Callable(self, "_atk3_take_effect_on")
		skillatk3.hero_hooks["canCastWithTarget"] = Callable(self, "_atk3_can_cast_with_target")
	# 源 :187 PreloadPuppetRcs("TBult") View 跳过
