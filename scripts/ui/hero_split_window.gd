class_name HeroSplitWindow
extends PopWindow

## 英雄分解主窗口（View 层）— 务实方案（2026-07-19）。
## 照源 ui/herosplit/window.lua，单机化简化：
## ① 选英雄不弹通用 selectwindow（目标侧缺失基建），改 HeroScroll 内联可分解英雄网格（Control cell 包 ReadheroIcon）
## ② 选碎片环节跳过（源联机 split_return 在 local_server 空壳；hero_manager.split 固定返还 Convert Fragments 专属碎片）
## ③ 联机 split_data/split_return/split_hero → 本地 hero_manager.preview_split/split
## frame 背景 hero_resolve_frame.png 源项目缺 → 降级 Panel + StyleBoxFlat。
## 流程：选英雄 → 显示返还碎片预览 → 分解按钮 → HeroSplitConfirm 二次确认（补 name）→ split → toast + 刷新。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/hero_split_window_content.tscn")
const HERO_CELL_SIZE: Vector2 = Vector2(104.0, 104.0)   # ReadheroIcon CONTAINER_SIZE（源 readhero.lua:326）
# 按钮 Scale9（源 uieditor/herosplit：sell_number_button/task_button + capInsets 照源）。
const BTN_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button.png"
const BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/sell_number_button_down.png"
const BTN_CAP: Rect2 = Rect2(15.63, 15.63, 19.53, 19.53)
const SPLIT_BTN_RES: String = "res://assets/ui/alpha/HVGA/task_button.png"
const SPLIT_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/task_button_press.png"
const SPLIT_BTN_CAP: Rect2 = Rect2(15.63, 15.63, 39.06, 15.63)
const BTN_LABEL_COLOR: Color = Color(234.0 / 255.0, 225.0 / 255.0, 205.0 / 255.0)
# 源 LSTR key（uieditor/herosplit + window.lua）。
const DETAIL_TITLE_KEY: String = "herosplit.1.10.1.003"
const GAIN_KEY: String = "herosplit.1.10.1.005"
const EXPLAIN_BTN_KEY: String = "herosplit.1.10.1.001"
const SPLIT_BTN_KEY: String = "heropackage.1.10.1.001"
const CONFIRM_MSG_KEY: String = "window.1.10.1.003"
const PLEASE_HERO_KEY: String = "EQUIPSTRENGTHEN.PLEASE_SELECT_HERO"
const SPLIT_DONE_KEY: String = "window.1.10.1.004"
const DETAIL_TITLE_FALLBACK: String = "分解详情"
const GAIN_FALLBACK: String = "你将获得："
const EXPLAIN_BTN_FALLBACK: String = "详细规则"
const SPLIT_BTN_FALLBACK: String = "分解"
const CONFIRM_MSG_FALLBACK: String = "是否确认分解英雄%s？"
const PLEASE_HERO_FALLBACK: String = "请选择英雄"
const SPLIT_DONE_FALLBACK: String = "分解成功"

signal split_done   # 分解完成（英雄被移除），调用方刷新列表

var cm: Variant = null
var pd: PlayerData = null
var _hero_mgr: HeroManager = null
var _selected: HeroInstance = null
var _grid: GridContainer = null
var _return_host: Control = null
var _split_btn: Button = null


func setup_panel(hero_mgr: HeroManager, p_cm: Variant = null, p_pd: PlayerData = null) -> void:
	_hero_mgr = hero_mgr
	cm = p_cm
	pd = p_pd
	setup()
	_build_content()
	_fill_hero_grid()


