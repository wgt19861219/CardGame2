class_name ExcavateManager
extends RefCounted

## 藏宝地穴（Logic 层）— 照源 local_server.lua:3438-3977 excavate handler + ui/excavate/excavate.lua 翻译（裁联机 excavatenet）。
## 矿点列表 excavate_data：6 态状态机（searched/battle/prepare/protect/occupy/empty）+ 跨天重置 search_times + 占领结算发 loot。
## 单机化：源 ed.send handler → 本地方法；mercenary/invite/复仇/联机锁定(battle 态)/被攻击保护(protect 态) 裁剪。

const OWNER_MONSTER: String = "monster"   # 搜索到的（野外怪守，可攻击占领）
const OWNER_MINE: String = "mine"         # 已占领（产出）
# 6 态状态机（照 local_server.lua:3542-3555 updateMineState 转换）。searched→empty(5min 过期) /
# prepare→occupy(占领准备期到期) / protect→occupy(保护期到期，单机不出现)。battle：源联机锁定，单机本地战斗即时不设入口；empty：过期空。
const STATE_SEARCHED: String = "searched"
const STATE_BATTLE: String = "battle"
const STATE_PREPARE: String = "prepare"
const STATE_PROTECT: String = "protect"
const STATE_OCCUPY: String = "occupy"
const STATE_EMPTY: String = "empty"
const SEARCH_EXPIRE_SEC: int = 300
const SECONDS_PER_MINUTE: int = 60
const ID_START: int = 1                   # 矿点 _id 起始
const ROUND_HALF: float = 0.5
const DAY_KEY_YEAR_WEIGHT: int = 10000    # 本地自然日序号 year 权重（照 tavern_data._local_day_key）
const DAY_KEY_MONTH_WEIGHT: int = 100
const REASON_MAX_TIME: String = "max_time"
const REASON_LACK_MONEY: String = "lack_money"
const REASON_NO_CANDIDATE: String = "no_candidate"
const WILD_DEFEND_TEAM_SIZE: int = 5

var excavate_data: Array = []   # 矿点 dict 列表
var search_times: int = 0
var last_search_ts: int = 0
var search_id: int = 0          # 当前搜索点 id（源 excavateSearchId）
var config: ConfigManager = null
var history: ExcavateHistory   # 战斗历史（单机：玩家 excavate 战斗记录）
var _next_id: int = ID_START
# T3 依赖倒置：战斗表现音效钩子（GameData 装配后注入 ExcavateBattle.assemble 用；缺省静默跳过）。
var sfx_hook: Callable = Callable()


func _init(cm: ConfigManager = null) -> void:
	config = cm
	history = ExcavateHistory.new()


## 矿点列表（照 getData:402 无参返全表）。
func get_data_list() -> Array:
	return excavate_data


## 取单矿点（照 getData:402 带 id）。
func get_data(excavate_id: int) -> Dictionary:
	for d in excavate_data:
		if int(d["_id"]) == excavate_id:
			return d
	return {}


## 当前搜索点（源 excavateSearchId 对应的 data）。
func get_searched() -> Dictionary:
	if search_id == 0:
		return {}
	return get_data(search_id)


## 能否搜索（照 checkSearchTimeMax:611 + cost>gold 判断）。返 {ok, reason, cost}。
func can_search(player: Variant, now: int) -> Dictionary:
	var max_time: int = ExcavateData.get_max_search_time(config)
	if search_times >= max_time:
		return {"ok": false, "reason": REASON_MAX_TIME, "cost": 0}
	var cost: int = ExcavateData.get_search_cost(config, search_times)
	if player != null and cost > int(player.hero_manager.gold):
		return {"ok": false, "reason": REASON_LACK_MONEY, "cost": cost}
	return {"ok": true, "reason": "", "cost": cost}


