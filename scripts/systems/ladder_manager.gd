class_name LadderManager
extends RefCounted

## 天梯/PVP（Logic 层）— 照源 local_server.lua:3013-3429 ladder handler + generateAiPlayer(:3013)。
## 单机 NPC PVP：AI 对手生成（PVPEmeny 表查 Hero1-5，本项目 JSON 无 Hero 字段 → fallback Unit 表
## Type!=Boss 随机 3-5，照源 :3047-3070）+ 11 子命令（open_panel/apply_opponent/start_battle/end_battle/
## buy_battle_chance/clear_battle_cd/query_records/query_rankborad/query_oppo/set_lineup/query_rankboard）。
## pvp 状态本类持有（照源 player._pvp，独立避 player_data 行数超）。阶段 2 PVP 战斗接入；阶段 3 UI。

const PVP_NAMES: Array[String] = [
	"亚历山大","贝奥武夫","克里斯蒂娜","达芙妮","埃里克","菲奥娜","加雷斯","海伦娜","伊莎贝拉","贾斯汀",
	"凯瑟琳","莱昂纳多","米开朗基罗","娜塔莎","奥利维亚","帕特里克","昆廷","罗莎琳德","塞巴斯蒂安","特里斯坦",
	"乌苏拉","薇薇安","沃尔特","谢丽尔","尤里乌斯","赵云","关羽","张飞","诸葛亮","周瑜",
	"吕布","貂蝉","孙策","马超","黄忠",
]
const AI_NAMES: Array[String] = [
	"暗影猎手","龙骑士","风暴法师","圣光骑士","血魔领主","冰霜女王","烈焰术士","大地守卫","幽灵刺客","雷霆战神",
	"月光游侠","黑暗领主","星辰法师","铁甲战士","毒蛇猎手",
]
const RANK_INIT: int = 1001
const LEFT_COUNT_DEFAULT: int = 5
const OPPONENT_COUNT: int = 3
const OPPONENT_RANK_BASE: int = 50
const BOARD_SIZE: int = 20
const REWARD_MIN: int = 10
const REWARD_BASE: int = 100
const CLEAR_CD_COST: int = 50
const BUY_COST_DEFAULT: int = 50
const RECORDS_MAX: int = 20
const LEVEL_DELTA_MIN: int = -3
const LEVEL_DELTA_MAX: int = 3
const LEVEL_CAP_OFFSET: int = 5
const AVATAR_MAX: int = 8
const VIP_DIVISOR: int = 20
const VIP_CAP: int = 5
const HERO_COUNT_MIN: int = 3
const HERO_COUNT_MAX: int = 5
const STARS_DIVISOR: int = 15
const RANK_DIVISOR: int = 10
const HERO_RANK_MIN: int = 5
const HERO_RANK_MAX: int = 22
const GS_PER_LEVEL: int = 10
const GS_PER_STAR: int = 50
const GS_PER_RANK: int = 30
const USER_ID_BASE: int = 10000
const LEVEL_HERO_DELTA_MAX: int = 2
const LEVEL_FALLBACK_DELTA_MAX: int = 3
const RSEED_MAX: int = 999999
const HERO_FIELD_COUNT: int = 5  # 源 :3033 Hero1-5
const STARS_MAX: int = 5  # 源 :3040/3065 stars 上限
const DEFEND_LINEUP_MAX: int = 5  # 源 :3196 防守阵容 5 英雄
const AVATAR_MOD: int = 10  # 源 :3125 (i%10)+1
const RANKLIST_LEVEL_BASE: int = 60  # 源 :3128 60-i*2
const RANKLIST_LEVEL_STEP: int = 2  # 源 :3128 i*2
const RANKLIST_LEVEL_MIN: int = 10  # 源 :3128 math.max(...,10)

var pvp: Dictionary = {}


# 源 :3013-3090 generateAiPlayer：AI 对手（PVPEmeny 查 Hero1-5，fallback Unit 表）+ gs。
static func generate_ai_player(rank: int, player_level: int, cm: ConfigManager, rng: BattleRng) -> Dictionary:
	var name_idx: int = rng.randi_range(1, PVP_NAMES.size())
	var level: int = clampi(player_level + rng.randi_range(LEVEL_DELTA_MIN, LEVEL_DELTA_MAX), 1, player_level + LEVEL_CAP_OFFSET)
	var heroes: Array = _generate_heroes(rank, level, cm, rng)
	var gs: int = 0
	for h in heroes:
		gs += int(h["_level"]) * GS_PER_LEVEL + int(h["_stars"]) * GS_PER_STAR + int(h["_rank"]) * GS_PER_RANK
	return {"user_id": USER_ID_BASE + rank, "name": PVP_NAMES[name_idx - 1], "avatar": rng.randi_range(1, AVATAR_MAX), "level": level, "vip": rng.randi_range(0, mini(VIP_CAP, player_level / VIP_DIVISOR)), "gs": gs, "rank": rank, "heroes": heroes, "is_robot": 1}


