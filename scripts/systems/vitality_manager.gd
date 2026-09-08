class_name VitalityManager
extends RefCounted

## 体力子系统 Logic 层（阶段三 T3，2026-08-14 自 PlayerData 内联逻辑归位，断薄代理）。
## 照源 player.lua:603-605 canBuyVitality/buyVitality + sync_vitality 时间恢复。
## 字段（vitality/vitality_max/vitality_last_recover/vitality_today_buy）留 PlayerData 保 serde 兼容
## （statics 收 pd 首参，对齐 SkillPointManager/EquipCraftManager 范式）；spend_vitality 属货币读写留 PlayerData。
## ⚠️ recover 当前零调用（feature_catalog 记 sync_vitality→本类，但恢复链路未接线）——
## 接线时机/触发点是游戏行为决策，2026-08-14 阶段三验收记录另记，不在搬位置的任务内擅动。

const BUY_COST: int = 50           # 购买消耗钻石（源 local_server:1793）
const BUY_AMOUNT: int = 120        # 购买获得体力
const BUY_HARD_CAP: int = 9999     # 体力硬上限（可超 vitality_max 攒体）
const RECOVER_INTERVAL: int = 360  # 每 360s 恢复 1 点（速率待核源 sync_vitality）


## 是否还能买体力（照源 player.lua:603 canBuyVitality：今日次数 < VIP["Buy Vit Max"]）。
## UI 预检用，与 buy 互补：本方法只查 VIP 当日上限，buy 还查钻石是否够。
## 单机去 VIP 限制：上限按特权档（满级）取值。
static func can_buy(pd: PlayerData) -> bool:
	var limit: int = int(VipData.get_vip_field(pd.privilege_vip_level(), "Buy Vit Max", pd.cm))
	return limit <= 0 or pd.vitality_today_buy < limit


## 买体力（照源 local_server:1793 buy_vitality + player.lua:605 VIP 上限）。
## 扣 50 钻 + 体力+120（硬上限 9999）+ today_buy++。返是否成功。
static func buy(pd: PlayerData) -> bool:
	var limit: int = int(VipData.get_vip_field(pd.privilege_vip_level(), "Buy Vit Max", pd.cm))
	if limit > 0 and pd.vitality_today_buy >= limit:
		return false   # 超 VIP 当日上限
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
