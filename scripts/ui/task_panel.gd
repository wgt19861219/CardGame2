class_name TaskPanel
extends PopWindow

## 任务面板(View 层)— 照源 ui/task.lua 完整翻译。
## basetask.createTask@417-598 共用渲染:bg(task_board/finished)+ icon+iconBg + name/progress/
## detail/reward_title 4 Label + reward icons 横排 + completeTag(完成领奖)/fastButton(日常去往)。
## 主线(ed.ui.task,Task 表 tm.task)+ 日常(ed.ui.dailyTask,Todolist)两段列表。

# ---- 资源(源 task.lua icon_res / reward_icon_res + createTask bgRes)----
const BOARD_RES := "res://assets/ui/alpha/HVGA/task_board.png"
const BOARD_FINISHED_RES := "res://assets/ui/alpha/HVGA/task_board_finished.png"
const ICON_BG_RES := "res://assets/ui/alpha/HVGA/task_icon_bg.png"
const BUTTON_RES := "res://assets/ui/alpha/HVGA/task_button.png"
const BUTTON_PRESS_RES := "res://assets/ui/alpha/HVGA/task_button_press.png"
# 源 reward_icon_res:task_gold_icon_2 等(task_exp_icon_2 缺 → excavate_exp_icon 降级)
const REWARD_ICON_RES := {
	"Coin": "res://assets/ui/alpha/HVGA/task_gold_icon_2.png",
	"Diamond": "res://assets/ui/alpha/HVGA/task_rmb_icon_2.png",
	"Vitality": "res://assets/ui/alpha/HVGA/task_vit_icon_2.png",
	"PlayerEXP": "res://assets/ui/alpha/HVGA/excavate/excavate_exp_icon.png",
	"GuildCoin": "res://assets/ui/alpha/HVGA/money_guildtoken_small.png",
}
# 源 icon_res:无任务 Icon 时按 reward[0].type 取单图标
const TYPE_ICON_RES := {
	"Coin": "res://assets/ui/alpha/HVGA/task_gold_icon.png",
	"Diamond": "res://assets/ui/alpha/HVGA/task_rmb_icon.png",
	"Vitality": "res://assets/ui/alpha/HVGA/task_vit_icon.png",
	"PlayerEXP": "res://assets/ui/alpha/HVGA/excavate/excavate_exp_icon.png",
	"GuildCoin": "res://assets/ui/alpha/HVGA/money_guildtoken_small.png",
}

# ---- bg 尺寸(task_board.png 实测 638×123,源 createTask bg 坐标基准)----
const BG_W: int = 638
const BG_H: int = 123

# ---- 源 createTask 坐标(cocos,bg 左下原点 y 向上,:444-509/544/584)----
const C_NAME: Vector2 = Vector2(95.0, 71.0)
const C_PROGRESS: Vector2 = Vector2(450.0, 71.0)
const C_DETAIL: Vector2 = Vector2(95.0, 46.0)
const C_REWARD_TITLE: Vector2 = Vector2(95.0, 20.0)
const C_ICON: Vector2 = Vector2(50.0, 48.0)
const C_ICON_BG: Vector2 = Vector2(50.0, 47.0)
const C_FAST_BTN: Vector2 = Vector2(450.0, 30.0)

# ---- 颜色(源 ccc3,0-255 → /255)----
const COLOR_NAME: Color = Color(66.0 / 255.0, 45.0 / 255.0, 28.0 / 255.0)
const COLOR_DETAIL: Color = Color(0.0, 0.0, 0.0)
const COLOR_REWARD_TITLE: Color = Color(155.0 / 255.0, 34.0 / 255.0, 14.0 / 255.0)
const COLOR_REWARD_AMT: Color = Color(155.0 / 255.0, 41.0 / 255.0, 14.0 / 255.0)
const COLOR_PROGRESS_DONE: Color = Color(70.0 / 255.0, 114.0 / 255.0, 0.0)
const COLOR_PROGRESS_TODO: Color = Color(138.0 / 255.0, 56.0 / 255.0, 1.0 / 255.0)
const COLOR_EMPTY: Color = Color(238.0 / 255.0, 204.0 / 255.0, 119.0 / 255.0)

# ---- 字号(源 createTask Label size)----
const FONT_NAME: int = 20
const FONT_PROGRESS: int = 18
const FONT_DETAIL: int = 16
const FONT_REWARD_TITLE: int = 20
const FONT_FAST: int = 18
const ICON_TARGET: int = 75  # 源 :524 icon scale 75/max
const REWARD_ICON_H: int = 20  # 源 :564 reward icon mh
const FAST_BTN_SIZE: Vector2 = Vector2(60.0, 45.0)  # 源 :757 createFastButton setContentSize
const ROW_SEP: int = 8

