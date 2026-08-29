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

const ReadequipIcon = preload("res://scripts/ui/readequip_icon.gd")

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

# ---- bg 尺寸：task_board.png 纹理 638×123px，源 createSprite 显示 = 纹理÷CS = 498.0×96.0 点
# （[[content-scale-factor]] 口径；旧值 638/123 为纹理 px 直用，行偏大 1.28× 致行背景超滚动区，
#  2026-08-22 溢出修复清查修正；BG_H 同时是行内 y 换算基准，见 bg_pos）。----
const BG_W: float = 638.0 / CONTENT_SCALE
const BG_H: float = 123.0 / CONTENT_SCALE

# ---- 行内坐标（cocos，bg 左下原点 y 向上）----
const C_NAME: Vector2 = Vector2(95.0, 71.0)
const C_PROGRESS: Vector2 = Vector2(450.0, 71.0)   # readNode 无 anchor 声明=默认(0.5,0.5) 中心锚（task.lua ui_info）
const C_DETAIL: Vector2 = Vector2(95.0, 46.0)
const C_REWARD_TITLE: Vector2 = Vector2(95.0, 20.0)
const C_ICON: Vector2 = Vector2(50.0, 48.0)
const C_ICON_BG: Vector2 = Vector2(50.0, 47.0)
const C_FAST_BTN: Vector2 = Vector2(450.0, 30.0)
# task.lua:583-585 completeTag 中心锚 ccp(420,45)，createSprite 原尺寸（126×89px÷CS）。
const C_COMPLETE: Vector2 = Vector2(420.0, 45.0)
const COMPLETE_TAG_SIZE: Vector2 = Vector2(126.0, 89.0) / CONTENT_SCALE
# task.lua:555-563 name/detail 超宽 setScale 压缩阈值（anchor 左中不变）。
const NAME_MAX_W: float = 300.0
const DETAIL_MAX_W: float = 280.0
# reward 小图标 Item 走 readequip.createIcon(id, mh=20)：72 点产物整体缩到高 20。
const REWARD_ITEM_ICON_H: float = 20.0

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


# cocos(800×480 左下) → Godot(800×480 左上): (cx, 480-cy)（同 hero_detail_fills）。
static func to_godot(cx: float, cy: float) -> Vector2:
	return Vector2(cx, 480.0 - cy)


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
# task.kind == "dailyjob" 且未完成 → 显示「前往」按钮；完成态优先显示 completeTag 领奖按钮。
# p_cm 供 Item 类奖励走 ReadequipIcon（源 readequip.createIcon(id, mh=20)，Task 表 76 条 Item 奖励实测在用）。
const KIND_DAILY: String = "dailyjob"


static func make_task_row(task: Dictionary, on_claim: Callable,
		reward_title_text: String = "奖励:", fast_btn_text: String = "前往",
		on_fast: Callable = Callable(), p_cm: Variant = null) -> Control:
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
	var name_lbl: Label = add_label(bg, str(task.get("name", "")), C_NAME, &"TaskNameLabel")
	var progress_text: String = "" if is_completed else "%d/%d" % [progress, target]
	var progress_var: StringName = &"TaskProgressDoneLabel" if is_completed else &"TaskProgressTodoLabel"
	var progress_lbl: Label = add_label(bg, progress_text, C_PROGRESS, progress_var)
	var detail_lbl: Label = add_label(bg, str(task.get("detail", "")), C_DETAIL, &"TaskDetailLabel")
	var title_lbl: Label = add_label(bg, reward_title_text, C_REWARD_TITLE, &"TaskRewardTitleLabel")
	var reward_chain: Array = add_reward_icons(bg, task.get("reward", []), p_cm)
	# 完成态 → completeTag(领奖)；否则 dailyjob → createFastButton(前往，on_fast 跳场景)
	if show_complete:
		_add_complete_tag(bg, on_claim)
	elif kind == KIND_DAILY:
		_add_fast_button(bg, fast_btn_text, on_fast)
	# 挂树后一次性 relayout（theme 链通后 get_minimum_size 才是 variation 真实字体尺寸，
	# 同 hero_package _relayout_name 判例）：progress 中心锚/name·detail 超宽压缩/reward 动态步进。
	bg.ready.connect(_deferred_relayout.bind(name_lbl, detail_lbl, title_lbl, progress_lbl, reward_chain))
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
static func add_label(parent: Control, text: String, cocos: Vector2, variation_name: StringName) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.theme_type_variation = variation_name
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs: int = _variation_font_size(variation_name)
	var h: float = float(fs) + 4.0
	lbl.position = bg_pos(cocos) - Vector2(0.0, h * 0.5)
	parent.add_child(lbl)
	return lbl


