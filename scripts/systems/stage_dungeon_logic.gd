class_name StageDungeonLogic
extends RefCounted

## 副本段结算逻辑（Logic 层）— 从 StageManager 拆出控 ≤300 行。
## static 方法，首参传 StageManager 实例（读 act_times/dungeon_bosses_cleared 字段）。

const DUNGEON_GOLD_BY_DIFF: Dictionary = {1: 2000, 2: 3500, 3: 5000, 4: 8000}
const DUNGEON_COIN_RANGES: Dictionary = {
	1: Vector2i(5, 8),
	2: Vector2i(10, 15),
	3: Vector2i(20, 30),
	4: Vector2i(35, 50),
}
const DUNGEON_COIN_DIFF_DEFAULT: int = 1
const DUNGEON_BOSS_BASE: int = 50000
const DUNGEON_BOSS_MOD: int = 1000
const DUNGEON_DAILY_LIMIT_DEFAULT: int = 2
const DUNGEON_MAX_BUY_DEFAULT: int = 3
const DUNGEON_BUYCOST_DEFAULT: int = 50
const DUNGEON_GOLD_FALLBACK: int = 2000
const EXP_MULTIPLIER: int = 10
# 英雄副本组 → 对应普通副本组（要求该普通组 Stages 所有 Boss 通关）。
# 注：local_server.lua:476 同名映射用 4000x 是源 latent bug（4000x 在 5000x 数据表查不到→永远放行），不照。
const HEROIC_PREREQ: Dictionary = {50005: 50001, 50006: 50002, 50007: 50003}


## rng 参数便于单测固定种子；exit_dungeon 运行时传 RandomNumberGenerator.new()。
static func get_dungeon_coin_reward(difficulty: int, rng: RandomNumberGenerator) -> int:
	var key: int = difficulty if DUNGEON_COIN_RANGES.has(difficulty) else DUNGEON_COIN_DIFF_DEFAULT
	var range: Vector2i = DUNGEON_COIN_RANGES[key]
	return rng.randi_range(range.x, range.y)


## 返 {ok: bool, prereq_group: int}（ok=true 放行；ok=false 拒绝，prereq_group=待通关普通组）。
static func check_heroic_prereq(group_id: int, mgr: StageManager, cm: ConfigManager) -> Dictionary:
	if not HEROIC_PREREQ.has(group_id):
		return {"ok": true, "prereq_group": 0}
	var normal_group: int = int(HEROIC_PREREQ[group_id])
	var group_cfg: Dictionary = cm.get_raw_table(&"ActStageGroupDungeon").get(str(normal_group), {})
	if group_cfg.is_empty():
		return {"ok": true, "prereq_group": 0}
	var stages_raw: Variant = group_cfg.get("Stages", [])
	if stages_raw == null:
		return {"ok": true, "prereq_group": 0}
	for sid in (stages_raw as Array):
		var stage_id: int = int(sid)
		if stage_id > 0 and mgr.stage_stars(stage_id) < 1:
			return {"ok": false, "prereq_group": normal_group}
	return {"ok": true, "prereq_group": 0}


const DAY_KEY_YEAR_WEIGHT: int = 10000    # 本地自然日序号（照 excavate_manager._local_day_key）
const DAY_KEY_MONTH_WEIGHT: int = 100
const SECONDS_PER_MINUTE: int = 60


## act_times 跨日清零（源 DailyLimit 每日语义，服务器每日重置→单机本地跨日；锚点
## mgr.act_times_reset_ts。2026-08-22 巡检接线）。
static func check_act_times_daily_reset(mgr: StageManager, now: int) -> void:
	# 锚点未初始化先建锚点不清表（2026-09-12 修 off-by-one：旧逻辑空表提前返回不设锚点，
	# 首次计数后被下一次调用的 clear 吞掉——dungeon/act 每组第一次计数实际被清，多放行一次）。
	if mgr.act_times_reset_ts <= 0:
		mgr.act_times_reset_ts = now
		return
	if mgr.act_times.is_empty():
		return
	if _crossed_day(mgr.act_times_reset_ts, now):
		mgr.act_times.clear()
		mgr.act_times_reset_ts = now


static func _crossed_day(last_ts: int, now: int) -> bool:
	if last_ts <= 0:
		return true
	var off_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return _local_day_key(last_ts, off_min) != _local_day_key(now, off_min)


static func _local_day_key(ts: int, off_min: int) -> int:
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(ts + off_min * SECONDS_PER_MINUTE)
	return int(dt["year"]) * DAY_KEY_YEAR_WEIGHT + int(dt["month"]) * DAY_KEY_MONTH_WEIGHT + int(dt["day"])


