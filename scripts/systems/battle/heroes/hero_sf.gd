extends RefCounted

## SF（影魔）英雄 hook（Logic 层）— 照源 battle/heroes/SF.lua（60 行）。
## 单位级：update（DYING 态 0.8s 后 SF_ult takeEffectAt 爆发）/ handleUnitDieEvent（单位死亡时 SF_atk3 自施效）。
## SF_atk2.finish：currentNum 计数，满 3 重置 + cd=12。
## SF_atk2.takeEffectAt：wraptable X Shift += currentNum×100（弹幕偏移）。
## ⚠️ 源 skill5_power(:25-32 定义)是死代码（init_hero :49-58 未 override），照源不挂 SF_ult.power，
##   SF_ult 走默认 power。第七轮 P0 修复（此前误激活 _ult_power 借 SF_atk2.info 改伤害公式，[[source-dead-code-activation]]）。

const SF_DYING_TIME: float = 0.8       # 源 :5 DYING 触发延迟
const SF_DYING_DONE: float = 99999.0   # 源 :9 触发后防重入
const SF_FINISH_COUNT: int = 3         # 源 :35 currentNum 满 3 重置
const SF_FINISH_CD: float = 12.0       # 源 :37 重置后 cd
const SF_SHIFT_STEP: float = 100.0     # 源 :44 X Shift 步进


func apply(hero: Variant) -> void:
	hero.hero_hooks["update"] = Callable(self, "_update")
	hero.hero_hooks["handleUnitDieEvent"] = Callable(self, "_handle_unit_die_event")
	var skill2: Variant = hero.skills.get("SF_atk2")
	if skill2:
		skill2.hero_hooks["takeEffectAt"] = Callable(self, "_atk2_take_effect_at")
		skill2.hero_hooks["finish"] = Callable(self, "_atk2_finish")
		skill2.custom_data["current_num"] = 0  # 源 :56 currentNum=0
	# 源 skill5_power(:25-32)是死代码（init_hero :49-58 未 override），照源不挂 SF_ult.power → 走默认


# 源 :2-17 update：DYING 态 dyingTimer 0.8s 后 SF_ult.takeEffectAt；非 DYING 清 timer。basefunc 在末尾。
func _update(hero: Variant, dt: float) -> void:
	if hero.state == BattleUnit.State.DYING:
		var dt_timer: float = float(hero.custom_data.get("dying_timer", -1.0))
		if dt_timer < 0.0:
			dt_timer = SF_DYING_TIME
		dt_timer -= dt
		if dt_timer <= 0.0:
			dt_timer = SF_DYING_DONE
			var skillult: Variant = hero.skills.get("SF_ult")
			skillult.take_effect_at(hero.position)
		hero.custom_data["dying_timer"] = dt_timer
	else:
		hero.custom_data.erase("dying_timer")
	hero._update_default(dt)


# 源 :18-24 handleUnitDieEvent：单位死亡（非召唤物）时 SF_atk3.takeEffectOn(self, self)。
func _handle_unit_die_event(hero: Variant, unit: Variant, _killer: Variant) -> void:
	var skillatk3: Variant = hero.skills.get("SF_atk3")
	if skillatk3 and not bool(unit.config.get("is_summoned", false)):
		skillatk3.take_effect_on(hero, hero)  # 源 takeEffectOn(self, self)：target=hero, source=hero


# 源 :33-40 SF_atk2.finish：currentNum++，满 3 重置 0 + cd=12；basefunc。
func _atk2_finish(skill: Variant) -> void:
	var cn: int = int(skill.custom_data.get("current_num", 0)) + 1
	if cn >= SF_FINISH_COUNT:
		cn = 0
		skill.cd_remaining = SF_FINISH_CD
	skill.custom_data["current_num"] = cn
	skill._finish_default()


# 源 :41-48 SF_atk2.takeEffectAt：wraptable X Shift += currentNum×100；basefunc；还原。
func _atk2_take_effect_at(skill: Variant, location: Vector2, source: Variant) -> void:
	var originfo: Dictionary = skill.info
	var cn: int = int(skill.custom_data.get("current_num", 0))
	var wrapped: Dictionary = originfo.duplicate()  # 源 wraptable(originfo,{X Shift+=cn*100})
	wrapped["X Shift"] = float(originfo.get("X Shift", 0.0)) + float(cn) * SF_SHIFT_STEP
	skill.info = wrapped
	BattleSkillEffect.take_effect_at(skill, location, source)  # basefunc
	skill.info = originfo
