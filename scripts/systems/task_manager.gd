class_name TaskManager
extends RefCounted

## 任务/成就（Step 3.7）：完成标记 + 领取奖励 + 日常任务（Todolist）进度 + job_rewards。
## job_rewards 照源 local_server.lua:4071-4110 日常分支（活动 act_ 分支单机裁剪——SKIPPED activity 域）。
## 持久化：player_data_serde 已序列化 task_manager.to_dict()（存档结构支持），但 GameData.save() 全项目
## 零调用致实际不持久化（项目级存档集成缺口，见 MEMORY project-save-game-not-integrated）。

const TASK_REWARD_FIRST: int = 1   # Task Reward 槽位起始（源 :4086 Task Reward %d Type）
const TASK_REWARD_LAST: int = 2    # Task Reward 槽位上限（源 :4085 for 1..2）
const SPLITBITS_MASK: int = 0xFFFF  # splitbits 16 位掩码（源 tools.lua:88）
const SPLITBITS_SHIFT: int = 16     # splitbits 位移（源 tools.lua:88，chain 低16/id 次16）
const MINUTES_PER_HOUR: int = 60   # 每小时分钟数（Display Time 解析）
const TIME_RANGE_PARTS: int = 2    # 时间格式 split 段数（"HH:MM-HH:MM"/"HH:MM" 各 2 段）

var completed: Dictionary = {}  # task_id(int) -> bool
var claimed: Dictionary = {}    # task_id(int) -> bool
# 日常任务进度（job_id -> 今日完成次数）。源 player._dailyjob getDailyjobCount。
var dailyjob_count: Dictionary = {}
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


## 当前时段可见的日常 job_id 列表（源 task.lua:1489-1495 initTaskList 过滤）。
func get_visible_daily_jobs(cm: ConfigManager, now_minutes: int) -> Array[int]:
	var raw: Dictionary = cm.get_raw_table("Todolist")
	var result: Array[int] = []
	for job_id_str in raw:
		if check_dailyjob_display(cm, int(job_id_str), now_minutes):
			result.append(int(job_id_str))
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
		"task": task.duplicate(true),
		"task_finished": task_finished.duplicate(true),
	}


static func from_dict(data: Dictionary) -> TaskManager:
	var mgr := TaskManager.new()
	mgr.completed = data.get("completed", {})
	mgr.claimed = data.get("claimed", {})
	mgr.dailyjob_count = data.get("dailyjob_count", {})
	mgr.task = data.get("task", [])
	mgr.task_finished = data.get("task_finished", [])
	return mgr


## 活动 act_ 分支单机裁剪（SKIPPED）。返 {ok}。
func claim_job_reward(player: PlayerData, job_id: int, cm: ConfigManager) -> Dictionary:
	var row: Dictionary = cm.get_raw_table("Todolist").get(str(job_id), {})
	if row.is_empty():
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
