class_name EquipboardOfbuyPanel
extends PopWindow

## 装备购买确认浮层（View 层）— 照源 ui/equipboard/ofbuy.lua（202 行）。
## shop 商品点击购买时弹出，显示 icon + name + 购买数量 + 货币图标 + 总价 + 确认按钮。
## 单机化：源 param.doBuy 闭包 → confirmed 信号（ShopPanel 连接执行 shop_mgr.buy）。

signal confirmed()

const FRAME_RES: String = "res://assets/ui/alpha/HVGA/package_detail_bg.png"
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png"
const BTN_NORMAL_RES: String = "res://assets/ui/alpha/HVGA/package_button.png"
const BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/package_button_down.png"
const BTN_CAP: Rect2 = Rect2(10.0, 10.0, 236.0, 29.0)
const MONEY_BG_RES: String = "res://assets/ui/alpha/HVGA/sell_number_bg.png"
const FRAME_SIZE: Vector2 = Vector2(288.0, 385.0)
const BTN_SIZE: Vector2 = Vector2(150.0, 45.0)
const MONEY_BG_SIZE: Vector2 = Vector2(155.0, 36.0)
const MONEY_ICON_SIZE: Vector2 = Vector2(28.0, 28.0)
const CLOSE_SIZE: Vector2 = Vector2(30.0, 30.0)
const LSTR_PURCHASE: String = "EQUIPINFO.PURCHASE"
const LSTR_ITEM: String = "EQUIPINFO.ITEM"
const LSTR_CONFIRM: String = "EQUIPINFO.CONFIRM_PURCHASE"

# frame_h=385；Godot y = frame_h - cocos_y。源 anchor 0,0.5（左中）→ Godot 左上 y - h/2。
const ICON_TOPLEFT: Vector2 = Vector2(14.0, 21.0)
const ICON_SCALE: float = 0.8   # 与 EquipboardPanel 一致（用户视觉偏好，源 createIcon 无 scale）
const NAME_POS: Vector2 = Vector2(92.0, 25.0)
const NAME_SIZE: Vector2 = Vector2(208.0, 30.0)
const AMOUNT_TITLE_POS: Vector2 = Vector2(25.0, 285.0)
const AMOUNT_TITLE_W: float = 60.0
const MONEY_Y: float = 285.0
const MONEY_ICON_POS: Vector2 = Vector2(131.0, 271.0)
const MONEY_LABEL_POS: Vector2 = Vector2(200.0, 285.0)
const BTN_TOPLEFT: Vector2 = Vector2(72.0, 322.5)
const CLOSE_TOPLEFT: Vector2 = Vector2(271.0, 12.0)

const NAME_COLOR: Color = Color(66.0 / 255.0, 45.0 / 255.0, 28.0 / 255.0, 1.0)
const TITLE_COLOR: Color = Color(67.0 / 255.0, 59.0 / 255.0, 56.0 / 255.0, 1.0)
const AMOUNT_COLOR: Color = Color(0.0, 71.0 / 255.0, 188.0 / 255.0, 1.0)
const BTN_LABEL_COLOR: Color = Color(234.0 / 255.0, 225.0 / 255.0, 205.0 / 255.0)
const LINE_H: float = 20.0   # 行高（Label vertical center 等高）

var cm: Variant = null
var _frame: Control = null
var _param: Dictionary = {}


func setup_panel(p_param: Dictionary, p_cm: Variant) -> void:
	_param = p_param
	cm = p_cm
	setup()
	if shade_layer != null:
		shade_layer.color.a = 0.4
		shade_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_build_content()
	register_on_enter(func() -> void: AudioPlayer.play_sfx("common_popup_window"))


func _build_content() -> void:
	_frame = Control.new()
	_frame.size = FRAME_SIZE
	# 屏幕居中（960×640，源 frame 中心 ccp(400,240) 近屏幕中心）
	_frame.position = Vector2((960.0 - FRAME_SIZE.x) * 0.5, (640.0 - FRAME_SIZE.y) * 0.5)
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP   # frame 区域吞点击（btRegisterOutClick out_click 关闭）
	container.add_child(_frame)
	_add_texture(_frame, FRAME_RES, Vector2.ZERO, FRAME_SIZE)
	_add_close_button()
	_add_icon()
	_add_name()
	_add_amount_row()
	_add_money_row()
	_add_confirm_button()


