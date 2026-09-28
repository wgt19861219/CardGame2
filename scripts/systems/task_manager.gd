class_name TaskManager
extends RefCounted

## 任务/成就（Step 3.7）：完成标记 + 领取奖励 + 日常任务（Todolist）进度 + job_rewards。
## job_rewards 照源 local_server.lua:4071-4110 日常分支（活动 act_ 分支单机裁剪——SKIPPED activity 域）。
## 持久化：player_data_serde 序列化 task_manager.to_dict() + task_panel 领奖 mark_save_dirty
## （View 接入层，照源 local_server:4480；存档集成批次 2/3 已接入）。

const TASK_REWARD_FIRST: int = 1   # Task Reward 槽位起始（源 :4086 Task Reward %d Type）
const TASK_REWARD_LAST: int = 2    # Task Reward 槽位上限（源 :4085 for 1..2）
const SPLITBITS_MASK: int = 0xFFFF  # splitbits 16 位掩码（源 tools.lua:88）
const SPLITBITS_SHIFT: int = 16     # splitbits 位移（源 tools.lua:88，chain 低16/id 次16）
const MINUTES_PER_HOUR: int = 60   # 每小时分钟数（Display Time 解析）
const TIME_RANGE_PARTS: int = 2    # 时间格式 split 段数（"HH:MM-HH:MM"/"HH:MM" 各 2 段）
const SECONDS_PER_MINUTE: int = 60      # DailyTime 触发器条件值是当天秒数（源 hms2Second）
const DAY_KEY_YEAR_WEIGHT: int = 10000  # 本地日 key 权重（照 ladder_manager 范式）
const DAY_KEY_MONTH_WEIGHT: int = 100

var completed: Dictionary = {}  # task_id(int) -> bool
var claimed: Dictionary = {}    # task_id(int) -> bool
# 日常任务进度（job_id -> 今日完成次数）。源 player._dailyjob getDailyjobCount。
var dailyjob_count: Dictionary = {}
# 日常任务领奖日（job_id -> 本地日 key）。源 task.lastTime + isShow"今日已领隐藏"：
# 领取当日不再显示/不可再领，跨日惰性清除（2026-09-28 审查 P1-5，兼防 target=0 行无限领）。
var dailyjob_claim_day: Dictionary = {}
# 主任务链（源 localdata.task）：Array[{chain:int, id:int, status:String, target:int}]
var task: Array = []
# 已完成链（源 localdata.task_finished）：Array[int]（存 chain，去重）
var task_finished: Array = []


func complete(task_id: int) -> void:
	completed[task_id] = true


func is_completed(task_id: int) -> bool:
	return bool(completed.get(task_id, false))


## 领奖：需已完成且未领（通用任务标记，不发奖——job_rewards 用 claim_job_reward 发奖）。
func claim(task_id: int) -> bool:
	if not is_completed(task_id) or bool(claimed.get(task_id, false)):
		return false
	claimed[task_id] = true
	return true


func is_claimed(task_id: int) -> bool:
	return bool(claimed.get(task_id, false))


# ---- 主任务链（源 local_server.lua:1484-1581 trigger_task + require_rewards）----

## 拆 splitbits（源 tools.lua:88 splitbits(packed,16,16)）：低16=chain 次16=id。
static func _split_chain_id(packed: int) -> Array[int]:
	return [packed & SPLITBITS_MASK, (packed >> SPLITBITS_SHIFT) & SPLITBITS_MASK]


## 移除同链旧任务（倒序避索引错位），插入 {chain, id, "working", 0}。
func trigger_task(packed_list: Array) -> void:
	for packed in packed_list:
		var ci: Array[int] = _split_chain_id(int(packed))
		var chain: int = ci[0]
		var tid: int = ci[1]
		# 倒序移除同链旧任务（源 :1488-1492 for j=#lt,1,-1）
		var i: int = task.size() - 1
		while i >= 0:
			if task[i].get("chain", -1) == chain:
				task.pop_at(i)
			i -= 1
		task.append({"chain": chain, "id": tid, "status": "working", "target": 0})


