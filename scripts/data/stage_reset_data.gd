class_name StageResetData
extends RefCounted

## 精英关次数重置（Data 层静态工具）— 照源 player.lua:790-1067 翻译。
# 源 5 方法挂在 player self（getResetEliteCost / getStageLimitResetTimes / checkStageLimitResetTimesMax
# / refreshStageEliteLimit / elite2NormalStage）。本项目 player_data.gd 行数压线（300 严管），
# 拆独立静态工具（同 VipData / PlayerLevelData 范式），参数传 PlayerData。
# player_data.stage_reset_times 字段存今日已重置次数（源 stage_reset_times，跨日清零待 SaveManager）。

const INVALID_COST: int = -1   # 源 getResetEliteCost row 缺失返 nil → 项目 -1 表不可重置
# 源 player.lua:793 精英关 sid 偏移（与 StageAccount.STAGE_NORMAL_MAX 同源，elite = normal + 10000）
const ELITE_SID_OFFSET: int = 10000


# 源 elite2NormalStage（player.lua:790-800）：精英关 sid 减 10000 映射普通关 sid（reset 计费 key）。
# 委托 StageAccount.stage_type 判定（同区间常量，DRY）。
static func elite_to_normal_stage(stage_id: int) -> int:
	if StageAccount.stage_type(stage_id) == "elite":
		return stage_id - ELITE_SID_OFFSET
	return stage_id


# 源 getStageLimitResetTimes（player.lua:1021-1024）：stage_reset_times[normalStageId] or 0。
static func get_reset_times(player: PlayerData, stage_id: int) -> int:
	var nid: int = elite_to_normal_stage(stage_id)
	return int(player.stage_reset_times.get(nid, 0))


# 源 checkStageLimitResetTimesMax（player.lua:1006-1019）：VIP[vip]["Elite Reset"] <= 已重置次数 → 达上限。
static func is_reset_times_max(player: PlayerData, stage_id: int) -> bool:
	var vip_max: int = int(VipData.get_vip_field(player.vip_level, "Elite Reset", player.cm))
	var nt: int = get_reset_times(player, stage_id)
	return vip_max <= nt


# 源 getResetEliteCost（player.lua:1026-1037）：GradientPrice[times+1]["Elite Reset"] 梯度计费。
# 梯度序列：20/50/50/100/.../1000（GradientPrice.json 1-30 行），row 缺失返 INVALID_COST。
static func get_reset_cost(player: PlayerData, stage_id: int) -> int:
	var times: int = get_reset_times(player, stage_id)
	var row: Dictionary = player.cm.get_raw_table(&"GradientPrice").get(str(times + 1), {})
	if row.is_empty():
		return INVALID_COST
	return int(row.get("Elite Reset", 0))


# 源 refreshStageEliteLimit（player.lua:1045-1051）：reset 后清该关 stage_limit + reset_times++。
static func refresh_elite_limit(player: PlayerData, stage_id: int) -> void:
	var nid: int = elite_to_normal_stage(stage_id)
	player.stage_limit[nid] = 0
	player.stage_reset_times[nid] = int(player.stage_reset_times.get(nid, 0)) + 1
