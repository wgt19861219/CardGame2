class_name MainStatusBar
extends RefCounted

const UIConstants := preload("res://resources/constants/ui_constants.gd")

## 主菜单状态栏（View helper）— 照源 ui/statusbar.lua createHead:554 + createTitle:706。
## 从 main_scene 拆出重建：头像（银/金框切换 + 昵称 + VIP 角标）+ 3 货币条（图标 + 数字 + 加号按钮）。
## 替代旧裸文字 Label 占位。main_scene._build_status_bar 委托本类 + _refresh_status 更新 label。
##
## 入口接线（照源 statusbar.lua:41-68 registerTitleTouchHandler）：
## - money_bg 整条可点 → doClickMidas（gold_plus_handler，main_scene 传 _open_midas）
## - vitality 加号按钮 → buyVitality（vitality_plus_handler）
## - rmb 加号单机化裁剪（充值无单机等价；diamond_plus_handler 空→加号 IGNORE）

# C13 坐标基准核查结论：statusbar 是 framework HUD 层（标准 UI），走 to_godot(cx,cy)=(cx+80,560-cy)
# （源 800×480 左下原点 → Godot 960×640 左上原点 + 居中偏移 80）；非 main_scene ENTRIES 的 MAP_H-cocos_y
# 基准（map 全屏背景适配，950×640 整张图）。两者不冲突——ENTRIES 是 map 装饰，statusbar 是 framework HUD。
const HEAD_POS: Vector2 = Vector2(150.0, 66.0)
const HEAD_SIZE: Vector2 = Vector2(137.0, 105.0)
const HEAD_FRAME_RES: Array = [
	"res://assets/ui/alpha/HVGA/main_head_bg_silver.png",   # VIP=0 银色
	"res://assets/ui/alpha/HVGA/main_head_bg_gold.png",     # VIP>0 金色
]
const HEAD_FRAME_BORDER_RES: Array = [
	"res://assets/ui/alpha/HVGA/main_head_frame_silver.png",
	"res://assets/ui/alpha/HVGA/main_head_frame_gold.png",
]
const NAME_BG_RES: Array = [
	"res://assets/ui/alpha/HVGA/main_head_name_bg_silver.png",
	"res://assets/ui/alpha/HVGA/main_head_name_bg_gold.png",
]
const VIP_BG_RES: String = "res://assets/ui/alpha/HVGA/recharge_vip_bg.png"
const VIP_ICON_RES: String = "res://assets/ui/alpha/HVGA/recharge_vip_icon.png"
# 货币条（源 createTitle getBarConfig：gold/rmb/vitality 三条）
const BAR_BG_RES: String = "res://assets/ui/alpha/HVGA/main_status_number_bg.png"
const GOLD_ICON_RES: String = "res://assets/ui/alpha/HVGA/add_goldicon_small.png"
const DIAMOND_ICON_RES: String = "res://assets/ui/alpha/HVGA/add_rmbicon.png"
const VITALITY_ICON_RES: String = "res://assets/ui/alpha/HVGA/add_vitalityicon.png"
const PLUS_ICON_RES: String = "res://assets/ui/alpha/HVGA/main_status_plus_icon_1.png"
# = (331,110)/(514,110)/(681,110)。源不等距：money→rmb 间距 183，rmb→vit 间距 167（旧版改等距 183 违反源）。
const BAR_POS_X: Array = [331.0, 514.0, 681.0]
const BAR_Y: float = 50.0
const BAR_SIZE: Vector2 = Vector2(178.0, 48.0)
const VIT_BAR_SIZE: Vector2 = Vector2(145.0, 48.0)


