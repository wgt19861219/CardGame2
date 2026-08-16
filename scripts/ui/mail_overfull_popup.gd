class_name MailOverfullPopup
extends Control

## 邮件附件溢满弹窗（View 层）— 照源 mail/overfull.lua + uieditor/mailoverfull.lua。
## frame（common_alert_bg）+ title_bg（herodetail-title-mark）+ 标题"超额提醒"
## + 3 段说明（overfull.1.10.1.001/002/003）+ 溢出物品 4 列网格
## + 「强行领取」(confirmed)/「稍后领取」(cancel)。left → emit confirmed（调用方继续领取），right → 关闭。
## Control 非 PopWindow：content 挂 panel 自身（参考 shortcut/battle_prepare/crusade_reset_confirm 范式）。
##
## 批 2 两件套改造（2026-08-16，uieditor/mailoverfull.lua 声明表直译）：chrome 全静态化进
## scenes/ui/mail_overfull_popup_content.tscn——Frame/TitleBg 源 Scale9Sprite →
## NinePatchRect（B 类 Scale9 误用修正，cap 纹理像素直译）；两按钮运行时
## UiScale9Button.apply_with_label → Button theme variation MailOverfullBtn（文字
## Button.text 承载）；desc 滚动区照源 cliprect DGRectMake×0.78125 直译补齐 ScrollContainer
## （GridContainer 静态化，fill 只挂溢出物品 icon，item 排序照源 ChaosNode 垂直流）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/mail_overfull_popup_content.tscn")
# 测试用：frame 贴图路径（_has_tex 递归扫 TextureRect.resource_path 比对）。
const FRAME_TEX: String = "res://assets/ui/alpha/HVGA/common/common_alert_bg.png"
# 溢出物品 icon 缩放（源 overfull.lua:79 createIconWithAmount(id, 60, amount)：
# ReadequipIcon 72px 基准 → 60/72）
const ICON_SCALE: float = 60.0 / 72.0
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


# 静态树从 .tscn instantiate + fill 动态文案/溢出物品 + 信号绑定（照源 createContent 垂直流顺序）。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	add_child(content)   # Control 非 PopWindow：content 挂 panel 自身
	(content.get_node("%TitleLabel") as Label).text = _lstr(LSTR_TITLE_KEY, TITLE_FALLBACK)
	(content.get_node("%Desc1Label") as Label).text = _lstr(LSTR_DESC1_KEY, DESC1_FALLBACK)
	(content.get_node("%Desc2Label") as Label).text = _lstr(LSTR_DESC2_KEY, DESC2_FALLBACK)
	(content.get_node("%Desc3Label") as Label).text = _lstr(LSTR_DESC3_KEY, DESC3_FALLBACK)
	_fill_overfull_grid(content)
	var left_btn: Button = content.get_node("%LeftBtn") as Button
	left_btn.pressed.connect(_on_left)
	var right_btn: Button = content.get_node("%RightBtn") as Button
	right_btn.pressed.connect(_close)


# 溢出物品挂静态 %OverfullGrid（4 列，源 :68-70；grid 位于 desc2/desc3 间照源 ChaosNode）。
func _fill_overfull_grid(content: Control) -> void:
	var grid: GridContainer = content.get_node("%OverfullGrid") as GridContainer
	for item in _items:
		var item_id: int = int(item.get("id", 0))
		var amount: int = int(item.get("amount", 1))
		if item_id == 0:
			continue
		var icon: Control = ReadequipIcon.create_icon(item_id, amount, _cm)
		icon.scale = Vector2(ICON_SCALE, ICON_SCALE)
		grid.add_child(icon)


func _on_left() -> void:
	emit_signal("confirmed")
	_close()


func _close() -> void:
	queue_free()