# 源 :3031-3070 英雄生成：PVPEmeny Hero1-5 优先（本项目 JSON 无 → 空 → fallback Unit Type!=Boss 随机 3-5）。
static func _generate_heroes(rank: int, level: int, cm: ConfigManager, rng: BattleRng) -> Array:
	var heroes: Array = []
	var pvp_enemy: Dictionary = cm.get_raw_table(&"PVPEmeny")
	for row_key in pvp_enemy:
		var row: Dictionary = pvp_enemy[row_key]
		if rank >= int(row.get("Rank", 0)):
			for i in range(1, HERO_FIELD_COUNT + 1):
				var hero_id: int = int(row.get("Hero" + str(i), 0))
				if hero_id > 0:
					heroes.append({"_tid": hero_id, "_level": maxi(1, level - rng.randi_range(0, LEVEL_HERO_DELTA_MAX)), "_stars": clampi(level / STARS_DIVISOR + rng.randi_range(0, 1), 1, STARS_MAX), "_rank": clampi(level / RANK_DIVISOR + 1, HERO_RANK_MIN, HERO_RANK_MAX)})
			break
	if heroes.is_empty():
		var all_tids: Array = []
		var unit_table: Dictionary = cm.get_raw_table(&"Unit")
		for tid in unit_table:
			if str(tid).is_valid_int() and str(unit_table[tid].get("Type", "")) != "Boss":
				all_tids.append(int(tid))
		for i in range(rng.randi_range(HERO_COUNT_MIN, HERO_COUNT_MAX)):
			if not all_tids.is_empty():
				var tid: int = all_tids[rng.randi_range(0, all_tids.size() - 1)]
				heroes.append({"_tid": tid, "_level": maxi(1, level - rng.randi_range(0, LEVEL_FALLBACK_DELTA_MAX)), "_stars": rng.randi_range(1, mini(STARS_MAX, level / STARS_DIVISOR + 1)), "_rank": clampi(maxi(1, level / RANK_DIVISOR), HERO_RANK_MIN, HERO_RANK_MAX)})
	return heroes


# 源 :3092-3101 generateAiOpponents：count 对手（targetRank=playerRank-random(1,50*i)），按 rank 升序。
static func generate_ai_opponents(player_rank: int, player_level: int, count: int, cm: ConfigManager, rng: BattleRng) -> Array:
	var opponents: Array = []
	for i in range(1, count + 1):
		opponents.append(generate_ai_player(maxi(1, player_rank - rng.randi_range(1, OPPONENT_RANK_BASE * i)), player_level, cm, rng))
	opponents.sort_custom(func(a, b): return int(a["rank"]) < int(b["rank"]))
	return opponents


# 源 :3103-3113 generateRankBoard：count 名（rank=i）。
static func generate_rank_board(player_level: int, count: int, cm: ConfigManager, rng: BattleRng) -> Array:
	var board: Array = []
	for i in range(1, count + 1):
		var entry: Dictionary = generate_ai_player(i, player_level, cm, rng)
		entry["rank"] = i
		board.append(entry)
	return board


# 源 player.lua:522-528 getPvpGs：所有英雄 gs 和。
static func get_pvp_gs(player: Variant) -> int:
	var total: int = 0
	var hm: Variant = player.get("hero_manager")
	if hm != null:
		for inst_id in hm.heroes:
			total += int(hm.heroes[inst_id].gs)
	return total


# 源 :3163-3176 pvp 初始化。
func ensure_pvp() -> void:
	if pvp.is_empty():
		pvp = {"rank": RANK_INIT, "gs": 0, "left_count": LEFT_COUNT_DEFAULT, "buy_times": 0, "last_bt_time": 0, "highest_rank": RANK_INIT, "enemies": [], "records": [], "defend_lineup": [], "last_oppo_rank": RANK_INIT}