# variation 字号查找：从 default_theme 读，避免散落常量。Theme 缺失/未注册 → 16 兜底。
static func _variation_font_size(variation_name: StringName) -> int:
	var t: Theme = load("res://resources/themes/default_theme.tres") as Theme
	if t != null and t.has_font_size("font_size", String(variation_name)):
		return int(t.get_font_size("font_size", String(variation_name)))
	return 16


# reward icons 横排（源 :565-580 getRightSidePos 累积：preNode=reward_title，icon→amt gap 0、
# amt→下个 icon gap 10；Item→readequip.createIcon(id, mh=20)）。
# 初摆用估算步进占位，挂树后 _deferred_relayout 按实测文字宽重排；返回链 refs 供 relayout。
static func add_reward_icons(bg: TextureRect, rewards: Array, p_cm: Variant = null) -> Array:
	var chain: Array = []
	if rewards.is_empty():
		return chain
	var y_base: float = bg_pos(C_REWARD_TITLE).y
	var rx: float = C_REWARD_TITLE.x + 45.0   # 占位起步（挂树后重排为 title 实测右缘）
	for r in rewards:
		var rtype: String = str(r.get("type", ""))
		var amount: int = int(r.get("amount", 0))
		if amount <= 0:
			continue
		if rtype == "Item":
			rx = _add_item_reward_icon(bg, int(r.get("id", 0)), rx, y_base, p_cm, chain)
			continue
		var res: String = REWARD_ICON_RES.get(rtype, "")
		if res.is_empty():
			continue
		rx = add_reward_icon(bg, res, rx, y_base, chain)
		rx = add_reward_amt(bg, amount, rx, y_base, chain)
	return chain


# :566-567 type=="Item" → readequip.createIcon(id, mh)：72 点产物整体 scale 到高 mh，无数量角标
# （数量由外层 "xN" 文字表达，amount 传 0）。产物挂 bg 计入链（方形，显示宽=高）。
static func _add_item_reward_icon(bg: TextureRect, id: int, rx: float, y_base: float,
		p_cm: Variant, chain: Array) -> float:
	if p_cm == null or id <= 0:
		return rx
	var icon: Control = ReadequipIcon.create_icon(id, 0, p_cm)
	var s: float = REWARD_ITEM_ICON_H / ReadequipIcon.ICON_SIZE
	icon.scale = Vector2(s, s)
	icon.position = Vector2(rx, y_base - REWARD_ITEM_ICON_H * 0.5)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(icon)
	chain.append({"node": icon, "w": ReadequipIcon.ICON_SIZE * s})
	return rx + ReadequipIcon.ICON_SIZE * s


static func add_reward_icon(bg: TextureRect, res: String, rx: float, y_base: float, chain: Array) -> float:
	var icon := TextureRect.new()
	icon.texture = load_tex(res)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var adv: float = rx
	if icon.texture:
		var s: float = float(REWARD_ICON_H) / icon.texture.get_height()
		# EXPAND_IGNORE_SIZE 下 size 默认 0 不渲染：须显式 size=纹理原尺寸再靠 scale 缩
		#（旧实现漏设，金币/钻石奖励图标 size=0 从未显示过，2026-08-28 实机判读揪出）。
		icon.size = icon.texture.get_size()
		icon.scale = Vector2(s, s)
		var tex_size: Vector2 = icon.texture.get_size() * s
		icon.position = Vector2(rx, y_base - tex_size.y * 0.5)
		adv = rx + tex_size.x
		chain.append({"node": icon, "w": tex_size.x})
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(icon)
	return adv


