class_name TaskPanel
extends PopWindow

## 任务面板(View 层)— 照源 ui/task.lua 完整翻译。
## basetask.createTask@417-598 共用渲染:bg(task_board/finished)+ icon+iconBg + name/progress/
## detail/reward_title 4 Label + reward icons 横排 + completeTag(完成领奖)/fastButton(日常去往)。
## 主线(ed.ui.task,Task 表 tm.task)+ 日常(ed.ui.dailyTask,Todolist)两段列表。
##
## 重构（2026-07-17，hero_detail 范式）：chrome(frame/title_bg/title/close)+ 段标题+ ScrollContainer
## 全静态化进 scenes/ui/task_content.tscn（位置/size 编辑器可视化调）；任务行（bg+icon+labels+reward+
## 按钮）数量随任务变，保留 procedural 挂 %MainList/%DailyList（行内坐标走 _bg_pos 局部）。
## 源 basetask.create@837-904 chrome 坐标(frame ccp(400,218)/title_bg ccp(400,399)/close ccp(675,382))
## 经 _to_godot(cx,cy)=(cx+80,560-cy) 转 + 纹理尺寸/CS=1.28125 算 size，固化进 .tscn offset。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/task_content.tscn")

const CONTENT_SCALE: float = 1.28125   # 源 hello.lua:311 setContentScaleFactor(1.28125)，cocos sprite 显示=纹理/CS（无 fix 时）
# ---- 行资源(源 task.lua icon_res / reward_icon_res + createTask bgRes)----
const BOARD_RES := "res://assets/ui/alpha/HVGA/task_board.png"
const BOARD_FINISHED_RES := "res://assets/ui/alpha/HVGA/task_board_finished.png"
const ICON_BG_RES := "res://assets/ui/alpha/HVGA/task_icon_bg.png"
const BUTTON_RES := "res://assets/ui/alpha/HVGA/task_button.png"
const BUTTON_PRESS_RES := "res://assets/ui/alpha/HVGA/task_button_press.png"
# 源 :583 completeTag 用 task_get_reward_button.png（assets 缺 → 降级 task_button.png+"完成"文字）
const COMPLETE_TAG_RES := "res://assets/ui/alpha/HVGA/task_get_reward_button.png"
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

# ---- 源 createTask 行内坐标(cocos,bg 左下原点 y 向上,:444-509/544/584)----
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

# 源 task.lua basetask.create @826 mainLayer=CCLayerColor:create(ccc4(0,0,0,200)) 半透明黑遮罩；
# framework.lua:644 addChild 到当前场景（popup，非 pushScene），透 main 地图，无全屏 bg.jpg。
# PopWindow 默认 shade alpha=150/255（popwindow.lua），此处覆盖为源的 200/255。
const SHADE_ALPHA: float = 200.0 / 255.0

# ---- 源 createFastButton fast_handler（task.lua:651-738）13 个 task.type→场景路由表 ----
# 已移植 type → main_scene 现有 _open_* 方法（GDScript 不强制 _ private，照 get_tree().current_scene 路由）。
const FAST_ROUTE := {
	"FarmPVEStage": "_open_stage_select",           # 源 :652 stageselect.create()
	"FarmElitePVEStage": "_open_stage_select",      # 源 :656 stageselect.create(nil,"elite")
	"FarmChapter": "_open_exercise_panel",          # 源 :660 exercise("em"/"equip")（progressid 102/103）
	"PVPBattle": "_open_ladder",                    # 源 :671 ladder
	"PVPWin": "_open_ladder",                       # 源 :677 ladder
	"SkillUpgradeSuccess": "_open_hero",            # 源 :683 heropackage
	"MidasUse": "_open_midas",                      # 源 :691 midas popup
	"TavernGroupUse": "_open_tavern",               # 源 :701 tavern
	"CompleteCrusadeStage": "_open_crusade",        # 源 :709 tbc/crusade
}
# 未移植 type → Toast 降级（源 handler 目标场景未实现：装备强化需选英雄 / 月卡充值联机 / 公会联机）。
const FAST_UNSUPPORTED := {
	"EnhanceLevelUp": "「装备强化」请从英雄详情进入（需选择英雄）",  # 源 :687 equipstrengthen
	"MonthlyCardPeriod": "月卡充值入口未开放",                      # 源 :705 newrecharge
	"SendMercenary": "公会功能未开放",                              # 源 :719 guild
	"EnterRaid": "公会功能未开放",                                  # 源 :729 guild
}

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
# 任务行 procedural 挂 %MainList/%DailyList。源 basetask.create + createListLayer。
func _build_content() -> void:
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	_main_list = content.get_node("%MainList") as VBoxContainer
	_daily_list = content.get_node("%DailyList") as VBoxContainer
	# fill 静态 Label LSTR（chrome title + 段标题）
	(content.get_node("%Title") as Label).text = _cm.get_lstr("TASK.TASK")
	(content.get_node("%MainTitleLabel") as Label).text = _cm.get_lstr("TASK.TASK")
	(content.get_node("%DailyTitleLabel") as Label).text = _cm.get_lstr("TASK.DAILY_ACTIVITIES")
	# close 按钮（源 :880-903 close z=30）
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	_fill_main_list()
	_fill_daily_list()


