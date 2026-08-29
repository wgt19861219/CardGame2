class_name StageAccount
extends RefCounted

## 战斗结算参数装配（Logic 层）— 照源 ui/stageaccount.lua 翻译（2026-07-03，Phase 4 续）。
## 纯计算：输入战斗结果 param + 玩家/英雄数据，输出结算 UI 所需展示参数（player_info/heroes/loot_list）。
## 不修改玩家数据（加经验/金币/掉落由上游 stage_manager / battle 衔接完成），不推场景（View 层调度）。
## 单机化去：mercenary（佣兵借将）/ guildInstanceData（公会副本）/ bestRankReward（PVP 排名）/
##   isDungeon 数据分支（StageDungeon 表未接入，is_dungeon_stage 判断保留）/ arena（sid==-1）。

const ARENA_STAGE_ID: int = -1
const EXP_DIVISOR_MIN: int = 1
const UI_RES_PREFIX: String = "UI/alpha/HVGA/"
const STAGE_TYPE_NORMAL: String = "normal"
const STAGE_TYPE_ELITE: String = "elite"
const STAGE_TYPE_ACT: String = "act"
const STAGE_TYPE_PVP: String = "pvp"
const STAGE_TYPE_RAID: String = "raid"
const STAGE_TYPE_DUNGEON: String = "dungeon"
const EXP_DUNGEON_MULTIPLIER: int = 10
const GOLD_BY_DIFFICULTY: Array = [2000, 3500, 5000, 8000]
const STAGE_NORMAL_MAX: int = 10000       # 普通关上界（< 10000）+ 精英下界（> 10000）
const STAGE_ELITE_MAX: int = 19999        # 精英关上界（< 19999）
const STAGE_ACT_MIN: int = 20000          # 活动关下界
const STAGE_ACT_MAX: int = 30000          # 活动关上界
const STAGE_PVP_ID: int = -1              # pvp stage_id
const STAGE_RAID_MIN: int = 40000         # raid 下界
const STAGE_RAID_MAX: int = 50000         # raid 上界
const DIAMOND_NORMAL: int = 20
const DIAMOND_ELITE: int = 50
const DIAMOND_ACT: int = 100


static func is_dungeon_stage(stage_id: int) -> bool:
	return StageData.is_dungeon_stage(stage_id)


static func stage_type(stage_id: int) -> String:
	if stage_id > 0 and stage_id < STAGE_NORMAL_MAX:
		return STAGE_TYPE_NORMAL
	if stage_id > STAGE_NORMAL_MAX and stage_id < STAGE_ELITE_MAX:
		return STAGE_TYPE_ELITE
	if stage_id > STAGE_ACT_MIN and stage_id < STAGE_ACT_MAX:
		return STAGE_TYPE_ACT
	if stage_id == STAGE_PVP_ID:
		return STAGE_TYPE_PVP
	if stage_id > STAGE_RAID_MIN and stage_id < STAGE_RAID_MAX:
		return STAGE_TYPE_RAID
	if StageData.is_dungeon_stage(stage_id):
		return STAGE_TYPE_DUNGEON
	return ""


static func diamond_reward(stage_id: int) -> int:
	match stage_type(stage_id):
		STAGE_TYPE_ELITE:
			return DIAMOND_ELITE
		STAGE_TYPE_ACT:
			return DIAMOND_ACT
		_:
			return DIAMOND_NORMAL


# 单机化：源 ed.replaceScene(stagedone/stagefailed) 推场景留 View 层，本函数只返装配好的 param。
static func build_result_param(param: Dictionary, cm: ConfigManager, player: PlayerData, hero_manager: HeroManager) -> Dictionary:
	if bool(param.get("victory", false)):
		return deal_victory_param(param, cm, player, hero_manager)
	return deal_lose_param(param, cm, player)


static func deal_lose_param(param: Dictionary, cm: ConfigManager, player: PlayerData) -> Dictionary:
	if bool(param.get("excavate_mode", false)):
		var sid: int = int(param.get("stage_id", 0))
		var data := StageData.from_config(cm, sid)
		param["exp"] = data.exp_reward
		var info := _player_info_input(player, data.exp_reward, cm)
		param["player_info"] = get_player_info(info, cm)
	return param


