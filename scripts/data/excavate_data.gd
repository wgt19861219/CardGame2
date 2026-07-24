class_name ExcavateData
extends RefCounted

## 藏宝地穴数据查询（Data 层）— 照源 ui/excavate/excavate.lua 表查询部分翻译。
## ExcavateTreasure（矿点配置）+ ExcavateWildEnemy（野外敌人）+ GradientPrice（搜索梯度）+ VIP（矿点上限）。
## 字段名照源（含笔误 "Priduce Speed Per Minute" / "Emeny ID"，不改源拼写）。

const TABLE_TREASURE: StringName = &"ExcavateTreasure"
const TABLE_WILD_ENEMY: StringName = &"ExcavateWildEnemy"
const TABLE_GRADIENT: StringName = &"GradientPrice"
const TABLE_VIP: StringName = &"VIP"

const FIELD_SEARCH_COST: StringName = &"Excavate Search"
const FIELD_MINE_LIMIT: StringName = &"Excavate Treasure Amount"
const FIELD_PROB_WEIGHT: StringName = &"Prob Weight"
const FIELD_LEVEL_REQ: StringName = &"Level Requirement"
const FIELD_MAX_PLAYER: StringName = &"Max Player"
const FIELD_PRODUCE_TYPE: StringName = &"Produce Type"
const FIELD_PRODUCE_SPEED: StringName = &"Priduce Speed Per Minute"  # 源笔误照搬
const FIELD_STORAGE: StringName = &"Storage Amount"
const FIELD_LOOT_RATIO: StringName = &"Loot Ratio"
const FIELD_PREPARE_TIME: StringName = &"Prepare Time"
const FIELD_SAFE_AMOUNT: StringName = &"Safe Amount"   # 源 :3846 lootAmount 下限保护（<Safe Amount→0）
const FIELD_DISPLAY_NAME: StringName = &"Display Name"
const FIELD_PRODUCE_ID: StringName = &"Produce ID"
const FIELD_WILD_STAGE: StringName = &"Stage ID"
const FIELD_WILD_AVATAR: StringName = &"Avatar ID"
const FIELD_WILD_NAME: StringName = &"Player Name"
const FIELD_WILD_LEVEL: StringName = &"Player Level"

const PRODUCE_DIAMOND: String = "Diamond"
const PRODUCE_GOLD: String = "Gold"
const PRODUCE_ITEM: String = "Item"
const SEARCH_COST_FALLBACK: int = 100   # GradientPrice 缺失默认（表 1 行 Excavate Search=100）
const WILD_INDEX_ONE: int = 1            # 单机 1 人矿点取 Wild ID 1（源 Max Player 对应，单机裁多人）
const SECONDS_PER_MINUTE: int = 60       # 产出速率 per minute → per second 换算（源 speed_time_unit=60）

# Picture 字段（excavate_{type}_{s/m/l}.jpg）源资源缺失，降级 name 图（含矿点名文字）。
const NAME_RES_BASE: String = "res://assets/ui/alpha/HVGA/excavate/excavate_name_"
const NAME_RES_EXT: String = ".png"
const PRODUCE_TO_NAME_KEY: Dictionary = {
	PRODUCE_DIAMOND: "diamond",
	PRODUCE_GOLD: "gold",
	PRODUCE_ITEM: "exp",
}


## 取矿点配置行（照 getRow:442）。
static func get_treasure_row(cm: Variant, type_id: int) -> Dictionary:
	return cm.get_raw_table(TABLE_TREASURE).get(str(type_id), {})


## 搜索消耗（照 getExcavateSearchCost:18-32）：gt[times+1]，<=0 用 maxCost（连续 >0 末值）。
static func get_search_cost(cm: Variant, times: int) -> int:
	var gt: Dictionary = cm.get_raw_table(TABLE_GRADIENT)
	var max_cost: int = SEARCH_COST_FALLBACK
	var idx: int = WILD_INDEX_ONE
	while gt.has(str(idx)):
		var c: int = int(gt[str(idx)].get(FIELD_SEARCH_COST, 0))
		if c > 0:
			max_cost = c
			idx += 1
		else:
			break
	var cost: int = int(gt.get(str(times + 1), {}).get(FIELD_SEARCH_COST, 0))
	return cost if cost > 0 else max_cost


## 最大搜索次数（照 getMaxSearchTime:596-610）：连续 >0 的最大 index。
static func get_max_search_time(cm: Variant) -> int:
	var gt: Dictionary = cm.get_raw_table(TABLE_GRADIENT)
	var max_time: int = 0
	var idx: int = WILD_INDEX_ONE
	while gt.has(str(idx)):
		if int(gt[str(idx)].get(FIELD_SEARCH_COST, 0)) > 0:
			max_time = idx
			idx += 1
		else:
			break
	return max_time


