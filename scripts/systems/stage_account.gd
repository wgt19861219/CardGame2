class_name StageAccount
extends RefCounted

## 战斗结算参数装配（Logic 层）— 照源 ui/stageaccount.lua 翻译（2026-07-03，Phase 4 续）。
## 纯计算：输入战斗结果 param + 玩家/英雄数据，输出结算 UI 所需展示参数（player_info/heroes/loot_list）。
## 不修改玩家数据（加经验/金币/掉落由上游 stage_manager / battle 衔接完成），不推场景（View 层调度）。
## 单机化去：mercenary（佣兵借将）/ guildInstanceData（公会副本）/ bestRankReward（PVP 排名）/
##   isDungeon 数据分支（StageDungeon 表未接入，is_dungeon_stage 判断保留）/ arena（sid==-1）。

const ARENA_STAGE_ID: int = -1  # 源 :74 sid==-1 arena（单机化无 arena，照源不接分支）
const EXP_DIVISOR_MIN: int = 1  # 源 #heroes 兜底（防除零，:81 math.floor(totalExp/#heroes)）
const UI_RES_PREFIX: String = "UI/alpha/HVGA/"  # 源 getBattleBgRes :194 / getLoseTitleRes :205-208 路径前缀
# 源 stageType（player.lua:770-788）6 类型字符串（stage_id 区间判定）
const STAGE_TYPE_NORMAL: String = "normal"
const STAGE_TYPE_ELITE: String = "elite"
const STAGE_TYPE_ACT: String = "act"
const STAGE_TYPE_PVP: String = "pvp"
const STAGE_TYPE_RAID: String = "raid"
const STAGE_TYPE_DUNGEON: String = "dungeon"
# 源 stageaccount.lua:54/:77 isDungeon 分支 Exp × 10
const EXP_DUNGEON_MULTIPLIER: int = 10
# 源 :55-56 goldByDiff（dungeon 金币按难度，不读 Money Reward）
const GOLD_BY_DIFFICULTY: Array = [2000, 3500, 5000, 8000]
# 源 stageType（player.lua:770-788）stage_id 区间边界（LINT 禁裸数字，提 const）
const STAGE_NORMAL_MAX: int = 10000       # 普通关上界（< 10000）+ 精英下界（> 10000）
const STAGE_ELITE_MAX: int = 19999        # 精英关上界（< 19999）
const STAGE_ACT_MIN: int = 20000          # 活动关下界
const STAGE_ACT_MAX: int = 30000          # 活动关上界
const STAGE_PVP_ID: int = -1              # pvp stage_id
const STAGE_RAID_MIN: int = 40000         # raid 下界
const STAGE_RAID_MAX: int = 50000         # raid 上界
const DIAMOND_NORMAL: int = 20  # 源 player.lua:1334 普通关钻石奖励
const DIAMOND_ELITE: int = 50   # 源 :1335 精英关钻石奖励
const DIAMOND_ACT: int = 100    # 源 :1336 活动关钻石奖励


# 源 isDungeonStage（local_server.lua:453-462）：委托 Data 层 StageData（DRY，分层 Systems→Data）。
static func is_dungeon_stage(stage_id: int) -> bool:
	return StageData.is_dungeon_stage(stage_id)


# 源 stageType（player.lua:770-788）：stage_id 区间 → 类型（normal/elite/act/pvp/raid/dungeon）。
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


# 源 player.lua:1334-1338 addrmb stageType 分级（normal 20/elite 50/act 100，其他默认 20）。
static func diamond_reward(stage_id: int) -> int:
	match stage_type(stage_id):
		STAGE_TYPE_ELITE:
			return DIAMOND_ELITE
		STAGE_TYPE_ACT:
			return DIAMOND_ACT
		_:
			return DIAMOND_NORMAL


# 源 initialize（stageaccount.lua:4-20）：按 victory 选 deal* 装配 param。
# 单机化：源 ed.replaceScene(stagedone/stagefailed) 推场景留 View 层，本函数只返装配好的 param。
static func build_result_param(param: Dictionary, cm: ConfigManager, player: PlayerData, hero_manager: HeroManager) -> Dictionary:
	if bool(param.get("victory", false)):
		return deal_victory_param(param, cm, player, hero_manager)
	return deal_lose_param(param, cm, player)


# 源 dealLoseParam（stageaccount.lua:21-35）：失败参数（仅 excavate_mode 给 exp/player_info）。
static func deal_lose_param(param: Dictionary, cm: ConfigManager, player: PlayerData) -> Dictionary:
	if bool(param.get("excavate_mode", false)):
		var sid: int = int(param.get("stage_id", 0))
		var data := StageData.from_config(cm, sid)
		param["exp"] = data.exp_reward  # 源 :26 row["Exp Reward"]
		var info := _player_info_input(player, data.exp_reward, cm)
		param["player_info"] = get_player_info(info, cm)
	return param


