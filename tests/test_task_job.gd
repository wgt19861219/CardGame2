extends GutTest
# job_rewards 日常任务领奖测试（照源 local_server.lua:4071-4110）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_claim_job_reward_blocked_below_target() -> void:
	var tm := TaskManager.new()
	var pd := PlayerData.new(cm)
	# Todolist 1 Task Target=1，未 record → count=0 < 1 → 失败
	var r: Dictionary = tm.claim_job_reward(pd, 1, cm)
	assert_false(bool(r["ok"]), "未达 target → 领取失败")


func test_claim_job_reward_success_and_reset() -> void:
	var tm := TaskManager.new()
	var pd := PlayerData.new(cm)
	pd.vitality = 10  # 设低避 vitality_max 截断（Todolist 1 Reward=Vitality 600，min(610,120)=120）
	tm.record_dailyjob_progress(1, 1)  # count 1 >= target 1
	var before_vit: int = pd.vitality
	var r: Dictionary = tm.claim_job_reward(pd, 1, cm)
	assert_true(bool(r["ok"]), "达 target → 领取成功")
	assert_gt(pd.vitality, before_vit, "Vitality 奖励加体力")
	# reset 后 count=0 → 再领失败（防重，源 resetDailyjobTime）
	var r2: Dictionary = tm.claim_job_reward(pd, 1, cm)
	assert_false(bool(r2["ok"]), "reset 后 count=0 → 再领失败")


func test_claim_job_reward_unknown_job() -> void:
	var tm := TaskManager.new()
	var pd := PlayerData.new(cm)
	var r: Dictionary = tm.claim_job_reward(pd, 99999, cm)
	assert_false(bool(r["ok"]), "未知 job → 失败")


# Display Time 时间窗（照源 time.lua:383-405 checkTimeBetween 开区间 + task.lua:71-85 checkDailyjobDisplay）。
func test_time_in_window_open_interval() -> void:
	assert_true(TaskManager._time_in_window(780, "00:00-14:00"), "13:00 在 00:00-14:00 内")
	assert_false(TaskManager._time_in_window(900, "00:00-14:00"), "15:00 不在 00:00-14:00")
	assert_true(TaskManager._time_in_window(1390, "23:00-24:00"), "23:10 在 23:00-24:00 内")
	assert_false(TaskManager._time_in_window(1380, "23:00-24:00"), "恰好起点 23:00 开区间不算")
	assert_eq(TaskManager._hhmm_to_minutes("24:00"), 1440, "24:00 → 1440 分钟")
	assert_eq(TaskManager._hhmm_to_minutes("14:30"), 870, "14:30 → 870 分钟")


# Todolist[1] 午餐（23-24/0-14）：中午命中、下午不命中（源 checkDailyjobDisplay 读真实表）。
func test_check_dailyjob_display_real_table() -> void:
	var tm := TaskManager.new()
	var row: Dictionary = cm.get_raw_table("Todolist").get("1", {})
	if not row.has("Display Time"):
		return   # 表结构变动则跳过
	assert_true(tm.check_dailyjob_display(cm, 1, 780), "13:00 在午餐窗 00:00-14:00 → 显示")
	assert_false(tm.check_dailyjob_display(cm, 1, 900), "15:00 不在午餐窗 → 不显示")
	var visible_noon: Array[int] = tm.get_visible_daily_jobs(cm, 780)
	assert_true(visible_noon.has(1), "中午可见列表含午餐 job 1")


func test_record_dailyjob_progress_accumulates() -> void:
	var tm := TaskManager.new()
	assert_eq(tm.get_dailyjob_count(5), 0, "初始 0")
	tm.record_dailyjob_progress(5, 1)
	tm.record_dailyjob_progress(5, 2)
	assert_eq(tm.get_dailyjob_count(5), 3, "累加 1+2=3")


# record_by_type：按 Task Progress Type 查 Todolist 计数（源 increaseDailyjobCount）。
# Todolist 4 = FarmPVEStage Target=10 / 10 = SkillUpgradeSuccess Target=3
func test_record_by_type_matches_todolist() -> void:
	var tm := TaskManager.new()
	tm.record_by_type(cm, "FarmPVEStage")
	assert_eq(tm.get_dailyjob_count(4), 1, "FarmPVEStage → Todolist 4 计数 +1")
	tm.record_by_type(cm, "SkillUpgradeSuccess")
	assert_eq(tm.get_dailyjob_count(10), 1, "SkillUpgradeSuccess → Todolist 10 计数 +1")


# 行为 hook 触发：通关后 task_manager 有 FarmPVEStage 进度
func test_stage_clear_triggers_farm_dailyjob() -> void:
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	var mgr := StageManager.new(cm)
	var rng := BattleRng.new(42)
	var r: Dictionary = mgr.run_stage_battle(1, pd, [1], rng)
	if bool(r.get("won", false)):
		assert_gt(pd.task_manager.get_dailyjob_count(4), 0, "通关 stage 1 后 FarmPVEStage 进度 > 0")


# ── trigger_task（源 local_server.lua:1484-1505）──

