class_name NameInputPanel
extends PopWindow

## 命名面板（View 层）— 照源 popwindow/bename.lua create :130-303。
## frame main_vit_tips 弹窗 + title + name_bg activate_input 输入框 + roll 骰子随机名 + ok/cancel sell_number_button。
## roll 随机名照源 affixcount 词库（bename.lua:9-16 rollName，affixcount.lua 5356 英文名 → AffixCount.json）。
## 坐标照源 frame 内（源 ccp y向上 → Godot frame 内 y_down = 180 - y_up）+ frame 中心 midas _to_godot(400,355)=(480,205)。

const FRAME_TEX: String = "res://assets/ui/alpha/HVGA/main_vit_tips.png"
const FRAME_SIZE: Vector2 = Vector2(355.0, 180.0)
const FRAME_POS: Vector2 = Vector2(303.0, 115.0)  # 源 frame 中心 ccp(400,355) → _to_godot(480,205) → 左上
const TITLE_TEXT: String = "请为您的战队命名"  # 源 :151 BENAME.A_NAME_FOR_YOUR_TEAM
const TITLE_POS: Vector2 = Vector2(30.0, 18.0)  # 源 ccp(30,150) anchor 0,0.5 左中 → frame 内左上
const NAME_BG_TEX: String = "res://assets/ui/alpha/HVGA/activate_input.png"
const NAME_BG_SIZE: Vector2 = Vector2(235.0, 42.0)  # 源 name_bg scaleSize
const NAME_BG_POS: Vector2 = Vector2(30.0, 64.0)  # 源 ccp(30,95) anchor 0,0.5 → 左上
const INPUT_INSET: float = 8.0
const ROLL_RES: String = "res://assets/ui/alpha/HVGA/naming_button_roll_1.png"
const ROLL_PRESS_RES: String = "res://assets/ui/alpha/HVGA/naming_button_roll_2.png"
const ROLL_POS: Vector2 = Vector2(269.0, 55.0)  # 源 roll 中心 ccp(300,95) → 左上
const BTN_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button.png"
const BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button_down.png"
const BTN_CAP: Rect2 = Rect2(15.0, 22.0, 15.0, 25.0)  # 源 bename :204/:251 sell_number_button capInsets
const BTN_LABEL_COLOR: Color = Color(235.0 / 255.0, 225.0 / 255.0, 205.0 / 255.0)  # 源 ccc3(235,225,205)
const BTN_SIZE: Vector2 = Vector2(110.0, 45.0)  # 源 ok/cancel scaleSize
const CANCEL_POS: Vector2 = Vector2(60.0, 123.0)  # 源 cancel 中心 ccp(115,35) → 左上
const OK_POS: Vector2 = Vector2(180.0, 123.0)  # 源 ok 中心 ccp(235,35) → 左上
const MAX_NAME_LEN: int = 12
# roll 随机名照源 affixcount 词库（bename.lua:9-16 rollName，affixcount.lua 5356 英文名转 AffixCount.json）。
const AFFIXCOUNT_PATH: String = "res://resources/data/AffixCount.json"

var _pd: PlayerData
var _input: LineEdit
var _affixcount: Array = []


func setup_panel(p_pd: PlayerData) -> void:
	_pd = p_pd
	setup()
	_build_ui()


func _build_ui() -> void:
	_load_affixcount()
	var frame := TextureRect.new()
	frame.texture = load(FRAME_TEX)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # [[texture-rect-expand-ignore-size]]
	frame.size = FRAME_SIZE
	frame.position = FRAME_POS
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(frame)
	var title := Label.new()
	title.text = TITLE_TEXT
	title.position = TITLE_POS
	title.add_theme_font_size_override("font", 20)  # 源 :152 size 20
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(title)
	var name_bg := TextureRect.new()
	name_bg.texture = load(NAME_BG_TEX)
	name_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	name_bg.size = NAME_BG_SIZE
	name_bg.position = NAME_BG_POS
	name_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(name_bg)
	_input = LineEdit.new()
	_input.position = NAME_BG_POS + Vector2(INPUT_INSET, INPUT_INSET)
	_input.size = NAME_BG_SIZE - Vector2(INPUT_INSET * 2.0, INPUT_INSET * 2.0)
	_input.max_length = MAX_NAME_LEN
	_input.text = _pd.player_name
	frame.add_child(_input)
	# roll 骰子按钮（源 :176 naming_button_roll_1 + :187 roll_2 press）。
	var roll: TextureButton = UiButton.make_at(ROLL_RES, ROLL_PRESS_RES, ROLL_POS)
	roll.pressed.connect(_on_roll)
	frame.add_child(roll)
	# ok/cancel（源 :199/:246 sell_number_button，frame 内底部）。
	var cancel: Button = UiScale9Button.make(BTN_RES, BTN_PRESS_RES, CANCEL_POS, BTN_SIZE, BTN_CAP, "取消", BTN_LABEL_COLOR)
	cancel.pressed.connect(remove_window)
	frame.add_child(cancel)
	var ok: Button = UiScale9Button.make(BTN_RES, BTN_PRESS_RES, OK_POS, BTN_SIZE, BTN_CAP, "确认", BTN_LABEL_COLOR)
	ok.pressed.connect(_on_confirm)
	frame.add_child(ok)


# 源 bename.lua:9-16 rollName（affixcount 随机取名）。AffixCount.json = affixcount.lua 5356 英文名转。
func _load_affixcount() -> void:
	var f := FileAccess.open(AFFIXCOUNT_PATH, FileAccess.READ)
	if f == null:
		return
	_affixcount = JSON.parse_string(f.get_as_text())
	f.close()


func _on_roll() -> void:
	if _affixcount.is_empty():
		return
	_input.text = String(_affixcount[randi_range(0, _affixcount.size() - 1)])


# 源 :383 doSetName 校验非空 + dirtyword → set_name。目标简化 set_player_name（第十三批简化沿用）。
func _on_confirm() -> void:
	var new_name: String = _input.text.strip_edges()
	if new_name == "":
		Toast.show_message("名称不能为空")
		return
	_pd.set_player_name(new_name)
	Toast.show_message("名称已修改")
	remove_window()
