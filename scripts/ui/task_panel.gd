class_name TaskPanel
extends PopWindow

## 任务面板（View 主控，task_panel 拆分 3/3，2026-07-24）。
## 职责：面板生命周期 + 列表填充协调 + 领奖/跳场景回调。
## 查询逻辑外迁 TaskQuery（fast 路由 / 主任务进度 / 奖励解析 / 英雄计数）；
## 行渲染外迁 TaskRowBuilder（procedural 行绘制 + Theme variation 接线）。
## 本文件只保留协调：fill 装配 + 回调分发。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/task_content.tscn")

# basetask.create @826 mainLayer=CCLayerColor:create(ccc4(0,0,0,200)) 半透明黑遮罩（popup 非场景）。
# PopWindow 默认 shade alpha=150/255（popwindow.lua），此处覆盖为源的 200/255。
const SHADE_ALPHA: float = 200.0 / 255.0

var _player: PlayerData
var _cm: ConfigManager
var _tm: TaskManager
var _main_list: VBoxContainer = null   # .tscn %MainList（主线任务行容器）
var _daily_list: VBoxContainer = null  # .tscn %DailyList（日常任务行容器）


func setup_panel(p_player: PlayerData, p_cm: ConfigManager, p_tm: TaskManager) -> void:
	_player = p_player
	_cm = p_cm
	_tm = p_tm
	setup()
	if shade_layer != null:
		shade_layer.color.a = SHADE_ALPHA
	_build_content()


# 建 UI 内容：chrome + 段标题 + Scroll 静态节点从 .tscn instantiate（位置/size 可视化），
# 任务行 procedural 挂 %MainList/%DailyList。
func _build_content() -> void:
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	_main_list = content.get_node("%MainList") as VBoxContainer
	_daily_list = content.get_node("%DailyList") as VBoxContainer
	# fill 静态 Label LSTR（chrome title + 段标题）
	(content.get_node("%Title") as Label).text = _cm.get_lstr("TASK.TASK")
	(content.get_node("%MainTitleLabel") as Label).text = _cm.get_lstr("TASK.TASK")
	(content.get_node("%DailyTitleLabel") as Label).text = _cm.get_lstr("TASK.DAILY_ACTIVITIES")
	# close 按钮
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	_fill_main_list()
	_fill_daily_list()


# ed.ui.task:initTaskList + basetask.createTask：遍历 tm.task → Task[chain][id] → 装行。
func _fill_main_list() -> void:
	if _tm.task.is_empty():
		_main_list.add_child(TaskRowBuilder.make_empty_prompt_with_text(_cm.get_lstr("TASK.NO_CURRENT_TASK_CAN_BE_ACCESSED")))
		return
	var task_table: Dictionary = _cm.get_raw_table("Task")
	var reward_title_text: String = _cm.get_lstr("EXERCISE.AWARDS_")
	var fast_btn_text: String = _cm.get_lstr("TASK.HEAD_TO")
	for entry in _tm.task:
		var chain: int = int(entry.get("chain", 0))
		var tid: int = int(entry.get("id", 0))
		var row: Dictionary = task_table.get(str(chain), {}).get(str(tid), {})
		if row.is_empty():
			continue
		var is_finished: bool = str(entry.get("status", "working")) == "finished"
		var task: Dictionary = TaskQuery.build_main_task(chain, tid, row, is_finished, _cm, _player)
		_main_list.add_child(TaskRowBuilder.make_task_row(task, _on_claim_main.bind(chain, tid), reward_title_text, fast_btn_text))


# ed.ui.dailyTask:initTaskList + task.lua:1489-1495：只显示当前时段的日常任务
# （checkDailyjobDisplay 时间窗；checkdbTrigger VIP 单机化不接）。
func _fill_daily_list() -> void:
	var jobs: Array[int] = _tm.get_visible_daily_jobs(_cm, _tm.current_now_minutes())
	if jobs.is_empty():
		_daily_list.add_child(TaskRowBuilder.make_empty_prompt_with_text(_cm.get_lstr("TASK.YOU_HAVE_DONE_TODAYS_TASKS")))
		return
	var raw: Dictionary = _cm.get_raw_table("Todolist")
	var reward_title_text: String = _cm.get_lstr("EXERCISE.AWARDS_")
	var fast_btn_text: String = _cm.get_lstr("TASK.HEAD_TO")
	for job_id in jobs:
		var row: Dictionary = raw.get(str(job_id), {})
		var target: int = int(row.get("Task Target", 0))
		var count: int = _tm.get_dailyjob_count(job_id)
		var task: Dictionary = {
			"kind": "dailyjob",
			# initTaskData@1514 type = row["Task Progress Type"]（fast_handler 路由 key）
			"type": str(row.get("Task Progress Type", "")),
			# pid = { row["Task Progress ID"] }（FarmChapter 遍历 v==102/103 选 em/equip）
			"progressid": [row.get("Task Progress ID", 0)],
			"name": _cm.get_lstr(str(row.get("Task Name", str(job_id)))),
			"detail": _cm.get_lstr(str(row.get("Task Detail", ""))),
			"target": target,
			"progress": min(count, target),
			"isFinished": false,
			"icon": str(row.get("Icon", "")),
			"reward": TaskQuery.parse_rewards(row, true),
		}
		_daily_list.add_child(TaskRowBuilder.make_task_row(task, _on_claim_daily.bind(job_id), reward_title_text, fast_btn_text))


# ---- 领奖 / 去往回调 ----
# 领奖公共尾巴（doClickTask :1024-1037 成功 announce 降级 Toast + 失败 TASK 文案）。
func _claim_reward(r: Dictionary, fail_key: String) -> void:
	if bool(r["ok"]):
		Toast.show_message("领取成功")
		GameData.mark_save_dirty()   # local_server:4480 领奖脏标（60s/退出刷）
		_refresh_ui()
	else:
		Toast.show_message(_cm.get_lstr(fail_key))


func _on_claim_main(chain: int, tid: int) -> void:
	_claim_reward(_tm.claim_task_reward(_player, chain, tid, _cm), "TASK.TASK_SUBMISSION_FAILED")


func _on_claim_daily(job_id: int) -> void:
	_claim_reward(_tm.claim_job_reward(_player, job_id, _cm), "TASK.THE_TASK_HAS_NOT_BEEN_COMPLETED")


# createFastButton fast_handler:按 Task Progress Type 跳场景（task.lua:651-738 共 13 type）。
# 已移植 type → main_scene._open_*（照源 pushScene 语义切场景）；
# 未移植 type → Toast 提示（worktree 隔离避免改 main_scene.gd）。
func _on_fast(task: Dictionary) -> void:
	var r: Dictionary = TaskQuery.resolve_fast_target(str(task.get("type", "")))
	if String(r.get("action", "")) == "call":
		var main_scene: Node = get_tree().current_scene
		if main_scene != null and main_scene.has_method(String(r["method"])):
			main_scene.call(String(r["method"]))
			remove_window()  # pushScene 切场景同时关闭当前 popup
			return
	Toast.show_message(String(r.get("msg", "前往任务目标")))


func _refresh_ui() -> void:
	for c in container.get_children():
		c.queue_free()
	_build_content()
