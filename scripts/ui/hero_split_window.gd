class_name HeroSplitWindow
extends PopWindow

## 英雄分解主窗口（View 层）— 两件套范式（批 1 Task 8，2026-08-15）。
## 静态树在 hero_split_window_content.tscn（照源 uieditor/herosplit.lua 声明表直译，
## 换算见 tscn 头注），本文件只做业务、信号 connect、fill。
## 单机化决策（2026-07-19 既有 + 本批裁剪清单见任务报告）：
## ① 选英雄不弹通用 selectwindow（基建缺失），改 HeroScroll 内联可分解英雄网格；
## ② 选碎片环节跳过（源联机 split_return 空壳；hero_manager.split 固定返还专属碎片）；
## ③ 详情组 visible 照源（未选隐藏 detail_container，选中显示）；
## ④ frame 贴图 hero_resolve_frame.png 源项目缺 → StyleBoxFlat 降级（rect 照源）。
## 流程：选英雄 → 详情组显示返还碎片预览 → 分解按钮 → HeroSplitConfirm（splitconfirm
## 语义）确认 → split → toast + 刷新 + split_done。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/hero_split_window_content.tscn")
const HERO_CELL_SIZE: Vector2 = Vector2(104.0, 104.0)   # ReadheroIcon CONTAINER_SIZE（源 readhero.lua:326）
# 文本（源 LSTR key，运行时 cm.get_lstr 解析）
const DETAIL_TITLE_KEY: String = "herosplit.1.10.1.003"
const GAIN_KEY: String = "herosplit.1.10.1.005"
const EXPLAIN_BTN_KEY: String = "herosplit.1.10.1.001"
const SPLIT_BTN_KEY: String = "heropackage.1.10.1.001"
const PLEASE_HERO_KEY: String = "EQUIPSTRENGTHEN.PLEASE_SELECT_HERO"
const SPLIT_DONE_KEY: String = "window.1.10.1.004"
const DETAIL_TITLE_FALLBACK: String = "分解详情"
const GAIN_FALLBACK: String = "你将获得："
const EXPLAIN_BTN_FALLBACK: String = "详细规则"
const SPLIT_BTN_FALLBACK: String = "分解"
const PLEASE_HERO_FALLBACK: String = "请选择英雄"
const SPLIT_DONE_FALLBACK: String = "分解成功"

signal split_done   # 分解完成（英雄被移除），调用方刷新列表

var cm: Variant = null
var pd: PlayerData = null
var _hero_mgr: HeroManager = null
var _selected: HeroInstance = null
var _content: Control = null
var _grid: GridContainer = null
var _return_host: Control = null
var _split_btn: Button = null
var _detail: Control = null


func setup_panel(hero_mgr: HeroManager, p_cm: Variant = null, p_pd: PlayerData = null) -> void:
	_hero_mgr = hero_mgr
	cm = p_cm
	pd = p_pd
	setup()
	_build_content()
	_fill_hero_grid()


# 绑定 .tscn 静态节点 + fill 静态文案（按钮三态样式走 theme variation，无运行时套样式）。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	_grid = _content.get_node("%GridHost") as GridContainer
	_return_host = _content.get_node("%ReturnHost") as Control
	_split_btn = _content.get_node("%DetailContainer/%SplitBtn") as Button
	_detail = _content.get_node("%DetailContainer") as Control
	(_content.get_node("%DetailContainer/TitleLabel") as Label).text = _lstr(DETAIL_TITLE_KEY, DETAIL_TITLE_FALLBACK)
	(_content.get_node("%DetailContainer/%Title2") as Label).text = _lstr(GAIN_KEY, GAIN_FALLBACK)
	(_content.get_node("%ExplainBtn") as Button).text = _lstr(EXPLAIN_BTN_KEY, EXPLAIN_BTN_FALLBACK)
	_split_btn.text = _lstr(SPLIT_BTN_KEY, SPLIT_BTN_FALLBACK)
	_split_btn.pressed.connect(_on_split_pressed)
	(_content.get_node("%ExplainBtn") as Button).pressed.connect(_on_explain_pressed)
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(_on_close_pressed)


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
	_detail.visible = true   # 源 setSplitStone detail_container:setVisible(true)
	_refresh_return_preview()


# 返还预览（单机化 preview_split 固定返还专属碎片）；未选/清选时详情组隐藏照源。
# icon 位置照源 scrollview oriPosition DGccp(240,200) → 裁剪区局部 (6.25,80.47)。
const RETURN_ICON_POS: Vector2 = Vector2(6.25, 80.47)


func _refresh_return_preview() -> void:
	for c in _return_host.get_children():
		c.free()
	if _selected == null:
		_detail.visible = false
		return
	var preview: Dictionary = _hero_mgr.preview_split(_selected.inst_id)
	var frag_id: int = int(preview.get("fragment_id", 0))
	var count: int = int(preview.get("count", 0))
	var icon: Control = ReadequipIcon.create_hero_stone_icon(frag_id, count, cm)
	icon.position = RETURN_ICON_POS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_return_host.add_child(icon)


func _on_split_pressed() -> void:
	if _selected == null:
		Toast.show_message(_lstr(PLEASE_HERO_KEY, PLEASE_HERO_FALLBACK))
		return
	var confirm := HeroSplitConfirm.new()
	confirm.setup(_selected, cm)
	confirm.confirmed.connect(_perform_split)
	get_parent().add_child(confirm)   # HeroSplitConfirm 是 Control（自带 shade），挂同 parent


func _perform_split() -> void:
	if _selected == null:
		return
	var result: Dictionary = _hero_mgr.split(_selected.inst_id)
	if result.has("fragment_id"):
		GameData.save()   # 分解移除英雄+返碎片后即时存（同召唤 _do_summon 判例；HeroManager 写操作
		# 无 save_hook，View 层漏存则 60s 窗口内进程被杀读档回滚，2026-09-17 同根因一并修）。
		Toast.show_message(_lstr(SPLIT_DONE_KEY, SPLIT_DONE_FALLBACK))
		_selected = null
		_fill_hero_grid()
		_refresh_return_preview()
		split_done.emit()


func _on_explain_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var explain := HeroSplitExplain.new()
	explain.setup(cm)
	get_parent().add_child(explain)


func _on_close_pressed() -> void:
	AudioPlayer.play_sfx("common_close_popup_window")
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