## 任务触发条件判定（源 task.lua:1108-1130 canTriggerTask）：Task[chain][tid] 的
## Trigger ID 列表逐条查 Triggers 表——CompleteStage 需玩家通关（星级>0）、
## PlayerLevel 需等级达标，其余 type 不拦截；row 不存在 → false（源 not task → nil）。
## 数据实测 Triggers 168 条全 CompleteStage（PlayerLevel 分支照源保留）。
static func can_trigger_task(chain: int, tid: int, player: PlayerData, cm: ConfigManager) -> bool:
	var row: Dictionary = cm.get_raw_table("Task").get(str(chain), {}).get(str(tid), {})
	if row.is_empty():
		return false
	var triggers: Variant = row.get("Trigger ID", {})
	if not triggers is Dictionary:
		return true
	var trigger_table: Dictionary = cm.get_raw_table("Triggers")
	for v in (triggers as Dictionary).values():
		if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
			continue
		if float(v) <= 0.0:
			continue
		var trow: Dictionary = trigger_table.get(str(int(v)), {})
		var ttype: String = str(trow.get("Trigger Type", ""))
		var cond: int = int(trow.get("Trigger Condition", 0))
		if ttype == "CompleteStage":
			if player.stage_manager.stage_stars(cond) <= 0:
				return false
		elif ttype == "PlayerLevel" and cond > player.team_level:
			return false
	return true


## 任务发现 + 登记（源打开面板 task.lua:1249 getTaskList → :1175 classifyTask →
## :1132 getCurrentTaskInChain：客户端发现可接任务 → 发服务器 trigger_task 登记 → 回复显示。
## 单机化合并为本地一步，View 打开/刷新面板时调用）。幂等：
## ① task_finished 链清除残留 entry（源 classifyTask :1182 exception=finished 链排除，链结束不显示）；
## ② 进行中链保留（源 :1139-1145 返回当前任务）；
## ③ 已领奖（finished）且下一任务条件满足 → 推进（源 :1147-1155 canTriggerTask(id+1) 登记）；
## ④ 未初始化链首任务条件满足 → 登记（源 :1158-1163 canTriggerTask(chain,1)）。
func sync_current_tasks(player: PlayerData, cm: ConfigManager) -> void:
	# ① 清 task_finished 链残留
	var i: int = task.size() - 1
	while i >= 0:
		if task_finished.has(int(task[i].get("chain", -1))):
			task.pop_at(i)
		i -= 1
	var task_table: Dictionary = cm.get_raw_table("Task")
	for chain_str in task_table:
		if str(chain_str) == "name":
			continue
		var chain: int = int(chain_str)
		if task_finished.has(chain):
			continue
		var cur: Dictionary = {}
		for entry in task:
			if int(entry.get("chain", -1)) == chain:
				cur = entry
				break
		if not cur.is_empty():
			# ②③ 已初始化链：working 保留；finished 推进下一任务
			if str(cur.get("status", "working")) != "finished":
				continue
			var next_id: int = int(cur.get("id", 0)) + 1
			if can_trigger_task(chain, next_id, player, cm):
				trigger_task([chain | (next_id << SPLITBITS_SHIFT)])
		elif can_trigger_task(chain, 1, player, cm):
			# ④ 未初始化链：首任务条件满足即登记
			trigger_task([chain | (1 << SPLITBITS_SHIFT)])


## 源 require_rewards :1508-1581：查 Task[chain][id] 单槽发奖 + Consume 扣资源 + status→finished + 链尾 task_finished。
## 返 {ok:bool}。
func claim_task_reward(player: PlayerData, chain: int, id: int, cm: ConfigManager) -> Dictionary:
	var task_table: Dictionary = cm.get_raw_table("Task")
	var row: Dictionary = task_table.get(str(chain), {}).get(str(id), {})
	if row.is_empty():
		return {"ok": false}
	# ① 发奖（单槽 Task Reward Type/ID/Amount，源 :1517-1527）
	var rtype: String = String(row.get("Task Reward Type", ""))
	var rid: int = int(row.get("Task Reward ID", 0))
	var ramount: int = int(row.get("Task Reward Amount", 0))
	if rtype != "" and ramount > 0:
		_apply_reward(player, rtype, rid, ramount)
	# ② 消耗类扣资源（源 :1529-1538，仅 Task Need Consume=true）
	if bool(row.get("Task Need Consume", false)):
		var ctype: String = String(row.get("Task Consume Type", ""))
		var cid: int = int(row.get("Task Consume ID", 0))
		var camount: int = int(row.get("Task Consume Amount", 0))
		_apply_reward(player, ctype, cid, -camount)
	# ③ status→finished（源 :1540-1544）
	for entry in task:
		if entry.get("chain") == chain and entry.get("id") == id:
			entry["status"] = "finished"
			break
	# ④ 链尾判定：Task[chain][id+1] 不存在 → 加 task_finished（源 :1546-1558）
	var has_next: bool = not task_table.get(str(chain), {}).get(str(id + 1), {}).is_empty()
	if not has_next and not task_finished.has(chain):
		task_finished.append(chain)
	return {"ok": true}