## enter 统一分派（enter_act_stage / assemble_stage_battle 共用）：dungeon 段走
## check_enter_dungeon（钥匙/前置/次数/买次），其余 act 段走 check_enter_act_group
## （资源副本组计次；普通/精英关 Stage Group 指章节、不在 ActStageGroup 表 → no-op）。
static func check_enter(mgr: StageManager, stage_id: int, stage_group: int, player: PlayerData, cm: ConfigManager) -> String:
	if StageData.is_dungeon_stage(stage_id):
		return check_enter_dungeon(mgr, stage_id, stage_group, player, cm)
	return check_enter_act_group(mgr, stage_id, cm)


## 资源副本（ActStageGroup 20001-20005：经验/金币/智力/敏捷/力量试炼）每日次数检查 + 计次。
## 源客户端 degreeWindow.getLeftTimes 读 DailyLimit-getActTimes，计次在服务端 enterActStage
## ——单机并入此处（进战斗即计次）。组键 sgid = Stage 表 "Stage Group" 字段（20001 组四难度
## 同键共享次数，源 getsgid 语义）。CD 字段全表实测为 0（2026-09-12）不实现 CD 检查。
## 返 "" 放行（已计次）；"no_attempts" 次数用尽。
static func check_enter_act_group(mgr: StageManager, stage_id: int, cm: ConfigManager) -> String:
	var sgid: int = int(cm.get_raw_table(&"Stage").get(str(stage_id), {}).get("Stage Group", 0))
	if sgid <= 0:
		return ""
	check_act_times_daily_reset(mgr, int(Time.get_unix_time_from_system()))
	var limit: int = int(cm.get_raw_table(&"ActStageGroup").get(str(sgid), {}).get("DailyLimit", 0))
	if limit <= 0:
		return ""
	var used: int = int(mgr.act_times.get(sgid, 0))
	if used >= limit:
		return "no_attempts"
	mgr.act_times[sgid] = used + 1
	return ""


static func check_enter_dungeon(mgr: StageManager, stage_id: int, stage_group: int, player: PlayerData, cm: ConfigManager) -> String:
	# Unlock Level 不在此查（enter_act_stage 外层 :111 查 + dungeon_degree_popup UI 层
	# unlock_level 拦截；2026-08-22 巡检曾挪入后退回——保持原职责分工）。
	check_act_times_daily_reset(mgr, int(Time.get_unix_time_from_system()))
	var prereq: Dictionary = check_heroic_prereq(stage_group, mgr, cm)
	if not bool(prereq.get("ok", true)):
		return "heroic_prereq"
	var key_cost: int = int(cm.get_raw_table(&"StageDungeon").get(str(stage_id), {}).get("Key Cost", 0))
	if key_cost > 0 and player.dungeonpoint < key_cost:
		return "not_enough_keys"
	var grp_cfg: Dictionary = cm.get_raw_table(&"ActStageGroupDungeon").get(str(stage_group), {})
	var daily_limit: int = int(grp_cfg.get("DailyLimit", DUNGEON_DAILY_LIMIT_DEFAULT))
	var max_buy: int = int(grp_cfg.get("MaxBuyPerDay", DUNGEON_MAX_BUY_DEFAULT))
	var used: int = int(mgr.act_times.get(stage_group, 0))
	if used >= daily_limit + max_buy:
		return "no_attempts"
	# 免费次数用完 → 扣 BuyCost 龙鳞硬币（源 :698-707）
	if used >= daily_limit:
		var buy_cost: int = int(grp_cfg.get("BuyCost", DUNGEON_BUYCOST_DEFAULT))
		if player.dungeonpoint < buy_cost:
			return "not_enough_coins"
		player.dungeonpoint -= buy_cost
	mgr.act_times[stage_group] = used + 1
	return ""


## 返 {stars, exp, money, coins}。
static func exit_dungeon(mgr: StageManager, cm: ConfigManager, sid: int, stars: int, player: PlayerData) -> Dictionary:
	var cfg: Dictionary = cm.get_raw_table(&"StageDungeon").get(str(sid), {})
	var diff: int = int(cfg.get("Difficulty", 1))
	var exp_reward: int = int(cfg.get("Exp Reward", 0)) * EXP_MULTIPLIER
	var gold_reward: int = int(DUNGEON_GOLD_BY_DIFF.get(diff, DUNGEON_GOLD_FALLBACK))
	var coins: int = get_dungeon_coin_reward(diff, RandomNumberGenerator.new())
	var base_id: int = DUNGEON_BOSS_BASE + sid % DUNGEON_BOSS_MOD
	mgr.dungeon_bosses_cleared[base_id] = true
	if player != null:
		player.dungeonpoint += coins
		var key_cost: int = int(cfg.get("Key Cost", 0))
		if key_cost > 0:
			player.dungeonpoint -= key_cost
	return {"stars": stars, "exp": exp_reward, "money": gold_reward, "coins": coins}
