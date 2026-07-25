class_name StageResetData
extends RefCounted

## 精英关次数重置（Data 层静态工具）— 照源 player.lua:790-1067 翻译。
# / refreshStageEliteLimit / elite2NormalStage）。本项目 player_data.gd 行数压线（300 严管），
# 拆独立静态工具（同 VipData / PlayerLevelData 范式），参数传 PlayerData。
# player_data.stage_reset_times 字段存今日已重置次数（源 stage_reset_times，跨日清零待 SaveManager）。

const INVALID_COST: int = -1
const ELITE_SID_OFFSET: int = 10000


# 委托 StageAccount.stage_type 判定（同区间常量，DRY）。
static func elite_to_normal_stage(stage_id: int) -> int:
	if StageAccount.stage_type(stage_id) == "elite":
		return stage_id - ELITE_SID_OFFSET
	return stage_id


static func get_reset_times(player: PlayerData, stage_id: int) -> int:
	var nid: int = elite_to_normal_stage(stage_id)
	return int(player.stage_reset_times.get(nid, 0))


static func is_reset_times_max(player: PlayerData, stage_id: int) -> bool:
	var vip_max: int = int(VipData.get_vip_field(player.vip_level, "Elite Reset", player.cm))
	var nt: int = get_reset_times(player, stage_id)
	return vip_max <= nt


# 梯度序列：20/50/50/100/.../1000（GradientPrice.json 1-30 行），row 缺失返 INVALID_COST。
static func get_reset_cost(player: PlayerData, stage_id: int) -> int:
	var times: int = get_reset_times(player, stage_id)
	var row: Dictionary = player.cm.get_raw_table(&"GradientPrice").get(str(times + 1), {})
	if row.is_empty():
		return INVALID_COST
	return int(row.get("Elite Reset", 0))


static func refresh_elite_limit(player: PlayerData, stage_id: int) -> void:
	var nid: int = elite_to_normal_stage(stage_id)
	player.stage_limit[nid] = 0
	player.stage_reset_times[nid] = int(player.stage_reset_times.get(nid, 0)) + 1