func get_dailyjob_count(job_id: int) -> int:
	return int(dailyjob_count.get(job_id, 0))


## 行为事件触发进度（源 Task Progress Type 事件 → 计数）。调用方按行为调（持久化待接玩家行为事件）。
func record_dailyjob_progress(job_id: int, amount: int = 1) -> void:
	dailyjob_count[job_id] = get_dailyjob_count(job_id) + amount


## 调用方传 type（FarmPVEStage/PVPBattle/SkillUpgradeSuccess/EnhanceLevelUp/MidasUse/TavernGroupUse 等）。
## type 在源 record.lua 各行为点触发（successFarmStage/chaosFarmStage/refreshCommonRecord）。
func record_by_type(cm: ConfigManager, type: String, amount: int = 1) -> void:
	var todolist: Dictionary = cm.get_raw_table("Todolist")
	for job_id_str in todolist:
		var row: Dictionary = todolist[job_id_str]
		if String(row.get("Task Progress Type", "")) == type:
			record_dailyjob_progress(int(job_id_str), amount)


## 当前系统时间当天分钟数（View 调用便利；Logic 测试用 get_visible_daily_jobs/check_dailyjob_display 注入 now_minutes）。
static func current_now_minutes() -> int:
	var d: Dictionary = Time.get_time_dict_from_system()
	return int(d["hour"]) * MINUTES_PER_HOUR + int(d["minute"])


## 当前时段可见的日常 job_id 列表（源 task.lua:1487-1496 isShow：
## 今日未领 && (checkDailyjobDisplay 时间窗 OR checkdbTrigger 触发器)）。
## player 为 null 时 VIP/PlayerLevel 类触发器按特权档宽容判定（不拦截）。
func get_visible_daily_jobs(cm: ConfigManager, now_minutes: int, player: PlayerData = null) -> Array[int]:
	var raw: Dictionary = cm.get_raw_table("Todolist")
	var result: Array[int] = []
	var today: int = _today_key()
	for job_id_str in raw:
		var job_id: int = int(job_id_str)
		var claim_day: int = int(dailyjob_claim_day.get(job_id, 0))
		if claim_day == today:
			continue   # 今日已领 → 隐藏（源 lastTime 同日）
		if claim_day != 0 and claim_day < today:
			dailyjob_claim_day.erase(job_id)   # 跨日惰性清（未来日期不前清，防回拨误清）
		if check_dailyjob_display(cm, job_id, now_minutes) or check_db_trigger(cm, job_id, player, now_minutes):
			result.append(job_id)
	return result


func check_dailyjob_display(cm: ConfigManager, job_id: int, now_minutes: int) -> bool:
	var row: Dictionary = cm.get_raw_table("Todolist").get(str(job_id), {})
	if row.is_empty():
		return false
	var dts_raw: Variant = row.get("Display Time", {})
	if not dts_raw is Dictionary:
		return false
	var dts: Dictionary = dts_raw   # JSON 存 Dictionary {"1":"HH:MM-HH:MM",...}（lua table→JSON）
	if dts.is_empty():
		return false
	for range_str in dts.values():
		if _time_in_window(now_minutes, str(range_str)):
			return true
	return false


static func _time_in_window(now_minutes: int, range_str: String) -> bool:
	var parts: PackedStringArray = range_str.split("-")
	if parts.size() < TIME_RANGE_PARTS:
		return false
	return now_minutes > _hhmm_to_minutes(parts[0]) and now_minutes < _hhmm_to_minutes(parts[1])


