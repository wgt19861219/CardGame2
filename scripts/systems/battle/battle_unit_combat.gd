class_name BattleUnitCombat
extends RefCounted

## 单位战斗结算（Logic 层）— 照源 unit.lua 伤害/死亡/受击/动作段翻译（Phase 2.2续-A，2026-07-01）。
## 从 unit.lua 拆出（源是一体，Godot ≤300 行铁律强制拆分，合规引擎适配，先例 battle_skill_effect）。
## 全静态方法，第一参 u 为 BattleUnit（duck-type：attribs/buff_list/buff_effects/hp/mp/info/level/camp/
##   state/current_skill/engine/dmg_statistics/dPSStatisticsRatio/isDeathWithEffect/puppet_stack/
##   set_hp/set_mp/is_alive/unfreeze_actor/remove_signed_buffer）。
## View 副作用（PopupCreate/showMonsterLoots/playEffect/actor.*）剥离为 Logic 桩（Phase 4 battle_scene 接）。

# —— takeDamage 公式常量（源 :1276-1299, :1248, :1338 裸数值，lint 禁魔法数字，照源值提 const）——
const DEF_COEFF_AD_DD: float = 8.0          # 源 :1276 AD: dd = defence*8
const DEF_COEFF_AD_DC: float = 8.0          # 源 :1277 AD: dc = defence*8
const DEF_COEFF_AP_DD: float = 12.0         # 源 :1282 AP: dd = defence*12
const DEF_COEFF_AP_DC: float = 2.5          # 源 :1283 AP: dc = defence*2.5
const CRIT_DENOM: float = 100.0             # 源 :1293 crit/(100+dc)
const CRIT_MULTIPLIER: float = 2.0          # 源 :1295 bCrit → ×2
const IMMUNITY_FULL: float = 100.0          # 源 :1299 immunity>=100 完全免疫
const IMMUNITY_DENOM: float = 100.0         # 源 :1248 (100-immunity)/100
const IMMUNITY_MIN_LOSS: int = 1            # 源 :1248 max(1, ...)
const INTERRUPT_HP_RATIO_DEFAULT: float = 0.08  # 源 :1338 Interrupt HP Ratio 缺省


# 源 takeDamage（unit.lua:1252-1376）。入参 Dictionary（源 :1253-1260 table 参数路径，skill_effect 调）。
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
	# 源 :1267 manually_casting 时 EDDebug（断言）—— Logic 不触发（受击不应在手动施法期），跳过
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
		pass  # 源 :1284-1289 defence/crit/immunity/dd/dc 全 0
	# 源 :1293-1295 暴击判定（D2 确定性：engine.rng 取代 ed.rand）
	var crit_prob: float = crit / (CRIT_DENOM + dc) * crit_mod
	var b_crit: bool = crit_prob > float(u.engine.rng.randf())
	var crit_multiplier: float = CRIT_MULTIPLIER if b_crit else 1.0
	amount = max(0.0, amount)
	# 源 :1297-1298 减伤公式 amount²/(amount+dd*coef) × 暴击 × source.PDM
	var damage: float = amount * amount / (amount + dd * coefficient)
	damage = damage * crit_multiplier * float(source.attribs.get("PDM", 1.0))
	if immunity >= IMMUNITY_FULL:
		_show_immune_popup(u)  # 源 :1299-1314 完全免疫 Popup 文本
		return 0.0
	# 源 :1316-1318 buff onDamaged 链（Phase 2.3 buff.on_damaged 已翻）
	for buff in u.buff_list:
		damage = float(buff.on_damaged(damage, dt))
	if damage <= 0.0:
		return 0.0  # 源 :1319-1321
	# 源 :1322 getLostHPAfterImmunity（英雄 hook override 点，Phoenix 蛋形态/BB ultBuff）— hook 内调静态 get_lost_hp_after_immunity 当 basefunc
	var hh: Variant = u.get("hero_hooks")
	var gh: Callable = hh.get("getLostHPAfterImmunity", Callable()) if hh is Dictionary else Callable()
	var lost: float = float(gh.call(u, damage, immunity)) if gh.is_valid() else get_lost_hp_after_immunity(damage, immunity)
	var dmg: float = min(float(u.hp), lost)
	dmg = dmg * float(u.dPSStatisticsRatio)  # 源 :1324（ crusade/excavate 统计缩放）
	if source != u:
		source.dmg_statistics = float(source.dmg_statistics) + dmg  # 源 :1325-1327
	if field == "hp":
		u.set_hp(int(float(u.hp) - lost))  # 源 :1333 setHP(hp - lost)
		if int(u.hp) == 0:
			die(u, source)  # 源 :1334-1335
		else:
			_try_hurt(u, lost)  # 源 :1337-1349 中断硬直判定
			var mp_gain: float = lost * float(u.info.get("MP Gain Rate", 0.0)) / float(u.attribs.get("HP", 1.0))
			u.set_mp(int(float(u.mp) + mp_gain * float(u.engine.mp_bonus)))  # 源 :1350-1351
	elif field == "mp":
		u.set_mp(int(float(u.mp) - lost))  # 源 :1354
	u.unfreeze_actor()  # 源 :1356（基类 BattleEntity.unfreeze_actor，View tint 桩）
	_show_damage_popup(u, lost, field, b_crit)  # 源 :1357-1368 伤害/扣 MP 飘字
	return lost