# 装配完整状态栏（头像 + 货币条）。返回 refs dict 供 _refresh_status 更新 label。
# vitality_plus_handler：体力加号点击回调（main_scene 传 _on_vitality_plus→buy_vitality）。
# gold_plus_handler：金币条整条点击回调（照源 statusbar.lua:41-49 money_bg 可点→doClickMidas，
#   main_scene 传 _open_midas）。非空→bar Control gui_input 连接（整条可点）；空→bar 不响应。
# player/cm：vit_bg 按住提示卡需要（源 statusbar.lua:69-79 pressHandler→createVitalityPrompt）。
#   传入则启用按住提示卡（C12）；不传则 vit_bg 不响应按住（仅 vitality 加号点击仍工作）。
static func build(parent: Control, vitality_plus_handler: Callable = Callable(), head_click_handler: Callable = Callable(), gold_plus_handler: Callable = Callable(), player: PlayerData = null, cm: ConfigManager = null) -> Dictionary:
	var vip_idx: int = 0   # build 时默认银框，refresh 按 PlayerData.vip_level 切金框（P2-5 已实现见 refresh）
	var refs: Dictionary = {}
	# 头像区（源 createHead）
	var head := Control.new()
	head.position = HEAD_POS - HEAD_SIZE / 2.0
	head.size = HEAD_SIZE
	parent.add_child(head)
	refs["head"] = head
	if head_click_handler.is_valid():
		var h: Callable = head_click_handler
		head.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				h.call())
	_add_texture_rect(head, HEAD_FRAME_RES[vip_idx], Vector2.ZERO, HEAD_SIZE, "head_bg")
	_add_texture_rect(head, HEAD_FRAME_BORDER_RES[vip_idx], Vector2.ZERO, HEAD_SIZE, "head_frame")
	# 昵称 Label
	var name_lbl := Label.new()
	name_lbl.text = "Player"
	name_lbl.position = Vector2(20.0, 75.0)
	name_lbl.add_theme_font_size_override("font_size", 15)
	head.add_child(name_lbl)
	refs["name"] = name_lbl
	# P1-15：等级 Label（源 statusbar.lua:658 level ccp(82,37) size=16）
	var level_lbl := Label.new()
	level_lbl.text = "Lv.1"
	level_lbl.position = Vector2(12.0, 55.0)
	# 走 BodyLabel 变体（default_theme.tres：font_size=16 继承 Label 默认 + 白字 + outline_size=2 黑描边）
	# outline 是行为变化但视觉更清晰（status bar HUD 层加描边改进，非回归）。
	level_lbl.theme_type_variation = &"BodyLabel"
	head.add_child(level_lbl)
	refs["level"] = level_lbl
	# VIP 角标（VIP>0 显示）
	var vip_bg := _add_texture_rect(head, VIP_BG_RES, Vector2(90.0, 18.0), Vector2(50.0, 50.0), "vip_bg")
	vip_bg.visible = false
	refs["vip_bg"] = vip_bg
	var vip_lbl := Label.new()
	vip_lbl.text = "0"
	vip_lbl.position = Vector2(85.0, 38.0)
	vip_lbl.visible = false
	head.add_child(vip_lbl)
	refs["vip"] = vip_lbl
	# 货币条（源 createTitle gold/rmb/vitality）。vit_bg 用源 145×48（比 money/rmb 178×48 窄）
	refs["gold"] = _build_bar(parent, BAR_POS_X[0], GOLD_ICON_RES, Callable(), BAR_Y, BAR_SIZE)
	refs["diamond"] = _build_bar(parent, BAR_POS_X[1], DIAMOND_ICON_RES, Callable(), BAR_Y, BAR_SIZE)
	refs["vitality"] = _build_bar(parent, BAR_POS_X[2], VITALITY_ICON_RES, vitality_plus_handler, BAR_Y, VIT_BAR_SIZE)
	# gold_plus_handler 非 empty → bar Control（gold Label 的 parent）gui_input 连接整条点击。
	if gold_plus_handler.is_valid():
		var gold_lbl: Label = refs["gold"] as Label
		gold_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 避 Label STOP 吞点击，让 bar 整条可点
		var gold_bar: Control = gold_lbl.get_parent()
		var g: Callable = gold_plus_handler
		gold_bar.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				g.call())
	# 按住 vit_bg 显体力恢复进度提示卡（C12），松开销毁。vit 加号 Button STOP 独立命中不冲突。
	if player != null and cm != null:
		_attach_vit_prompt(refs["vitality"] as Label, parent, player, cm)
	return refs


# 仅货币条（无头像）— 非 main 场景用（源 framework.createTitle 所有场景建货币条，createHead 只 main）。
# bar_pos_x/bar_y 由调用方传源 common 中心点（heroScene：cocos(251,434,601) y450 → godot [331,514,681] y110）。
# parent: 挂载父节点（子场景直接挂 panel/scene）
# gold_plus_handler: 金币"+"回调（照源 statusbar.lua:42-49 registerTitleTouchHandler，子场景也开 midas）
static func build_bars_only(parent: Control, bar_pos_x: Array, bar_y: float, vitality_plus_handler: Callable = Callable(), gold_plus_handler: Callable = Callable()) -> Dictionary:
	var refs: Dictionary = {}
	refs["gold"] = _build_bar(parent, float(bar_pos_x[0]), GOLD_ICON_RES, gold_plus_handler, bar_y, BAR_SIZE)
	refs["diamond"] = _build_bar(parent, float(bar_pos_x[1]), DIAMOND_ICON_RES, Callable(), bar_y, BAR_SIZE)
	refs["vitality"] = _build_bar(parent, float(bar_pos_x[2]), VITALITY_ICON_RES, vitality_plus_handler, bar_y, VIT_BAR_SIZE)
	return refs


