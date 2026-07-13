extends RefCounted

## BossTB（Boss 版恐怖利刃）— 照源 BossTB.lua（203 行）翻译。
## 复用续8 TB 变身系 + 幻象召唤模式：BossTB_atk6（ult）createBuff 变身（改 BossTB_atk info wraptable + onRemoved 还原，
##   无 mp 耗尽 update）/ finish x偏移×1.2 / takeEffectOn counter==1 View / start 加 Buff90 +
## BossTB_atk2 takeEffectAt 召唤 4 幻象（tid 129/130 + 2 组位置 ±50x/∓100x + mDuration 倒计 die）+
## BossTB_atk3 canCastWithTarget（basefunc and ultBuff → true，正向互斥）。
## 源 atk3 onAttackFrame 取 originfo/counter 未用（死代码），等价默认不挂。

const TB_RANGE_INTERVAL: float = 150.0      # 源 :2 变身态 atk 射程+
const MIRROR_TIME: float = 10.0             # 源 :3 幻象持续
const TB_ULT_ATK_CD: float = 0.5            # 源 :4 变身态 atk CD
const MIRROR_NORMAL_TID: int = 129          # 源 :29 常态幻象 tid
const MIRROR_ULT_TID: int = 130             # 源 :35 变身态幻象 tid
const MIRROR_BUFF_ID: int = 89              # 源 :45 幻象 buff
const ULT_BUFF_ID: int = 90                 # 源 :177 变身 buff
const MIRROR_X_NEAR: float = 50.0           # 源 :59/:63 身前 +50·dir
const MIRROR_X_FAR: float = 100.0           # 源 :82/:86 身后 -100·dir
const MIRROR_Y_NEAR_A: float = 30.0         # 源 :60 +30y
const MIRROR_Y_NEAR_B: float = -30.0        # 源 :64 -30y
const MIRROR_Y_FAR_A: float = 50.0          # 源 :83 +50y
const MIRROR_Y_FAR_B: float = -50.0         # 源 :87 -50y
const FINISH_X_OFFSET: float = 127.0        # 源 :150 finish x 偏移
const FINISH_X_MULT: float = 1.2            # 源 :150 ×1.2
const CD_RESTORE: float = 1.0               # 源 :102 onRemoved cd_remaining=1
const HP_MOD: float = 0.5                   # 源 :40 幻象 hp_mod
const DPS_MOD_DIVISOR: float = 3.0          # 源 :41 幻象 dps_mod/3
const DEFAULT_DPS_MOD: float = 1.0          # 源 :41 /3 or 1 的 fallback
const PLUS_RATIO: float = 0.9               # 源 :137 变身态 Plus Ratio
const ATK_COUNTER_FIRST: int = 1            # 源 :154 attack_counter==1


# 源 :25-97 atk2 takeEffectAt：basefunc + 召唤 4 幻象（tid 129/130 + Buff89 + mDuration + update + setDeathWithEffect + summonUnit）。
func _atk2_take_effect_at(skill: Variant, location: Vector2, src: Variant) -> void:
	BattleSkillEffect.take_effect_at(skill, location, src)
	var caster: Variant = skill.caster
	var in_ult: bool = caster.custom_data.get("ultBuff", null) != null
	var tid: int = MIRROR_ULT_TID if in_ult else MIRROR_NORMAL_TID
	# 源 :30 _level = skill.level or 1（Lua：0 truthy 保留 0，nil→1；GDScript 用 != null 守卫，勿 >0）
	var lvl: int = int(skill.level) if skill.level != null else 1
	var proto: Dictionary = {"_tid": tid, "_level": lvl, "_stars": int(caster.stars), "_rank": int(caster.rank)}
	# 源 :41 dps_mod = caster.config.dps_mod / 3 or 1（Lua 0 truthy 致 or 永不触发，忠实直用 raw_dps 无 fallback）
	var raw_dps: float = float(caster.config.get("dps_mod", 0.0)) / DPS_MOD_DIVISOR
	var config: Dictionary = {"is_monster": true, "estimate_rank": true, "hp_mod": HP_MOD, "dps_mod": raw_dps}
	var binfo: Variant = caster.cm.lookup(&"Buff", "", MIRROR_BUFF_ID)
	var dir: int = int(caster.direction)
	var m1: BattleUnit = _create_mirror(caster, proto, config, binfo, Vector2(location.x + MIRROR_X_NEAR * dir, location.y + MIRROR_Y_NEAR_A), dir)
	var m2: BattleUnit = _create_mirror(caster, proto, config, binfo, Vector2(location.x + MIRROR_X_NEAR * dir, location.y + MIRROR_Y_NEAR_B), dir)
	var m3: BattleUnit = _create_mirror(caster, proto, config, binfo, Vector2(location.x - MIRROR_X_FAR * dir, location.y + MIRROR_Y_FAR_A), dir)
	var m4: BattleUnit = _create_mirror(caster, proto, config, binfo, Vector2(location.x - MIRROR_X_FAR * dir, location.y + MIRROR_Y_FAR_B), dir)
	caster.custom_data["TBMirror"] = [m1, m2, m3, m4]


