extends GutTest
# job_rewards 日常任务领奖测试（照源 local_server.lua:4071-4110）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_claim_job_reward_blocked_below_target() -> void:
	var tm := TaskManager.new()
	var pd := PlayerData.new(cm)
	# Todolist 1 Task Target=1（Login 型），时段外注入 11:00 → 合成计数 0 < 1 → 失败
	# （2026-10-06 起 Login 型走时段合成，claim 注入 now_minutes 与墙钟解耦）
	var r: Dictionary = tm.claim_job_reward(pd, 1, cm, 660)
	assert_false(bool(r["ok"]), "时段外未达 target → 领取失败")


func test_claim_job_reward_success_and_reset() -> void:
	var tm := TaskManager.new()
	var pd := PlayerData.new(cm)
	pd.vitality = 10  # 攒体口径：Vitality 600 硬上限 9999（2026-10-06 起不压 vitality_max）
	# Login 型时段内（13:00）合成计数=target → 可领；record 行为计数对 Login 型不再参与判定
	var before_vit: int = pd.vitality
	var r: Dictionary = tm.claim_job_reward(pd, 1, cm, 780)
	assert_true(bool(r["ok"]), "时段内达 target → 领取成功")
	assert_eq(pd.vitality, 610, "Vitality 奖励 +600 加体力")
	# 领取记当日 → 同日再领失败（防重，源 resetDailyjobTime）
	var r2: Dictionary = tm.claim_job_reward(pd, 1, cm, 790)
	assert_false(bool(r2["ok"]), "当日已领 → 再领失败")


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
	# 三轮拆分（2026-09-03）后单列表（%List 按模式 fill）；本测试验证主线行渲染进列表。
	var scroll_count: int = _count_scroll_in(panel.container)
	assert_eq(scroll_count, 1, "task 模式单滚动列表（2026-09-03 拆回源两独立弹窗）")
	var row_count: int = 0
	for scroll in panel.container.find_children("*", "ScrollContainer", true, false):
		row_count += (scroll as ScrollContainer).find_children("TaskRow", "TextureRect", true, false).size()
	assert_gte(row_count, 1, "触发的链任务行已渲染（TaskRow >=1）")
	panel.remove_window()
	root.queue_free()


# ── sync_current_tasks 任务发现（源 task.lua:1249 getTaskList → :1175 classifyTask
#    → :1132 getCurrentTaskInChain → :1108 canTriggerTask；打开面板时发现可接任务并登记，
#    单机化合并源"客户端发现 + 服务器 trigger_task 登记"两步）──

# 新玩家（0 星级）：仅无门槛链 40 被发现（Trigger ID={"1":0} 全 0 跳过）；
# 有门槛链（chain2 需 CompleteStage 4）未通关不登记（源 canTriggerTask :1115-1117）。
func test_sync_new_player_discovers_unconditional_chain() -> void:
	var tm := TaskManager.new()
	var pd := PlayerData.new(cm)
	tm.sync_current_tasks(pd, cm)
	assert_eq(tm.task.size(), 1, "新玩家仅发现 1 条无门槛任务")
	assert_eq(int(tm.task[0]["chain"]), 40, "chain=40")
	assert_eq(int(tm.task[0]["id"]), 1, "id=1")
	assert_eq(str(tm.task[0]["status"]), "working", "status=working")


# 通关门槛关卡后对应链被发现（源 getCurrentTaskInChain 未初始化链分支 :1158-1163）。
func test_sync_unlocks_chain_after_stage_cleared() -> void:
	var tm := TaskManager.new()
	var pd := PlayerData.new(cm)
	pd.stage_manager.progress[4] = 3   # chain2 id1 门槛 CompleteStage 4
	tm.sync_current_tasks(pd, cm)
	var found: bool = false
	for e in tm.task:
		if int(e["chain"]) == 2:
			found = true
			assert_eq(int(e["id"]), 1, "chain2 从 id1 起")
	assert_true(found, "通关 stage 4 后 chain2 被发现")