# 源 cocos(800×480 左下) → Godot(960×640 左上):cx+80, 560-cy（同 hero_detail_builder/handbook_builder）。
static func _to_godot(cx: float, cy: float) -> Vector2:
	return Vector2(cx + 80.0, 560.0 - cy)


# 源 ed.ui.task:initTaskList + basetask.createTask:遍历 tm.task → Task[chain][id] → createTask
func _fill_main_list() -> void:
	if _tm.task.is_empty():
		_main_list.add_child(_make_empty_prompt("task"))
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
		_main_list.add_child(_make_task_row(task, _on_claim_main.bind(chain, tid)))


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


# 源 task.lua:1064-1080 getProgress + :150-215 getCount：查 Task[chain][id] Task Progress Type/ID，
# 按类型实时查 player 状态（源非事件累计——CompleteStage/PlayerLevel/HeroRank/MultiHeroRank 全实时查询；
# 仅 FarmStage/KillMonster 用 getTaskCount record，TaskManager 未接 → 降级返 0）。
# Task 表 5 type 分布（实测 task.json）：CompleteStage 144 / MultiHeroRank 38 / FarmStage 25 /
# PlayerLevel 24 / HeroRank 2 → 4/5 type 实时查覆盖 89% 主任务。
func _get_main_progress(row: Dictionary) -> int:
	var ptype: String = String(row.get("Task Progress Type", ""))
	var pids: Array = _pid_values(row.get("Task Progress ID", {}))
	var target: int = int(row.get("Task Target", 1))
	return _get_count(ptype, pids, target, _player)


# 源 getCount@150-215 翻译：按 Task Progress Type 查 player 实时状态。
# pid 字段：源 lua table {v1, v2}（v==0 跳过），项目 JSON Dictionary {"1":v1,"2":v2}（_pid_values 转 Array）。
# 照源完整翻译 9 type（Task 表实测用 5 个，余 4 个 ItemQuantity/HeroLevel/MultiHeroLevel/KillMonster
# 为源完整性保留，便于后续扩展或 mod）。
func _get_count(ptype: String, pids: Array, target: int, player: PlayerData) -> int:
	match ptype:
		# 源 :159-164：pid 中任一关卡通关（stars>0）→ 返 target（视为完成）
		"CompleteStage":
			for v in pids:
				if int(v) != 0 and player.stage_manager.stage_stars(int(v)) > 0:
					return target
			return 0
		# 源 :173-174：当前战队等级
		"PlayerLevel":
			return player.team_level
		# 源 :181-186：英雄 tid 的 rank（品质阶）
		"HeroRank":
			for v in pids:
				if int(v) != 0:
					var h: HeroInstance = player.hero_manager.find_hero_by_tid(int(v))
					if h != null:
						return h.rank
			return 0
		# 源 :187-198：rank>=v 的英雄数量
		"MultiHeroRank":
			for v in pids:
				if int(v) != 0:
					return _count_heroes_by_rank(player, int(v))
			return 0
		# 源 :199-210：level>v 的英雄数量
		"MultiHeroLevel":
			for v in pids:
				if int(v) != 0:
					return _count_heroes_by_level(player, int(v))
			return 0
		# 源 :175-180：英雄 tid 的 level
		"HeroLevel":
			for v in pids:
				if int(v) != 0:
					var h: HeroInstance = player.hero_manager.find_hero_by_tid(int(v))
					if h != null:
						return h.level
			return 0
		# 源 :167-172：物品持有量（源 equip_qunty[v]，项目 items dict）
		"ItemQuantity":
			for v in pids:
				if int(v) != 0:
					return int(player.items.get(int(v), 0))
			return 0
		# 源 :165/212 getTaskCount(chain,id) 需 record 计数（未接）→ 降级 0
		"KillMonster", "FarmStage":
			return 0
		_:
			return 0