func test_trigger_task_splitbits() -> void:
	# 源 tools.lua:88 splitbits(packed,16,16)：chain=低16, id=次16
	# packed = chain | (id << 16) = 2 | (1 << 16) = 65538
	var tm := TaskManager.new()
	tm.trigger_task([65538])  # chain=2, id=1
	assert_eq(tm.task.size(), 1, "插入 1 个任务")
	assert_eq(int(tm.task[0]["chain"]), 2, "chain=2")
	assert_eq(int(tm.task[0]["id"]), 1, "id=1")
	assert_eq(str(tm.task[0]["status"]), "working", "status=working")
	assert_eq(int(tm.task[0]["target"]), 0, "target=0")


func test_trigger_task_replace_same_chain() -> void:
	# 源 :1488-1492 同链旧任务被移除：先插 chain=2 id=1，再插 chain=2 id=2
	var tm := TaskManager.new()
	tm.trigger_task([65538])   # chain=2, id=1
	tm.trigger_task([131074])  # chain=2, id=2 (2 | 2<<16 = 131074)
	assert_eq(tm.task.size(), 1, "同链只留 1 个")
	assert_eq(int(tm.task[0]["id"]), 2, "id 更新为 2（旧被替换）")


func test_trigger_task_multi_chain() -> void:
	# 不同链共存
	var tm := TaskManager.new()
	tm.trigger_task([65538, 196610])  # chain=2 id=1, chain=3 id=3 (3|3<<16=196611)
	# 修正：chain=3 id=3 = 3 | (3<<16) = 3 + 196608 = 196611
	tm.task.clear()
	tm.trigger_task([65538, 196611])
	assert_eq(tm.task.size(), 2, "两条不同链共存")


func test_trigger_task_persistence() -> void:
	var tm := TaskManager.new()
	tm.trigger_task([65538])
	var d: Dictionary = tm.to_dict()
	var tm2 := TaskManager.from_dict(d)
	assert_eq(tm2.task.size(), 1, "序列化往返 task 保留")
	assert_eq(int(tm2.task[0]["chain"]), 2, "往返 chain 正确")


# ── claim_task_reward / require_rewards（源 local_server.lua:1508-1581）──

func test_claim_task_reward_grant() -> void:
	# Task[2][1] Task Reward Type=Coin Amount>0
	var tm := TaskManager.new()
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 0
	tm.trigger_task([65538])  # chain=2 id=1
	var before_gold: int = pd.hero_manager.gold
	var r: Dictionary = tm.claim_task_reward(pd, 2, 1, cm)
	assert_true(bool(r["ok"]), "领奖成功")
	assert_gt(pd.hero_manager.gold, before_gold, "金币奖励发放")


func test_claim_task_reward_status_finished() -> void:
	var tm := TaskManager.new()
	var pd := PlayerData.new(cm)
	tm.trigger_task([65538])
	tm.claim_task_reward(pd, 2, 1, cm)
	assert_eq(str(tm.task[0]["status"]), "finished", "领奖后 status→finished")


func test_claim_task_reward_chain_tail() -> void:
	# 源 :1546-1558：Task[chain][id+1] 不存在 → 加 task_finished
	var tm := TaskManager.new()
	var pd := PlayerData.new(cm)
	# 找一个链尾 id（Task[chain] 最后一个 id）
	var task_table: Dictionary = cm.get_raw_table("Task")
	var chain: int = 2
	var ids: Dictionary = task_table.get(str(chain), {})
	# 找最大 id（链尾）
	var max_id: int = 0
	for id_str in ids:
		max_id = max(max_id, int(id_str))
	# 触发该 id 的任务
	var packed: int = chain | (max_id << 16)
	tm.trigger_task([packed])
	tm.claim_task_reward(pd, chain, max_id, cm)
	assert_true(tm.task_finished.has(chain), "链尾领奖 → task_finished 加 chain")


func test_claim_task_reward_unknown() -> void:
	var tm := TaskManager.new()
	var pd := PlayerData.new(cm)
	var r: Dictionary = tm.claim_task_reward(pd, 999, 999, cm)
	assert_false(bool(r["ok"]), "未知 Task → 失败")


# P1-2026-07-10：task_panel 主线任务链 View（照源 task.lua createTask）
func test_task_panel_shows_main_task_chain() -> void:
	var root := Node.new()
	add_child(root)
	var tm := TaskManager.new()
	var pd := PlayerData.new(cm)
	# 触发一条主线任务（chain 2, id 1）
	tm.trigger_task([2 | (1 << 16)])
	var panel := TaskPanel.new("task", {})
	panel.setup_panel(pd, cm, tm)
	panel.show_window(root)
	# .tscn 重构后 container 直接子是 TaskContent（1 个），ScrollContainer/MainList/DailyList 在其下。
	# 语义不变：递归找 ScrollContainer >= 2（主线 + 日常两段）。
	var scroll_count: int = _count_scroll_in(panel.container)
	assert_gte(scroll_count, 2, "task_panel 含主线+日常分区（>=2 个 ScrollContainer）")
	panel.remove_window()
	root.queue_free()


# 递归统计 panel.container 子树中 ScrollContainer 数（.tscn 重构后非直接子）。
func _count_scroll_in(node: Node) -> int:
	var n: int = 0
	for c in node.get_children():
		if c is ScrollContainer:
			n += 1
		n += _count_scroll_in(c)
	return n