static func deal_victory_param(param: Dictionary, cm: ConfigManager, player: PlayerData, hero_manager: HeroManager) -> Dictionary:
	var sid: int = int(param.get("stage_id", 0))
	var data := StageData.from_config(cm, sid)
	var is_dungeon: bool = StageData.is_dungeon_stage(sid)
	param["is_key_stage"] = false if is_dungeon else data.key_stage
	param["chapter"] = data.chapter_id
	if is_dungeon:
		param["exp"] = data.exp_reward * EXP_DUNGEON_MULTIPLIER
		param["gold"] = _gold_by_difficulty(data.difficulty)
	else:
		param["exp"] = data.exp_reward
		param["gold"] = data.money_reward
	param["loot_list"] = _aggregate_loots(param.get("loots", []))
	var total_exp: int = 0
	if sid == ARENA_STAGE_ID:
		total_exp = 0
	elif is_dungeon:
		total_exp = data.exp_reward * EXP_DUNGEON_MULTIPLIER
	else:
		total_exp = data.heroexp_reward
	var hero_ids: Array = param.get("heroes", [])
	var hero_exp: int = int(total_exp / max(hero_ids.size(), EXP_DIVISOR_MIN))
	param["total_exp"] = total_exp
	param["hero_exp"] = hero_exp
	var hero_hp_mp: Dictionary = param.get("hero_hp_mp", {})
	var heroes: Array = []
	for tid in hero_ids:
		heroes.append(get_hero_info(int(tid), hero_exp, cm, hero_manager, hero_hp_mp))
	param["heroes"] = heroes
	param["player_info"] = get_player_info(_player_info_input(player, int(param["exp"]), cm), cm)
	return param


static func _gold_by_difficulty(difficulty: int) -> int:
	if difficulty >= 1 and difficulty <= GOLD_BY_DIFFICULTY.size():
		return int(GOLD_BY_DIFFICULTY[difficulty - 1])
	return int(GOLD_BY_DIFFICULTY[0])


# 单机化：去 isMercenary（佣兵）/ isMaxLevel（playerlimit 未接入）。hp/mp 从 finalize BattleUnit 快照（源 :138-139 player.heroes[id]:hp_perc()）。
static func get_hero_info(tid: int, hero_exp: int, cm: ConfigManager, hero_manager: HeroManager, hero_hp_mp: Dictionary = {}) -> Dictionary:
	var hero := _find_hero_by_tid(hero_manager, tid)
	if hero == null:
		return {}
	var levels: Dictionary = cm.get_raw_table(&"Levels")
	var hc: Dictionary = hero_manager.hero_cache.get(tid, {})
	var exp: int = hero.exp
	var level: int = hero.level
	var max_exp: int = int(levels.get(str(level), {}).get(&"Exp", 0))
	var pre_exp: int = int(hc.get("pre_exp", 0))
	var pre_level: int = int(hc.get("pre_level", 0))
	var add_exp: int = int(hc.get("exp_increment", 0))
	var pre_max_exp: int = int(levels.get(str(pre_level), {}).get(&"Exp", 0)) if pre_level > 0 else max_exp
	var hp_mp: Dictionary = hero_hp_mp.get(tid, {})
	return {
		"id": tid, "rank": hero.rank, "level": pre_level, "exp": pre_exp, "max_exp": pre_max_exp,
		"t_level": level, "t_exp": exp, "t_max_exp": max_exp,
		"add_exp": add_exp, "add_hero_exp": hero_exp,
		"is_max_level": false,
		"stars": int(hero.stars),   # 源 stagedone createIcon stars=hero._stars（结算头像显星，2026-08-28 头像专项补译）
		"hp": int(hp_mp.get("hp", 0)), "mp": int(hp_mp.get("mp", 0)),
	}