func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	_grid = content.get_node("%GridHost") as GridContainer
	_return_host = content.get_node("%ReturnHost") as Control
	_split_btn = content.get_node("%SplitBtn") as Button
	# 按钮 Scale9（.tscn 普通 Button，运行时套 StyleBox 补九宫格图，照 hero_package 范式）。
	UiScale9Button.apply_with_label(_split_btn, SPLIT_BTN_RES, SPLIT_BTN_PRESS_RES, SPLIT_BTN_CAP, _lstr(SPLIT_BTN_KEY, SPLIT_BTN_FALLBACK), BTN_LABEL_COLOR)
	var explain_btn: Button = content.get_node("%ExplainBtn") as Button
	UiScale9Button.apply_with_label(explain_btn, BTN_RES, BTN_PRESS_RES, BTN_CAP, _lstr(EXPLAIN_BTN_KEY, EXPLAIN_BTN_FALLBACK), BTN_LABEL_COLOR)
	_split_btn.pressed.connect(_on_split_pressed)
	explain_btn.pressed.connect(_on_explain_pressed)
	_split_btn.disabled = true   # 未选英雄禁用（源 firstConfirm 无 hid 守卫）
	(content.get_node("%CloseBtn") as TextureButton).pressed.connect(_on_close_pressed)
	(content.get_node("%DetailTitleLabel") as Label).text = _lstr(DETAIL_TITLE_KEY, DETAIL_TITLE_FALLBACK)
	(content.get_node("%GainLabel") as Label).text = _lstr(GAIN_KEY, GAIN_FALLBACK)


# 源 getSplitableHeroes（单机化：所有已拥有英雄可分解；源联机 split_data 在 local_server 空壳）。
func _fill_hero_grid() -> void:
	for c in _grid.get_children():
		c.free()
	var heroes: Array = _hero_mgr.heroes.values()
	for hero in heroes:
		var h: HeroInstance = hero as HeroInstance
		_grid.add_child(_create_hero_cell(h))


# ReadheroIcon 是 Node2D（无 gui_input），Control wrapper 处理布局 + 点击。
func _create_hero_cell(hero: HeroInstance) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = HERO_CELL_SIZE
	cell.add_child(ReadheroIcon.create_icon_by_hero(hero, cm))
	cell.gui_input.connect(_on_hero_icon_gui_input.bind(hero))
	return cell


func _on_hero_icon_gui_input(event: InputEvent, hero: HeroInstance) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_select_hero(hero)


func _select_hero(hero: HeroInstance) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	_selected = hero
	_refresh_return_preview()
	_split_btn.disabled = false


# 源 setSplitStone 返还详情（单机化：preview_split 算 fragment_id/count，ReadequipIcon 显示碎片 icon）。
func _refresh_return_preview() -> void:
	for c in _return_host.get_children():
		c.free()
	if _selected == null:
		return
	var preview: Dictionary = _hero_mgr.preview_split(_selected.inst_id)
	var frag_id: int = int(preview.get("fragment_id", 0))
	var count: int = int(preview.get("count", 0))
	_return_host.add_child(ReadequipIcon.create_hero_stone_icon(frag_id, count, cm))


# 源 firstConfirm（window.lua:88-103）：校验已选 → popConfirmDialog "确认分解 {name}？"。
func _on_split_pressed() -> void:
	if _selected == null:
		Toast.show_message(_lstr(PLEASE_HERO_KEY, PLEASE_HERO_FALLBACK))
		return
	var msg: String = _lstr(CONFIRM_MSG_KEY, CONFIRM_MSG_FALLBACK) % _hero_display_name(_selected)
	var confirm := HeroSplitConfirm.new()
	confirm.set_message(msg)
	confirm.confirmed.connect(_perform_split)
	get_parent().add_child(confirm)   # HeroSplitConfirm 是 Control（自带 shade），挂同 parent


# 源 secondConfirm → doSplit（单机化：hero_manager.split 本地执行，源联机 split_hero）。
func _perform_split() -> void:
	if _selected == null:
		return
	var result: Dictionary = _hero_mgr.split(_selected.inst_id)
	if result.has("fragment_id"):
		Toast.show_message(_lstr(SPLIT_DONE_KEY, SPLIT_DONE_FALLBACK))
		_selected = null
		_fill_hero_grid()
		_refresh_return_preview()
		_split_btn.disabled = true
		split_done.emit()


func _on_explain_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var explain := HeroSplitExplain.new()
	explain.setup(cm)
	get_parent().add_child(explain)


func _on_close_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	remove_window()


func _hero_display_name(hero: HeroInstance) -> String:
	if cm == null:
		return str(hero.tid)
	var unit: Dictionary = cm.get_raw_table(&"Unit").get(str(hero.tid), {})
	var name_key: String = String(unit.get(&"Display Name", ""))
	if name_key == "":
		return str(hero.tid)
	return str(cm.get_lstr(name_key))


func _lstr(key: String, fallback: String) -> String:
	return str(cm.get_lstr(key)) if cm != null else fallback
