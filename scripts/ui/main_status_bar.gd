class_name MainStatusBar
extends RefCounted

## 主菜单状态栏（View helper）— 照源 ui/statusbar.lua createHead:554 + createTitle:706。
## 从 main_scene 拆出重建：头像（银/金框切换 + 昵称 + VIP 角标）+ 3 货币条（图标 + 数字 + 加号按钮）。
## 替代旧裸文字 Label 占位。main_scene._build_status_bar 委托本类 + _refresh_status 更新 label。
##
## 单机化：源 doClickMidas/doClickrmb/buyVitality 加号按钮 → Toast 提示（单机直接调 PlayerData）。

const HEAD_POS: Vector2 = Vector2(70.0, 52.0)        # 源 head_bg_pos（左上头像区）
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
const BAR_POS_X: Array = [280.0, 463.0, 630.0]   # P1-15：照源 statusbar.lua 251/434/601 间距 183/167（等距 180→183/167）
const BAR_Y: float = 30.0


# 装配完整状态栏（头像 + 货币条）。返回 refs dict 供 _refresh_status 更新 label。
# vitality_plus_handler：体力加号点击回调（main_scene 传 _on_vitality_plus→buy_vitality）。
static func build(parent: Control, vitality_plus_handler: Callable = Callable(), head_click_handler: Callable = Callable()) -> Dictionary:
	var vip_idx: int = 0   # build 时默认银框，refresh 按 PlayerData.vip_level 切金框（P2-5 已实现见 refresh）
	var refs: Dictionary = {}
	# 头像区（源 createHead）
	var head := Control.new()
	head.position = HEAD_POS - HEAD_SIZE / 2.0
	head.size = HEAD_SIZE
	parent.add_child(head)
	refs["head"] = head
	# 源 statusbar:313-322 headIcon 点击 → configure 设置面板。head Control gui_input 接点击调 head_click_handler。
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
	level_lbl.position = Vector2(12.0, 55.0)  # 源 ccp(82,37) → Godot head 内相对坐标
	level_lbl.add_theme_font_size_override("font_size", 16)
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
	# 货币条（源 createTitle gold/rmb/vitality）
	refs["gold"] = _build_bar(parent, BAR_POS_X[0], GOLD_ICON_RES)
	refs["diamond"] = _build_bar(parent, BAR_POS_X[1], DIAMOND_ICON_RES)
	refs["vitality"] = _build_bar(parent, BAR_POS_X[2], VITALITY_ICON_RES, vitality_plus_handler)
	return refs


# 装配单条货币条：背景条 + 图标 + 数字 label + 加号。返回 label ref。
# plus_handler 非空（vitality）→ 加号是 Button 可点（照源 statusbar:59-68 radius=30 圆形点击 → buyVitality）；
# plus_handler 空（gold/diamond）→ 加号 IGNORE（gold 走 midas_btn，diamond 充值单机化裁剪；避 STOP 吞点击）。
static func _build_bar(parent: Control, x: float, icon_res: String, plus_handler: Callable = Callable()) -> Label:
	var bar := Control.new()
	bar.position = Vector2(x, BAR_Y)
	bar.size = Vector2(160.0, 40.0)
	parent.add_child(bar)
	_add_texture_rect(bar, BAR_BG_RES, Vector2.ZERO, Vector2(140.0, 32.0), "bg")
	_add_texture_rect(bar, icon_res, Vector2(5.0, 0.0), Vector2(32.0, 32.0), "icon")
	var lbl := Label.new()
	lbl.position = Vector2(40.0, 8.0)
	lbl.add_theme_font_size_override("font_size", 14)
	bar.add_child(lbl)
	if plus_handler.is_valid():
		# 加号 Button（flat + StyleBoxEmpty 去默认样式，icon=PLUS_ICON_RES；照源圆形点击区 radius=30）
		var plus_btn := Button.new()
		plus_btn.position = Vector2(120.0, 0.0)
		plus_btn.size = Vector2(32.0, 32.0)
		plus_btn.icon = load(PLUS_ICON_RES)
		plus_btn.flat = true
		plus_btn.focus_mode = Control.FOCUS_NONE
		plus_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		plus_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		plus_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		plus_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		plus_btn.pressed.connect(plus_handler)
		bar.add_child(plus_btn)
	else:
		# 无处理器（gold/diamond）：IGNORE 避 STOP 吞点击无响应（P1-复审2-3 核心危害）
		var plus := _add_texture_rect(bar, PLUS_ICON_RES, Vector2(120.0, 0.0), Vector2(32.0, 32.0), "plus")
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


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
	tr.position = pos
	tr.custom_minimum_size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr
