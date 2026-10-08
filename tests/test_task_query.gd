extends GutTest
## TaskQuery 查询 helper 单测（纯逻辑，无 Node 依赖）。

var cm: ConfigManager

func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()

func test_resolve_fast_target_call() -> void:
	var r: Dictionary = TaskQuery.resolve_fast_target("FarmPVEStage")
	assert_eq(String(r.get("action", "")), "call")
	assert_eq(String(r.get("method", "")), "_open_stage_select")

func test_resolve_fast_target_toast() -> void:
	var r: Dictionary = TaskQuery.resolve_fast_target("MonthlyCardPeriod")
	assert_eq(String(r.get("action", "")), "toast")
	assert_true(String(r.get("msg", "")).length() > 0)

func test_resolve_fast_target_unknown() -> void:
	var r: Dictionary = TaskQuery.resolve_fast_target("UnknownType")
	assert_eq(String(r.get("action", "")), "toast")

func test_pid_values_dict() -> void:
	var d: Dictionary = {"1": 100, "2": 200}
	var arr: Array = TaskQuery.pid_values(d)
	assert_eq(arr.size(), 2)
	assert_true(100 in arr)
	assert_true(200 in arr)

func test_pid_values_array() -> void:
	var a: Array = [1, 2, 3]
	assert_eq(TaskQuery.pid_values(a), [1, 2, 3])

func test_pid_values_other() -> void:
	assert_eq(TaskQuery.pid_values(42), [])

func test_parse_rewards_main_single() -> void:
	var row: Dictionary = {"Task Reward Type": "Coin", "Task Reward ID": 1, "Task Reward Amount": 100}
	var rewards: Array = TaskQuery.parse_rewards(row, false)
	assert_eq(rewards.size(), 1)
	assert_eq(str(rewards[0]["type"]), "Coin")
	assert_eq(int(rewards[0]["amount"]), 100)

func test_parse_rewards_daily_double() -> void:
	var row: Dictionary = {
		"Task Reward 1 Type": "Coin", "Task Reward 1 ID": 1, "Task Reward 1 Amount": 50,
		"Task Reward 2 Type": "Diamond", "Task Reward 2 ID": 2, "Task Reward 2 Amount": 10,
	}
	var rewards: Array = TaskQuery.parse_rewards(row, true)
	assert_eq(rewards.size(), 2)


# 源 local_server.lua:4068-4069：Todolist 表 1 号奖励无编号 amount 字段（id=1/2 实测，
# amount 存于无编号 "Task Reward Amount"），发奖侧 fallback 到该字段；显示侧 parse_rewards
# 须同款 fallback（2026-09-03 奖励行空根修——漏译致 amount=0 被过滤、奖励链全空）。
func test_parse_rewards_daily_amount_fallback() -> void:
	var row: Dictionary = {
		"Task Reward 1 Type": "Vitality", "Task Reward 1 ID": 0,
		"Task Reward Amount": 600,
	}
	var rewards: Array = TaskQuery.parse_rewards(row, true)
	assert_eq(rewards.size(), 1, "1 号奖励不因无编号 amount 字段丢失")
	assert_eq(int(rewards[0]["amount"]), 600, "amount fallback 到无编号 Task Reward Amount")

# ==== get_count/get_main_progress：9 type 分支进度查询（task_panel 拆分时丢失，2026-07-24 补回）====

# 未知 type → 0（fallback 分支）
func test_get_count_unknown_type() -> void:
	var pd := PlayerData.new(cm)
	assert_eq(TaskQuery.get_count("UnknownType", [1], 10, pd), 0)

# KillMonster/FarmStage 需 record 计数（TaskManager 未接）→ 降级 0
func test_get_count_killmonster_fallback_zero() -> void:
	var pd := PlayerData.new(cm)
	assert_eq(TaskQuery.get_count("KillMonster", [1], 10, pd), 0)
	assert_eq(TaskQuery.get_count("FarmStage", [1], 10, pd), 0)

# pid 含 0 应跳过（CompleteStage 0 pid 不查 stage_stars；返 0）
func test_get_count_pid_zero_skipped() -> void:
	var pd := PlayerData.new(cm)
	assert_eq(TaskQuery.get_count("CompleteStage", [0], 10, pd), 0)

# PlayerLevel 返当前战队等级（pid 被忽略）
func test_get_count_player_level() -> void:
	var pd := PlayerData.new(cm)
	pd.team_level = 15
	assert_eq(TaskQuery.get_count("PlayerLevel", [1], 99, pd), 15)

