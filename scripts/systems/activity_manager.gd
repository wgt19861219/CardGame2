class_name ActivityManager
extends RefCounted

## 运营活动（Logic 层）— 照源 ui/activitiesList.lua + ui/rebateActivities.lua +
## local_server.lua:4607-4703（周常生成钻石消费返利/青铜单抽/青铜十连优惠，数值照搬）。
## 单机化：源联机 activity_info 推送 → ActivitiesConfig 表 + 本地进度累计；
## 钻石消费挂 PlayerData.spend_diamond、青铜抽卡挂 PlayerData.draw_tavern。
##
## 源缺陷修正（设计偏离，见验收记录-活动系统迁移-2026-10-13）：
## ① 源奖励条目 _amount 一字段三义（rebateActivities.lua:123-134 把奖励数量当门槛显示），
##   本版拆为 threshold（门槛）/ progress（进度，按活动类型累计）/ reward.amount（奖励数量）；
## ② 源 activity_claimed 跨周不清理（第二周已领标记残留，未领档位却因进度清零永不可达），
##   本版随周锚统一重置（进度+已领一起清，每周重新可领）；
## ③ 源红点判"未领且未达标"（activitiesList.lua:149-160，达标可领反而不亮，疑漏分支），
##   本版统一"存在未领档位即亮"。
## 受控裁剪：源 overGetTime 结束后 1 天宽限（local_server 周常数据下 end=重置点，分支不可达）；
## rmb_recharge 充值返利活动类型（单机无充值行为）。

const CONFIG_TABLE: StringName = &"ActivitiesConfig"
const SECS_PER_WEEK: int = 604800
const SECS_PER_DAY: int = 86400
const SECS_PER_HOUR: int = 3600
const SECS_PER_MIN: int = 60
const WEEK_DAYS: int = 7
const TAVERN_POOL_KEY: String = "Bronze"

const TYPE_DIAMOND: String = "diamond_consume"
const TYPE_TAVERN_ONCE: String = "tavern_once"
const TYPE_TAVERN_TEN: String = "tavern_ten"

var week_key: int = 0
var diamond_spent: int = 0
var tavern_once_draws: int = 0
var tavern_ten_draws: int = 0
var claimed: Dictionary = {}


## 周一 0 点锚（源 getActivityPeriod local_server.lua:4607，本地时区；周日回退 6 天）。
static func week_start(now: int) -> int:
	var off_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(now + off_min * SECS_PER_MIN)
	var day_secs: int = int(d.get("hour", 0)) * SECS_PER_HOUR \
			+ int(d.get("minute", 0)) * SECS_PER_MIN + int(d.get("second", 0))
	var days_to_monday: int = (int(d.get("weekday", 1)) + WEEK_DAYS - 1) % WEEK_DAYS
	return now - day_secs - days_to_monday * SECS_PER_DAY


func _ensure_week(now: int) -> void:
	var wk: int = week_start(now)
	if week_key != wk:
		week_key = wk
		diamond_spent = 0
		tavern_once_draws = 0
		tavern_ten_draws = 0
		claimed.clear()


## 钻石消费累计（挂 PlayerData.spend_diamond；源 trackDiamondSpent local_server.lua:4698）。
func on_diamond_spent(amount: int, now: int = 0) -> void:
	if amount <= 0:
		return
	_ensure_week(now if now > 0 else _sys_now())
	diamond_spent += amount


## 青铜抽卡累计（挂 PlayerData.draw_tavern；源 buildTavernBonusActivity 只针对青铜 br 池）。
## 十连按操作计 1 次十连（源 combo_br_tavern task_target=1），不折 10 次单抽。
func on_tavern_draw(pool_key: String, is_ten: bool, now: int = 0) -> void:
	if pool_key != TAVERN_POOL_KEY:
		return
	_ensure_week(now if now > 0 else _sys_now())
	if is_ten:
		tavern_ten_draws += 1
	else:
		tavern_once_draws += 1


func get_progress(cfg_type: String) -> int:
	match cfg_type:
		TYPE_DIAMOND:
			return diamond_spent
		TYPE_TAVERN_ONCE:
			return tavern_once_draws
		TYPE_TAVERN_TEN:
			return tavern_ten_draws
	return 0