static func get_player_info(info: Dictionary, cm: ConfigManager) -> Dictionary:
	var pt: Dictionary = cm.get_raw_table(&"PlayerLevel")
	var exp: int = int(info.get("exp", 0))
	var add_exp: int = int(info.get("add_exp", 0))
	var level: int = int(info.get("level", 1))
	var max_exp: int = int(info.get("max_exp", 0))
	var c_exp: int = exp
	var c_level: int = level
	var c_add_exp: int = add_exp
	var anim_list: Array = []
	while c_exp < c_add_exp:
		anim_list.insert(0, {"be": 0, "ee": c_exp, "len": _plvl_exp(pt, c_level), "lv": c_level})
		c_add_exp = c_add_exp - c_exp
		if not pt.has(str(c_level - 1)):
			break
		c_level = c_level - 1
		c_exp = _plvl_exp(pt, c_level)
	anim_list.insert(0, {"be": c_exp - c_add_exp, "ee": c_exp, "len": _plvl_exp(pt, c_level), "lv": c_level})
	c_exp = c_exp - c_add_exp
	return {
		"ori_exp": c_exp, "ori_level": c_level, "ori_max_exp": _plvl_exp(pt, c_level),
		"exp": exp, "level": level, "add_exp": add_exp, "max_exp": max_exp, "anim_list": anim_list,
	}


static func get_battle_bg_res(stage_id: int, cm: ConfigManager) -> String:
	var data := StageData.from_config(cm, stage_id)
	var wave_row: Dictionary = cm.get_raw_table(&"Battle").get(str(stage_id), {}).get(str(data.waves), {})
	var res: String = String(wave_row.get(&"Background Pic", ""))
	return UI_RES_PREFIX + res


static func get_stage_vitality_cost(stage_id: int, cm: ConfigManager) -> int:
	return StageData.from_config(cm, stage_id).vitality_cost


static func get_lose_title_res(lose_type: String) -> String:
	if lose_type == "timeout":
		return UI_RES_PREFIX + "overtime_title.png"
	if lose_type == "fail":
		return UI_RES_PREFIX + "failed_title.png"
	return ""


static func _aggregate_loots(loots: Array) -> Dictionary:
	var loot_list: Dictionary = {}
	for v in loots:
		var vd: Dictionary = v
		var lid: int = int(vd.get("id", 0))
		if loot_list.has(lid):
			loot_list[lid]["amount"] = int(loot_list[lid]["amount"]) + 1
		else:
			loot_list[lid] = {"amount": 1, "type": String(vd.get("type", ""))}
	return loot_list


# 玩家信息输入装配（源 :93-98 info 结构）。
static func _player_info_input(player: PlayerData, add_exp: int, cm: ConfigManager) -> Dictionary:
	return {
		"exp": player.team_exp, "add_exp": add_exp,
		"level": player.team_level, "max_exp": PlayerLevelData.get_level_exp(player.team_level, cm),
	}


# PlayerLevel[level].Exp 查询（源 :162/163/176 pt[cLevel].Exp）。
static func _plvl_exp(pt: Dictionary, level: int) -> int:
	return int(pt.get(str(level), {}).get(&"Exp", 0))


# 按 tid 找玩家首个英雄实例（hero_manager.heroes 按 inst_id 存，需遍历）。
static func _find_hero_by_tid(hero_manager: HeroManager, tid: int) -> HeroInstance:
	for inst_id in hero_manager.heroes:
		var h: HeroInstance = hero_manager.heroes[inst_id]
		if h.tid == tid:
			return h
	return null


const NORMAL_MAX_SID: int = 10000
const ELITE_MIN_SID: int = 10001
const ELITE_MAX_SID: int = 19999

static func get_normal_progress(progress: Dictionary) -> int:
	var m: int = 0
	for sid in progress:
		if sid > 0 and sid < NORMAL_MAX_SID and int(progress[sid]) > 0: m = maxi(m, int(sid))
	return m

static func get_elite_progress(progress: Dictionary, st: Dictionary) -> int:
	var m: int = 0
	for sid in progress:
		if sid >= ELITE_MIN_SID and sid <= ELITE_MAX_SID and int(progress[sid]) > 0:
			var g: int = int(st.get(str(sid), {}).get("Stage Group", 0))
			if g > 0 and int(progress.get(g, 0)) > 0: m = maxi(m, int(sid))
	return m

static func get_max_chapter(mode: String, progress: Dictionary, st: Dictionary) -> int:
	var ps: int = get_elite_progress(progress, st) if mode == "elite" else get_normal_progress(progress)
	if ps == 0: return 1
	if mode == "elite": ps = int(st.get(str(ps), {}).get("Stage Group", ps))
	return int(st.get(str(ps), {}).get("Chapter ID", 1))
