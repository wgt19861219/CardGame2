class_name CrusadeManager
extends RefCounted

## 远征/十字军（Logic 层，Step 3.5）：15 层 + 英雄 HP/MP 跨战斗保存 + 分组 reset(满血) + 每层领奖。
## 分组 reset 走数据驱动（治旧版 reset_group 硬编码）。英雄状态独立（hero_crusade_data）。

const MAX_STAGE: int = 15
const FULL_HP_MP: float = 1.0
const CRUSADE_MAX_TICKS: int = 300  # 战斗最大 tick（防死循环，同 StageManager.BATTLE_MAX_TICKS）
const DEFAULT_WAVE: int = 1         # Crusade 单波（源每关 wave=1）
const PERC_DENOM: int = 10000
const TEAM_SIZE: int = 5
const FORMATION_MAX_PER_LINE: int = 3
const LINE_REAR: int = 2           # 阵型数组后列索引（lint 禁裸 2）
const VIP_MAX: int = 3
const VIP_STAGE_DIVISOR: int = 5
const PICK_OFFSET_SCALE: int = 3
const REWARD_CRUSADE_POINT := "CrusadePoint"
const REWARD_CHEST_BOX := "ChestBox"
const REWARD_ITEM := "Item"
const CRUSADE_POINT_MULTIPLIER: int = 10
const CHEST_BOX_COIN_DEFAULT: int = 50
const CHEST_BOX_COIN_MAP: Dictionary = {1: 50, 2: 100, 3: 200, 4: 100, 5: 200, 6: 400}
const AI_NAMES: Array[String] = [
	"暗影猎手", "龙骑士", "风暴法师", "圣光骑士", "血魔领主",
	"冰霜女王", "烈焰术士", "大地守卫", "幽灵刺客", "雷霆战神",
	"月光游侠", "黑暗领主", "星辰法师", "铁甲战士", "毒蛇猎手",
]

var cur_stage: int = 1
var reset_times: int = 0
var last_reset_ts: int = 0   # 跨日清零锚点（check_daily_reset；0=未记录，旧档兼容）
var hero_hp_perc: Dictionary = {}   # tid(int) -> hp%(0-1)
var hero_mp_perc: Dictionary = {}   # tid(int) -> mp%
var cleared_stages: Dictionary = {}  # stage(int) -> bool
var rewarded_stages: Dictionary = {} # stage(int) -> bool
var enemies: Dictionary = {}  # stage(int) -> {heroes, name, level, avatar, vip}（源 initCrusade 生成）
var config: ConfigManager = null
# T3 依赖倒置：战斗表现音效钩子（GameData 装配后注入；缺省 Callable 静默跳过，headless 可测）。
var sfx_hook: Callable = Callable()


func _init(cm: ConfigManager = null) -> void:
	config = cm

## 战斗结算：保存 HP/MP 百分比，胜利推进下一层。
func fight(won: bool, hp_perc_map: Dictionary, mp_perc_map: Dictionary, stage: int = -1) -> bool:
	hero_hp_perc = hp_perc_map
	hero_mp_perc = mp_perc_map
	var battle_stage: int = cur_stage if stage < 0 else stage
	if won:
		cleared_stages[battle_stage] = true
		if battle_stage >= cur_stage:
			cur_stage = mini(battle_stage + 1, MAX_STAGE)
		return true
	return false

const RESET_MAX_PER_DAY: int = 10
func get_reset_left() -> int:
	return RESET_MAX_PER_DAY - reset_times


## 跨日重置 reset_times（源 crusade.lua:536-538 leftTime=10-_reset_times 服务器每日重置；
## 单机化本地跨日清零，照 excavate_manager.check_search_day_reset 范式。2026-08-22 巡检接线）。
func check_daily_reset(now: int) -> void:
	if reset_times > 0 and _crossed_day(last_reset_ts, now):
		reset_times = 0
		last_reset_ts = now


const DAY_KEY_YEAR_WEIGHT: int = 10000
const DAY_KEY_MONTH_WEIGHT: int = 100
const SECONDS_PER_MINUTE: int = 60


static func _crossed_day(last_ts: int, now: int) -> bool:
	if last_ts <= 0:
		return true
	var off_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return _local_day_key(last_ts, off_min) != _local_day_key(now, off_min)


static func _local_day_key(ts: int, off_min: int) -> int:
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(ts + off_min * SECONDS_PER_MINUTE)
	return int(dt["year"]) * DAY_KEY_YEAR_WEIGHT + int(dt["month"]) * DAY_KEY_MONTH_WEIGHT + int(dt["day"])


