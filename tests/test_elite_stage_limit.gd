extends GutTest
# 精英关每日次数限制（2026-09-17 经济单机优化）：stage_limit 累加写入端补全
# （此前只有 UI 读与花钻重置，Daily Limit 恒放行=精英关 50 钻/次无限刷）+ 跨日清零。

var cm: ConfigManager

const ELITE_SID: int = 10001      # Stage 表精英关（Daily Limit=3，Vitality Cost=12）
const NORMAL_SID: int = 1         # 普通关（Daily Limit=0 不计）
const TS_DAY1_NOON: int = 1800000000
const TS_DAY2_NOON: int = TS_DAY1_NOON + 86400


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# ---- 累加判定（非精英关不计；胜利结算与扫荡共用 StageManager._record_stage_limit）----

func test_record_counts_elite_only() -> void:
	var pd := PlayerData.new(cm)
	StageManager._record_stage_limit(pd, ELITE_SID, 1)
	assert_eq(int(pd.stage_limit.get(ELITE_SID, 0)), 1, "精英关胜利 → 计 1 次")
	StageManager._record_stage_limit(pd, NORMAL_SID, 1)
	assert_false(pd.stage_limit.has(NORMAL_SID), "普通关不计（Daily Limit=0）")
	StageManager._record_stage_limit(null, ELITE_SID, 1)   # null player 防御不崩
	assert_eq(int(pd.stage_limit.get(ELITE_SID, 0)), 1, "null player 不影响既有计数")


func test_record_accumulates() -> void:
	var pd := PlayerData.new(cm)
	StageManager._record_stage_limit(pd, ELITE_SID, 1)
	StageManager._record_stage_limit(pd, ELITE_SID, 2)   # 扫荡 2 次合并计
	assert_eq(int(pd.stage_limit.get(ELITE_SID, 0)), 3, "累加到 3（= Daily Limit 封顶线）")


# ---- sweep 路径（真实调用链：扫荡 N 次 → stage_limit +N）----

func test_sweep_accumulates_elite_stage_limit() -> void:
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	pd.vitality = 200
	pd.add_item(PlayerData.SWEEP_COIN_ID, 10)
	var r: Dictionary = mgr.sweep(ELITE_SID, 2, BattleRng.new(1), pd)
	assert_true(bool(r.get("ok", false)), "前置：扫荡成功")
	assert_eq(int(pd.stage_limit.get(ELITE_SID, 0)), 2, "扫荡 2 次 → 计 2")


# ---- 跨日清零（PlayerData.check_stage_limit_daily_reset，面板打开时惰性触发）----

func test_daily_reset_clears_limit_and_reset_times() -> void:
	var pd := PlayerData.new(cm)
	pd.stage_limit = {ELITE_SID: 3}
	pd.stage_reset_times = {ELITE_SID: 2}
	pd.check_stage_limit_daily_reset(TS_DAY1_NOON)
	assert_true(pd.stage_limit.is_empty(), "跨日清 stage_limit")
	assert_true(pd.stage_reset_times.is_empty(), "跨日清 stage_reset_times（重置梯度同日重置）")
	pd.stage_limit = {ELITE_SID: 1}
	pd.check_stage_limit_daily_reset(TS_DAY1_NOON + 3600)   # 同日
	assert_eq(int(pd.stage_limit.get(ELITE_SID, 0)), 1, "同日不清")
	pd.check_stage_limit_daily_reset(TS_DAY2_NOON)
	assert_true(pd.stage_limit.is_empty(), "次日再清")


func test_stage_limit_roundtrip_serde() -> void:
	var pd := PlayerData.new(cm)
	pd.stage_limit = {ELITE_SID: 2}
	var restored := PlayerData.from_dict(pd.to_dict(), cm)
	assert_eq(int(restored.stage_limit.get(ELITE_SID, 0)), 2, "stage_limit 落盘回读")