# 源 dealVictoryParam（stageaccount.lua:36-100）：胜利参数装配。
static func deal_victory_param(param: Dictionary, cm: ConfigManager, player: PlayerData, hero_manager: HeroManager) -> Dictionary:
	var sid: int = int(param.get("stage_id", 0))
	var data := StageData.from_config(cm, sid)
	var is_dungeon: bool = StageData.is_dungeon_stage(sid)  # 源 :39 isDungeonStage
	# 源 :50 isKeyStage = not isDungeon and row["Key Stage"]（dungeon 强制 false）
	param["is_key_stage"] = false if is_dungeon else data.key_stage
	param["chapter"] = data.chapter_id       # 源 :51 row["Chapter ID"]
	# 源 :52-60 exp/gold（dungeon: Exp×10 + goldByDiff[difficulty] / 普通: Exp + Money Reward）
	if is_dungeon:
		param["exp"] = data.exp_reward * EXP_DUNGEON_MULTIPLIER   # 源 :54
		param["gold"] = _gold_by_difficulty(data.difficulty)       # 源 :55-56
	else:
		param["exp"] = data.exp_reward         # 源 :58
		param["gold"] = data.money_reward       # 源 :59（guildInstanceData.gold 分支照源不接）
	param["loot_list"] = _aggregate_loots(param.get("loots", []))  # 源 :61-71
	# 源 :73-80 totalExp（arena sid==-1 / isDungeon Exp×10 / 普通 Heroexp Reward）。arena 分支照源不接。
	var total_exp: int = 0
	if sid == ARENA_STAGE_ID:
		total_exp = 0
	elif is_dungeon:
		total_exp = data.exp_reward * EXP_DUNGEON_MULTIPLIER  # 源 :77
	else:
		total_exp = data.heroexp_reward                        # 源 :79
	var hero_ids: Array = param.get("heroes", [])
	var hero_exp: int = int(total_exp / max(hero_ids.size(), EXP_DIVISOR_MIN))  # 源 :81 floor(totalExp/#heroes)
	param["total_exp"] = total_exp
	param["hero_exp"] = hero_exp
	# 源 :84-92 heroes → getHeroInfo（mercenary 分支照源不接）
	var hero_hp_mp: Dictionary = param.get("hero_hp_mp", {})  # 源 :138-139 hp/mp（finalize 快照）
	var heroes: Array = []
	for tid in hero_ids:
		heroes.append(get_hero_info(int(tid), hero_exp, cm, hero_manager, hero_hp_mp))
	param["heroes"] = heroes
	# 源 :93-99 player_info（addExp = param.exp，含 dungeon ×10）
	param["player_info"] = get_player_info(_player_info_input(player, int(param["exp"]), cm), cm)
	return param


# 源 stageaccount.lua:55-56 goldByDiff（dungeon 金币按难度 1-4 → 2000/3500/5000/8000）。
static func _gold_by_difficulty(difficulty: int) -> int:
	if difficulty >= 1 and difficulty <= GOLD_BY_DIFFICULTY.size():
		return int(GOLD_BY_DIFFICULTY[difficulty - 1])
	return int(GOLD_BY_DIFFICULTY[0])  # 源 :56 or 2000 兜底


# 源 getHeroInfo（stageaccount.lua:101-144）：单英雄结算信息（hero_cache 快照 + 当前态）。
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
	var hp_mp: Dictionary = hero_hp_mp.get(tid, {})  # 源 :138-139（死亡英雄不在快照 → 默认 0）
	return {
		"id": tid, "rank": hero.rank, "level": pre_level, "exp": pre_exp, "max_exp": pre_max_exp,
		"t_level": level, "t_exp": exp, "t_max_exp": max_exp,
		"add_exp": add_exp, "add_hero_exp": hero_exp,
		"is_max_level": false,  # 源 :125-127 heroLevelLimit 未接入，照源不接
		"hp": int(hp_mp.get("hp", 0)), "mp": int(hp_mp.get("mp", 0)),  # 源 :138-139 BattleUnit 快照
	}


# 源 getPlayerInfo（stageaccount.lua:145-189）：玩家信息 + animList 升级动画分段（从当前态反推）。
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
	while c_exp < c_add_exp:  # 源 :158 while cExp < cAddExp
		anim_list.insert(0, {"be": 0, "ee": c_exp, "len": _plvl_exp(pt, c_level), "lv": c_level})
		c_add_exp = c_add_exp - c_exp
		if not pt.has(str(c_level - 1)):  # 源 :166 pt[cLevel-1] == nil
			break
		c_level = c_level - 1
		c_exp = _plvl_exp(pt, c_level)
	anim_list.insert(0, {"be": c_exp - c_add_exp, "ee": c_exp, "len": _plvl_exp(pt, c_level), "lv": c_level})
	c_exp = c_exp - c_add_exp
	return {
		"ori_exp": c_exp, "ori_level": c_level, "ori_max_exp": _plvl_exp(pt, c_level),
		"exp": exp, "level": level, "add_exp": add_exp, "max_exp": max_exp, "anim_list": anim_list,
	}


# 源 getBattleBgRes（stageaccount.lua:190-195）：Battle[stage][waves]["Background Pic"]。
static func get_battle_bg_res(stage_id: int, cm: ConfigManager) -> String:
	var data := StageData.from_config(cm, stage_id)
	var wave_row: Dictionary = cm.get_raw_table(&"Battle").get(str(stage_id), {}).get(str(data.waves), {})
	var res: String = String(wave_row.get(&"Background Pic", ""))
	return UI_RES_PREFIX + res


# 源 getStageVitalityCost（stageaccount.lua:196-202）。
static func get_stage_vitality_cost(stage_id: int, cm: ConfigManager) -> int:
	return StageData.from_config(cm, stage_id).vitality_cost


# 源 getLoseTitleRes（stageaccount.lua:203-209）：失败标题图（timeout/fail）。
static func get_lose_title_res(lose_type: String) -> String:
	if lose_type == "timeout":
		return UI_RES_PREFIX + "overtime_title.png"
	if lose_type == "fail":
		return UI_RES_PREFIX + "failed_title.png"
	return ""


# 源 loots 聚合（stageaccount.lua:61-71）：lootList[id] = {amount, type}。
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


# 源 stageselect.lua:19-37 + player.lua:850-875 进度跟踪（static，供 StageManager 调）。
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