## 搜索矿点（照 doSearchExcavateReply:291-323 + search:324）：扣金 + roll + 加 monster 矿点。
## 单机化：源联机 ed.send → 本地 roll_search_type_id + 直接加 data。返 {ok, type_id, owner, reason}。
func search(player: Variant, rng: Variant, now: int) -> Dictionary:
	refresh(now)
	var check: Dictionary = can_search(player, now)
	if not bool(check["ok"]):
		return {"ok": false, "type_id": 0, "owner": "", "reason": String(check["reason"])}
	var cost: int = int(check["cost"])
	var level: int = int(player.team_level) if player != null else ID_START
	var type_id: int = ExcavateData.roll_search_type_id(config, rng, level)
	if type_id == 0:
		return {"ok": false, "type_id": 0, "owner": "", "reason": REASON_NO_CANDIDATE}
	if player != null:
		player.hero_manager.add_money(-cost)
	search_times += 1
	last_search_ts = now
	_remove_searched()   # 清旧搜索点（源 removeSearchData:226）
	var d: Dictionary = _new_monster_node(type_id, now, player, rng)
	excavate_data.append(d)
	search_id = int(d["_id"])
	return {"ok": true, "type_id": type_id, "owner": OWNER_MONSTER, "reason": ""}


## 建搜索到的 monster 矿点（owner=monster, state=occupy, 配置驱动 produce_speed/storage）。
func _new_monster_node(type_id: int, now: int, player: Variant, rng: Variant) -> Dictionary:
	var id: int = _next_id
	_next_id += 1
	return {
		"_id": id,
		"_type_id": type_id,
		"_owner": OWNER_MONSTER,
		"_state": STATE_SEARCHED,
		"_state_end_ts": now + SEARCH_EXPIRE_SEC,
		"_found_ts": now,
		"_produce_speed": ExcavateData.produce_speed(config, type_id),
		"_storage": ExcavateData.storage_amount(config, type_id),
		"_res_got": 0.0,
		"_wild_id": ExcavateData.get_wild_enemy_id(config, type_id),
		"_team": _generate_wild_team(player, rng),
	}


## 已产出量（照 calcProduced:3534，不限 owner 任何态累计；占领 loot/drop 结算用）= speed×elapsed_min + res_got。
func _calc_produced(d: Dictionary, now: int) -> int:
	if int(d.get("_found_ts", 0)) == 0:
		return 0
	var elapsed_min: float = float(now - int(d["_found_ts"])) / SECONDS_PER_MINUTE
	if elapsed_min < 0.0:
		elapsed_min = 0.0
	var amount: float = float(d["_produce_speed"]) * elapsed_min + float(d["_res_got"])
	return int(amount + ROUND_HALF) if amount > 0.0 else 0


## UI 显示产出量（照 getProduced:462-489：仅 mine owner 矿点产出可见）。
func produce_amount(excavate_id: int, now: int) -> int:
	var d: Dictionary = get_data(excavate_id)
	if d.is_empty() or String(d["_owner"]) != OWNER_MINE:
		return 0
	return _calc_produced(d, now)


## 总累计产出（照 getProduced:462 无 owner 限制公开版）：monster 可掠夺量 fill 用
## （源 excavatemap refreshBaseRecord:333 produced×getRobRatio，非 mine 也计产）。
func produced_total(excavate_id: int, now: int) -> int:
	var d: Dictionary = get_data(excavate_id)
	if d.is_empty():
		return 0
	return _calc_produced(d, now)


## 存储剩余（照 getStorage:490）：storage - produced（不低于 0）。
func storage_remaining(excavate_id: int, now: int) -> int:
	var d: Dictionary = get_data(excavate_id)
	if d.is_empty():
		return 0
	var remain: int = int(d["_storage"]) - produce_amount(excavate_id, now)
	return maxi(remain, 0)


## 刷新所有矿点状态 + 跨天重置（照 query handler :3671-3675 顶部副作用）。UI open/search 时调。
func refresh(now: int) -> void:
	for d in excavate_data:
		_update_mine_state(d, now)
	check_search_day_reset(now)


## 更新单矿点状态（照 updateMineState:3542-3555：到期态转换 searched→empty / prepare,protect→occupy）。
func _update_mine_state(d: Dictionary, now: int) -> void:
	var end_ts: int = int(d.get("_state_end_ts", 0))
	if end_ts <= 0 or now < end_ts:
		return
	var s: String = String(d.get("_state", ""))
	if s == STATE_SEARCHED:
		d["_state"] = STATE_EMPTY
	elif s == STATE_PREPARE or s == STATE_PROTECT:
		d["_state"] = STATE_OCCUPY
	else:
		return
	d["_state_end_ts"] = 0


