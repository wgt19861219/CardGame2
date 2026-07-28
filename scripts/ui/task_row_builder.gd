class_name TaskRowBuilder
extends RefCounted

## TaskPanel 渲染 helper（task_panel 拆分 2/3，2026-07-24）。
## 从 task_panel.gd 外迁的 procedural 行绘制：make_task_row/add_icon/add_label/
## add_reward_*/add_action_button/make_empty_prompt + 坐标 bg_pos/load_tex/to_godot。
##
## Theme variation 范式（spec Q5 路径1：彻底归零 add_theme override）：
## 8 Task Label variation 在 resources/themes/default_theme.tres（TaskName/Detail/RewardTitle/
## RewardAmt/FastBtn/Empty/ProgressDone/ProgressTodo），set_type_variation(*, "Label") 继承阶段 0
## 基础项。本脚本建 Label 后只设 theme_type_variation = &"XxxLabel"，颜色/字号由 Theme 提供。
## progress 二态（done/todo）运行时切 theme_type_variation（非 override）。

const CONTENT_SCALE: float = 1.28125   # setContentScaleFactor(1.28125)，cocos sprite 显示=纹理/CS（无 fix 时）

# ---- 行资源 ----
const BOARD_RES := "res://assets/ui/alpha/HVGA/task_board.png"
const BOARD_FINISHED_RES := "res://assets/ui/alpha/HVGA/task_board_finished.png"
const ICON_BG_RES := "res://assets/ui/alpha/HVGA/task_icon_bg.png"
const BUTTON_RES := "res://assets/ui/alpha/HVGA/task_button.png"
const BUTTON_PRESS_RES := "res://assets/ui/alpha/HVGA/task_button_press.png"
const COMPLETE_TAG_RES := "res://assets/ui/alpha/HVGA/task_get_reward_button.png"
const REWARD_ICON_RES := {
	"Coin": "res://assets/ui/alpha/HVGA/task_gold_icon_2.png",
	"Diamond": "res://assets/ui/alpha/HVGA/task_rmb_icon_2.png",
	"Vitality": "res://assets/ui/alpha/HVGA/task_vit_icon_2.png",
	"PlayerEXP": "res://assets/ui/alpha/HVGA/excavate/excavate_exp_icon.png",
	"GuildCoin": "res://assets/ui/alpha/HVGA/money_guildtoken_small.png",
}
const TYPE_ICON_RES := {
	"Coin": "res://assets/ui/alpha/HVGA/task_gold_icon.png",
	"Diamond": "res://assets/ui/alpha/HVGA/task_rmb_icon.png",
	"Vitality": "res://assets/ui/alpha/HVGA/task_vit_icon.png",
	"PlayerEXP": "res://assets/ui/alpha/HVGA/excavate/excavate_exp_icon.png",
	"GuildCoin": "res://assets/ui/alpha/HVGA/money_guildtoken_small.png",
}

# ---- bg 尺寸（task_board.png 实测 638×123，行内坐标基准）----
const BG_W: int = 638
const BG_H: int = 123

# ---- 行内坐标（cocos，bg 左下原点 y 向上）----
const C_NAME: Vector2 = Vector2(95.0, 71.0)
const C_PROGRESS: Vector2 = Vector2(450.0, 71.0)
const C_DETAIL: Vector2 = Vector2(95.0, 46.0)
const C_REWARD_TITLE: Vector2 = Vector2(95.0, 20.0)
const C_ICON: Vector2 = Vector2(50.0, 48.0)
const C_ICON_BG: Vector2 = Vector2(50.0, 47.0)
const C_FAST_BTN: Vector2 = Vector2(450.0, 30.0)

const ICON_TARGET: int = 75  # icon scale 75/max
const REWARD_ICON_H: int = 20  # reward icon mh
const FAST_BTN_SIZE: Vector2 = Vector2(60.0, 45.0)  # createFastButton setContentSize
# task.lua:324 doPressInList bg setScale(0.98)：按下缩 0.98，松开回弹 1.0（视觉反馈）。
const ROW_PRESS_SCALE: Vector2 = Vector2(0.98, 0.98)
const ROW_PRESS_SEC: float = 0.1

# createTask 奖励标题 LSTR key（panel 层 fill 调用传入 reward_title 文字）。
const LSTR_REWARD_TITLE: StringName = &"EXERCISE.AWARDS_"
# createFastButton 日常「前往」文案 key。
const LSTR_FAST_BTN: StringName = &"TASK.HEAD_TO"
# createEmptyPrompt:task/dailyjob 两态 LSTR key。
const LSTR_EMPTY_TASK: StringName = &"TASK.NO_CURRENT_TASK_CAN_BE_ACCESSED"
const LSTR_EMPTY_DAILY: StringName = &"TASK.YOU_HAVE_DONE_TODAYS_TASKS"