# CompleteStage：pid 任一关卡通关（stars>0）→ 返 target；未通关 → 0
func test_get_count_complete_stage() -> void:
	var pd := PlayerData.new(cm)
	var stage_id: int = 10001
	pd.stage_manager.progress[stage_id] = 3
	assert_eq(TaskQuery.get_count("CompleteStage", [stage_id], 5, pd), 5)
	assert_eq(TaskQuery.get_count("CompleteStage", [99999], 5, pd), 0)

# ItemQuantity：返当前持有量（源 equip_qunty[v]）
func test_get_count_item_quantity() -> void:
	var pd := PlayerData.new(cm)
	pd.items[101] = 10
	assert_eq(TaskQuery.get_count("ItemQuantity", [101], 99, pd), 10)

# ItemQuantity 物品不存在 → 0
func test_get_count_item_quantity_missing() -> void:
	var pd := PlayerData.new(cm)
	assert_eq(TaskQuery.get_count("ItemQuantity", [999], 99, pd), 0)


# ── is_task_ready / entry_progress（源 ui/task.lua:1052-1063 isTaskCompleted；
#    shortcut 任务红点判定，2026-10-08 前读恒空的 tm.completed 永不亮）──

# 事件累计型（FarmStage 战利品1）：entry.target 达标且 working 才就绪；finished（已领）不亮。
func test_is_task_ready_event_type() -> void:
	var pd := PlayerData.new(cm)
	var row20: Dictionary = cm.get_raw_table("Task").get("20", {}).get("1", {})
	assert_false(TaskQuery.is_task_ready({"chain": 20, "id": 1, "status": "working", "target": 0}, row20, pd),
			"FarmStage 0/1 → 未就绪")
	assert_true(TaskQuery.is_task_ready({"chain": 20, "id": 1, "status": "working", "target": 1}, row20, pd),
			"FarmStage 1/1 → 就绪（红点亮）")
	assert_false(TaskQuery.is_task_ready({"chain": 20, "id": 1, "status": "finished", "target": 1}, row20, pd),
			"已领取（finished）→ 不亮")

# 状态型（PlayerLevel）：entry.target 被忽略，走实时查询（team_level）。
func test_is_task_ready_state_type() -> void:
	var pd := PlayerData.new(cm)
	var row50: Dictionary = cm.get_raw_table("Task").get("50", {}).get("1", {})
	assert_false(TaskQuery.is_task_ready({"chain": 50, "id": 1, "status": "working", "target": 99}, row50, pd),
			"等级 1 < target 5 → 未就绪（entry.target 不参与状态型）")
	pd.team_level = 80
	assert_true(TaskQuery.is_task_ready({"chain": 50, "id": 1, "status": "working", "target": 0}, row50, pd),
			"等级 80 >= 5 → 就绪")

# entry_progress：事件型取 entry.target，状态型取实时查询（build_main_task 同源共用）。
func test_entry_progress_event_vs_state() -> void:
	var pd := PlayerData.new(cm)
	pd.team_level = 80
	var row20: Dictionary = cm.get_raw_table("Task").get("20", {}).get("1", {})
	var row50: Dictionary = cm.get_raw_table("Task").get("50", {}).get("1", {})
	assert_eq(TaskQuery.entry_progress({"target": 1}, row20, pd), 1, "事件型 → entry.target")
	assert_eq(TaskQuery.entry_progress({"target": 0}, row50, pd), 80, "状态型 → 实时查询（team_level）")

# HeroRank：默认英雄 tid 1-5（apply_default_data），rank=1 默认初始
func test_get_count_hero_rank_default_hero() -> void:
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	var rank: int = TaskQuery.get_count("HeroRank", [1], 99, pd)
	assert_gte(rank, 1)

# HeroRank 英雄不存在 → 0
func test_get_count_hero_rank_missing() -> void:
	var pd := PlayerData.new(cm)
	assert_eq(TaskQuery.get_count("HeroRank", [999], 99, pd), 0)

# get_main_progress：空 row → 0（无 Task Progress Type，ptype 空 → match _ 分支）
func test_get_main_progress_empty_row() -> void:
	var pd := PlayerData.new(cm)
	assert_eq(TaskQuery.get_main_progress({}, pd), 0)

# get_main_progress：端到端组装（PlayerLevel type → team_level）
func test_get_main_progress_end_to_end_player_level() -> void:
	var pd := PlayerData.new(cm)
	pd.team_level = 20
	var row: Dictionary = {"Task Progress Type": "PlayerLevel", "Task Progress ID": {"1": 0}, "Task Target": 10}
	assert_eq(TaskQuery.get_main_progress(row, pd), 20)