const CLOSE_POS: Vector2 = Vector2(880.0, 20.0)
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png"
const TITLE_MAIN_POS: Vector2 = Vector2(141.0, 20.0)
const SCROLL_MAIN_POS: Vector2 = Vector2(141.0, 50.0)
const SCROLL_MAIN_SIZE: Vector2 = Vector2(638.0, 140.0)
const TITLE_DAILY_POS: Vector2 = Vector2(141.0, 200.0)
const SCROLL_DAILY_POS: Vector2 = Vector2(141.0, 230.0)
const SCROLL_DAILY_SIZE: Vector2 = Vector2(638.0, 360.0)

var _player: PlayerData
var _cm: ConfigManager
var _tm: TaskManager


func setup_panel(p_player: PlayerData, p_cm: ConfigManager, p_tm: TaskManager) -> void:
	_player = p_player
	_cm = p_cm
	_tm = p_tm
	setup()
	_build_ui()


func _build_ui() -> void:
	var close: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, CLOSE_POS)
	close.pressed.connect(remove_window)
	container.add_child(close)
	# 主线任务链(源 ed.ui.task:initTaskList@1038 读 tm.task → Task 表)
	_build_list_section(true)
	# 日常任务(源 ed.ui.dailyTask:initTaskList@1542 读 Todolist + player._dailyjob)
	_build_list_section(false)


func _build_list_section(is_main: bool) -> void:
	var title := Label.new()
	title.text = "主线任务" if is_main else "日常任务"
	title.position = TITLE_MAIN_POS if is_main else TITLE_DAILY_POS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(title)
	var sc := ScrollContainer.new()
	sc.position = SCROLL_MAIN_POS if is_main else SCROLL_DAILY_POS
	sc.size = SCROLL_MAIN_SIZE if is_main else SCROLL_DAILY_SIZE
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	container.add_child(sc)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", ROW_SEP)
	sc.add_child(vbox)
	if is_main:
		_fill_main(vbox)
	else:
		_fill_daily(vbox)


# 源 ed.ui.task:initTaskList + basetask.createTask:遍历 tm.task → Task[chain][id] → createTask
func _fill_main(vbox: VBoxContainer) -> void:
	if _tm.task.is_empty():
		vbox.add_child(_make_empty_prompt("task"))
		return
	var task_table: Dictionary = _cm.get_raw_table("Task")
	for entry in _tm.task:
		var chain: int = int(entry.get("chain", 0))
		var tid: int = int(entry.get("id", 0))
		var row: Dictionary = task_table.get(str(chain), {}).get(str(tid), {})
		if row.is_empty():
			continue
		var is_finished: bool = str(entry.get("status", "working")) == "finished"
		var task: Dictionary = _build_main_task(chain, tid, row, is_finished)
		vbox.add_child(_make_task_row(task, _on_claim_main.bind(chain, tid)))


func _build_main_task(chain: int, tid: int, row: Dictionary, is_finished: bool) -> Dictionary:
	var target: int = int(row.get("Task Target", 1))
	var progress: int = _get_main_progress(row)
	return {
		"kind": "task",
		"name": _cm.get_lstr(str(row.get("Task Name", str(chain)))),
		"detail": _cm.get_lstr(str(row.get("Task Detail", ""))),
		"target": target,
		"progress": min(progress, target),
		"isFinished": is_finished,
		"icon": str(row.get("Icon", "")),
		"reward": _parse_rewards(row, false),
	}


# 源 getProgress@1064 + getCount:查 Task Progress Type/ID + player record。
# 单机化行为点未全接(无 server 推送 progress),降级 0;完成态靠 status=="finished"(领奖后)。Logic 待接 record。
func _get_main_progress(row: Dictionary) -> int:
	return 0


# 源 ed.ui.dailyTask:initTaskList@1542:遍历 Todolist + getDailyjobCount
func _fill_daily(vbox: VBoxContainer) -> void:
	var raw: Dictionary = _cm.get_raw_table("Todolist")
	if raw.is_empty():
		vbox.add_child(_make_empty_prompt("dailyjob"))
		return
	for job_str in raw:
		var job_id: int = int(job_str)
		var row: Dictionary = raw[job_str]
		var target: int = int(row.get("Task Target", 0))
		var count: int = _tm.get_dailyjob_count(job_id)
		var task: Dictionary = {
			"kind": "dailyjob",
			"name": _cm.get_lstr(str(row.get("Task Name", str(job_id)))),
			"detail": _cm.get_lstr(str(row.get("Task Detail", ""))),
			"target": target,
			"progress": min(count, target),
			"isFinished": false,
			"icon": str(row.get("Icon", "")),
			"reward": _parse_rewards(row, true),
		}
		vbox.add_child(_make_task_row(task, _on_claim_daily.bind(job_id)))