## 触发器判定（源 task.lua:22-69 checkdbTrigger）：Trigger ID 全 0（或无正值）恒 true；
## 逐条查 TodoTriggers 且多条为 AND（任一不满足即 false）。VIP 类按单机特权档
## （privilege_vip_level 满级）判；DailyTimeAfter/Before 条件值为当天秒数（源 hms2Second）。
## 2026-09-28 审查 P1-5：常规日常（job 4-15 空 Display Time）靠本函数显示，原缺译致永不显示。
static func check_db_trigger(cm: ConfigManager, job_id: int, player: PlayerData, now_minutes: int) -> bool:
	var row: Dictionary = cm.get_raw_table("Todolist").get(str(job_id), {})
	if row.is_empty():
		return false
	var tg_raw: Variant = row.get("Trigger ID", {})
	if not tg_raw is Dictionary:
		return true
	var ids: Array[int] = []
	for v in (tg_raw as Dictionary).values():
		if (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and float(v) > 0.0:
			ids.append(int(v))
	if ids.is_empty():
		return true   # 源 #tg<1 或正值集空 → 恒显示
	var trigger_table: Dictionary = cm.get_raw_table("TodoTriggers")
	var vip: int = VipData.get_max_level(cm) if player == null else player.privilege_vip_level()
	var now_seconds: int = now_minutes * SECONDS_PER_MINUTE
	for tid in ids:
		var trow: Dictionary = trigger_table.get(str(tid), {})
		var ttype: String = str(trow.get("Trigger Type", ""))
		var cond: int = int(trow.get("Trigger Condition", 0))
		match ttype:
			"VIPLevel":
				if cond > vip:
					return false
			"VIPLevelLessThan":
				if cond <= vip:
					return false
			"VIPLevelEqual":
				if vip != cond:
					return false
			"PlayerLevel":
				if player == null or cond > player.team_level:
					return false
			"DailyTimeAfter":
				if cond >= now_seconds:
					return false
			"DailyTimeBefore":
				if cond <= now_seconds:
					return false
	return true


## 本地日 key（照 ladder_manager._local_day_key 范式，YYYYMMDD int）。
static func _local_day_key(ts: int, off_min: int) -> int:
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(ts + off_min * SECONDS_PER_MINUTE)
	return int(dt["year"]) * DAY_KEY_YEAR_WEIGHT + int(dt["month"]) * DAY_KEY_MONTH_WEIGHT + int(dt["day"])


static func _today_key() -> int:
	return _local_day_key(int(Time.get_unix_time_from_system()), int(Time.get_time_zone_from_system().get("bias", 0)))


## "HH:MM" → 当天分钟数（照源 gfind "%d+:%d+" 解析 h/m；24:00=1440）。
static func _hhmm_to_minutes(hhmm: String) -> int:
	var hm: PackedStringArray = hhmm.split(":")
	if hm.size() < TIME_RANGE_PARTS:
		return 0
	return int(hm[0]) * MINUTES_PER_HOUR + int(hm[1])


func reset_dailyjob(job_id: int) -> void:
	dailyjob_count[job_id] = 0


## 存档序列化（照 crusade_manager 范式）。
func to_dict() -> Dictionary:
	return {
		"completed": completed.duplicate(true),
		"claimed": claimed.duplicate(true),
		"dailyjob_count": dailyjob_count.duplicate(true),
		"dailyjob_claim_day": dailyjob_claim_day.duplicate(true),
		"task": task.duplicate(true),
		"task_finished": task_finished.duplicate(true),
	}


static func from_dict(data: Dictionary) -> TaskManager:
	var mgr := TaskManager.new()
	mgr.completed = data.get("completed", {})
	mgr.claimed = data.get("claimed", {})
	mgr.dailyjob_count = data.get("dailyjob_count", {})
	mgr.dailyjob_claim_day = data.get("dailyjob_claim_day", {})
	mgr.task = data.get("task", [])
	mgr.task_finished = data.get("task_finished", [])
	return mgr


## 活动 act_ 分支单机裁剪（SKIPPED）。返 {ok}。
## 今日已领防重（源 isShow 隐藏 + resetDailyjobTime；target=0 行曾可无限领，2026-09-28 审查 P1-5）。
func claim_job_reward(player: PlayerData, job_id: int, cm: ConfigManager) -> Dictionary:
	var row: Dictionary = cm.get_raw_table("Todolist").get(str(job_id), {})
	if row.is_empty():
		return {"ok": false}
	var today: int = _today_key()
	if int(dailyjob_claim_day.get(job_id, 0)) == today:
		return {"ok": false}
	if get_dailyjob_count(job_id) < int(row.get("Task Target", 0)):
		return {"ok": false}
	for i in range(TASK_REWARD_FIRST, TASK_REWARD_LAST + 1):
		var rtype: String = String(row.get("Task Reward %d Type" % i, ""))
		var rid: int = int(row.get("Task Reward %d ID" % i, 0))
		var ramount: int = int(row.get("Task Reward %d Amount" % i, 0))
		if ramount <= 0 and i == TASK_REWARD_FIRST:
			ramount = int(row.get("Task Reward Amount", 0))
		if rtype == "" or ramount <= 0:
			continue
		_apply_reward(player, rtype, rid, ramount)
	reset_dailyjob(job_id)
	dailyjob_claim_day[job_id] = today
	return {"ok": true}


func _apply_reward(player: PlayerData, rtype: String, rid: int, amount: int) -> void:
	match rtype:
		"Coin":
			player.hero_manager.add_money(amount)
		"Diamond":
			player.add_diamond(amount)
		"Vitality":
			player.vitality = min(player.vitality + amount, player.vitality_max)
		"PlayerEXP":
			player.add_team_exp(amount)
		"Item":
			player.add_item(rid, amount)