## 跨天重置搜索次数（照 checkSearchDayReset:3628-3637：checkTwoDateod 不同日→search_times=0）。
func check_search_day_reset(now: int) -> void:
	if search_times > 0 and _crossed_day(last_search_ts, now):
		search_times = 0
		last_search_ts = now


static func _crossed_day(last_ts: int, now: int) -> bool:
	if last_ts <= 0:
		return true
	var off_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return _local_day_key(last_ts, off_min) != _local_day_key(now, off_min)


static func _local_day_key(ts: int, off_min: int) -> int:
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(ts + off_min * SECONDS_PER_MINUTE)
	return int(dt["year"]) * DAY_KEY_YEAR_WEIGHT + int(dt["month"]) * DAY_KEY_MONTH_WEIGHT + int(dt["day"])


## 占领矿点（照 _excavate_end_battle victory:3849-3859）：monster→mine + state=prepare（占领准备期）+ state_end_ts=now+Prepare Time。
## prepare 态到期（_update_mine_state）→ occupy 产出态。found_ts=now 重算产出。draw_battle_reward 胜利后调。
func occupy(excavate_id: int, now: int) -> void:
	var d: Dictionary = get_data(excavate_id)
	if d.is_empty():
		return
	d["_owner"] = OWNER_MINE
	d["_state"] = STATE_PREPARE
	d["_state_end_ts"] = now + ExcavateData.prepare_time(config, int(d["_type_id"]))
	d["_found_ts"] = now
	d["_res_got"] = 0.0
	if search_id == excavate_id:
		search_id = 0


## 放弃矿点（照 _drop_excavate:3943-3962 + doGiveup:681）：结算累计产出（calcProduced 不限 owner）+ 移除。返结算量（giveup 弹窗用）。
func drop(excavate_id: int, now: int) -> int:
	var d: Dictionary = get_data(excavate_id)
	var amount: int = _calc_produced(d, now) if not d.is_empty() else 0
	for i in range(excavate_data.size()):
		if int(excavate_data[i]["_id"]) == excavate_id:
			excavate_data.remove_at(i)
			break
	if search_id == excavate_id:
		search_id = 0
	return amount


## 清当前搜索点（照 removeSearchData:226：重搜前清旧 search_id 矿点）。
func _remove_searched() -> void:
	if search_id == 0:
		return
	for i in range(excavate_data.size()):
		if int(excavate_data[i]["_id"]) == search_id:
			excavate_data.remove_at(i)
			break
	search_id = 0


## 矿点数（照 getMineExcavateAmount:572，mine 计数；占领上限检查用）。
func mine_count() -> int:
	var c: int = 0
	for d in excavate_data:
		if String(d["_owner"]) == OWNER_MINE:
			c += 1
	return c


## 序列化（矿点动态占领/产出必须存档；源联机持久化 → 本地存档）。
func to_dict() -> Dictionary:
	return {
		"excavate_data": excavate_data.duplicate(true),
		"search_times": search_times,
		"last_search_ts": last_search_ts,
		"search_id": search_id,
		"next_id": _next_id,
		"history": history.to_dict(),
	}


static func from_dict(data: Dictionary, cm: ConfigManager) -> ExcavateManager:
	var mgr := ExcavateManager.new(cm)
	mgr.excavate_data = data.get("excavate_data", [])
	mgr.search_times = int(data.get("search_times", 0))
	mgr.last_search_ts = int(data.get("last_search_ts", 0))
	mgr.search_id = int(data.get("search_id", 0))
	mgr._next_id = int(data.get("next_id", ID_START))
	mgr.history = ExcavateHistory.from_dict(data.get("history", {}))
	return mgr


## 玩家驻防队伍 tid 列表（照 getTeamData:335 + sendHeroesMining，单机简化单 team）。
func get_defend_team(excavate_id: int) -> Array:
	var d: Dictionary = get_data(excavate_id)
	if d.is_empty() or String(d["_owner"]) != OWNER_MINE:
		return []
	var teams: Array = d.get("_team", [])
	if teams.is_empty():
		return []
	return teams[0].get("_hero_bases", [])


