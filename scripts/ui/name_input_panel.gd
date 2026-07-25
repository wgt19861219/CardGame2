class_name NameInputPanel
extends PopWindow

## 命名面板（View 层）— 照源 popwindow/bename.lua create :130-303。
## frame main_vit_tips 弹窗 + title + name_bg activate_input 输入框 + roll 骰子随机名 + ok/cancel sell_number_button。
## roll 随机名照源 affixcount 词库（bename.lua:9-16 rollName，affixcount.lua 5356 英文名 → AffixCount.json）。
## 重构（2026-07-18，照 hero_detail 范式）：frame/title/name_bg/Input/roll/ok/cancel 静态化进
## scenes/ui/name_input_content.tscn（位置/size 编辑器可视化）；运行时 fill LineEdit text（玩家名/roll 随机）+
## ok/cancel 套 UiScale9Button.apply_with_label 补九宫格（cap 15,22,15,25 照源 bename）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/name_input_content.tscn")
const TITLE_TEXT: String = "请为您的战队命名"
# Scale9 按钮样式（源 bename.lua :204/:251 sell_number_button，capInsets 15,22,15,25）。
const BTN_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button.png"
const BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button_down.png"
const BTN_CAP: Rect2 = Rect2(15.0, 22.0, 15.0, 25.0)
const BTN_LABEL_COLOR: Color = Color(235.0 / 255.0, 225.0 / 255.0, 205.0 / 255.0)
# roll 随机名照源 affixcount 词库（bename.lua:9-16 rollName，affixcount.lua 5356 英文名转 AffixCount.json）。
const AFFIXCOUNT_PATH: String = "res://resources/data/AffixCount.json"

var _pd: PlayerData
var _input: LineEdit
var _affixcount: Array = []


func setup_panel(p_pd: PlayerData) -> void:
	_pd = p_pd
	setup()
	_build_content()


# Phase A：panel 层从 .tscn instantiate（位置/size .tscn 固化）+ fill 动态数据 + Scale9 + 信号绑定。
func _build_content() -> void:
	_load_affixcount()
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	(content.get_node("%Title") as Label).text = TITLE_TEXT
	_input = content.get_node("%Input") as LineEdit
	_input.text = _pd.player_name
	(content.get_node("%RollBtn") as BaseButton).pressed.connect(_on_roll)
	var cancel: Button = content.get_node("%CancelBtn") as Button
	UiScale9Button.apply_with_label(cancel, BTN_RES, BTN_PRESS_RES, BTN_CAP, "取消", BTN_LABEL_COLOR)
	cancel.pressed.connect(remove_window)
	var ok: Button = content.get_node("%OkBtn") as Button
	UiScale9Button.apply_with_label(ok, BTN_RES, BTN_PRESS_RES, BTN_CAP, "确认", BTN_LABEL_COLOR)
	ok.pressed.connect(_on_confirm)


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


func _on_confirm() -> void:
	var new_name: String = _input.text.strip_edges()
	if new_name == "":
		Toast.show_message("名称不能为空")
		return
	_pd.set_player_name(new_name)
	GameData.mark_save_dirty()
	Toast.show_message("名称已修改")
	remove_window()
