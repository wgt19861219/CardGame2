class_name ExcavateGiveupPanel
extends PopWindow

## 放弃矿点确认（View 层）— 照源 ui/excavate/giveup.lua pop:3。
## 显示已产出资源 + 确认放弃 → ExcavateManager.drop 结算（照 doGiveup:681）。
## 单机简化：源掠夺比例 Loot Ratio（其他人抢夺）裁剪，实得=全额产出。

const FRAME_TEX: String = "res://assets/ui/alpha/HVGA/excavate/excavate_main_frame.png"
const FRAME_W: float = 420.0
const FRAME_H: float = 240.0
const FONT_TITLE: int = 22
const FONT_BODY: int = 18
const TITLE_TEXT: String = "放弃矿点"
const CONFIRM_TEXT: String = "确认放弃"
const CANCEL_TEXT: String = "取消"
# 源 confirmdialog.lua popConfirmDialog（giveup.lua:132）sell_number_button Scale9 capInsets 15.63,15.63,19.53,15.63 + 浅金 ccc3(234,225,205)。
const SELL_BTN_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button.png"
const SELL_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button_down.png"
const SELL_BTN_CAP: Rect2 = Rect2(15.63, 15.63, 19.53, 15.63)
const BTN_LABEL_COLOR: Color = Color(234.0 / 255.0, 225.0 / 255.0, 205.0 / 255.0)
const BODY_TEXT: String = "放弃后将立即结算已产出资源："

var pd: PlayerData
var _excavate_id: int
var _on_confirmed: Callable


func setup_panel(p_pd: PlayerData, excavate_id: int, on_confirmed: Callable) -> void:
	pd = p_pd
	_excavate_id = excavate_id
	_on_confirmed = on_confirmed
	setup()
	_build_ui()


func _build_ui() -> void:
	var frame := TextureRect.new()
	frame.texture = load(FRAME_TEX)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # [[texture-rect-expand-ignore-size]]
	frame.size = Vector2(FRAME_W, FRAME_H)
	frame.position = Vector2(960.0 * 0.5 - FRAME_W * 0.5, 640.0 * 0.5 - FRAME_H * 0.5)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(frame)
	var title := Label.new()
	title.text = TITLE_TEXT
	title.position = Vector2(0, 15)
	title.size = Vector2(FRAME_W, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font", FONT_TITLE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(title)
	var now: int = int(Time.get_unix_time_from_system())
	var amount: int = pd.excavate.produce_amount(_excavate_id, now)
	var type_id: int = int(pd.excavate.get_data(_excavate_id).get("_type_id", 0))
	var body := Label.new()
	body.text = BODY_TEXT + str(amount) + " " + _type_name(type_id)
	body.position = Vector2(30, 70)
	body.size = Vector2(FRAME_W - 60, 60)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font", FONT_BODY)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(body)
	_add_buttons(frame)


func _add_buttons(frame: TextureRect) -> void:
	var cancel: Button = UiScale9Button.make(SELL_BTN_RES, SELL_BTN_PRESS_RES, Vector2(FRAME_W * 0.25 - 60.0, FRAME_H - 55.0), Vector2(120.0, 36.0), SELL_BTN_CAP, CANCEL_TEXT, BTN_LABEL_COLOR)
	cancel.pressed.connect(remove_window)
	frame.add_child(cancel)
	var confirm: Button = UiScale9Button.make(SELL_BTN_RES, SELL_BTN_PRESS_RES, Vector2(FRAME_W * 0.75 - 60.0, FRAME_H - 55.0), Vector2(120.0, 36.0), SELL_BTN_CAP, CONFIRM_TEXT, BTN_LABEL_COLOR)
	confirm.pressed.connect(_on_confirm_pressed)
	frame.add_child(confirm)


func _on_confirm_pressed() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var amount: int = pd.excavate.drop(_excavate_id, now)
	if _on_confirmed.is_valid():
		_on_confirmed.call(amount)
	remove_window()


func _type_name(type_id: int) -> String:
	match ExcavateData.produce_type(pd.cm, type_id):
		ExcavateData.PRODUCE_DIAMOND:
			return "钻石"
		ExcavateData.PRODUCE_GOLD:
			return "金币"
		ExcavateData.PRODUCE_ITEM:
			return "经验药水"
	return ""