# 源 :1299-1314 完全免疫 Popup（camp 反向色 + immune/physical_immune/magic_immune 文本）。
# actor==null（headless 无 scene）守卫，等价源 ed.run_with_scene。
static func _show_immune_popup(u: Variant) -> void:
	var actor: Variant = u.get("actor")
	if actor == null or not actor.has_method("spawn_popup"):
		return
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
	actor.spawn_popup(str_text, color, false, "text")


# 源 :1357-1368 伤害/扣 MP 飘字（mp=yellow、player 受伤=red、enemy 受伤=orange），-0 不弹，crit 影响动作。
static func _show_damage_popup(u: Variant, lost: float, field: String, b_crit: bool) -> void:
	var actor: Variant = u.get("actor")
	if actor == null or not actor.has_method("spawn_popup"):
		return
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
	actor.spawn_popup(str_text, color, b_crit, "damage")


# 源 battle_engine.lua:1014-1018 英雄击杀奖励（setMP+bonus + kill 飘字 camp player→blue/enemy→red）。
# engine.on_unit_die 调（battle_engine 超 300 行，提取至此控行数）。kill_mp_bonus 透传 engine 常量。
static func on_hero_kill(killer: Variant, kill_mp_bonus: int) -> void:
	killer.set_mp(int(killer.mp) + kill_mp_bonus)
	var actor: Variant = killer.get("actor")
	if actor == null or not actor.has_method("spawn_popup"):
		return
	actor.spawn_popup("kill", "blue" if int(killer.camp) == BattleEngine.CAMP_PLAYER else "red", false, "text")


# 源 :1338-1349 中断硬直判定（lost 超阈值 + 非 Birth + 当前技能可打断 + 非不受控 → hurt）
static func _try_hurt(u: Variant, lost: float) -> void:
	var interrupt_ratio: float = float(u.info.get("Interrupt HP Ratio", 0.0))
	if interrupt_ratio == 0.0:
		interrupt_ratio = INTERRUPT_HP_RATIO_DEFAULT
	if lost <= float(u.attribs.get("HP", 0.0)) * interrupt_ratio:
		return  # 源 :1339 损失过小不打断
	if u.state == BattleUnit.State.BIRTH:
		return  # 源 :1340 Birth 期不打断
	if u.current_skill != null and not bool(u.current_skill.info.get("Interruptable", false)):
		return  # 源 :1341-1342 当前技能不可打断
	if bool(u.buff_effects.get("uncontrollable", false)):
		return  # 源 :1342 不受控
	hurt(u)