# 源 :189-197 / :200-209 遍历 ed.player.heroes 统计满足条件的英雄数。
static func _count_heroes_by_rank(player: PlayerData, rank_min: int) -> int:
	var count: int = 0
	for inst_id in player.hero_manager.heroes:
		var h: HeroInstance = player.hero_manager.heroes[inst_id]
		if h.rank >= rank_min:
			count += 1
	return count


static func _count_heroes_by_level(player: PlayerData, level_min: int) -> int:
	var count: int = 0
	for inst_id in player.hero_manager.heroes:
		var h: HeroInstance = player.hero_manager.heroes[inst_id]
		if h.level > level_min:
			count += 1
	return count


# pid 字段：源 lua table {v1, v2} → JSON Dictionary {"1":v1,"2":v2}（取 values）；兼容裸 Array/单值。
static func _pid_values(pid_raw: Variant) -> Array:
	if pid_raw is Dictionary:
		return (pid_raw as Dictionary).values()
	if pid_raw is Array:
		return pid_raw
	return []


# 源 ed.ui.dailyTask:initTaskList@1542 + task.lua:1489-1495：只显示当前时段的日常任务（checkDailyjobDisplay 时间窗；checkdbTrigger VIP 单机化不接）。
func _fill_daily_list() -> void:
	var jobs: Array[int] = _tm.get_visible_daily_jobs(_cm, _tm.current_now_minutes())
	if jobs.is_empty():
		_daily_list.add_child(_make_empty_prompt("dailyjob"))
		return
	var raw: Dictionary = _cm.get_raw_table("Todolist")
	for job_id in jobs:
		var row: Dictionary = raw.get(str(job_id), {})
		var target: int = int(row.get("Task Target", 0))
		var count: int = _tm.get_dailyjob_count(job_id)
		var task: Dictionary = {
			"kind": "dailyjob",
			# 源 initTaskData@1514 type = row["Task Progress Type"]（fast_handler 路由 key）
			"type": str(row.get("Task Progress Type", "")),
			# 源 :1502-1504 pid = { row["Task Progress ID"] }（FarmChapter :660 遍历 v==102/103 选 em/equip）
			"progressid": [row.get("Task Progress ID", 0)],
			"name": _cm.get_lstr(str(row.get("Task Name", str(job_id)))),
			"detail": _cm.get_lstr(str(row.get("Task Detail", ""))),
			"target": target,
			"progress": min(count, target),
			"isFinished": false,
			"icon": str(row.get("Icon", "")),
			"reward": _parse_rewards(row, true),
		}
		_daily_list.add_child(_make_task_row(task, _on_claim_daily.bind(job_id)))


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


# ---- 源 basetask.createTask@417-598 完整翻译（行内 procedural 挂 vbox）----
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
	_add_label(bg, _cm.get_lstr("EXERCISE.AWARDS_"), C_REWARD_TITLE, FONT_REWARD_TITLE, COLOR_REWARD_TITLE)  # 源 :494 奖励：
	_add_reward_icons(bg, task.get("reward", []))  # 源 :556-581
	# 源 :582-591:isCompleted → completeTag;elif dailyjob → createFastButton
	if show_complete:
		# 源 :583 completeTag 是 task_get_reward_button.png 图（assets 缺 → 降级 task_button.png+"完成"文字）
		_add_action_button(bg, "完成", on_claim, true)  # completeTag(领奖)
	elif kind == "dailyjob":
		_add_action_button(bg, _cm.get_lstr("TASK.HEAD_TO"), _on_fast.bind(task), false)  # 源 :763 前往
	return bg