# 源 createTask reward:主线单槽(Task Reward Type/ID/Amount)/ 日常双槽(:1525 for 1..2)
func _parse_rewards(row: Dictionary, is_daily: bool) -> Array:
	var rewards: Array = []
	if is_daily:
		for i in range(1, 3):
			var rtype: String = str(row.get("Task Reward %d Type" % i, ""))
			if rtype == "":
				continue
			rewards.append({
				"type": rtype,
				"id": int(row.get("Task Reward %d ID" % i, 0)),
				"amount": int(row.get("Task Reward %d Amount" % i, 0)),
			})
	else:
		var rtype: String = str(row.get("Task Reward Type", ""))
		if rtype != "":
			rewards.append({
				"type": rtype,
				"id": int(row.get("Task Reward ID", 0)),
				"amount": int(row.get("Task Reward Amount", 0)),
			})
	return rewards


# ---- 源 basetask.createTask@417-598 完整翻译 ----
func _make_task_row(task: Dictionary, on_claim: Callable) -> Control:
	var target: int = int(task.get("target", 1))
	var progress: int = int(task.get("progress", 0))
	var is_completed: bool = target <= progress
	var is_finished: bool = bool(task.get("isFinished", false))
	var show_complete: bool = is_completed or is_finished
	var kind: String = str(task.get("kind", ""))
	var bg := TextureRect.new()
	bg.texture = _load_tex(BOARD_FINISHED_RES if show_complete else BOARD_RES)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.custom_minimum_size = Vector2(float(BG_W), float(BG_H))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.name = "TaskRow"
	_add_icon(bg, task)  # 源 :512-549 icon+iconBg
	_add_label(bg, str(task.get("name", "")), C_NAME, FONT_NAME, COLOR_NAME)  # 源 :446
	var progress_text: String = "" if is_completed else "%d/%d" % [progress, target]
	_add_label(bg, progress_text, C_PROGRESS, FONT_PROGRESS, COLOR_PROGRESS_DONE if is_completed else COLOR_PROGRESS_TODO)  # 源 :466
	_add_label(bg, str(task.get("detail", "")), C_DETAIL, FONT_DETAIL, COLOR_DETAIL)  # 源 :479
	_add_label(bg, "奖励", C_REWARD_TITLE, FONT_REWARD_TITLE, COLOR_REWARD_TITLE)  # 源 :494 EXERCISE.AWARDS_
	_add_reward_icons(bg, task.get("reward", []))  # 源 :556-581
	# 源 :582-591:isCompleted → completeTag;elif dailyjob → createFastButton
	if show_complete:
		_add_action_button(bg, "完成", on_claim)  # completeTag(领奖)
	elif kind == "dailyjob":
		_add_action_button(bg, "前往", _on_fast.bind())  # createFastButton(去往)
	return bg


# 源 createTask icon:task→Task.Icon / dailyjob→Todolist.Icon / 无→reward[0] type 图;scale 75/max(:524)
func _add_icon(bg: TextureRect, task: Dictionary) -> void:
	var icon_bg := TextureRect.new()
	icon_bg.texture = _load_tex(ICON_BG_RES)
	icon_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var ibg_size: Vector2 = icon_bg.texture.get_size() if icon_bg.texture else Vector2(94.0, 101.0)
	icon_bg.custom_minimum_size = ibg_size
	icon_bg.position = _bg_pos(C_ICON_BG) - ibg_size * 0.5
	icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(icon_bg)
	var icon_res: String = str(task.get("icon", ""))
	if icon_res.is_empty():
		var rewards_v: Variant = task.get("reward", [])
		if rewards_v is Array and (rewards_v as Array).size() > 0:
			var first: Dictionary = (rewards_v as Array)[0]
			icon_res = TYPE_ICON_RES.get(str(first.get("type", "")), "")
	if icon_res.is_empty():
		return
	var icon := TextureRect.new()
	icon.texture = _load_tex(icon_res)
	if icon.texture:
		var tex_size: Vector2 = icon.texture.get_size()
		var s: float = float(ICON_TARGET) / max(tex_size.x, tex_size.y)
		icon.scale = Vector2(s, s)
		icon.position = _bg_pos(C_ICON) - tex_size * s * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(icon)