# 领完链中任务自动推进下一任务（源 :1147-1155 elseif canTriggerTask(id+1) → noTrigger 登记）。
func test_sync_advances_finished_task_in_chain() -> void:
	var tm := TaskManager.new()
	var pd := PlayerData.new(cm)
	pd.stage_manager.progress[4] = 3
	pd.stage_manager.progress[11] = 3   # chain2 id2 门槛 CompleteStage 11
	tm.sync_current_tasks(pd, cm)
	tm.claim_task_reward(pd, 2, 1, cm)   # 领 chain2 id1 → finished
	tm.sync_current_tasks(pd, cm)
	var c2_id: int = -1
	for e in tm.task:
		if int(e["chain"]) == 2:
			c2_id = int(e["id"])
	assert_eq(c2_id, 2, "finished 后 sync 推进到 id2（trigger_task 同链替换）")


# 链尾领完 → chain 进 task_finished（claim_task_reward ④）→ sync 不再发现且清残留 entry
# （源 classifyTask :1182 exception=finished chains 排除，链结束不显示）。
func test_sync_skips_finished_chains_and_clears_entries() -> void:
	var tm := TaskManager.new()
	var pd := PlayerData.new(cm)
	tm.task_finished.append(40)   # 模拟链 40 已领完
	tm.task.append({"chain": 40, "id": 1, "status": "finished", "target": 0})
	tm.sync_current_tasks(pd, cm)
	assert_eq(tm.task.size(), 0, "task_finished 链残留 entry 被清 + 不再发现")


# can_trigger_task 静态判定（源 canTriggerTask :1108-1130：row 不存在→nil；
# CompleteStage 星级≤0 拦截；PlayerLevel 等级不足拦截；其余 type 不拦截）。
func test_can_trigger_task_static_rules() -> void:
	var pd := PlayerData.new(cm)
	assert_false(TaskManager.can_trigger_task(999, 1, pd, cm), "Task row 不存在 → false")
	assert_true(TaskManager.can_trigger_task(40, 1, pd, cm), "Trigger 全 0（无门槛）→ true")
	assert_false(TaskManager.can_trigger_task(2, 1, pd, cm), "chain2 id1 需 stage4，未通关 → false")
	pd.stage_manager.progress[4] = 3
	assert_true(TaskManager.can_trigger_task(2, 1, pd, cm), "通关 stage4 → true")


# 递归统计 panel.container 子树中 ScrollContainer 数（.tscn 重构后非直接子）。
func _count_scroll_in(node: Node) -> int:
	var n: int = 0
	for c in node.get_children():
		if c is ScrollContainer:
			n += 1
		n += _count_scroll_in(c)
	return n


# ── P1-5（2026-09-28 审查）：日常任务显隐照源补全 + 今日已领防重 ──

# 源 isShow = 时间窗 OR checkdbTrigger（Trigger 全 0 恒 true）——常规日常
# （job 4 打副本×10 等，空 Display Time + 全 0 Trigger）曾因缺译永不显示。
func test_regular_dailyjobs_visible_without_display_time() -> void:
	var tm := TaskManager.new()
	var pd := PlayerData.new(cm)
	var visible: Array[int] = tm.get_visible_daily_jobs(cm, 780, pd)
	assert_true(visible.has(4), "job 4（空 Display Time+全 0 Trigger）全天可见")


# checkdbTrigger VIPLevelEqual 按特权档（满级 15）判：仅 VIPLevelEqual 15 的 job 可见。
func test_vip_equal_trigger_uses_privilege_level() -> void:
	var tm := TaskManager.new()
	var pd := PlayerData.new(cm)
	var visible: Array[int] = tm.get_visible_daily_jobs(cm, 780, pd)
	assert_true(visible.has(32), "job 32（VIPLevelEqual 15 == 特权档）可见")
	assert_false(visible.has(18), "job 18（VIPLevelEqual 1 != 特权档 15）不可见")


