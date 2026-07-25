class_name MailOverfullPopup
extends Control

## 邮件附件溢满弹窗（View 层）— 照源 mail/overfull.lua + uieditor/mailoverfull.lua。
## frame（common_alert_bg）+ title_bg（herodetail-title-mark）+ 标题"超额提醒"
## + 3 段说明（overfull.1.10.1.001/002/003）+ 溢出物品 4 列网格
## + 「强行领取」(confirmed)/「稍后领取」(cancel)。left → emit confirmed（调用方继续领取），right → 关闭。
## Phase A 静态化（2026-07-18）：shade/frame/title_bg/title/desc1·2·3/left·right 从 procedural
## 改 instantiate mail_overfull_popup_content.tscn（位置/size .tscn 固化，照 hero_detail 范式）。
## Control 非 PopWindow：content 挂 panel 自身（参考 shortcut/battle_prepare/crusade_reset_confirm 范式）。
## 溢出物品 4 列网格保留 procedural 挂 %ContentVBox（数量随 items 变，插 desc2/desc3 之间）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/mail_overfull_popup_content.tscn")
# 测试用：frame 贴图路径（_has_tex 递归扫 TextureRect.resource_path 比对）。
const FRAME_TEX: String = "res://assets/ui/alpha/HVGA/common/common_alert_bg.png"
const GRID_COLS: int = 4
const ICON_SCALE: float = 0.85
const BTN_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button.png"
const BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button_down.png"
const BTN_CAP: Rect2 = Rect2(15.63, 15.63, 19.53, 15.63)
const BTN_LABEL_COLOR: Color = Color(239.0 / 255.0, 230.0 / 255.0, 209.0 / 255.0)
# P1（2026-07-16）：UI 文案 cm.get_lstr 化（源 LSTR key，GameData.config 解析，fallback 中文兜底）。
const LSTR_TITLE_KEY: String = "mailoverfull.1.10.1.003"
const TITLE_FALLBACK: String = "超额提醒"
const LSTR_DESC1_KEY: String = "overfull.1.10.1.001"
const DESC1_FALLBACK: String = "部分道具将超出可携带上限(999个)。如果强行领取，将损失超出的道具。"
const LSTR_DESC2_KEY: String = "overfull.1.10.1.002"
const DESC2_FALLBACK: String = "超出："
const LSTR_DESC3_KEY: String = "overfull.1.10.1.003"
const DESC3_FALLBACK: String = "是否继续领取？"
const LSTR_LEFT_KEY: String = "mailoverfull.1.10.1.001"
const LEFT_FALLBACK: String = "强行领取"
const LSTR_RIGHT_KEY: String = "mailoverfull.1.10.1.002"
const RIGHT_FALLBACK: String = "稍后领取"

signal confirmed

var _items: Array = []
var _cm: Variant


func _lstr(key: String, fallback: String) -> String:
	var cfg: ConfigManager = GameData.config
	if cfg != null:
		return cfg.get_lstr(key)
	return fallback


# items = 溢出列表 [{id, amount}]（源 overfull.lua:67 self.param.items）。
func setup(items: Array, cm: Variant) -> void:
	_items = items
	_cm = cm


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 模态拦截底层
	_build_content()


# Phase A：静态节点从 .tscn instantiate（位置/size .tscn 固化）+ fill 动态文案/Scale9 + 信号绑定。
# 溢出物品 4 列网格保留 procedural 挂 %ContentVBox（在 desc2/desc3 之间，照源 overfull.lua ChaosNode 垂直流）。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	add_child(content)   # Control 非 PopWindow：content 挂 panel 自身
	(content.get_node("%TitleLabel") as Label).text = _lstr(LSTR_TITLE_KEY, TITLE_FALLBACK)
	var vbox: VBoxContainer = content.get_node("%ContentVBox") as VBoxContainer
	(vbox.get_node("Desc1Label") as Label).text = _lstr(LSTR_DESC1_KEY, DESC1_FALLBACK)
	(vbox.get_node("Desc2Label") as Label).text = _lstr(LSTR_DESC2_KEY, DESC2_FALLBACK)
	(vbox.get_node("Desc3Label") as Label).text = _lstr(LSTR_DESC3_KEY, DESC3_FALLBACK)
	_build_grid(vbox)
	# 取消/确认按钮（源 uieditor sell_number_button Scale9 cap 15.63,15.63,19.53,15.63 + 浅金 ccc3）
	var left_btn: Button = content.get_node("%LeftBtn") as Button
	UiScale9Button.apply_with_label(left_btn, BTN_RES, BTN_PRESS_RES, BTN_CAP, _lstr(LSTR_LEFT_KEY, LEFT_FALLBACK), BTN_LABEL_COLOR)
	left_btn.pressed.connect(_on_left)
	var right_btn: Button = content.get_node("%RightBtn") as Button
	UiScale9Button.apply_with_label(right_btn, BTN_RES, BTN_PRESS_RES, BTN_CAP, _lstr(LSTR_RIGHT_KEY, RIGHT_FALLBACK), BTN_LABEL_COLOR)
	right_btn.pressed.connect(_close)


# grid 创建后插到 vbox 的 desc2(idx=1) 和 desc3(idx=2) 之间（move_child 到 idx=2，保持源 ChaosNode 垂直顺序）。
func _build_grid(vbox: VBoxContainer) -> void:
	var grid: GridContainer = GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item in _items:
		var item_id: int = int(item.get("id", 0))
		var amount: int = int(item.get("amount", 1))
		if item_id == 0:
			continue
		var icon: Control = ReadequipIcon.create_icon(item_id, amount, _cm)
		icon.scale = Vector2(ICON_SCALE, ICON_SCALE)
		grid.add_child(icon)
	vbox.add_child(grid)
	vbox.move_child(grid, 2)   # 插到 desc2(1) 和 desc3(2) 之间


func _on_left() -> void:
	emit_signal("confirmed")
	_close()


func _close() -> void:
	queue_free()