# 源 :444-509 Label(anchor(0,0.5) 左中,垂直居中在 cocos_y)
func _add_label(parent: Control, text: String, cocos: Vector2, font_size: int, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h: float = float(font_size) + 4.0
	lbl.position = _bg_pos(cocos) - Vector2(0.0, h * 0.5)
	parent.add_child(lbl)


# 源 :556-581 reward icons 横排:getRightSidePos 累积(reward_title 右侧,i==1 gap0 else gap10)
func _add_reward_icons(bg: TextureRect, rewards: Array) -> void:
	if rewards.is_empty():
		return
	var y_base: float = _bg_pos(C_REWARD_TITLE).y
	var rx: float = C_REWARD_TITLE.x + 45.0  # "奖励" 文字右侧起步
	for r in rewards:
		var rtype: String = str(r.get("type", ""))
		var amount: int = int(r.get("amount", 0))
		var res: String = REWARD_ICON_RES.get(rtype, "")
		if res.is_empty() or amount <= 0:
			continue
		rx = _add_reward_icon(bg, res, rx, y_base)
		rx = _add_reward_amt(bg, amount, rx, y_base)
		rx += 10.0  # 源 :571 gap 10


func _add_reward_icon(bg: TextureRect, res: String, rx: float, y_base: float) -> float:
	var icon := TextureRect.new()
	icon.texture = _load_tex(res)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var adv: float = rx
	if icon.texture:
		var s: float = float(REWARD_ICON_H) / icon.texture.get_height()
		icon.scale = Vector2(s, s)
		var tex_size: Vector2 = icon.texture.get_size() * s
		icon.position = Vector2(rx, y_base - tex_size.y * 0.5)
		adv = rx + tex_size.x + 4.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(icon)
	return adv


func _add_reward_amt(bg: TextureRect, amount: int, rx: float, y_base: float) -> float:
	var amt := Label.new()
	amt.text = "x%d" % amount
	amt.add_theme_font_size_override("font_size", FONT_PROGRESS)
	amt.add_theme_color_override("font_color", COLOR_REWARD_AMT)
	amt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h: float = float(FONT_PROGRESS) + 4.0
	amt.position = Vector2(rx, y_base - h * 0.5)
	bg.add_child(amt)
	return rx + 30.0


# 源 :583 completeTag(task_get_reward_button 缺→ task_button "完成"降级)/ :755 createFastButton "前往"
func _add_action_button(bg: TextureRect, label_text: String, on_press: Callable) -> void:
	var btn := TextureButton.new()
	btn.texture_normal = _load_tex(BUTTON_RES)
	btn.texture_pressed = _load_tex(BUTTON_PRESS_RES)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	btn.custom_minimum_size = FAST_BTN_SIZE
	btn.position = _bg_pos(C_FAST_BTN) - FAST_BTN_SIZE * 0.5
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", FONT_FAST)
	lbl.add_theme_color_override("font_color", COLOR_REWARD_TITLE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = FAST_BTN_SIZE
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)
	if not on_press.is_null():
		btn.pressed.connect(on_press)
	bg.add_child(btn)


# 源 createEmptyPrompt@784:"暂无可领取任务"(task)/ "今日任务已完成"(dailyjob)
func _make_empty_prompt(kind: String) -> Label:
	var lbl := Label.new()
	lbl.text = "暂无可领取任务" if kind == "task" else "今日任务已完成"
	lbl.add_theme_font_size_override("font_size", FONT_NAME)
	lbl.add_theme_color_override("font_color", COLOR_EMPTY)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


# 坐标转换:cocos bg 左下原点(y 向上)→ Godot 左上原点(y 向下)
static func _bg_pos(cocos: Vector2) -> Vector2:
	return Vector2(cocos.x, float(BG_H) - cocos.y)


func _load_tex(res_path: String) -> Texture2D:
	if res_path.is_empty() or not ResourceLoader.exists(res_path):
		return null
	return load(res_path) as Texture2D


# ---- 领奖 / 去往回调 ----
func _on_claim_main(chain: int, tid: int) -> void:
	var r: Dictionary = _tm.claim_task_reward(_player, chain, tid, _cm)
	Toast.show_message("领取成功" if bool(r["ok"]) else "领取失败")
	if bool(r["ok"]):
		_refresh_ui()


func _on_claim_daily(job_id: int) -> void:
	var r: Dictionary = _tm.claim_job_reward(_player, job_id, _cm)
	Toast.show_message("领取成功" if bool(r["ok"]) else "未达成")
	if bool(r["ok"]):
		_refresh_ui()


# 源 createFastButton fast_handler:按 Task Progress Type 跳场景(stageselect/ladder/heropackage/midas/tavern)。
# 单机化场景跳转未全接,降级 Toast(Logic 待接场景路由)。
func _on_fast() -> void:
	Toast.show_message("前往任务目标")


func _refresh_ui() -> void:
	for c in container.get_children():
		c.queue_free()
	_build_ui()
