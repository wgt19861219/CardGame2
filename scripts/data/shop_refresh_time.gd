class_name ShopRefreshTime
extends RefCounted

## 商店自动刷新时刻计算（Data 层纯函数）— 照源 ui/market/market.lua:137-229 + local_server.lua:1219。
## Shop.Refresh Times 表驱动每天定时刷新点（"9:00:00" 等）；_last_auto_refresh_time 持久化（0=不自动刷新）。
## 单机化：源 ed.getServerTime() → 调用方传 now_ts（Time.get_unix_time_from_system()，可注入测）。

const SECS_PER_DAY: int = 86400
const SECS_PER_MIN: int = 60
const SHOP_TABLE: StringName = &"Shop"
const HMS_SEC_IDX: int = 2   # "H:M:S" split 后 sec 索引（hour/min 索引 0/1 在 lint 白名单）


## 读 Shop 表 Refresh Times，返按数字 key 排序的 ["H:M:S"] 数组。
static func get_refresh_times(shop_id: int, cm: Variant) -> Array:
	var row: Dictionary = cm.get_raw_table(SHOP_TABLE).get(str(shop_id), {})
	var rt: Dictionary = row.get("Refresh Times", {})
	var indexed: Array = []
	for k in rt.keys():
		indexed.append({"idx": int(k), "hms": String(rt[k])})
	indexed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["idx"]) < int(b["idx"]))
	return indexed.map(func(d: Dictionary) -> String: return String(d["hms"]))


## "H:M:S" → {hour,min,sec}（源 ed.hmsNString2HMS）。
static func parse_hms(hms: String) -> Dictionary:
	var parts: PackedStringArray = hms.split(":")
	return {
		"hour": int(parts[0]) if parts.size() > 0 else 0,
		"min": int(parts[1]) if parts.size() > 1 else 0,
		"sec": int(parts[HMS_SEC_IDX]) if parts.size() > HMS_SEC_IDX else 0,
	}


## 今天 hms 时刻的 unix ts（源 time.lua:47 getTimeByTodayHMS = 本地今天零点 + H*M*S）。
## Godot 两 Time API 均 UTC 语义（headless 实测：ts=0 拆 hour=0 / epoch0 组回 ts=0），
## 本地日期须 +bias 拆解、组回后 -bias 还原（与 daily_login_manager/_local_date 同口径）。
static func today_ts(hms: String, now_ts: int) -> int:
	var off_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var nd: Dictionary = Time.get_datetime_dict_from_unix_time(now_ts + off_min * SECS_PER_MIN)
	var parts: Dictionary = parse_hms(hms)
	var d: Dictionary = {
		"year": int(nd["year"]), "month": int(nd["month"]), "day": int(nd["day"]),
		"hour": int(parts["hour"]), "minute": int(parts["min"]), "second": int(parts["sec"]),
	}
	return int(Time.get_unix_time_from_datetime_dict(d)) - off_min * SECS_PER_MIN


## 下一个自动刷新点（源 getShopNextAutoRefreshPoint:148-177）。
## 返 {time_str, point_ts, period} 或 {}（last_ts==0 不自动刷新 / 无 Refresh Times）。
static func get_next_point(shop_id: int, last_ts: int, now_ts: int, cm: Variant) -> Dictionary:
	if last_ts == 0:
		return {}
	var mts: Array = get_refresh_times(shop_id, cm)
	if mts.is_empty():
		return {}
	var min_time: String = ""
	var min_point: int = 0
	var has_min: bool = false
	for hms in mts:
		var te: int = today_ts(hms, now_ts)
		if not has_min:
			min_point = te
			min_time = hms
			has_min = true
		if now_ts >= te:
			if last_ts < te:   # 已过该点且上次刷新在其前 → 该点 today 触发
				return {"time_str": hms, "point_ts": te, "period": "today"}
		else:                 # 未到该点 → today 下一个
			return {"time_str": hms, "point_ts": te, "period": "today"}
		if te < min_point:    # 跟踪最早点（tomorrow 用）
			min_point = te
			min_time = hms
	return {"time_str": min_time, "point_ts": min_point + SECS_PER_DAY, "period": "tomorrow"}


## 距下次刷新秒数（源 getShopCountDown:137-146）。返 -1 表示无自动刷新。
static func count_down(shop_id: int, last_ts: int, now_ts: int, cm: Variant) -> int:
	var np: Dictionary = get_next_point(shop_id, last_ts, now_ts, cm)
	if np.is_empty():
		return -1
	return int(np["point_ts"]) - now_ts


## 下次刷新描述 "今天 09:00" / "明天 21:00"（源 getShopNextAutoRefreshPointDesc:179-198）。无自动刷新返 ""。
static func next_desc(shop_id: int, last_ts: int, now_ts: int, cm: Variant) -> String:
	var np: Dictionary = get_next_point(shop_id, last_ts, now_ts, cm)
	if np.is_empty():
		return ""
	var parts: Dictionary = parse_hms(String(np["time_str"]))
	var pre: String = ""
	var period: String = String(np["period"])
	if period == "tomorrow":
		pre = "明天"
	elif period == "today":
		pre = "今天"
	return "%s %02d:%02d" % [pre, int(parts["hour"]), int(parts["min"])]


## 时间类型（源 checkShopTimeType:222-229）：停留中→"expire"，否则有自动刷新→"refresh"，否则""。
## expire_end_ts = 停留结束 ts（地精/黑市出现时刻 + Expire Time；0=无停留），调用方算好传入。
static func time_type(shop_id: int, expire_end_ts: int, last_ts: int, now_ts: int, cm: Variant) -> String:
	if expire_end_ts != 0:
		return "expire"
	# 有下个刷新点即 refresh（源 getShopCountDown 返负数 Lua 仍 truthy；含已过应触发的点）。
	if not get_next_point(shop_id, last_ts, now_ts, cm).is_empty():
		return "refresh"
	return ""