static func add_reward_amt(bg: TextureRect, amount: int, rx: float, y_base: float, chain: Array) -> float:
	var amt := Label.new()
	amt.text = "x%d" % amount
	amt.theme_type_variation = &"TaskRewardAmtLabel"
	amt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h: float = float(_variation_font_size(&"TaskRewardAmtLabel")) + 4.0
	amt.position = Vector2(rx, y_base - h * 0.5)
	bg.add_child(amt)
	chain.append({"node": amt, "w": 30.0})   # 占位宽（挂树后重排为实测）
	return rx + 30.0


# :583-589 completeTag = createSprite(task_get_reward_button) 原尺寸（126×89px÷CS=98.3×69.5）
# 中心锚 (420,45)。源点击走 draglist 整行 doClickInList，本项目按钮承载 on_claim（可点面=贴图原尺寸）。
static func _add_complete_tag(bg: TextureRect, on_claim: Callable) -> void:
	var btn := TextureButton.new()
	var normal_tex: Texture2D = load_tex(COMPLETE_TAG_RES)
	if normal_tex == null:
		normal_tex = load_tex(BUTTON_RES)
	btn.texture_normal = normal_tex
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	btn.custom_minimum_size = COMPLETE_TAG_SIZE
	btn.size = COMPLETE_TAG_SIZE
	btn.position = bg_pos(C_COMPLETE) - COMPLETE_TAG_SIZE * 0.5
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	if not on_claim.is_null():
		btn.pressed.connect(on_claim)
	# doPressInList（task.lua:318-328）整行按压缩放适用所有行（含 complete 态），借按钮驱动同 fast。
	btn.button_down.connect(_tween_row_scale.bind(bg, ROW_PRESS_SCALE))
	btn.button_up.connect(_tween_row_scale.bind(bg, Vector2.ONE))
	bg.add_child(btn)


# :645-775 createFastButton：Scale9 60×45 + label(28,23) size18（本项目 label 居中 60×45 等价）。
static func _add_fast_button(bg: TextureRect, label_text: String, on_fast: Callable) -> void:
	var btn := TextureButton.new()
	btn.texture_normal = load_tex(BUTTON_RES)
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
	if not on_fast.is_null():
		btn.pressed.connect(on_fast)
	# task.lua:324 doPressInList bg setScale(0.98)：按钮 down→bg 缩 0.98，up→回弹 1.0。
	# 项目 bg mouse_filter=IGNORE 不接收输入，借子按钮 button_down/up 信号驱动 bg 缩放。
	btn.button_down.connect(_tween_row_scale.bind(bg, ROW_PRESS_SCALE))
	btn.button_up.connect(_tween_row_scale.bind(bg, Vector2.ONE))
	bg.add_child(btn)


# 挂树后一次性 relayout（theme 链通后 variation 字体测量生效；同 hero_package deferred 判例）：
# ① progress 中心锚（源 readNode 默认 anchor(0.5,0.5)，非左中）② name/detail 超宽压缩
# （源 :555-563 setScale(300/280÷w)）③ reward 链动态步进（源 getRightSidePos 实测右缘累积，
# icon→amt gap 0、amt→icon gap 10，起步=title 实测右缘）。
static func _deferred_relayout(name_lbl: Label, detail_lbl: Label, title_lbl: Label,
		progress_lbl: Label, reward_chain: Array) -> void:
	var nw: float = name_lbl.get_minimum_size().x
	if nw > NAME_MAX_W:
		name_lbl.scale = Vector2(NAME_MAX_W / nw, NAME_MAX_W / nw)
	var dw: float = detail_lbl.get_minimum_size().x
	if dw > DETAIL_MAX_W:
		detail_lbl.scale = Vector2(DETAIL_MAX_W / dw, DETAIL_MAX_W / dw)
	var pw: Vector2 = progress_lbl.get_minimum_size()
	progress_lbl.position = bg_pos(C_PROGRESS) - pw * 0.5
	var rx: float = C_REWARD_TITLE.x + title_lbl.get_minimum_size().x
	for i in range(reward_chain.size()):
		var entry: Dictionary = reward_chain[i]
		var node: Control = entry["node"]
		node.position.x = rx
		var w: float = float(entry["w"])
		if node is Label:
			w = (node as Label).get_minimum_size().x
			entry["w"] = w
		rx += w
		# amt 后 gap 10 给下一组 icon（源 :571 i==1 and 0 or 10；amt→icon 间隙，icon→amt 无）
		if node is Label and i < reward_chain.size() - 1:
			rx += 10.0


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