# 源 :43-97 UnitCreate 单个幻象：Buff89 + mDuration + update hook + setDeathWithEffect + direction + summonUnit。
func _create_mirror(caster: Variant, proto: Dictionary, config: Dictionary, binfo: Variant, loc: Vector2, dir: int) -> BattleUnit:
	var mirror: BattleUnit = BattleUnit.new(proto, int(caster.camp), config, caster.cm, caster.engine, {}, caster.skill_lib)
	mirror.add_buff(binfo, caster)
	mirror.custom_data["mDuration"] = MIRROR_TIME
	mirror.hero_hooks["update"] = Callable(self, "_mirror_update")
	mirror.isDeathWithEffect = true  # 源 :51 setDeathWithEffectOrNot(true)，字段直设
	mirror.direction = dir
	caster.engine.summon_unit(mirror, loc, caster)
	return mirror


# 源 :17-24 TBMirror update：mDuration 倒计 ≤0 die；else basefunc。
func _mirror_update(unit: Variant, dt: float) -> void:
	var dur: float = float(unit.custom_data.get("mDuration", MIRROR_TIME)) - dt
	unit.custom_data["mDuration"] = dur
	if dur <= 0.0:
		unit.die(null)
	else:
		unit._update_default(dt)


# 源 :125-146 atk6 createBuff：basefunc + onRemoved hook + 改 BossTB_atk info wraptable（变身态射程/CD/弹道/Plus Ratio）+ attack_range + global_cd + ultBuff。
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


# 源 :98-124 atk6 buff onRemoved：还原 BossTB_atk info/range/cd + ultBuff=nil + basefunc + hurt + setAction Birth（panel/scene View 跳过）。
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


# 源 :147-151 atk6 finish：basefunc + caster.position x 偏移（反向 127×1.2）。
func _ult_finish(skill: Variant) -> void:
	skill._finish_default()
	var caster: Variant = skill.caster
	caster.position = Vector2(caster.position.x - float(caster.direction) * FINISH_X_OFFSET * FINISH_X_MULT, caster.position.y)


# 源 :152-175 atk6 takeEffectOn：counter==1 View（selectTarget）/ else basefunc。
func _ult_take_effect_on(skill: Variant, target: Variant, src: Variant) -> Array:
	if int(skill.attack_counter) == ATK_COUNTER_FIRST:
		skill._select_target(skill.caster)
		return [true, 0.0]
	return BattleSkillEffect.take_effect_on(skill, target, src)


# 源 :176-182 atk6 start：加 Buff 90 + basefunc。
func _ult_start(skill: Variant, target: Variant) -> void:
	var binfo: Variant = skill.caster.cm.lookup(&"Buff", "", ULT_BUFF_ID)
	skill.caster.add_buff(binfo, skill.caster)
	skill._start_default(target)


# 源 :10-16 atk3 canCastWithTarget：basefunc and ultBuff → true（正向：变身态才能放）。
func _atk3_can_cast_with_target(skill: Variant, target: Variant) -> Dictionary:
	var base: Dictionary = skill._can_cast_with_target_default(target)
	if bool(base.get("ok", false)) and skill.caster.custom_data.get("ultBuff", null) != null:
		return base
	return {"ok": false, "reason": "bosstb atk3"}


# 源 :183-202 init_hero：atk2 takeEffectAt + atk6（createBuff/finish/start/takeEffectOn）+ atk3 canCastWithTarget + hero.info.mDuration。
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
