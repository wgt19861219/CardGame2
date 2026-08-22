class_name DailyLoginManager
extends RefCounted

## 连续登录奖励（Logic 层）— 照源 player.lua:224 getLoginFrequency/getLoginRewardStatus +
## local_server.lua:2096 ask_daily_login + DailyLoginReward 表查询。
## 单机化：源联机 frequency/status → 本地会话内累计 + 领奖后标 received。
##
## 状态机（源 _daily_login._status）：nothing(3) → part(2,领普通) → all(1,领VIP双倍)
## frequency：连续登录天数（源 checkTwoDateod 跨天+1，checkTwoDateom 跨月重置1）。
## 跨天按 5:00 重置线分段判（源 time.lua:299 reset_time={h=5,m=0} + :366 checkBOA），
## 时区单机化为本地（源 time2China 中国时区，设备在中国时区时两者一致）。

var frequency: int = 0
var status: String = "nothing"
var last_login_ts: int = 0

const VIP_DOUBLE_MULTIPLIER: int = 2
const FALLBACK_YEAR: int = 2018
const STATUS_ALL: int = 1
const STATUS_COMMON: int = 2
const SECS_PER_DAY: int = 86400
const SECS_PER_MIN: int = 60
const MIN_PER_HOUR: int = 60
const RESET_HOUR: int = 5   # 源 time.lua:299 reset_time = {h=5, m=0}
const RESET_MIN: int = 0


func get_login_frequency(now: int) -> int:
	if _is_month_reset(last_login_ts, now):
		return 1   # 月初重置（源 checkTwoDateom：较晚者 day==1 且跨天）
	if _is_reset_apart(last_login_ts, now):
		return frequency + 1   # 跨 5:00 重置线 +1（源 checkTwoDateod）
	return frequency


func get_reward_status(now: int) -> String:
	if _is_reset_apart(last_login_ts, now):
		return "common"   # 新重置段可领
	if status == "all" or status == "part":
		return "received"   # 今日已领
	return "common"


## status 参数照源 :2097（1=all 含 VIP 双倍，2=common 普通单倍，3=vip）；默认 2 不双倍。
func claim_reward(player: PlayerData, cm: ConfigManager, now: int, status: int = STATUS_COMMON) -> Dictionary:
	if get_reward_status(now) == "received":
		return {"ok": false, "reason": "received"}
	var freq: int = get_login_frequency(now)
	var row: Dictionary = _find_reward_row(cm, freq)
	if row.is_empty():
		return {"ok": false, "reason": "no_data"}
	var rtype: String = String(row.get("Reward Type", ""))
	var rid: int = int(row.get("Reward ID", 0))
	var ramount: int = int(row.get("Reward Amount", 0))
	var vip_req: int = int(row.get("Double Reward VIP Level", 0))
	var multiplier: int = VIP_DOUBLE_MULTIPLIER if (status == STATUS_ALL and vip_req > 0 and player.vip_level >= vip_req) else 1
	var items: Array = []
	var diamond: int = 0
	match rtype:
		"Item":
			player.add_item(rid, ramount * multiplier)
			items.append({"id": rid, "amount": ramount * multiplier})
		"Hero":
			player.hero_manager.add_hero(rid)
			items.append({"id": rid, "amount": 1, "type": "hero"})
		"Diamond":
			diamond = ramount * multiplier
			player.add_diamond(diamond)
		"Gold":
			player.hero_manager.add_money(ramount * multiplier)
		"PlayerEXP":
			player.add_team_exp(ramount * multiplier)
	frequency = freq
	last_login_ts = now
	self.status = "all"   # 实例字段（String）；参数 status 是 int 请求类型，用 self 消歧
	return {"ok": true, "frequency": frequency, "items": items, "diamond": diamond, "type": rtype, "amount": ramount * multiplier}


static func _find_reward_row(cm: ConfigManager, freq: int) -> Dictionary:
	var table: Dictionary = cm.get_raw_table("DailyLoginReward")
	var now_dict: Dictionary = Time.get_datetime_dict_from_system()
	var year: int = int(now_dict.get("year", FALLBACK_YEAR))
	var month: int = int(now_dict.get("month", 1))
	for try_year in [year, FALLBACK_YEAR]:
		var month_data: Dictionary = table.get(str(try_year), {}).get(str(month), {})
		if not month_data.is_empty():
			return month_data.get(str(freq), {})
	return {}


## ts → 本地日期 dict。Time.get_datetime_dict_from_unix_time 返 UTC（headless 实测
## ts=0 拆 hour=0），+bias 后拆解为本地（与 tavern_data/excavate_manager 同口径）。
static func _local_date(ts: int) -> Dictionary:
	var off_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return Time.get_datetime_dict_from_unix_time(ts + off_min * SECS_PER_MIN)


## 时刻是否在 5:00 重置线之后（源 checkBOA after：60*h+m >= 60*5）。
static func _after_reset(d: Dictionary) -> bool:
	return int(d.get("hour", 0)) * MIN_PER_HOUR + int(d.get("minute", 0)) >= RESET_HOUR * MIN_PER_HOUR + RESET_MIN


## 跨重置线判定（源 time.lua:323 checkTwoDateod）：间隔>24h 直判跨；否则按 5:00 线
## 分段——同日号跨线 / 异日号同段 = 跨。last_ts=0 视为跨（源 abs>86400 对 0 恒成立）。
static func _is_reset_apart(old_ts: int, new_ts: int) -> bool:
	if old_ts == 0:
		return true
	if absi(new_ts - old_ts) > SECS_PER_DAY:
		return true
	var od: Dictionary = _local_date(old_ts)
	var nd: Dictionary = _local_date(new_ts)
	if int(od.get("day", 0)) == int(nd.get("day", 0)):
		return _after_reset(nd) != _after_reset(od)
	return _after_reset(nd) == _after_reset(od)


## 月重置判定（源 time.lua:300 checkTwoDateom）：较晚者 day==1 且跨重置线 → 月重置。
static func _is_month_reset(old_ts: int, new_ts: int) -> bool:
	var later: Dictionary = _local_date(maxi(old_ts, new_ts))
	if int(later.get("day", 0)) != 1:
		return false
	return _is_reset_apart(old_ts, new_ts)


## 存档序列化。
func to_dict() -> Dictionary:
	return {"frequency": frequency, "status": status, "last_login_ts": last_login_ts}


static func from_dict(data: Dictionary) -> DailyLoginManager:
	var mgr := DailyLoginManager.new()
	mgr.frequency = int(data.get("frequency", 0))
	mgr.status = String(data.get("status", "nothing"))
	mgr.last_login_ts = int(data.get("last_login_ts", 0))
	return mgr