## 设置驻防队伍（照 addTeamData:354 + sendHeroesMining:147，玩家英雄进驻 mine 矿点）。
func set_defend_team(excavate_id: int, hero_tids: Array[int], now: int) -> void:
	var d: Dictionary = get_data(excavate_id)
	if d.is_empty():
		return
	var dynas: Array = []
	for _tid in hero_tids:
		dynas.append({"_hp_perc": ExcavateData.FULL_HP_PERC, "_mp_perc": 0})
	d["_team"] = [{"_team_id": 0, "_hero_bases": hero_tids.duplicate(), "_hero_dynas": dynas}]


## 野怪防守队（照源 local_server.lua:3558-3625 generateWildTeam）：玩家自己英雄池 shuffle 抽5镜像。
## hero.get() 通用访问（真 HeroInstance Object.get + 测试 Dictionary.get 均可）。
static func _generate_wild_team(player: Variant, rng: Variant) -> Array:
	var pool: Array[Dictionary] = []
	var heroes: Dictionary = player.hero_manager.heroes
	for inst_id in heroes:
		var hero: Variant = heroes.get(inst_id)
		if hero == null:
			continue
		pool.append({
			"_tid": int(hero.get("tid")),
			"_level": int(hero.get("level")),
			"_stars": int(hero.get("stars")),
			"_rank": int(hero.get("rank")),
		})
	# Fisher-Yates shuffle（照源 :3604-3607 math_random swap）
	var n: int = pool.size()
	while n > 1:
		n -= 1
		var j: int = rng.randi_range(0, n)
		var tmp: Dictionary = pool[n]
		pool[n] = pool[j]
		pool[j] = tmp
	var count: int = mini(WILD_DEFEND_TEAM_SIZE, pool.size())
	var bases: Array = []
	var dynas: Array = []
	var i: int = 0
	while i < count:
		bases.append(pool[i])
		dynas.append({"_hp_perc": ExcavateData.FULL_HP_PERC, "_mp_perc": 0})
		i += 1
	return [{"_team_id": 0, "_hero_bases": bases, "_hero_dynas": dynas}]


## monster 敌人英雄（照源 generateWildTeam：搜索时存的玩家英雄镜像 _team）。
## 返 [{base,dyna}]（兼容 assemble_excavate_battle/excavate_team_panel 调用方 e["base"] 格式）。
func get_enemy_heroes(excavate_id: int) -> Array:
	var d: Dictionary = get_data(excavate_id)
	if d.is_empty() or String(d["_owner"]) != OWNER_MONSTER:
		return []
	var teams: Array = d.get("_team", [])
	if teams.is_empty():
		return []
	var bases: Array = teams[0].get("_hero_bases", [])
	var dynas: Array = teams[0].get("_hero_dynas", [])
	var result: Array = []
	var i: int = 0
	while i < bases.size():
		var dyna: Dictionary = dynas[i] if i < dynas.size() else {"_hp_perc": ExcavateData.FULL_HP_PERC, "_mp_perc": 0}
		result.append({"base": bases[i], "dyna": dyna})
		i += 1
	return result


## 战斗胜利占领（照 _excavate_end_battle victory:3839-3868）：占领(monster→mine, state=prepare) + 发 loot。
## loot = 占领前 monster 态累计产出(calcProduced) × Loot Ratio，<Safe Amount→0（源 :3843-3847）。
## 返 {ok, type_id, produce_type, storage, loot, reward}：reward 资源结构（源 :3861 buildResourceReward）。
func draw_battle_reward(excavate_id: int, now: int) -> Dictionary:
	var d: Dictionary = get_data(excavate_id)
	if d.is_empty():
		return {"ok": false}
	var type_id: int = int(d["_type_id"])
	var produced: int = _calc_produced(d, now)   # 占领前 monster 态累计产出（不限 owner，照源 :3843）
	var loot: int = int(float(produced) * ExcavateData.loot_ratio(config, type_id))
	if loot < ExcavateData.safe_amount(config, type_id):
		loot = 0
	occupy(excavate_id, now)
	return {
		"ok": true,
		"type_id": type_id,
		"produce_type": ExcavateData.produce_type(config, type_id),
		"storage": int(d["_storage"]),
		"loot": loot,
		"reward": ExcavateData.build_resource_reward(config, type_id, loot),
	}