## 矿点持有上限（照 getMineExcavateLimit:567）：VIP[vip]["Excavate Treasure Amount"]。
static func get_mine_limit(cm: Variant, vip: int) -> int:
	return int(cm.get_raw_table(TABLE_VIP).get(str(vip), {}).get(FIELD_MINE_LIMIT, 0))


## 最大矿点数（照 getMineExcavateMaxAmount:554）：遍历 VIP 取最大 limit。
static func get_mine_max_amount(cm: Variant) -> int:
	var vip_table: Dictionary = cm.get_raw_table(TABLE_VIP)
	var amount: int = 0
	var idx: int = 0
	while vip_table.has(str(idx)):
		amount = maxi(amount, int(vip_table[str(idx)].get(FIELD_MINE_LIMIT, 0)))
		idx += 1
	return amount


## 按 Prob Weight 随机选矿点类型（单机化：源服务端选 → 本地 roll；过滤 Level Requirement）。
## 返 0 表示无候选（表空或等级全不够）。
static func roll_search_type_id(cm: Variant, rng: Variant, player_level: int) -> int:
	var t: Dictionary = cm.get_raw_table(TABLE_TREASURE)
	var candidates: Array = []
	var total: float = 0.0
	for key in t:
		var row: Dictionary = t[key]
		if int(row.get(FIELD_LEVEL_REQ, 0)) > player_level:
			continue   # 等级不够不 roll（单机化过滤，源服务端按等级筛）
		var w: float = float(row.get(FIELD_PROB_WEIGHT, 0))
		if w <= 0.0:
			continue
		candidates.append({"id": int(key), "weight": w})
		total += w
	if candidates.is_empty() or total <= 0.0:
		return 0
	var r: float = float(rng.randf()) * total
	var acc: float = 0.0
	for c in candidates:
		acc += float(c["weight"])
		if r <= acc:
			return int(c["id"])
	return int(candidates.back()["id"])


## 矿点对应野外敌人 id（照 ExcavateTreasure "Wild ID N" 按 Max Player；单机取 Wild ID 1）。
static func get_wild_enemy_id(cm: Variant, type_id: int) -> int:
	var row: Dictionary = get_treasure_row(cm, type_id)
	var wild_dict: Dictionary = row.get("Wild ID %d" % WILD_INDEX_ONE, {})
	return int(wild_dict.get(str(WILD_INDEX_ONE), 0))


## 野外敌人配置（照 ExcavateWildEnemy 表）。
static func get_wild_enemy(cm: Variant, wild_id: int) -> Dictionary:
	return cm.get_raw_table(TABLE_WILD_ENEMY).get(str(wild_id), {})


## 野外敌人 Stage ID（dict {"1":30001,"2":0}，取主 stage 1）。
static func get_wild_stage_id(cm: Variant, wild_id: int) -> int:
	var wild: Dictionary = get_wild_enemy(cm, wild_id)
	var stage_dict: Dictionary = wild.get(FIELD_WILD_STAGE, {})
	return int(stage_dict.get(str(WILD_INDEX_ONE), 0))


static func produce_type(cm: Variant, type_id: int) -> String:
	return String(get_treasure_row(cm, type_id).get(FIELD_PRODUCE_TYPE, ""))


static func produce_speed(cm: Variant, type_id: int) -> float:
	return float(get_treasure_row(cm, type_id).get(FIELD_PRODUCE_SPEED, 0.0))


static func storage_amount(cm: Variant, type_id: int) -> int:
	return int(get_treasure_row(cm, type_id).get(FIELD_STORAGE, 0))


static func loot_ratio(cm: Variant, type_id: int) -> float:
	return float(get_treasure_row(cm, type_id).get(FIELD_LOOT_RATIO, 0.0))


static func prepare_time(cm: Variant, type_id: int) -> int:
	return int(get_treasure_row(cm, type_id).get(FIELD_PREPARE_TIME, 0))


static func max_player(cm: Variant, type_id: int) -> int:
	return int(get_treasure_row(cm, type_id).get(FIELD_MAX_PLAYER, WILD_INDEX_ONE))


static func display_name(cm: Variant, type_id: int) -> String:
	return String(get_treasure_row(cm, type_id).get(FIELD_DISPLAY_NAME, ""))


static func produce_id(cm: Variant, type_id: int) -> int:
	return int(get_treasure_row(cm, type_id).get(FIELD_PRODUCE_ID, 0))


## lootAmount 下限保护（照 local_server.lua:3846 typeRow["Safe Amount"]）。
## 占领结算 loot<safe_amount 时归零（掠夺量不足保底不发）。
static func safe_amount(cm: Variant, type_id: int) -> int:
	return int(get_treasure_row(cm, type_id).get(FIELD_SAFE_AMOUNT, 0))