## 分组 reset：满血 + 回到层 1 + 清进度（reset_times++，走数据驱动重置）。
func reset() -> void:
	cur_stage = 1
	reset_times += 1
	hero_hp_perc.clear()
	hero_mp_perc.clear()
	cleared_stages.clear()
	rewarded_stages.clear()

## 领奖：需通关且未领。
func draw_reward(stage: int) -> bool:
	if not bool(cleared_stages.get(stage, false)):
		return false
	if bool(rewarded_stages.get(stage, false)):
		return false
	rewarded_stages[stage] = true
	return true


## 领奖并返奖励槽（照源 CrusadeRewards 表）：查 CrusadeRewardsData + 标记 rewarded。
func draw_reward_slots(stage: int, vip_valid: bool = false) -> Array[Dictionary]:
	if not bool(cleared_stages.get(stage, false)) or bool(rewarded_stages.get(stage, false)):
		return []
	rewarded_stages[stage] = true
	return CrusadeRewardsData.get_reward_slots(config, stage, DEFAULT_WAVE, vip_valid)

func hero_hp(tid: int) -> float:
	return float(hero_hp_perc.get(tid, FULL_HP_MP))

func hero_mp(tid: int) -> float:
	return float(hero_mp_perc.get(tid, FULL_HP_MP))

func is_stage_cleared(stage: int) -> bool:
	return bool(cleared_stages.get(stage, false))

func is_stage_rewarded(stage: int) -> bool:
	return bool(rewarded_stages.get(stage, false))


## 已生成则跳过（:2404-2406）。单机化：math_random→rng 注入（确定性）。
func init_crusade(rng: BattleRng) -> void:
	if not enemies.is_empty() or config == null or rng == null:
		return
	var pools: Dictionary = CrusadeData.build_hero_pools(config, rng)
	var front: Array = pools["front"]
	var middle: Array = pools["middle"]
	var rear: Array = pools["rear"]
	var s: int = 1
	while s <= MAX_STAGE:
		var lvl: int = CrusadeData.stage_level(s)
		var stars: int = CrusadeData.stage_stars(s)
		var rank: int = CrusadeData.stage_rank(s)
		var formation: Array[int] = _random_formation(rng)
		var stage_enemies: Array[Dictionary] = []
		stage_enemies.append_array(_pick_line(front, s, formation[0], lvl, stars, rank))
		stage_enemies.append_array(_pick_line(middle, s, formation[1], lvl, stars, rank))
		stage_enemies.append_array(_pick_line(rear, s, formation[LINE_REAR], lvl, stars, rank))
		var name_idx: int = int(rng.randi_range(0, AI_NAMES.size() - 1))
		enemies[s] = {
			"heroes": stage_enemies,
			"name": AI_NAMES[name_idx],
			"level": lvl,
			"avatar": int(stage_enemies[0]["_tid"]) if not stage_enemies.is_empty() else 0,
			"vip": mini(int(s / VIP_STAGE_DIVISOR), VIP_MAX),
		}
		s += 1


static func _random_formation(rng: BattleRng) -> Array[int]:
	var n_front: int = int(rng.randi_range(1, FORMATION_MAX_PER_LINE))
	var n_mid: int = int(rng.randi_range(1, mini(FORMATION_MAX_PER_LINE, TEAM_SIZE - n_front)))
	var n_rear: int = TEAM_SIZE - n_front - n_mid
	if n_rear < 1:
		n_rear = 1
		n_mid = TEAM_SIZE - n_front - n_rear
	if n_mid < 1:
		n_mid = 1
		n_front = TEAM_SIZE - n_mid - n_rear
	return [n_front, n_mid, n_rear]


static func _pick_line(pool: Array, stage: int, count: int, lvl: int, stars: int, rank: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if pool.is_empty():
		return out
	var i: int = 1
	while i <= count:
		var offset: int = stage * PICK_OFFSET_SCALE + i
		var tid: int = int(pool[(offset - 1) % pool.size()])
		out.append({"_tid": tid, "_level": lvl, "_stars": stars, "_rank": rank})
		i += 1
	return out


## 应用奖励到玩家（照源 local_server.lua:2553-2570 getCrusadeReward）。
## CrusadePoint/ChestBox 转 crusadepoint（×10）；ChestBox 按 coinMap[id]；Item 进背包。
func apply_rewards(slots: Array, player: PlayerData, rng: BattleRng) -> void:
	for s in slots:
		var stype: String = String(s.get("type", ""))
		var amount: int = int(s.get("amount", 0))
		if stype == REWARD_CRUSADE_POINT:
			player.crusade_point += amount * CRUSADE_POINT_MULTIPLIER
		elif stype == REWARD_CHEST_BOX:
			var coins: int = int(CHEST_BOX_COIN_MAP.get(int(s.get("id", 0)), CHEST_BOX_COIN_DEFAULT))
			player.crusade_point += coins * CRUSADE_POINT_MULTIPLIER
		elif stype == REWARD_ITEM:
			player.add_item(int(s.get("id", 0)), amount)


## 查关敌人配置（战斗装配用）。
func get_stage_enemies(stage: int) -> Array:
	var info: Dictionary = enemies.get(stage, {})
	return info.get("heroes", [])


## 端到端 Crusade 战斗：玩家英雄（跨关 HP/MP）+ 敌人英雄（max_rank 装备）+ BattleEngine 跑 + fight 存状态。
## 敌人来源 enemies[stage].heroes（init_crusade 生成）；玩家跨关 HP/MP from hero_hp_perc/hero_mp_perc。
func run_crusade_battle(stage: int, player: PlayerData, player_tids: Array[int], rng: BattleRng) -> Dictionary:
	# 空队伍拒绝（对齐源 2026-08-19 enterStage 空队防护）：必败 fight() 会污染 crusade
	# 跨关 HP/MP 与进度状态，拒绝进入而非记一场空队败仗。
	if player_tids.is_empty():
		return {"ok": false, "error": "empty_team"}
	if config == null or rng == null:
		return {"ok": false}
	var stage_enemies: Array = get_stage_enemies(stage)
	if stage_enemies.is_empty():
		return {"ok": false}
	var eng := BattleEngine.new()
	eng.rng = rng
	eng.sfx_hook = sfx_hook   # T3 注入（胜/败音效；crusade 不走 waves，无需 skill_lib）
	var hero_list: Array[Dictionary] = []
	var self_crusade: Dictionary = {}
	for tid in player_tids:
		var proto: Dictionary = {"_tid": tid}
		var hero: HeroInstance = StageManager._find_hero_by_tid(player.hero_manager, tid)
		if hero != null:
			proto["_level"] = hero.level
			proto["_stars"] = hero.stars
			proto["_rank"] = hero.rank
			proto["_items"] = StageManager._hero_items(hero)
		else:
			proto["_level"] = 1
			proto["_stars"] = 1
		hero_list.append(proto)
		self_crusade[tid] = {
			"_hp_perc": int(hero_hp(tid) * PERC_DENOM),
			"_mp_perc": int(hero_mp(tid) * PERC_DENOM),
		}
	var lib := SkillLibrary.new(config)
	BattleEngineArena.enter_crusade(eng, config, lib, hero_list, stage_enemies, true, self_crusade, {}, stage)
	var ticks: int = CRUSADE_MAX_TICKS
	while eng.running and not eng.stage_ended and ticks > 0:
		eng.update(BattleEngine.TICK_INTERVAL)
		ticks -= 1
	var won: bool = eng.foreach_alive_unit(BattleEngine.CAMP_ENEMY).is_empty()
	# 存跨关 HP/MP（存活英雄当前 HP/MP 占比；阵亡 0）
	var hp_map: Dictionary = {}
	var mp_map: Dictionary = {}
	var player_units: Array = eng.foreach_alive_unit(BattleEngine.CAMP_PLAYER)
	for u in player_units:
		var max_hp: float = float(u.attribs.get("HP", 0.0))
		var max_mp: float = float(u.attribs.get("MP", 0.0))
		hp_map[u.tid] = float(u.hp) / max_hp if max_hp > 0 else 0.0
		mp_map[u.tid] = float(u.mp) / max_mp if max_mp > 0 else 0.0
	fight(won, hp_map, mp_map)
	return {"ok": true, "won": won}


## 序列化（持久化，含旧版跨关状态 + 敌人配置）。
func to_dict() -> Dictionary:
	return {
		"cur_stage": cur_stage,
		"reset_times": reset_times,
		"last_reset_ts": last_reset_ts,
		"hero_hp_perc": hero_hp_perc.duplicate(true),
		"hero_mp_perc": hero_mp_perc.duplicate(true),
		"cleared_stages": cleared_stages.duplicate(true),
		"rewarded_stages": rewarded_stages.duplicate(true),
		"enemies": enemies.duplicate(true),
	}


static func from_dict(data: Dictionary, cm: ConfigManager) -> CrusadeManager:
	var mgr := CrusadeManager.new(cm)
	mgr.cur_stage = int(data.get("cur_stage", 1))
	mgr.reset_times = int(data.get("reset_times", 0))
	mgr.last_reset_ts = int(data.get("last_reset_ts", 0))
	mgr.hero_hp_perc = data.get("hero_hp_perc", {})
	mgr.hero_mp_perc = data.get("hero_mp_perc", {})
	mgr.cleared_stages = data.get("cleared_stages", {})
	mgr.rewarded_stages = data.get("rewarded_stages", {})
	mgr.enemies = data.get("enemies", {})
	return mgr