# 源 :3116-3429 ladder handler 11 子命令分发。返 reply。
func handle(obj: Dictionary, player: PlayerData, cm: ConfigManager, rng: BattleRng, now: int) -> Dictionary:
	ensure_pvp()
	pvp["gs"] = get_pvp_gs(player)
	var reply: Dictionary = {}
	if obj.has("_query_rankboard"):
		reply["_query_rankboard"] = _cmd_query_rankboard(player)
	if obj.has("_open_panel"):
		pvp["left_count"] = LEFT_COUNT_DEFAULT
		pvp["enemies"] = generate_ai_opponents(int(pvp["rank"]), player.team_level, OPPONENT_COUNT, cm, rng)
		if (pvp["defend_lineup"] as Array).is_empty():
			pvp["defend_lineup"] = _default_defend_lineup(player)
		reply["_open_panel"] = {"rank": pvp["rank"], "gs": pvp["gs"], "left_count": pvp["left_count"], "buy_times": pvp["buy_times"], "last_bt_time": pvp["last_bt_time"], "highestrank": pvp["highest_rank"], "oppos": pvp["enemies"], "lineup": pvp["defend_lineup"]}
	if obj.has("_apply_opponent"):
		pvp["enemies"] = generate_ai_opponents(int(pvp["rank"]), player.team_level, OPPONENT_COUNT, cm, rng)
		reply["_apply_opponent"] = {"oppos": pvp["enemies"]}
	if obj.has("_start_battle"):
		reply["_start_battle"] = _cmd_start_battle(obj["_start_battle"], player, cm, rng, now)
	if obj.has("_end_battle"):
		reply["_end_battle"] = _cmd_end_battle(obj["_end_battle"], player, now)
	if obj.has("_buy_battle_chance"):
		reply["_buy_battle_chance"] = _cmd_buy_battle_chance(player)
	if obj.has("_clear_battle_cd"):
		reply["_clear_battle_cd"] = _cmd_clear_battle_cd(player)
	if obj.has("_query_records"):
		reply["_query_records"] = {"records": pvp["records"]}
	if obj.has("_query_rankborad"):
		reply["_query_rankborad"] = {"rankboard": _cmd_query_rankborad(player, cm, rng)}
	if obj.has("_query_oppo"):
		reply["_query_oppo"] = _cmd_query_oppo(obj["_query_oppo"])
	if obj.has("_set_lineup"):
		pvp["defend_lineup"] = (obj["_set_lineup"] as Dictionary).get("lineup", [])
		pvp["gs"] = get_pvp_gs(player)
		reply["_set_lineup"] = {"result": "success", "lineup": pvp["defend_lineup"], "gs": str(pvp["gs"])}
	return reply


# 源 :3118-3155 _query_rankboard：20 NPC 假榜（AI_NAMES）+ self rank。
func _cmd_query_rankboard(player: PlayerData) -> Dictionary:
	var rank_list: Array = []
	for i in range(1, BOARD_SIZE + 1):
		var ni: int = ((i - 1) % AI_NAMES.size()) + 1
		rank_list.append({"avatar": (i % AVATAR_MOD) + 1, "vip": 0, "name": AI_NAMES[ni - 1], "level": maxi(RANKLIST_LEVEL_BASE - i * RANKLIST_LEVEL_STEP, RANKLIST_LEVEL_MIN)})
	return {"rank_list": rank_list, "pos": int(pvp["rank"]), "prev_pos": int(pvp["rank"]), "self_rank": {"avatar": player.avatar, "vip": 0, "name": player.player_name, "level": player.team_level}}


# 源 :3191-3203 默认防守阵容=前 5 英雄 tid。
func _default_defend_lineup(player: PlayerData) -> Array:
	var lineup: Array = []
	var hm: Variant = player.get("hero_manager")
	if hm != null:
		for inst_id in hm.heroes:
			if lineup.size() >= DEFEND_LINEUP_MAX:
				break
			lineup.append(int(hm.heroes[inst_id].tid))
	return lineup


# 源 :3226-3284 _start_battle：找 enemy（fallback 反推 rank）+ 装配 self/enemy heroes + 扣 left_count + rseed。
func _cmd_start_battle(cmd: Variant, player: PlayerData, cm: ConfigManager, rng: BattleRng, now: int) -> Dictionary:
	var cmd_d: Dictionary = cmd if cmd is Dictionary else {}
	var oppo_id: int = int(cmd_d.get("oppo_user_id", 0))
	var enemy: Dictionary = {}
	for e in (pvp["enemies"] as Array):
		if int(e["user_id"]) == oppo_id:
			enemy = e
			break
	if enemy.is_empty():
		enemy = generate_ai_player(maxi(1, oppo_id - USER_ID_BASE), player.team_level, cm, rng)
	if enemy.is_empty():
		return {}
	pvp["left_count"] = maxi(0, int(pvp["left_count"]) - 1)
	pvp["last_bt_time"] = now
	pvp["last_oppo_rank"] = int(enemy["rank"])
	return {"heroes": enemy["heroes"], "self_heroes": _assemble_self_heroes(cmd_d.get("attack_lineup", []), player), "is_robot": int(enemy.get("is_robot", 1)), "rseed": rng.randi_range(1, RSEED_MAX)}