## 组装运行时活动列表（源 generateActivities local_server.lua:4683 + splitInfo"进行中"组；
## 单机周常滚动生成，无"已结束"组）。每条：key/type/title/desc/rules/start/end/progress/
## tiers[]，tier = {job, threshold, reward{type,id,amount}, claimed, ready}。
func get_activities(now: int, cm: ConfigManager) -> Array:
	_ensure_week(now)
	var table: Dictionary = cm.get_raw_table(CONFIG_TABLE)
	var result: Array = []
	for key in table:
		var cfg: Dictionary = table[key]
		var cfg_type: String = String(cfg.get("type", ""))
		var progress: int = get_progress(cfg_type)
		var tiers: Array = []
		for tier_cfg in cfg.get("rewards", []):
			var tc: Dictionary = tier_cfg
			var job: String = String(tc.get("job", ""))
			var threshold: int = int(tc.get("threshold", 0))
			tiers.append({
				"job": job,
				"threshold": threshold,
				"reward": tc.get("reward", {}),
				"claimed": bool(claimed.get(job, false)),
				"ready": progress >= threshold,
			})
		result.append({
			"key": String(key),
			"type": cfg_type,
			"title": String(cfg.get("title", "")),
			"desc": String(cfg.get("desc", "")),
			"rules": String(cfg.get("rules", "")),
			"start": week_key,
			"end": week_key + SECS_PER_WEEK,
			"progress": progress,
			"tiers": tiers,
		})
	return result


## 领取（源 job_rewards act_ 分支 local_server.lua:4512-4563：已领拒/未达标拒 → 标记+发放）。
## 入账照源 doTaskConsume rebateActivities.lua:220-244（money→金币 / rmb→钻石 / item→物品）。
func claim(player: PlayerData, cm: ConfigManager, job: String, now: int = 0) -> Dictionary:
	_ensure_week(now if now > 0 else _sys_now())
	var table: Dictionary = cm.get_raw_table(CONFIG_TABLE)
	for key in table:
		var cfg: Dictionary = table[key]
		var cfg_type: String = String(cfg.get("type", ""))
		for tier_cfg in cfg.get("rewards", []):
			var tc: Dictionary = tier_cfg
			if String(tc.get("job", "")) != job:
				continue
			if bool(claimed.get(job, false)):
				return {"ok": false, "reason": "claimed"}
			if get_progress(cfg_type) < int(tc.get("threshold", 0)):
				return {"ok": false, "reason": "not_ready"}
			claimed[job] = true
			var reward: Dictionary = tc.get("reward", {})
			var rid: int = int(reward.get("id", 0))
			var ramount: int = int(reward.get("amount", 0))
			match String(reward.get("type", "")):
				"money":
					player.hero_manager.add_money(ramount)
				"rmb":
					player.add_diamond(ramount)
				"item":
					player.add_item(rid, ramount)
			return {"ok": true, "reward": reward, "activity_title": String(cfg.get("title", ""))}
	return {"ok": false, "reason": "no_job"}


## 红点（源 judgeAllowData activitiesList.lua:149-160 修正版：存在未领档位即亮）。
func has_red_dot(now: int, cm: ConfigManager) -> bool:
	for act in get_activities(now, cm):
		for tier in act["tiers"]:
			if not bool(tier["claimed"]):
				return true
	return false


func to_dict() -> Dictionary:
	return {
		"week_key": week_key,
		"diamond_spent": diamond_spent,
		"tavern_once_draws": tavern_once_draws,
		"tavern_ten_draws": tavern_ten_draws,
		"claimed": claimed.duplicate(),
	}


static func from_dict(data: Dictionary) -> ActivityManager:
	var mgr := ActivityManager.new()
	mgr.week_key = int(data.get("week_key", 0))
	mgr.diamond_spent = int(data.get("diamond_spent", 0))
	mgr.tavern_once_draws = int(data.get("tavern_once_draws", 0))
	mgr.tavern_ten_draws = int(data.get("tavern_ten_draws", 0))
	var c: Dictionary = data.get("claimed", {})
	for k in c:
		mgr.claimed[k] = true
	return mgr


static func _sys_now() -> int:
	return int(Time.get_unix_time_from_system())