# 源 getLostHPAfterImmunity（unit.lua:1247-1249）：max(1, damage*(100-immunity)/100)
static func get_lost_hp_after_immunity(damage: float, immunity: float) -> float:
	return max(float(IMMUNITY_MIN_LOSS), damage * (IMMUNITY_DENOM - immunity) / IMMUNITY_DENOM)


# 源 die（unit.lua:1148-1209）。音效/actor.onUnitDeath 走 View 桥（play_voice/play_gold_drop_effect）。
static func die(u: Variant, killer: Variant) -> void:
	if not bool(u.is_alive()):
		return
	# 源 :1155-1159 死亡音效 ed.playEffect("sound/<NAME>_DEATH.mp3")（Logic→actor View 桥）
	var death_name: String = String(u.name).to_upper()
	var voice_actor: Variant = u.get("actor")
	if death_name != "" and voice_actor != null and voice_actor.has_method("play_voice"):
		voice_actor.play_voice(death_name, "_DEATH")
	u.remove_signed_buffer()  # 源 :1160（Phase 2.3续 buff 对接，BattleUnit 桩）
	if bool(u.manually_casting):
		u.manually_casting = false
		u.engine.unfreeze()  # 源 :1161-1164
	if u.current_skill != null:
		u.current_skill.interrupt()  # 源 :1165-1167
	u.state = BattleUnit.State.DYING  # 源 :1168
	u.can_cast_manual = false
	u.walk_v = Vector2.ZERO
	u.hp = 0
	u.mp = 0
	if not bool(u.isDeathWithEffect):
		set_action(u, "Death", false, true)  # 源 :1173-1174
	else:
		u.action_name = ""  # 源 :1176-1179（特效死亡：动作清空，elapsed/duration 归零）
		u.action_loop = false
		u.action_duration = 0.0
		u.action_elapsed = 0.0
	u.engine.on_unit_die(u, killer)  # 源 :1194
	# 源 :1195-1205 光环 rebuild（aura_skill_list/effect_enemy_aura_skill_list，initSkill 装配，默认空跳过）
	if u.aura_skill_list.size() > 0:
		for unit in u.engine.foreach_alive_unit(int(u.camp)):
			unit.rebuild()
	if u.effect_enemy_aura_skill_list.size() > 0:
		var foe_camp: int = BattleEngine.CAMP_ENEMY if int(u.camp) == BattleEngine.CAMP_PLAYER else BattleEngine.CAMP_PLAYER
		for unit in u.engine.foreach_alive_unit(foe_camp):
			unit.rebuild()
	# 源 :1206-1208 actor.onUnitDeath → playGoldDropEffect（monster 死亡掉金币飘字 + addGold）
	var actor: Variant = u.get("actor")
	if actor != null and actor.has_method("play_gold_drop_effect"):
		actor.play_gold_drop_effect()


# 源 hurt（unit.lua:1122-1135）：当前技能打断 + Damaged 动作 + HURT 状态。
static func hurt(u: Variant) -> void:
	if not bool(u.is_alive()):
		return
	if u.current_skill != null:
		u.current_skill.interrupt()  # 源 :1126-1127
	# 源 :1129-1130 actor.puppet:interruptSound（View）桩
	set_action(u, "Damaged", false, true)
	u.state = BattleUnit.State.HURT
	u.walk_v = Vector2.ZERO