# 源 :3250-3270 装配玩家进攻阵容（attack_lineup tid → hero data；找不到 fallback level 1）。
func _assemble_self_heroes(attack_lineup: Variant, player: PlayerData) -> Array:
	var hm: Variant = player.get("hero_manager")
	var result: Array = []
	var lineup: Array = attack_lineup if attack_lineup is Array else []
	for tid in lineup:
		var inst_id: int = _find_hero_inst_by_tid(hm, int(tid))
		if inst_id > 0:
			var h: Variant = hm.heroes[inst_id]
			result.append({"_tid": int(h.tid), "_level": int(h.level), "_rank": int(h.rank), "_stars": int(h.stars), "_items": StageManager._hero_items(h)})
		else:
			result.append({"_tid": int(tid), "_level": 1})
	return result


static func _find_hero_inst_by_tid(hm: Variant, tid: int) -> int:
	if hm == null:
		return 0
	for inst_id in hm.heroes:
		if int(hm.heroes[inst_id].tid) == tid:
			return int(inst_id)
	return 0


# 源 :3287-3330 _end_battle：记 record + victory 排名互换（rank=oppo_rank）+ highest + addPvpMoney 奖励。
func _cmd_end_battle(cmd: Variant, player: PlayerData, now: int) -> Dictionary:
	var result_str: String = str((cmd as Dictionary).get("result", "")) if cmd is Dictionary else str(cmd)
	(pvp["records"] as Array).insert(0, {"result": result_str, "time": now, "rank": int(pvp["rank"])})
	while (pvp["records"] as Array).size() > RECORDS_MAX:
		(pvp["records"] as Array).pop_back()
	if result_str == "victory" or result_str == "0":
		var old_rank: int = int(pvp["rank"])
		var oppo_rank: int = int(pvp.get("last_oppo_rank", pvp["rank"]))
		if oppo_rank < old_rank:
			pvp["rank"] = oppo_rank
		if int(pvp["rank"]) < int(pvp["highest_rank"]):
			pvp["highest_rank"] = pvp["rank"]
		var reward: int = maxi(REWARD_MIN, REWARD_BASE - int(pvp["rank"]))
		player.add_point("arenapoint", reward)  # 源 addPvpMoney→addPoint（arenapoint 归 PlayerData）
		return {"result": "victory", "rank": pvp["rank"], "prev_rank": old_rank, "reward": reward}
	return {"result": "defeat", "rank": pvp["rank"], "prev_rank": pvp["rank"], "reward": 0}


# 源 :3333-3355 _buy_battle_chance：GradientPrice["PVP Buy"][buy_times+1] 钻石购买 +1 left_count。
func _cmd_buy_battle_chance(player: PlayerData) -> Dictionary:
	var cost: int = BUY_COST_DEFAULT
	var price_row: Dictionary = player.cm.get_raw_table(&"GradientPrice").get(str(int(pvp["buy_times"]) + 1), {})
	if price_row.has("PVP Buy"):
		cost = int(price_row["PVP Buy"])
	if player.spend_diamond(cost):
		pvp["buy_times"] = int(pvp["buy_times"]) + 1
		pvp["left_count"] = int(pvp["left_count"]) + 1
		return {"result": "success", "left_count": pvp["left_count"], "buy_times": pvp["buy_times"]}
	return {"result": "fail"}


# 源 :3358-3372 _clear_battle_cd：50 钻清 last_bt_time。
func _cmd_clear_battle_cd(player: PlayerData) -> Dictionary:
	if player.spend_diamond(CLEAR_CD_COST):
		pvp["last_bt_time"] = 0
		return {"result": "success"}
	return {"result": "fail"}


# 源 :3402-3414 _query_oppo：按 user_id 查 enemies。
func _cmd_query_oppo(cmd: Variant) -> Dictionary:
	var oppo_id: int = int((cmd as Dictionary).get("user_id", 0)) if cmd is Dictionary else 0
	for e in (pvp["enemies"] as Array):
		if int(e["user_id"]) == oppo_id:
			return e
	return {}


# 源 :3382-3399 _query_rankborad：generateRankBoard 20 + self。
func _cmd_query_rankborad(player: PlayerData, cm: ConfigManager, rng: BattleRng) -> Array:
	var board: Array = generate_rank_board(player.team_level, BOARD_SIZE, cm, rng)
	board.append({"user_id": 0, "name": player.player_name, "avatar": player.avatar, "level": player.team_level, "vip": player.vip_level, "gs": pvp["gs"], "rank": pvp["rank"], "is_self": 1})
	return board


func to_dict() -> Dictionary:
	return {"pvp": pvp}


func from_dict(data: Dictionary) -> void:
	pvp = data.get("pvp", {})
	ensure_pvp()
