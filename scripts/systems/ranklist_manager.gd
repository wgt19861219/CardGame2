class_name RanklistManager
extends RefCounted

## 排行榜 NPC 假榜（Logic 层）— 照源 local_server.lua:2227-2332 query_ranklist + :2337-2368 top_arena。
## ladder 完整 PVP 战斗（:3116-3666）留专项；本类覆盖排行查询（query_ranklist/top_arena 共用）。

const NPC_NAMES: Array[String] = [
	"暗影猎手", "龙骑士", "风暴法师", "圣光骑士", "血魔领主",
	"冰霜女王", "烈焰术士", "大地守卫", "幽灵刺客", "雷霆战神",
	"月光游侠", "黑暗领主", "星辰法师", "铁甲战士", "毒蛇猎手",
]
const RANKLIST_SIZE: int = 20
const NPC_LEVEL_DELTA: int = 5
const NPC_LEVEL_MIN: int = 5
const PARAM_FLOOR: int = 10
const PARAM_SCALE_BASE: float = 1.5
const PARAM_SCALE_STEP: float = 0.06
const PARAM_MIN_BASE: int = 100
const TOP_GS_TEAM_SIZE: int = 5
const TOP_GS_FULL_SIZE: int = 15
const DEFAULT_PARAM_RATIO: float = 0.1
const GUILD_NAMES: Array[String] = [
	"暗影军团", "龙骑联盟", "风暴之翼", "圣光骑士团", "血魔殿",
	"冰霜堡垒", "烈焰公会", "大地之盾", "幽灵暗杀", "雷霆战队",
	"月光森林", "黑暗帝国", "星辰学院", "铁甲军团", "毒蛇巢穴",
]
const GUILD_LIVENESS_BASE: int = 3000
const GUILD_LIVENESS_STEP: int = 120
const GUILD_LIVENESS_MIN: int = 100


func generate_ranklist(player: PlayerData, rank_type: String) -> Dictionary:
	var player_level: int = player.team_level
	var self_param: int = _player_param(player, rank_type)
	var base_scale: int = maxi(self_param, PARAM_MIN_BASE)
	var items: Array = []
	var i: int = 1
	while i <= RANKLIST_SIZE:
		var ni: int = ((i - 1) % NPC_NAMES.size()) + 1
		if rank_type == "guildliveness":
			var guild_param: int = maxi(GUILD_LIVENESS_BASE - i * GUILD_LIVENESS_STEP, GUILD_LIVENESS_MIN)
			items.append({"name": GUILD_NAMES[ni - 1], "level": 0, "param": guild_param})
		else:
			var lvl: int = maxi(player_level + NPC_LEVEL_DELTA - i, NPC_LEVEL_MIN)
			var param: int = maxi(int(float(base_scale) * (PARAM_SCALE_BASE - float(i) * PARAM_SCALE_STEP)), PARAM_FLOOR)
			items.append({"name": NPC_NAMES[ni - 1], "level": lvl, "param": param, "avatar": ni})
		i += 1
	var self_rank: int = RANKLIST_SIZE + 1
	for idx in items.size():
		if self_param >= int(items[idx]["param"]):
			self_rank = idx + 1
			break
	return {
		"rank_type": rank_type,
		"items": items,
		"self_rank": self_rank,
		"self_param": self_param,
		"self_level": player_level,
		"self_name": player.player_name,
		"self_avatar": player.avatar,
	}


## 玩家战力（源 local_server:2234-2272 selfParam 按 rank_type 5 档聚合英雄数据）。
## top_gs→top15Gs / full_hero_gs→totalGs / hero_team_gs→top5Gs / hero_evo_star→totalStars /
## hero_arousal→totalArousal(=Σhero.rank) / default→floor(totalGs×0.1)。
func _player_param(player: PlayerData, rank_type: String) -> int:
	var total_gs: int = 0
	var top_gs: Array[int] = []
	var total_stars: int = 0
	var total_arousal: int = 0
	for inst_id in player.hero_manager.heroes:
		var hero: Variant = player.hero_manager.heroes[inst_id]
		var gs: int = int(hero.gs)
		total_gs += gs
		top_gs.append(gs)
		total_stars += int(hero.stars)
		total_arousal += int(hero.rank)
	top_gs.sort()
	top_gs.reverse()
	var top5: int = 0
	var top15: int = 0
	for i in top_gs.size():
		if i < TOP_GS_TEAM_SIZE:
			top5 += top_gs[i]
		if i < TOP_GS_FULL_SIZE:
			top15 += top_gs[i]
	match rank_type:
		"top_gs":
			return top15
		"full_hero_gs":
			return total_gs
		"hero_team_gs":
			return top5
		"hero_evo_star":
			return total_stars
		"hero_arousal":
			return total_arousal
		_:
			return int(float(total_gs) * DEFAULT_PARAM_RATIO)