# cocos(800×480 左下) → Godot(960×640 左上):cx+80, 560-cy（同 hero_detail_builder）。
static func to_godot(cx: float, cy: float) -> Vector2:
	return Vector2(cx + 80.0, 560.0 - cy)


# 坐标转换:cocos bg 左下原点(y 向上)→ Godot 左上原点(y 向下)
static func bg_pos(cocos: Vector2) -> Vector2:
	return Vector2(cocos.x, float(BG_H) - cocos.y)


static func load_tex(res_path: String) -> Texture2D:
	if res_path.is_empty() or not ResourceLoader.exists(res_path):
		return null
	return load(res_path) as Texture2D


# ==================== 行装配 ====================

# 任务行（bg + icon + labels + reward + 按钮）。reward_title_text / fast_btn_text 由 panel
# 层 get_lstr 后传入（保持本 helper 无 cm 依赖；daily_kind_text 用于「前往」按钮可见性）。
# task.kind == "dailyjob" 且未完成 → 显示「前往」按钮；完成态优先显示「完成」领奖按钮。
const KIND_DAILY: String = "dailyjob"


static func make_task_row(task: Dictionary, on_claim: Callable,
		reward_title_text: String = "奖励:", fast_btn_text: String = "前往",
		on_fast: Callable = Callable()) -> Control:
	var target: int = int(task.get("target", 1))
	var progress: int = int(task.get("progress", 0))
	var is_completed: bool = target <= progress
	var is_finished: bool = bool(task.get("isFinished", false))
	var show_complete: bool = is_completed or is_finished
	var kind: String = str(task.get("kind", ""))
	var bg := TextureRect.new()
	bg.texture = load_tex(BOARD_FINISHED_RES if show_complete else BOARD_RES)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.custom_minimum_size = Vector2(float(BG_W), float(BG_H))
	# pivot 居中：源 bg anchor(0.5,0.5) 按中心 setScale → Godot Control scale 绕 pivot_offset。
	bg.pivot_offset = Vector2(float(BG_W), float(BG_H)) * 0.5
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.name = "TaskRow"
	add_icon(bg, task)
	add_label(bg, str(task.get("name", "")), C_NAME, &"TaskNameLabel")
	var progress_text: String = "" if is_completed else "%d/%d" % [progress, target]
	var progress_var: StringName = &"TaskProgressDoneLabel" if is_completed else &"TaskProgressTodoLabel"
	add_label(bg, progress_text, C_PROGRESS, progress_var)
	add_label(bg, str(task.get("detail", "")), C_DETAIL, &"TaskDetailLabel")
	add_label(bg, reward_title_text, C_REWARD_TITLE, &"TaskRewardTitleLabel")
	add_reward_icons(bg, task.get("reward", []))
	# 完成态 → completeTag(领奖)；否则 dailyjob → createFastButton(前往，on_fast 跳场景)
	if show_complete:
		add_action_button(bg, "完成", on_claim, true)
	elif kind == KIND_DAILY:
		add_action_button(bg, fast_btn_text, on_fast, false)
	return bg


# icon:task→Task.Icon / dailyjob→Todolist.Icon / 无→reward[0] type 图;scale 75/max
static func add_icon(bg: TextureRect, task: Dictionary) -> void:
	var icon_bg := TextureRect.new()
	icon_bg.texture = load_tex(ICON_BG_RES)
	icon_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var ibg_size: Vector2 = TexDisplaySize.display_size(ICON_BG_RES) if icon_bg.texture else Vector2(94.0, 101.0) / CONTENT_SCALE
	icon_bg.custom_minimum_size = ibg_size
	icon_bg.position = bg_pos(C_ICON_BG) - ibg_size * 0.5
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
	icon.texture = load_tex(icon_res)
	if icon.texture:
		var tex_size: Vector2 = icon.texture.get_size()
		var s: float = float(ICON_TARGET) / max(tex_size.x, tex_size.y)
		icon.scale = Vector2(s, s)
		icon.position = bg_pos(C_ICON) - tex_size * s * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(icon)


# Label(anchor(0,0.5) 左中,垂直居中在 cocos_y)。variation_name 决定颜色/字号（Theme variation）。
# 字号从 Theme 读：theme.get_font_size(level) 不可行（需同步读 Theme），故 h 估算法保留：
# variation 字号固定（Theme 已设），用 theme_type_variation 查 font_size 兜底为 16（防 0）。
static func add_label(parent: Control, text: String, cocos: Vector2, variation_name: StringName) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.theme_type_variation = variation_name
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs: int = _variation_font_size(variation_name)
	var h: float = float(fs) + 4.0
	lbl.position = bg_pos(cocos) - Vector2(0.0, h * 0.5)
	parent.add_child(lbl)