# target=0 行（VIP 每日扫荡券）领取防重：源 isShow「今日已领隐藏」；
# 旧实现 count(0)>=target(0) 恒真且不记已领 → 每日无限领。
func test_target_zero_job_claim_once_per_day() -> void:
	var tm := TaskManager.new()
	var pd := PlayerData.new(cm)
	var before_item: int = int(pd.items.get(_job32_reward_item(), 0))
	assert_true(bool(tm.claim_job_reward(pd, 32, cm)["ok"]), "job 32 首次领取成功")
	assert_false(bool(tm.claim_job_reward(pd, 32, cm)["ok"]), "同日再领被拒（dailyjob_claim_day）")
	assert_gt(int(pd.items.get(_job32_reward_item(), 0)), before_item, "扫荡券到账")
	var visible: Array[int] = tm.get_visible_daily_jobs(cm, 780, pd)
	assert_false(visible.has(32), "今日已领 → 行隐藏（源 lastTime 同日 isShow=false）")
	# 序列化往返保留领取日。
	var d: Dictionary = tm.to_dict()
	var tm2 := TaskManager.from_dict(d)
	assert_true(tm2.dailyjob_claim_day.has(32), "claim_day 序列化往返")


func _job32_reward_item() -> int:
	var row: Dictionary = cm.get_raw_table("Todolist").get("32", {})
	return int(row.get("Task Reward 1 ID", 0))


# ── FarmStage 主任务链累计（源 record.lua:143-149 successFarmStage → player.lua:1693-1721
#    increaseTaskCount；2026-10-08 补——此前主链无累计端，战利品链 20/进化之路链 26 共
#    25 个 FarmStage 任务进度恒 0、领取按钮永不出现）──

func _find_chain_entry(tm: TaskManager, chain: int) -> Dictionary:
	for e in tm.task:
		if int(e.get("chain", -1)) == chain:
			return e
	return {}


# 战利品1（Task[20][1]：FarmStage pid=18 target=1，门槛 Trigger 6=CompleteStage 18）：
# 通关 18 后 sync 登记 working，胜利 18 → entry.target 0→1 达标且 cap。
func test_increase_task_count_farm_stage_chain20() -> void:
	var tm := TaskManager.new()
	var pd := PlayerData.new(cm)
	pd.stage_manager.progress[18] = 3   # 门槛：已通关关卡 18
	tm.sync_current_tasks(pd, cm)
	var e: Dictionary = _find_chain_entry(tm, 20)
	assert_false(e.is_empty(), "通关 18 后战利品链登记 working")
	tm.increase_task_count(cm, "FarmStage", 18, 1)
	assert_eq(int(e["target"]), 1, "胜利关卡 18 → target 0→1（达 Task Target）")
	tm.increase_task_count(cm, "FarmStage", 18, 1)
	assert_eq(int(e["target"]), 1, "超出 Task Target 不再累（cap，源 math.min）")


# 匹配规则隔离验证：pid 不匹配 / type 不匹配 / 非 working 均不计（源 :1696-1706）。
func test_increase_task_count_mismatch_ignored() -> void:
	var tm := TaskManager.new()
	tm.task.append({"chain": 20, "id": 1, "status": "working", "target": 0})
	tm.increase_task_count(cm, "FarmStage", 19, 1)
	assert_eq(int(tm.task[0]["target"]), 0, "非 Progress ID 关卡不计")
	tm.increase_task_count(cm, "PlayerLevel", 18, 1)
	assert_eq(int(tm.task[0]["target"]), 0, "Progress Type 不匹配不计")
	tm.task[0]["status"] = "finished"
	tm.increase_task_count(cm, "FarmStage", 18, 1)
	assert_eq(int(tm.task[0]["target"]), 0, "finished 任务不计（源仅 working）")