## 构建资源奖励结构（照 local_server.lua:3648-3661 buildResourceReward）。
## amount<=0 返空 Dict（无奖励）；Produce Type→gold/diamond/item（item 带 Produce ID param1）。
static func build_resource_reward(cm: Variant, type_id: int, amount: int) -> Dictionary:
	if amount <= 0:
		return {}
	var pt: String = produce_type(cm, type_id)
	var reward_type: String = "gold"   # 源 :3651 default
	if pt == PRODUCE_DIAMOND:
		reward_type = "diamond"
	elif pt == PRODUCE_ITEM:
		reward_type = "item"
	if reward_type == "item":
		return {"_type": "item", "_param1": produce_id(cm, type_id), "_param2": amount}
	return {"_type": reward_type, "_param1": amount}


## 发放资源奖励给 player（照 excavatenet.lua:48-60 dealEndBattle：gold→addMoney/diamond→addrmb/item→addEquip）。
## reward = build_resource_reward 返的 {_type, _param1[, _param2]}；player null 或 reward 空跳过。
## 战斗胜利占领（finalize_excavate_battle）+ 放弃结算（ExcavateGiveupPanel）共用。
static func grant_resource_reward(player: PlayerData, reward: Dictionary) -> void:
	if player == null or reward.is_empty():
		return
	var rtype: String = String(reward.get("_type", ""))
	var p1: int = int(reward.get("_param1", 0))
	match rtype:
		"gold":
			player.add_point("gold", p1)
		"diamond":
			player.add_point("diamond", p1)
		"item":
			player.add_item(p1, int(reward.get("_param2", 0)))


## 矿点展示图（源 Picture 字段 excavate_{type}_{s/m/l}.jpg 资源全缺，降级 name 图，含矿点名文字）。
static func picture_res(cm: Variant, type_id: int) -> String:
	var pt: String = produce_type(cm, type_id)
	var mp: int = max_player(cm, type_id)
	var key: String = String(PRODUCE_TO_NAME_KEY.get(pt, "exp"))
	return NAME_RES_BASE + key + "_" + str(mp) + NAME_RES_EXT


const TABLE_STAGE: StringName = &"Stage"
const TABLE_BATTLE: StringName = &"Battle"
const FIELD_MONSTER_LEVEL: StringName = &"Monster Level"
const RANK_DIVISOR: int = 10          # 源 heroLevel2Rank（tools.lua:1021-1026）ceil(level/10) 分母
const RANK_MAX: int = 10              # 源 heroLevel2Rank min(r, 10)（旧误 5，照源修 10）
const FULL_HP_PERC: int = 10000       # 源 downmsg.hero_dyna _hp_perc=10000（满血）
const WAVE_ONE: String = "1"          # Battle 表 wave 1 key（excavate 单波）

## 照源 heroLevel2Rank（tools.lua:1021-1026）：l=max(1,level)；r=ceil(l/10)；min(r,10)。
## level 1-10→1 / 11-20→2 / ... / 91-100→10。旧版整数除法（向下）+ max 5 偏离源（修）。
static func hero_level_to_rank(level: int) -> int:
	var lvl: int = maxi(1, level)
	return mini(int(ceil(float(lvl) / float(RANK_DIVISOR))), RANK_MAX)


## 敌人英雄装配（照 getStageEnemyData:362-401）：Stage/Battle 表查 Monster ID/Level/Stars/MP。
## rank = hero_level_to_rank(level)（照源 heroLevel2Rank）。
## 返 [{base={_tid,_rank,_level,_stars,_exp,_gs,_skill_levels,_items}, dyna={_hp_perc,_mp_perc}}]。
static func get_stage_enemy_data(cm: Variant, stage_id: int) -> Array:
	var srow: Dictionary = cm.get_raw_table(TABLE_STAGE).get(str(stage_id), {})
	var brow: Dictionary = cm.get_raw_table(TABLE_BATTLE).get(str(stage_id), {}).get(WAVE_ONE, {})
	var level: int = int(srow.get(FIELD_MONSTER_LEVEL, WILD_INDEX_ONE))
	var rank: int = hero_level_to_rank(level)
	var heroes: Array = []
	var i: int = WILD_INDEX_ONE
	while true:
		var tid: int = int(brow.get("Monster %d ID" % i, 0))
		if tid == 0:
			break
		var base: Dictionary = {
			"_tid": tid,
			"_rank": rank,
			"_level": level,
			"_stars": int(brow.get("Stars %d" % i, WILD_INDEX_ONE)),
			"_exp": 0,
			"_gs": 0,
			"_skill_levels": {},
			"_items": {},
		}
		var dyna: Dictionary = {
			"_hp_perc": FULL_HP_PERC,
			"_mp_perc": int(brow.get("MP %d" % i, 0)),
		}
		heroes.append({"base": base, "dyna": dyna})
		i += 1
	return heroes
