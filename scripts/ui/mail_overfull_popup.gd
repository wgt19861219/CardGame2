class_name MailOverfullPopup
extends Control

## 邮件附件溢满弹窗（View 层）— 照源 mail/overfull.lua + uieditor/mailoverfull.lua。
## frame（common_alert_bg）+ title_bg（herodetail-title-mark）+ 标题"超额提醒"
## + 3 段说明（overfull.1.10.1.001/002/003）+ 溢出物品 4 列网格
## + 「强行领取」(confirmed)/「稍后领取」(cancel)。left → emit confirmed（调用方继续领取），right → 关闭。

const FRAME_TEX: String = "res://assets/ui/alpha/HVGA/common/common_alert_bg.png"
const TITLE_BG_TEX: String = "res://assets/ui/alpha/HVGA/herodetail-title-mark.png"
const BTN_TEX: String = "res://assets/ui/alpha/HVGA/sell_number_button.png"
const BTN_P_TEX: String = "res://assets/ui/alpha/HVGA/sell_number_button_down.png"
const FRAME_SIZE: Vector2 = Vector2(463.0, 363.0)   # 源 uieditor scaleSize
const SHADE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.5)
const TITLE_COLOR: Color = Color(253.0 / 255.0, 215.0 / 255.0, 17.0 / 255.0)   # 源 uieditor title ccc3
const DESC_COLOR: Color = Color(243.0 / 255.0, 194.0 / 255.0, 113.0 / 255.0)   # 源 overfull.lua:47 说明色
const GRID_COLS: int = 4                # 源 overfull.lua:68-70 4 列
const ICON_SCALE: float = 0.85          # 源 createIconWithAmount(id, 60) ≈ 60/72
# P1（2026-07-16）：UI 文案 cm.get_lstr 化（源 LSTR key，GameData.config 解析，fallback 中文兜底）。
const LSTR_TITLE_KEY: String = "mailoverfull.1.10.1.003"   # 源 uieditor/mailoverfull.lua:106
const TITLE_FALLBACK: String = "超额提醒"
const LSTR_DESC1_KEY: String = "overfull.1.10.1.001"       # 源 overfull.lua:43
const DESC1_FALLBACK: String = "部分道具将超出可携带上限(999个)。如果强行领取，将损失超出的道具。"
const LSTR_DESC2_KEY: String = "overfull.1.10.1.002"       # 源 overfull.lua:58
const DESC2_FALLBACK: String = "超出："
const LSTR_DESC3_KEY: String = "overfull.1.10.1.003"       # 源 overfull.lua:91
const DESC3_FALLBACK: String = "是否继续领取？"
const LSTR_LEFT_KEY: String = "mailoverfull.1.10.1.001"    # 源 uieditor:20
const LEFT_FALLBACK: String = "强行领取"
const LSTR_RIGHT_KEY: String = "mailoverfull.1.10.1.002"   # 源 uieditor:46
const RIGHT_FALLBACK: String = "稍后领取"

signal confirmed

var _items: Array = []
var _cm: Variant


# 源 LSTR 走 GameData.config（autoload）；未初始化（headless 测试）fallback 中文兜底。
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
	_build()


func _build() -> void:
	var frame_pos: Vector2 = Vector2(960.0 * 0.5 - FRAME_SIZE.x * 0.5, 640.0 * 0.5 - FRAME_SIZE.y * 0.5)
	var shade := ColorRect.new()
	shade.color = SHADE_COLOR
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var frame := TextureRect.new()
	frame.texture = load(FRAME_TEX)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # [[texture-rect-expand-ignore-size]]
	frame.size = FRAME_SIZE
	frame.position = frame_pos
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_add_title(frame)
	_add_content(frame)
	_add_buttons(frame)


func _add_title(frame: TextureRect) -> void:
	var title_bg := TextureRect.new()
	title_bg.texture = load(TITLE_BG_TEX)
	title_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_bg.size = Vector2(359.0, 12.0)
	title_bg.position = Vector2(frame.size.x * 0.5 - 179.5, 30.0)
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(title_bg)
	var title := Label.new()
	title.text = _lstr(LSTR_TITLE_KEY, TITLE_FALLBACK)
	title.position = Vector2(0.0, 20.0)
	title.size = Vector2(frame.size.x, 30.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font", 23)   # 源 uieditor size=23
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(title)


# 3 段说明 + 溢出物品 4 列网格（源 overfull.lua:28-110 ChaosNode 垂直排列）。
func _add_content(frame: TextureRect) -> void:
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(50.0, 65.0)
	vbox.custom_minimum_size = Vector2(frame.size.x - 100.0, 0.0)
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(vbox)
	vbox.add_child(_make_desc(_lstr(LSTR_DESC1_KEY, DESC1_FALLBACK), 16, true))
	vbox.add_child(_make_desc(_lstr(LSTR_DESC2_KEY, DESC2_FALLBACK), 18, false))
	var grid := GridContainer.new()
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
	var desc3 := _make_desc(_lstr(LSTR_DESC3_KEY, DESC3_FALLBACK), 18, false)
	desc3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc3)


func _make_desc(text: String, font: int, wrap: bool) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font", font)
	lbl.add_theme_color_override("font_color", DESC_COLOR)
	if wrap:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _add_buttons(frame: TextureRect) -> void:
	var btn_w: float = 121.0   # 源 uieditor scaleSize 121.09
	var btn_h: float = 55.0
	var gap: float = 20.0
	var left := TextureButton.new()
	left.texture_normal = load(BTN_TEX)
	left.texture_pressed = load(BTN_P_TEX)
	left.ignore_texture_size = true
	left.custom_minimum_size = Vector2(btn_w, btn_h)
	left.size = Vector2(btn_w, btn_h)
	left.position = Vector2(frame.size.x * 0.5 - btn_w - gap * 0.5, frame.size.y - 70.0)
	left.add_child(_make_btn_label(_lstr(LSTR_LEFT_KEY, LEFT_FALLBACK), Vector2(btn_w, btn_h)))
	left.pressed.connect(_on_left)
	frame.add_child(left)
	var right := TextureButton.new()
	right.texture_normal = load(BTN_TEX)
	right.texture_pressed = load(BTN_P_TEX)
	right.ignore_texture_size = true
	right.custom_minimum_size = Vector2(btn_w, btn_h)
	right.size = Vector2(btn_w, btn_h)
	right.position = Vector2(frame.size.x * 0.5 + gap * 0.5, frame.size.y - 70.0)
	right.add_child(_make_btn_label(_lstr(LSTR_RIGHT_KEY, RIGHT_FALLBACK), Vector2(btn_w, btn_h)))
	right.pressed.connect(_close)
	frame.add_child(right)


func _make_btn_label(text: String, sz: Vector2) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.size = sz
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font", 20)   # 源 uieditor size=20
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


# 源 overfull.lua:10-16 left_button clickHandler → leftCallback（继续领取）+ destroy。
func _on_left() -> void:
	emit_signal("confirmed")
	_close()


func _close() -> void:
	queue_free()