# 源 createTask icon:task→Task.Icon / dailyjob→Todolist.Icon / 无→reward[0] type 图;scale 75/max(:524)
func _add_icon(bg: TextureRect, task: Dictionary) -> void:
	var icon_bg := TextureRect.new()
	icon_bg.texture = _load_tex(ICON_BG_RES)
	icon_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var ibg_size: Vector2 = TexDisplaySize.display_size(ICON_BG_RES) if icon_bg.texture else Vector2(94.0, 101.0) / CONTENT_SCALE   # 源 task.lua:526/537/541 iconBg createSprite 无 fix
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


# 源 :583 completeTag 用 task_get_reward_button.png（assets 缺 → 降级 task_button.png+"完成"文字）；
# 源 :755-757 createFastButton 用 task_button.png+task_button_press.png Scale9 60×45（assets 有，正确）。
func _add_action_button(bg: TextureRect, label_text: String, on_press: Callable, is_complete: bool) -> void:
	var btn := TextureButton.new()
	# completeTag 优先 task_get_reward_button.png（缺图返 null → fallback BUTTON_RES）
	var normal_tex: Texture2D = _load_tex(COMPLETE_TAG_RES if is_complete else BUTTON_RES)
	if normal_tex == null:
		normal_tex = _load_tex(BUTTON_RES)
	btn.texture_normal = normal_tex
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


# 源 createEmptyPrompt@784-810：task→TASK.NO_CURRENT_TASK_CAN_BE_ACCESSED；dailyjob→TASK.YOU_HAVE_DONE_TODAYS_TASKS
func _make_empty_prompt(kind: String) -> Label:
	var lbl := Label.new()
	lbl.text = _cm.get_lstr("TASK.NO_CURRENT_TASK_CAN_BE_ACCESSED") if kind == "task" else _cm.get_lstr("TASK.YOU_HAVE_DONE_TODAYS_TASKS")
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
# 领奖公共尾巴（源 doClickTask :1024-1037 成功 announce 降级 Toast + 失败 TASK 文案）。
func _claim_reward(r: Dictionary, fail_key: String) -> void:
	if bool(r["ok"]):
		Toast.show_message("领取成功")
		GameData.mark_save_dirty()   # 照源 local_server:4480 领奖脏标（60s/退出刷）
		_refresh_ui()
	else:
		Toast.show_message(_cm.get_lstr(fail_key))


func _on_claim_main(chain: int, tid: int) -> void:
	_claim_reward(_tm.claim_task_reward(_player, chain, tid, _cm), "TASK.TASK_SUBMISSION_FAILED")


func _on_claim_daily(job_id: int) -> void:
	_claim_reward(_tm.claim_job_reward(_player, job_id, _cm), "TASK.THE_TASK_HAS_NOT_BEEN_COMPLETED")


# 源 createFastButton fast_handler:按 Task Progress Type 跳场景(task.lua:651-738 共 13 type)。
# 已移植 type → main_scene._open_*（GDScript 不强制 _ private，照源 pushScene 语义切场景）；
# 未移植 type → Toast 提示（worktree 隔离避免改 main_scene.gd）。
func _on_fast(task: Dictionary) -> void:
	var r: Dictionary = resolve_fast_target(str(task.get("type", "")))
	if String(r.get("action", "")) == "call":
		var main_scene: Node = get_tree().current_scene
		if main_scene != null and main_scene.has_method(String(r["method"])):
			main_scene.call(String(r["method"]))
			remove_window()  # 源 pushScene 切场景同时关闭当前 popup
			return
	Toast.show_message(String(r.get("msg", "前往任务目标")))


# 路由分派（纯查询，便于单测）：返回 {"action":"call","method":...} 或 {"action":"toast","msg":...}。
# 13 type 照源 fast_handler 映射：9 已移植 / 4 未移植；未知 type → Toast 默认文案。
static func resolve_fast_target(ttype: String) -> Dictionary:
	var method: String = FAST_ROUTE.get(ttype, "")
	if not method.is_empty():
		return {"action": "call", "method": method}
	return {"action": "toast", "msg": FAST_UNSUPPORTED.get(ttype, "前往任务目标")}


func _refresh_ui() -> void:
	for c in container.get_children():
		c.queue_free()
	_build_content()