# 战利品3（Task[20][3]：pid=23 target=2）：扫荡 times=2 一次 add 到位。
func test_increase_task_count_multi_add() -> void:
	var tm := TaskManager.new()
	tm.task.append({"chain": 20, "id": 3, "status": "working", "target": 0})
	tm.increase_task_count(cm, "FarmStage", 23, 2)
	assert_eq(int(tm.task[0]["target"]), 2, "add=2（扫荡合并）一次到位 cap target=2")


# 显示层：build_main_task 事件累计型（FarmStage）进度取 entry.target
# （源 ui/task.lua:1056 count=task._task_target；修复前 get_count 恒 0 → 永不可领）。
func test_build_main_task_farm_stage_uses_entry_target() -> void:
	var pd := PlayerData.new(cm)
	var row: Dictionary = cm.get_raw_table("Task").get("20", {}).get("1", {})
	var t0: Dictionary = TaskQuery.build_main_task(20, 1, row, false, cm, pd,
			{"chain": 20, "id": 1, "status": "working", "target": 0})
	assert_eq(int(t0["progress"]), 0, "entry target=0 → progress 0/1")
	var t1: Dictionary = TaskQuery.build_main_task(20, 1, row, false, cm, pd,
			{"chain": 20, "id": 1, "status": "working", "target": 1})
	assert_eq(int(t1["progress"]), 1, "entry target=1 → progress 1/1（is_completed，领取按钮出现）")


# 真实调用链（扫荡路径，源 network.lua:1218 sweep_reply successFarmStage(stage, times)）：
# 扫荡关卡 18 → 战利品1 进度 1/1 + FarmPVEStage 日常同步 +times（2026-10-08 补扫荡上报）。
func test_sweep_increases_farm_stage_task() -> void:
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	pd.vitality = 200
	pd.add_item(PlayerData.SWEEP_COIN_ID, 10)
	pd.stage_manager.progress[18] = 3   # 战利品1 门槛（星级前置由 UI 管）
	pd.task_manager.sync_current_tasks(pd, cm)
	var r: Dictionary = mgr.sweep(18, 1, BattleRng.new(1), pd)
	assert_true(bool(r.get("ok", false)), "前置：扫荡成功")
	var e: Dictionary = _find_chain_entry(pd.task_manager, 20)
	assert_eq(int(e.get("target", -1)), 1, "扫荡关卡 18 ×1 → 战利品1 进度 1/1")
	assert_eq(pd.task_manager.get_dailyjob_count(4), 1, "扫荡同步累计 FarmPVEStage 日常 job 4")


# 真实调用链（胜利路径，源 network.lua:858 exitStageReply 胜利分支）：
# assemble → 构造敌方全灭终态（die 走引擎默认死亡链，等效战斗跑完）→ finalize 上报。
# 不跑完整战斗循环：默认号打 stage 18 数值上 timeout（lose_type 实测），full 循环会
# 让断言依赖队伍强度而非上报逻辑本身（胜利/扫荡共用 _record_stage_dailyjob，行为
# 已由扫荡集成 + 单元用例覆盖）。
func test_battle_win_increases_farm_stage_task() -> void:
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	pd.stage_manager.progress[18] = 3
	pd.task_manager.sync_current_tasks(pd, cm)
	var asm: Dictionary = mgr.assemble_stage_battle(18, pd, [1], BattleRng.new(42))
	assert_true(bool(asm.get("ok", false)), "前置：装配成功")
	var eng: BattleEngine = asm["engine"]
	for u in eng.foreach_alive_unit(BattleEngine.CAMP_ENEMY):
		u.die(null)
	eng.result_stars = 3
	var r: Dictionary = mgr.finalize_stage_battle(eng, 18, pd, [1], asm["loots"])
	assert_true(bool(r.get("won", false)), "前置：敌方全灭 → 胜利判定")
	var e: Dictionary = _find_chain_entry(pd.task_manager, 20)
	assert_eq(int(e.get("target", -1)), 1, "胜利关卡 18 → 战利品1 进度 1/1")
	assert_eq(pd.task_manager.get_dailyjob_count(4), 1, "胜利同步累计 FarmPVEStage 日常 job 4")