# 源 setAction（unit.lua:814-837）。AnimDuration 表查询 Phase 2.4续/Phase 4 Puppet 接入补真值。
static func set_action(u: Variant, action_name: String, loop: bool, interrupt: bool) -> void:
	u.action_loop = loop
	if loop and action_name == u.action_name:
		return  # 源 :816-817 同名 loop 动作不重置
	u.action_name = action_name
	# 源 :821 action_elapsed = interrupt ? 0 : max(0, elapsed-duration)
	if interrupt:
		u.action_elapsed = 0.0
	else:
		u.action_elapsed = max(0.0, float(u.action_elapsed) - float(u.action_duration))
	# 源 :823-833 非循环动作 → AnimDuration 表查时长（puppet 栈顶资源 + 动作名）；本轮空栈/无表 fallback 0
	if not loop and action_name != "":
		u.action_duration = _lookup_anim_duration(u, action_name)
	else:
		u.action_duration = 0.0
	# 源 :834-836 actor.onStartNewAction（View）→ 战斗动作 FCA 播放（鸭子，actor 未装配时跳过）
	var actor: Variant = u.get("actor")
	if actor != null and actor.has_method("on_start_new_action"):
		actor.on_start_new_action()


# 源 :824-826 lookupDataTable("Puppet","Resource",puppet)+".cha" + lookupDataTable("AnimDuration","Duration",resourceName,action)。
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


# 源 takeHeal（unit.lua:1217-1242）。is_add_point 是源内部局部变量（:1225 true，仅 unheal 未回血
# :1231 才 false）——所有治疗默认弹飘字（含 HPS/MPS 持续回复），非参数。mp=yellow、hp=green，amount>1 守卫。
static func take_heal(u: Variant, amount: float, p_type: String, source: Variant) -> void:
	if not bool(u.is_alive()):
		return
	if p_type == "":
		p_type = "hp"  # 源 :1221 _type = _type or "hp"
	if source != null:
		amount = amount * float(source.attribs.get("PDM", 1.0))  # 源 :1222-1224
	var is_add_point: bool = true  # 源 :1225
	if p_type == "mp":
		u.set_mp(int(float(u.mp) + amount))  # 源 :1226-1227
	elif not bool(u.buff_effects.get("unheal", false)):
		u.set_hp(int(float(u.hp) + amount))  # 源 :1228-1229
	else:
		is_add_point = false  # 源 :1230-1231 unheal 未回血
	u.unfreeze_actor()  # 源 :1236
	if is_add_point and amount > 1.0:  # 源 :1237-1240 飘字
		var actor: Variant = u.get("actor")
		if actor != null and actor.has_method("spawn_popup"):
			var str_text: String = "+" + str(int(round(amount)))
			var color: String = "yellow" if p_type == "mp" else "green"
			actor.spawn_popup(str_text, color, false, "heal")


# 源 knockup（unit.lua:1393-1407）：stable 免击退；否则置 knockup_time/knockup_v。
static func knockup(u: Variant, time: float, distance: Vector2) -> void:
	if bool(u.buff_effects.get("stable", false)):
		return  # 源 :1394 稳固免击退
	u.knockup_time = time
	u.knockup_v = Vector2(distance.x / time, distance.y / time) if time != 0.0 else Vector2.ZERO  # 源 :1398-1402
	# 源 :1403-1405 actor.launch(time)（View 击飞弧线）；用 get 鸭子访问（MockUnit 无 actor 字段安全）
	var actor: Variant = u.get("actor")
	if actor != null and actor.has_method("launch"):
		actor.launch(time)


# 源 startScalingAction（unit.lua:1482-1494）：技能缩放动画（Boss 大招放大 1.2x），getRuntimeScale 读。
static func start_scaling_action(u: Variant, scale_x: float, duration: float) -> void:
	u.is_scale_action_running = true
	u.scale_action_duration = duration
	u.scale_action_running_time = 0.0
	u.scale_action_scale_value = scale_x


# 源 endScalingAction（:1497-1502）
static func end_scaling_action(u: Variant) -> void:
	u.is_scale_action_running = false
	u.scale_action_duration = 0.0
	u.scale_action_running_time = 0.0
	u.scale_action_scale_value = 0.0


# 源 reset（unit.lua:643-665）：多波/重置清状态 + skill reset + rebuild + 重算 hp/mp。
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
	u._init_hp_mp()  # 源 :664 initHpMpInfo(self, true)（hpmpInited 守卫简化，reset 重算 hp/mp）