# variation 字号查找：从 default_theme 读，避免散落常量。Theme 缺失/未注册 → 16 兜底。
static func _variation_font_size(variation_name: StringName) -> int:
	var t: Theme = load("res://resources/themes/default_theme.tres") as Theme
	if t != null and t.has_font_size("font_size", String(variation_name)):
		return int(t.get_font_size("font_size", String(variation_name)))
	return 16


# reward icons 横排:getRightSidePos 累积(reward_title 右侧,i==1 gap0 else gap10)
static func add_reward_icons(bg: TextureRect, rewards: Array) -> void:
	if rewards.is_empty():
		return
	var y_base: float = bg_pos(C_REWARD_TITLE).y
	var rx: float = C_REWARD_TITLE.x + 45.0  # "奖励" 文字右侧起步
	for r in rewards:
		var rtype: String = str(r.get("type", ""))
		var amount: int = int(r.get("amount", 0))
		var res: String = REWARD_ICON_RES.get(rtype, "")
		if res.is_empty() or amount <= 0:
			continue
		rx = add_reward_icon(bg, res, rx, y_base)
		rx = add_reward_amt(bg, amount, rx, y_base)
		rx += 10.0  # gap 10


static func add_reward_icon(bg: TextureRect, res: String, rx: float, y_base: float) -> float:
	var icon := TextureRect.new()
	icon.texture = load_tex(res)
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


static func add_reward_amt(bg: TextureRect, amount: int, rx: float, y_base: float) -> float:
	var amt := Label.new()
	amt.text = "x%d" % amount
	amt.theme_type_variation = &"TaskRewardAmtLabel"
	amt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h: float = float(_variation_font_size(&"TaskRewardAmtLabel")) + 4.0
	amt.position = Vector2(rx, y_base - h * 0.5)
	bg.add_child(amt)
	return rx + 30.0


# completeTag 用 task_get_reward_button.png（assets 缺 → fallback task_button.png+"完成"）;
# createFastButton 用 task_button.png+task_button_press.png Scale9 60×45（assets 有）。
static func add_action_button(bg: TextureRect, label_text: String, on_press: Callable, is_complete: bool) -> void:
	var btn := TextureButton.new()
	# completeTag 优先 task_get_reward_button.png（缺图返 null → fallback BUTTON_RES）
	var normal_tex: Texture2D = load_tex(COMPLETE_TAG_RES if is_complete else BUTTON_RES)
	if normal_tex == null:
		normal_tex = load_tex(BUTTON_RES)
	btn.texture_normal = normal_tex
	btn.texture_pressed = load_tex(BUTTON_PRESS_RES)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	btn.custom_minimum_size = FAST_BTN_SIZE
	btn.position = bg_pos(C_FAST_BTN) - FAST_BTN_SIZE * 0.5
	var lbl := Label.new()
	lbl.text = label_text
	lbl.theme_type_variation = &"TaskFastBtnLabel"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = FAST_BTN_SIZE
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)
	if not on_press.is_null():
		btn.pressed.connect(on_press)
	# task.lua:324 doPressInList bg setScale(0.98)：按钮 down→bg 缩 0.98，up→回弹 1.0。
	# 项目 bg mouse_filter=IGNORE 不接收输入，借子按钮 button_down/up 信号驱动 bg 缩放。
	btn.button_down.connect(_tween_row_scale.bind(bg, ROW_PRESS_SCALE))
	btn.button_up.connect(_tween_row_scale.bind(bg, Vector2.ONE))
	bg.add_child(btn)


# 行 bg 按下/松开 scale Tween（源 task.lua:324 setScale 0.98 视觉反馈）。
# bg 未入树时 create_tween 返回无效 Tween（无 scene tree）；入树后正常。
static func _tween_row_scale(bg: TextureRect, target: Vector2) -> void:
	if not is_instance_valid(bg) or not bg.is_inside_tree():
		return
	var tw: Tween = bg.create_tween()
	tw.tween_property(bg, "scale", target, ROW_PRESS_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# createEmptyPrompt@784-810：task/dailyjob 两态 LSTR key。
# 本 helper 不依赖 cm，故按 kind 给中文兜底文案；panel 可调 make_empty_prompt_with_text
# 传已 get_lstr 的本地化文字覆盖。Theme variation 决定颜色/字号（TaskEmptyLabel）。
static func make_empty_prompt(kind: String = "task") -> Label:
	var fallback_text: String = "今日任务已全部完成" if kind == KIND_DAILY else "暂无可领取的任务"
	return make_empty_prompt_with_text(fallback_text)


# 显式文字版：panel 层 get_lstr 后传入（保留 make_empty_prompt(kind) 兜底入口）。
static func make_empty_prompt_with_text(empty_text: String) -> Label:
	var lbl := Label.new()
	lbl.text = empty_text
	lbl.theme_type_variation = &"TaskEmptyLabel"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl
