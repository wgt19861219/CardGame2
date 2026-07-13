extends GutTest
# StageRes 关卡图标映射（P1-12，照源 ui/parameter/stageselectres.lua:7-23 getStageIcon）。
# 普通关卡 stage-{id}.png / 精英关卡 stage-{Stage Group}.png。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 找一个普通关卡 id（stage_type != elite，>0 排除 PVP 占位）。
func _find_normal_stage() -> int:
	var stage: Dictionary = cm.get_raw_table(&"Stage")
	for tid_str in stage:
		var sid: int = int(tid_str)
		if sid > 0 and StageAccount.stage_type(sid) != "elite":
			return sid
	return 0


# 找一个精英关卡 id（stage_type == elite）。
func _find_elite_stage() -> int:
	var stage: Dictionary = cm.get_raw_table(&"Stage")
	for tid_str in stage:
		var sid: int = int(tid_str)
		if sid > 0 and StageAccount.stage_type(sid) == "elite":
			return sid
	return 0


# 普通关卡图标 = stage-{id}.png（源 :21 sid=id）。
func test_normal_stage_icon_uses_id() -> void:
	var sid: int = _find_normal_stage()
	assert_gt(sid, 0, "存在普通关卡")
	var res: String = StageRes.get_stage_icon(sid, cm)
	assert_eq(res, "res://assets/ui/alpha/HVGA/key_stages/stage-%d.png" % sid, "普通关卡图标 stage-{id}")


# 精英关卡图标 = stage-{Stage Group}.png（源 :12 isElite 用 Stage Group）。
func test_elite_stage_icon_uses_stage_group() -> void:
	var sid: int = _find_elite_stage()
	if sid == 0:
		assert_true(true, "无精英关卡样本，跳过")
		return
	var stage_group: int = int(cm.get_raw_table(&"Stage").get(str(sid), {}).get("Stage Group", sid))
	var res: String = StageRes.get_stage_icon(sid, cm)
	assert_eq(res, "res://assets/ui/alpha/HVGA/key_stages/stage-%d.png" % stage_group, "精英关卡图标 stage-{Stage Group}")


# 关卡图标资源存在（key_stages 220 张）。
func test_stage_icon_resource_exists() -> void:
	var sid: int = _find_normal_stage()
	assert_gt(sid, 0, "存在普通关卡")
	var res: String = StageRes.get_stage_icon(sid, cm)
	assert_true(ResourceLoader.exists(res), "关卡图标资源存在")