func _add_close_button() -> void:
	var close := TextureButton.new()
	close.texture_normal = load(CLOSE_RES) as Texture2D
	close.texture_pressed = load(CLOSE_PRESS_RES) as Texture2D
	close.position = CLOSE_TOPLEFT
	close.size = CLOSE_SIZE
	close.mouse_filter = Control.MOUSE_FILTER_STOP
	close.pressed.connect(_on_close)
	_frame.add_child(close)


func _add_icon() -> void:
	var icon: Control = ReadequipIcon.create_icon(int(_param.get("id", 0)), 0, cm)
	icon.position = ICON_TOPLEFT
	icon.scale = Vector2(ICON_SCALE, ICON_SCALE)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(icon)


func _add_name() -> void:
	var lbl := Label.new()
	lbl.text = _equip_name()
	lbl.position = NAME_POS
	lbl.size = NAME_SIZE
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", NAME_COLOR)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(lbl)


func _add_amount_row() -> void:
	var title := Label.new()
	title.text = String(cm.get_lstr(LSTR_PURCHASE))
	title.position = AMOUNT_TITLE_POS
	title.size = Vector2(AMOUNT_TITLE_W, LINE_H)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(title)
	var amount: int = int(_param.get("amount", 1))
	var amt := Label.new()
	amt.text = str(amount)
	amt.position = Vector2(AMOUNT_TITLE_POS.x + AMOUNT_TITLE_W + 5.0, AMOUNT_TITLE_POS.y)
	amt.size = Vector2(30.0, LINE_H)
	amt.add_theme_font_size_override("font_size", 16)
	amt.add_theme_color_override("font_color", AMOUNT_COLOR)
	amt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(amt)
	var suf := Label.new()
	suf.text = String(cm.get_lstr(LSTR_ITEM))
	suf.position = Vector2(amt.position.x + 30.0, AMOUNT_TITLE_POS.y)
	suf.size = Vector2(60.0, LINE_H)
	suf.add_theme_font_size_override("font_size", 18)
	suf.add_theme_color_override("font_color", TITLE_COLOR)
	suf.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	suf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(suf)


func _add_money_row() -> void:
	_add_texture(_frame, MONEY_BG_RES, Vector2(115.0, MONEY_Y - MONEY_BG_SIZE.y * 0.5), MONEY_BG_SIZE)
	var pay: String = String(_param.get("pay", "gold"))
	_add_texture(_frame, _pay_icon_path(pay), MONEY_ICON_POS, MONEY_ICON_SIZE)
	var cost: int = int(_param.get("cost", 0))
	var lbl := Label.new()
	lbl.text = str(cost)
	lbl.position = MONEY_LABEL_POS
	lbl.size = Vector2(80.0, LINE_H)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(lbl)


func _add_confirm_button() -> void:
	var btn: Button = UiScale9Button.make(BTN_NORMAL_RES, BTN_PRESS_RES, BTN_TOPLEFT, BTN_SIZE, BTN_CAP,
		String(cm.get_lstr(LSTR_CONFIRM)), BTN_LABEL_COLOR)
	btn.pressed.connect(_on_confirm)
	_frame.add_child(btn)


func _on_close() -> void:
	AudioPlayer.play_sfx("common_close_popup_window")
	remove_window()


func _on_confirm() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	confirmed.emit()
	remove_window()


func _equip_name() -> String:
	var item_id: int = int(_param.get("id", 0))
	var row: Dictionary = cm.get_raw_table(&"Equip").get(str(item_id), {})
	var raw_name: String = String(row.get(&"Name", str(item_id)))
	var amount: int = int(_param.get("amount", 1))
	return raw_name + "x" + str(amount) if amount > 1 else raw_name


func _pay_icon_path(pay: String) -> String:
	return MarketConfig.UI_DIR + MarketConfig.get_coin_res(pay)


func _add_texture(parent: Control, path: String, pos: Vector2, sz: Vector2) -> void:
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return
	var tr := TextureRect.new()
	tr.texture = tex
	tr.position = pos
	tr.size = sz
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
