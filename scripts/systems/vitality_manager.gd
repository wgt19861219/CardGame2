class_name VitalityManager
extends RefCounted

## 体力子系统 Logic 层（阶段三 T3，2026-08-14 自 PlayerData 内联逻辑归位，断薄代理）。
## 照源 player.lua:603-605 canBuyVitality/buyVitality + sync_vitality 时间恢复。
## 字段（vitality/vitality_max/vitality_last_recover/vitality_today_buy/vitality_buy_day）
## 留 PlayerData 保 serde 兼容（statics 收 pd 首参，对齐 SkillPointManager/EquipCraftManager 范式）；
## spend_vitality 属货币读写留 PlayerData。恢复链路 2026-09-17 经济单机优化接线
## （GameData 60s autosave tick 调 recover，此前零调用断链）。

const BUY_COST: int = 50           # 购买消耗钻石（源 local_server:1793）
const BUY_AMOUNT: int = 120        # 购买获得体力
const BUY_HARD_CAP: int = 999      # 体力硬上限（2026-10-12 与自然恢复上限统一 999；旧 9999 攒体口径退役）
const RECOVER_INTERVAL: int = 360  # 每 360s 恢复 1 点（源 parameterTable sync_vitality_gap=360）
const DAY_KEY_YEAR_WEIGHT: int = 10000  # 本地日 key 权重（跨日清零 today_buy，照 ladder 范式）
const DAY_KEY_MONTH_WEIGHT: int = 100
const DAY_KEY_DAY_WEIGHT: int = 100
const SECONDS_PER_MINUTE: int = 60
const NOW_DEFAULT: int = -1        # now 缺省标记（内部取系统时间；测试可注入固定时刻）


## 是否还能买体力（照源 player.lua:603 canBuyVitality：今日次数 < VIP["Buy Vit Max"]）。
## UI 预检用，与 buy 互补：本方法只查 VIP 当日上限，buy 还查钻石是否够。
## 单机去 VIP 限制：上限按特权档（满级）取值。now 可注入（跨日清零判定）。
static func can_buy(pd: PlayerData, now: int = NOW_DEFAULT) -> bool:
	_reset_today_buy_if_new_day(pd, _resolve_now(now))
	var limit: int = int(VipData.get_vip_field(pd.privilege_vip_level(), "Buy Vit Max", pd.cm))
	return limit <= 0 or pd.vitality_today_buy < limit


## 买体力（照源 local_server:1793 buy_vitality + player.lua:605 VIP 上限）。
## 扣 50 钻 + 体力+120（硬上限 9999）+ today_buy++。返是否成功。
## 2026-09-17 补跨日清零（源由服务器日重置 todaybuy，此前只增不清=16 次终身上限）。
static func buy(pd: PlayerData, now: int = NOW_DEFAULT) -> bool:
	_reset_today_buy_if_new_day(pd, _resolve_now(now))
	var limit: int = int(VipData.get_vip_field(pd.privilege_vip_level(), "Buy Vit Max", pd.cm))
	if limit > 0 and pd.vitality_today_buy >= limit:
		return false   # 超 VIP 当日上限
	if pd.vitality >= BUY_HARD_CAP:
		return false   # 已满 999（2026-10-12 上限统一后防白扣钻）
	if pd.diamond < BUY_COST:
		return false
	pd.diamond -= BUY_COST
	pd.vitality = min(pd.vitality + BUY_AMOUNT, BUY_HARD_CAP)
	pd.vitality_today_buy += 1
	if pd.save_hook.is_valid():
		pd.save_hook.call()   # 写操作自动标脏（存档调度内聚 Logic，阶段一 T2）
	return true


## 体力恢复（基于时间差，源 sync_vitality）。返回恢复量；满体力时刷新时间戳。
static func recover(pd: PlayerData, now_seconds: int) -> int:
	if pd.vitality >= pd.vitality_max:
		pd.vitality_last_recover = now_seconds
		return 0
	var elapsed: int = now_seconds - pd.vitality_last_recover
	if elapsed < RECOVER_INTERVAL:
		return 0
	var recovered: int = elapsed / RECOVER_INTERVAL
	pd.vitality = min(pd.vitality + recovered, pd.vitality_max)
	pd.vitality_last_recover += recovered * RECOVER_INTERVAL
	return recovered


## 使用体力药（2026-10-06 体力药使用链路，扣 1 个 + 体力 + Equip.Vitality 字段值，
## 攒体硬上限 9999 与 buy 口径一致）。纯 Logic 可单测；存盘由 View 层调用方负责。
## 返 {ok, gained, reason}：full=体力已满（**不消耗物品**，2026-10-06 用户实测边界——
## GM 拉满 9999 后吃药 gained=0 且药被白扣）；no_item=持有不足；no_vitality=配置缺字段。
static func use_tonic_pill(pd: PlayerData, item_id: int, cm: ConfigManager) -> Dictionary:
	if pd.vitality >= BUY_HARD_CAP:
		return {"ok": false, "reason": "full"}
	if int(pd.items.get(item_id, 0)) <= 0:
		return {"ok": false, "reason": "no_item"}
	var vit: int = int(cm.get_raw_table(&"Equip").get(str(item_id), {}).get(&"Vitality", 0))
	if vit <= 0:
		return {"ok": false, "reason": "no_vitality"}
	if pd.remove_item(item_id, 1) <= 0:
		return {"ok": false, "reason": "no_item"}
	var before: int = pd.vitality
	pd.vitality = min(pd.vitality + vit, BUY_HARD_CAP)
	return {"ok": true, "gained": pd.vitality - before}


## 跨日清零今日购买次数（pd.vitality_buy_day 本地日锚，照源服务器日重置语义）。
static func _reset_today_buy_if_new_day(pd: PlayerData, now: int) -> void:
	var day: int = _local_day_key(now)
	if pd.vitality_buy_day != day:
		pd.vitality_buy_day = day
		pd.vitality_today_buy = 0


static func _local_day_key(ts: int) -> int:
	var off_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(ts + off_min * SECONDS_PER_MINUTE)
	return int(dt["year"]) * DAY_KEY_YEAR_WEIGHT + int(dt["month"]) * DAY_KEY_MONTH_WEIGHT + int(dt["day"]) * DAY_KEY_DAY_WEIGHT


static func _resolve_now(now: int) -> int:
	return now if now > 0 else int(Time.get_unix_time_from_system())
