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
# 双模式（2026-09-03 三轮：拆回源两独立弹窗 framework.lua:644 task / :34 dailyTask，
# 2026-08-22 合并双区系受控偏离，用户指示还原）。单列表 %List 按模式 fill。
const KIND_TASK: String = "task"
const KIND_DAILY: String = "dailyTask"
var _kind: String = KIND_TASK
var _list: VBoxContainer = null   # .tscn %List（任务行容器，双模式共用）
var _content: Control = null      # content 引用（空态提示挂 frame 中心用）


func setup_panel(p_player: PlayerData, p_cm: ConfigManager, p_tm: TaskManager,
		p_kind: String = KIND_TASK) -> void:
	_player = p_player
	_cm = p_cm
	_tm = p_tm
	_kind = p_kind
	setup()
	# HUD 隐藏：源 task/dailyTask 均 popup 挂 scene z=101 盖住 statusbar（framework.lua:644/:34，
	# CanvasLayer(150) 恒浮弹窗上致货币栏穿透，2026-09-03 根修）；identity 即 kind。
	hud_identity = p_kind
	if shade_layer != null:
		shade_layer.color.a = SHADE_ALPHA
	_build_content()


# 建 UI 内容：chrome + 单列表 Scroll 静态节点从 .tscn instantiate（位置/size 可视化），
# 任务行 procedural 挂 %List；标题按模式（源 task.lua:832-835 dailyTask→DAILY_ACTIVITIES）。
func _build_content() -> void:
	var content := CONTENT_SCENE.instantiate()
	_content = content
	container.add_child(content)
	_list = content.get_node("%List") as VBoxContainer
	var title_key: String = "TASK.DAILY_ACTIVITIES" if _kind == KIND_DAILY else "TASK.TASK"
	(content.get_node("%Title") as Label).text = _cm.get_lstr(title_key)
	# close 按钮
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	if _kind == KIND_DAILY:
		_fill_daily_list()
	else:
		_fill_main_list()


# 空态提示挂 frame 正中（源 createEmptyPrompt@784-810 readnode 挂 ui.frame，
# ccp(269,189)=frame 显示 546×378 正中 → Godot 全屏 (400,262) 锚点居中，三轮照源）。
func _add_empty_prompt(text: String) -> void:
	var prompt := TaskRowBuilder.make_empty_prompt_with_text(text)
	prompt.anchor_left = 0.5
	prompt.anchor_right = 0.5
	prompt.anchor_top = 262.0 / 480.0
	prompt.anchor_bottom = 262.0 / 480.0
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt.grow_vertical = Control.GROW_DIRECTION_BOTH
	_content.add_child(prompt)


# ed.ui.task:initTaskList + basetask.createTask：遍历 tm.task → Task[chain][id] → 装行。
# 打开/刷新即发现（源 :1343 behindShowHandler → getTaskList classifyTask 发现可接任务并
# 服务器登记；单机合并为 TaskManager.sync_current_tasks 本地一步，2026-09-03 根修任务不显示）；
# 显示序照源 orderList（:1315-1333 可领优先 + chain/id 升序）。
func _fill_main_list() -> void:
	_tm.sync_current_tasks(_player, _cm)
	if _tm.task.is_empty():
		_add_empty_prompt(_cm.get_lstr("TASK.NO_CURRENT_TASK_CAN_BE_ACCESSED"))
		return
	var task_table: Dictionary = _cm.get_raw_table("Task")
	var reward_title_text: String = _cm.get_lstr("EXERCISE.AWARDS_")
	var fast_btn_text: String = _cm.get_lstr("TASK.HEAD_TO")
	var rows: Array = []
	for entry in _tm.task:
		var chain: int = int(entry.get("chain", 0))
		var tid: int = int(entry.get("id", 0))
		var row: Dictionary = task_table.get(str(chain), {}).get(str(tid), {})
		if row.is_empty():
			continue
		var is_finished: bool = str(entry.get("status", "working")) == "finished"
		var task: Dictionary = TaskQuery.build_main_task(chain, tid, row, is_finished, _cm, _player)
		rows.append({"chain": chain, "id": tid, "task": task})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_ready: bool = int(a["task"]["progress"]) >= int(a["task"]["target"])
		var b_ready: bool = int(b["task"]["progress"]) >= int(b["task"]["target"])
		if a_ready != b_ready:
			return a_ready
		if int(a["chain"]) != int(b["chain"]):
			return int(a["chain"]) < int(b["chain"])
		return int(a["id"]) < int(b["id"]))
	for r in rows:
		_list.add_child(TaskRowBuilder.make_task_row(r["task"], _on_claim_main.bind(r["chain"], r["id"]), reward_title_text, fast_btn_text, Callable(), _cm))


# ed.ui.dailyTask:initTaskList + task.lua:1489-1495：只显示当前时段的日常任务
# （checkDailyjobDisplay 时间窗；checkdbTrigger VIP 单机化不接）。
func _fill_daily_list() -> void:
	var jobs: Array[int] = _tm.get_visible_daily_jobs(_cm, _tm.current_now_minutes())
	if jobs.is_empty():
		_add_empty_prompt(_cm.get_lstr("TASK.YOU_HAVE_DONE_TODAYS_TASKS"))
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
		_list.add_child(TaskRowBuilder.make_task_row(task, _on_claim_daily.bind(job_id), reward_title_text, fast_btn_text, _on_fast.bind(task), _cm))


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
