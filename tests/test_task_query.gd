extends GutTest
## TaskQuery 查询 helper 单测（纯逻辑，无 Node 依赖）。

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
