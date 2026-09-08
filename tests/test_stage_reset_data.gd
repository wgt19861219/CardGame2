extends GutTest
# StageResetData 精英关次数重置单测（P1-C1 修复：照源 player.lua:790-1067）。
# 覆盖：elite_to_normal_stage 映射 / get_reset_cost 梯度计费 / is_reset_times_max VIP 上限 /
# refresh_elite_limit 扣次数 + stage_limit 清零。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 源 elite2NormalStage（player.lua:790-800）：精英 sid-10000 / 普通 sid 不变。
func test_elite_to_normal_stage_mapping() -> void:
	assert_eq(StageResetData.elite_to_normal_stage(10001), 1, "精英 10001 → 1")
	assert_eq(StageResetData.elite_to_normal_stage(10500), 500, "精英 10500 → 500")
	assert_eq(StageResetData.elite_to_normal_stage(5), 5, "普通 5 不变")
	assert_eq(StageResetData.elite_to_normal_stage(100), 100, "普通 100 不变")


# 源 getResetEliteCost（player.lua:1026-1037）：GradientPrice[times+1]["Elite Reset"] 梯度。
# GradientPrice.json 1-3 行：20/50/50（实测核对源数据）
func test_get_reset_cost_gradient() -> void:
	var pd := PlayerData.new(cm)
	# times=0 → GradientPrice[1]["Elite Reset"] = 20
	assert_eq(StageResetData.get_reset_cost(pd, 10001), 20, "首次 reset cost=20（GradientPrice[1]）")
	StageResetData.refresh_elite_limit(pd, 10001)
	# times=1 → GradientPrice[2] = 50
	assert_eq(StageResetData.get_reset_cost(pd, 10001), 50, "二次 reset cost=50（GradientPrice[2]）")
	StageResetData.refresh_elite_limit(pd, 10001)
	# times=2 → GradientPrice[3] = 50
	assert_eq(StageResetData.get_reset_cost(pd, 10001), 50, "三次 reset cost=50（GradientPrice[3]）")


# 源 is_reset_times_max（player.lua:1006-1019）：VIP[vip]["Elite Reset"] <= 已重置次数 → 达上限。
# 单机去 VIP 限制（2026-09-08）：上限按特权档（满级）取值，与显示 vip_level 解耦。
# VIP.json: 最高档 VIP 15 ["Elite Reset"]=14。
func test_is_reset_times_max_privilege_level_decoupled() -> void:
	var pd := PlayerData.new(cm)
	pd.vip_level = 0  # 显示层 VIP 0，特权档仍满级
	assert_false(StageResetData.is_reset_times_max(pd, 10001), "VIP 0（特权满级）→ 未达上限，可 reset")


func test_is_reset_times_max_privilege_cap() -> void:
	var pd := PlayerData.new(cm)
	var cap: int = int(VipData.get_vip_field(VipData.get_max_level(cm), "Elite Reset", cm))
	if cap <= 0:
		assert_true(true, "特权档 Elite Reset=0，无上限语义，跳过")
		return
	for i in range(cap - 1):
		StageResetData.refresh_elite_limit(pd, 10001)
	assert_false(StageResetData.is_reset_times_max(pd, 10001), "特权档上限-1 次 → 未达上限")
	StageResetData.refresh_elite_limit(pd, 10001)
	assert_true(StageResetData.is_reset_times_max(pd, 10001), "特权档 reset 满 cap 次后达上限")


# 源 refreshStageEliteLimit（player.lua:1045-1051）：清 stage_limit[nid] + reset_times[nid]++。
func test_refresh_elite_limit_clears_stage_limit_and_increments_times() -> void:
	var pd := PlayerData.new(cm)
	pd.stage_limit[1] = 3   # normalStage 1 已挑战 3 次
	pd.stage_reset_times[1] = 0
	StageResetData.refresh_elite_limit(pd, 10001)   # 精英 10001 → normalStage 1
	assert_eq(int(pd.stage_limit.get(1, -1)), 0, "refresh 后 stage_limit 清零")
	assert_eq(int(pd.stage_reset_times.get(1, -1)), 1, "refresh 后 reset_times++")


# 旧版 bug 验证：Stage 表无 "Reset Cost" 字段，照源应读 GradientPrice 而非 Stage（P1-C1 修复）
func test_stage_table_has_no_reset_cost_field() -> void:
	var stage_row: Dictionary = cm.get_raw_table("Stage").get("10001", {})
	assert_false(stage_row.has("Reset Cost"), "Stage.json 无 Reset Cost 字段（旧版读错表）")
	assert_true(cm.get_raw_table("GradientPrice").has("1"), "GradientPrice.json 有 key=1（照源）")
	assert_true(cm.get_raw_table("GradientPrice")["1"].has("Elite Reset"), "GradientPrice[1] 含 Elite Reset")
