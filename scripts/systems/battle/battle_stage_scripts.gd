class_name BattleStageScripts
extends RefCounted

## 关卡脚本（Logic 层）— 照源 stage.lua:1-172 翻译（Phase 2.6，2026-07-01）。
## 关卡/波次切换的特殊规则 hook（DR 加 mp / boss 大招 mp / 怪物 buff / 英雄性别校验 / 怪物重定位）。
## get_stage_script(eng,cm,stageid,waveid) → Callable(eng) 或空 Callable（无脚本）。
## 由 nextBattle（Phase 2.1续模式入口）调用。addBuffForGuildStage（guild 模式加 unheal）照源 :167。
## LSTR/T() 国际化（源 checkHeroGender gender）单机化去本地化层，gender 直传字段值（如 "Female"）。
## scripts 表 key 用字符串（源数据 ID，避 lint 裸数字），mp/坐标提 const。

const GUILD_BUFF: String = "unheal"  # 源 :167 addBuffForGuildStage
const DR_MP_BONUS: int = 150  # 源 :48/:58/:66 DR 加 mp
const BOSS_MP_6: int = 800    # 源 :73 stage6 boss mp
const BOSS_MP_7: int = 950    # 源 :78 stage7 boss mp
const BOSS_MP_23: int = 800   # 源 :83 stage23 boss mp
const RESET_40021: Dictionary = {"tid": 135, "x": 95.0, "y": -70.0}  # 源 :147 [tid, x, y]
const RESET_40049: Dictionary = {"tid": 141, "x": 169.0, "y": -50.0}  # 源 :150
const RESET_40055: Dictionary = {"tid": 142, "x": 70.0, "y": -40.0}   # 源 :153


# 源 getStageScript（:166-171）：guild 模式加 unheal + 返 scripts[stageid][waveid]
static func get_stage_script(eng: Variant, cm: ConfigManager, stageid: int, waveid: int) -> Callable:
	if bool(eng.guild_instance_mode):  # 源 :158 ed.engine.guildInstance_mode
		var guild_script: Callable = monster_add_buff(cm, GUILD_BUFF)
		if guild_script.is_valid():
			guild_script.call(eng)
	var wave: Dictionary = _scripts(cm).get(str(stageid), {})
	return wave.get(str(waveid), Callable())


# 源 scripts 表（:43-155）：stageid → waveid → 脚本工厂。lambda 捕获 cm（Buff 查表）/ 参数。
static func _scripts(cm: ConfigManager) -> Dictionary:
	return {
		"1": {"2": _dr_add_mp_factory(DR_MP_BONUS), "3": _boss_no_manual_factory()},
		"2": {"2": _dr_add_mp_factory(DR_MP_BONUS)},
		"3": {"2": _dr_add_mp_factory(DR_MP_BONUS)},
		"6": {"3": _boss_set_mp_factory(BOSS_MP_6)},
		"7": {"3": _boss_set_mp_factory(BOSS_MP_7)},
		"23": {"3": _boss_set_mp_factory(BOSS_MP_23)},
		"20003": _pimu_wave(cm), "21003": _pimu_wave(cm), "22003": _pimu_wave(cm), "23003": _pimu_wave(cm),
		"20004": _mimu_wave(cm), "21004": _mimu_wave(cm), "22004": _mimu_wave(cm), "23004": _mimu_wave(cm),
		"20005": _female_wave(), "21005": _female_wave(), "22005": _female_wave(), "23005": _female_wave(),
		"40021": {"3": monster_reset_pos_and_buff(RESET_40021["tid"], RESET_40021["x"], RESET_40021["y"])},
		"40049": {"3": monster_reset_pos_and_buff(RESET_40049["tid"], RESET_40049["x"], RESET_40049["y"])},
		"40055": {"3": monster_reset_pos_and_buff(RESET_40055["tid"], RESET_40055["x"], RESET_40055["y"])},
	}


# 源 scripts PIMU/MIMU/Female 三波（每波同脚本）helper
static func _pimu_wave(cm: ConfigManager) -> Dictionary:
	return {"1": monster_add_buff(cm, "PIMU"), "2": monster_add_buff(cm, "PIMU"), "3": monster_add_buff(cm, "PIMU")}

static func _mimu_wave(cm: ConfigManager) -> Dictionary:
	return {"1": monster_add_buff(cm, "MIMU"), "2": monster_add_buff(cm, "MIMU"), "3": monster_add_buff(cm, "MIMU")}

static func _female_wave() -> Dictionary:
	return {"1": check_hero_gender("Female"), "2": check_hero_gender("Female"), "3": check_hero_gender("Female")}


# 源 monsterAddBuff（:3-10）：返闭包，调用时给所有敌方加 bid buff
static func monster_add_buff(cm: ConfigManager, bid: String) -> Callable:
	return func(eng: Variant) -> void:
		var info: Dictionary = _lookup_buff(cm, bid)
		for monster in eng.foreach_alive_unit(BattleEngine.CAMP_ENEMY):
			monster.add_buff(info, monster)


# 源 checkHeroGender（:12-24）：返闭包，性别不符退出（源 exitStage(0) 即 RESULT_WIN 退出）
static func check_hero_gender(gender: String) -> Callable:
	return func(eng: Variant) -> void:
		for hero in eng.foreach_alive_unit(BattleEngine.CAMP_PLAYER):
			if str(hero.info.get("Gender", "")) != gender:
				eng.exit_stage(BattleEngine.RESULT_WIN)


# 源 monsterResetPosAndBuff（:26-41）：所有敌方加 unheal + tid 匹配者重定位 + Building_boss
static func monster_reset_pos_and_buff(monster_tid: Variant, pos_x: Variant, pos_y: Variant) -> Callable:
	return func(eng: Variant) -> void:
		var cm: Variant = eng.get("cm") if eng.get("cm") != null else null  # eng.cm 注入（Phase 2.1续模式入口）
		var rect: Dictionary = eng.stage_rect
		for monster in eng.foreach_alive_unit(BattleEngine.CAMP_ENEMY):
			if cm != null:
				monster.add_buff(_lookup_buff(cm, "unheal"), monster)
			if int(monster.tid) == int(monster_tid):
				monster.position = Vector2(float(rect["maxX"]) - float(pos_x), float(pos_y))
				if cm != null:
					monster.add_buff(_lookup_buff(cm, "Building_boss"), monster)


# 源 scripts 内联：DR 加 mp / boss 设 mp / boss 关手动大招
static func _dr_add_mp_factory(amount: int) -> Callable:
	return func(eng: Variant) -> void:
		var dr: Variant = eng.find_hero("DR")
		if dr != null:
			dr.set_mp(int(dr.mp) + amount)

static func _boss_set_mp_factory(amount: int) -> Callable:
	return func(eng: Variant) -> void:
		var boss: Variant = eng.find_boss()
		if boss != null:
			boss.mp = amount

static func _boss_no_manual_factory() -> Callable:
	return func(eng: Variant) -> void:
		var boss: Variant = eng.find_boss()
		if boss != null and boss.ai != null:
			boss.ai.will_cast_manual_skill = false


# 源 ed.lookupDataTable("Buff", nil, bid)：Buff 表 by name 查（ConfigManager get_raw_table）
static func _lookup_buff(cm: ConfigManager, bid: String) -> Dictionary:
	var buff_table: Dictionary = cm.get_raw_table("Buff")
	return buff_table.get(bid, {})
