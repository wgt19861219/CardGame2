class_name StageRes
extends RefCounted

## 关卡图标资源映射（Logic 层）— 照源 ui/parameter/stageselectres.lua:7-23 getStageIcon。
## 普通关卡 key_stages/stage-{id}.png / 精英关卡 key_stages/stage-{Stage Group}.png。
## 简化：跳过源 map resid 修正（:14-20，少数关卡 resid 覆盖；默认 sid=Stage Group/id 视觉差异小，待 resid 表移植补全）。

const ICON_PATH: String = "res://assets/ui/alpha/HVGA/key_stages/stage-%d.png"

# 照源 getStageIcon :7-23。返关卡图标资源路径（普通 id / 精英 Stage Group）。
static func get_stage_icon(stage_id: int, cm: Variant) -> String:
	var is_elite: bool = StageAccount.stage_type(stage_id) == "elite"
	var stage_row: Dictionary = cm.get_raw_table(&"Stage").get(str(stage_id), {})
	var sid: int = stage_id
	if is_elite:
		sid = int(stage_row.get("Stage Group", stage_id))
	return ICON_PATH % sid