# 装配单条货币条：背景条 + 图标 + 数字 label + 加号。返回 label ref。
# plus_handler 非空（vitality）→ 加号是 Button 可点（照源 statusbar:59-68 radius=30 圆形点击 → buyVitality）；
# plus_handler 空（gold/diamond）→ 加号 IGNORE（gold 走 midas_btn，diamond 充值单机化裁剪；避 STOP 吞点击）。
# x/bar_y 为源 Scale9Sprite 中心点（anchor 0.5,0.5），内部转 Godot 左上角定位（减 size/2）。
static func _build_bar(parent: Control, x: float, icon_res: String, plus_handler: Callable = Callable(), bar_y: float = BAR_Y, bar_size: Vector2 = BAR_SIZE) -> Label:
	var bar := Control.new()
	bar.position = Vector2(x - bar_size.x / 2.0, bar_y - bar_size.y / 2.0)
	bar.size = bar_size
	parent.add_child(bar)
	_add_texture_rect(bar, BAR_BG_RES, Vector2.ZERO, bar_size, "bg")
	_add_texture_rect(bar, icon_res, Vector2(142.0, 8.0), Vector2(32.0, 32.0), "icon")
	var lbl := Label.new()
	lbl.position = Vector2(50.0, 16.0)
	# 不引入 BodyLabel 变体（货币条数值可能有色，仅替换裸数字 14 为常量）
	lbl.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SMALL)
	bar.add_child(lbl)
	if plus_handler.is_valid():
		# 加号 Button（flat + StyleBoxEmpty 去默认样式，icon=PLUS_ICON_RES；照源圆形点击区 radius=30）
		var plus_btn := Button.new()
		plus_btn.position = Vector2(4.0, 8.0)
		plus_btn.size = Vector2(32.0, 32.0)
		plus_btn.icon = load(PLUS_ICON_RES)
		plus_btn.flat = true
		plus_btn.focus_mode = Control.FOCUS_NONE
		# 走 GhostButton 变体（default_theme.tres：normal/hover/pressed/focus 全 StyleBoxEmpty）
		plus_btn.theme_type_variation = &"GhostButton"
		plus_btn.pressed.connect(plus_handler)
		bar.add_child(plus_btn)
	else:
		# 无处理器（gold/diamond）：IGNORE 避 STOP 吞点击无响应（P1-复审2-3 核心危害）
		var plus := _add_texture_rect(bar, PLUS_ICON_RES, Vector2(4.0, 8.0), Vector2(32.0, 32.0), "plus")
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


# vit_bg 按住提示卡接线（源 statusbar.lua:69-79 pressHandler/liftHandler）。
# vit_bg bar Control mouse_filter=PASS + gui_input 监听 mouse pressed/released（不影响 plus_btn STOP）。
static func _attach_vit_prompt(vit_lbl: Label, parent: Control, player: PlayerData, cm: ConfigManager) -> void:
	if vit_lbl == null:
		return
	vit_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 避 Label STOP 吞事件
	var vit_bar: Control = vit_lbl.get_parent()
	vit_bar.mouse_filter = Control.MOUSE_FILTER_PASS   # 让事件冒泡到 bar（plus_btn 仍独立命中）
	vit_bar.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			if (ev as InputEventMouseButton).pressed:
				VitPromptCard.show(parent, player, cm)
			else:
				VitPromptCard.destroy_prompt())


# 刷新状态栏数值（main_scene._refresh_status 调）。
static func refresh(refs: Dictionary, level: int, gold: int, diamond: int, vitality: int, vitality_max: int, name: String, vip: int, avatar: int) -> void:
	if refs.has("gold"):
		(refs["gold"] as Label).text = str(gold)
	if refs.has("diamond"):
		(refs["diamond"] as Label).text = str(diamond)
	if refs.has("vitality"):
		(refs["vitality"] as Label).text = "%d/%d" % [vitality, vitality_max]
	if refs.has("name"):
		(refs["name"] as Label).text = name
	# P1-15：等级 Label 更新（源 self.playerLevel）
	if refs.has("level"):
		(refs["level"] as Label).text = "Lv.%d" % level
	# VIP 角标显示切换（源 visible = self.vip > 0）
	var vip_idx: int = 1 if vip > 0 else 0
	if refs.has("vip"):
		(refs["vip"] as Label).text = str(vip)
		(refs["vip"] as Label).visible = vip > 0
	if refs.has("vip_bg"):
		(refs["vip_bg"] as TextureRect).visible = vip > 0
	# 头像框银/金切换（源 vip>0 用 gold 资源）
	_refresh_head_frame(refs, vip_idx)


# 头像框银/金资源切换（源 refreshHead:200-280）。
static func _refresh_head_frame(refs: Dictionary, vip_idx: int) -> void:
	var head: Control = refs.get("head", null)
	if head == null:
		return
	var head_bg: TextureRect = head.get_node_or_null("head_bg")
	if head_bg != null:
		head_bg.texture = load(HEAD_FRAME_RES[vip_idx])
	var head_frame: TextureRect = head.get_node_or_null("head_frame")
	if head_frame != null:
		head_frame.texture = load(HEAD_FRAME_BORDER_RES[vip_idx])


# 辅助：创建 TextureRect 子节点。
static func _add_texture_rect(parent: Control, res_path: String, pos: Vector2, size: Vector2, node_name: String) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = node_name
	tr.texture = load(res_path)
	# EXPAND_IGNORE_SIZE + 显式 size：纹理原始尺寸不撑大（照源 Scale9 scaleSize/fix_size 等价）。
	# 默认 KEEP_SIZE 致 main_status_number_bg 纹理原始尺寸撑大 → 货币条 3 框重叠（memory: texture-rect-expand-ignore-size）。
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.position = pos
	tr.size = size
	tr.custom_minimum_size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr
