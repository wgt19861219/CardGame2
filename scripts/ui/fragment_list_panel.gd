class_name FragmentListPanel
extends PopWindow

## 碎片合成列表入口（View 层）— 照源 package.lua 碎片段入口精神。
## 本项目无完整 package 背包（多 tab 装备/碎片/物品，完整复刻是后续独立任务），
## 简化为碎片合成专属列表：扫 PlayerData.hero_manager.fragments 反查 Fragment 表得有碎片的英雄，
## 点选弹 FragmentComposePanel。

const TITLE_POS: Vector2 = Vector2(380.0, 50.0)
const LIST_POS: Vector2 = Vector2(300.0, 100.0)
const LIST_SIZE: Vector2 = Vector2(360.0, 400.0)
const CLOSE_POS: Vector2 = Vector2(800.0, 50.0)
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-detail-close-p.png"
const LIST_SEPARATION: int = 8
const ROW_SEPARATION: int = 12
const ICON_SCALE: float = 0.6
const NAME_WIDTH: float = 180.0
const NAME_HEIGHT: float = 60.0

var cm: Variant = null
var pd: PlayerData = null
var _list: VBoxContainer = null


func setup_panel(p_cm: Variant, p_pd: PlayerData) -> void:
	cm = p_cm
	pd = p_pd
	setup()
	_build_ui()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "碎片合成"
	title.position = TITLE_POS
	container.add_child(title)
	_list = VBoxContainer.new()
	_list.position = LIST_POS
	_list.custom_minimum_size = LIST_SIZE
	_list.add_theme_constant_override("separation", LIST_SEPARATION)
	container.add_child(_list)
	_fill_list()
	var close: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, CLOSE_POS)   # 替原文字按钮（X 关闭弹窗，参照同表 fragmentcompose.lua:409 herodetail-detail-close）
	close.pressed.connect(remove_window)
	container.add_child(close)


func _fill_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var composables := _composable_tids()
	if composables.is_empty():
		var empty := Label.new()
		empty.text = "暂无碎片（酒馆抽卡可获得）"
		_list.add_child(empty)
		return
	for tid in composables:
		_list.add_child(_make_row(int(tid)))


# 有专属或通用碎片 → 列出该英雄（玩家可看合成进度）。
func _composable_tids() -> Array:
	var frag_table: Dictionary = cm.get_raw_table(&"Fragment")
	var owned: Dictionary = pd.hero_manager.fragments
	var tids: Array = []
	for tid_str in frag_table:
		var row: Dictionary = frag_table[tid_str]
		var frag_id := int(row.get("Fragment ID", 0))
		var uni_id := int(row.get("Universal Fragment ID", 0))
		if int(owned.get(frag_id, 0)) > 0 or int(owned.get(uni_id, 0)) > 0:
			tids.append(int(tid_str))
	tids.sort()
	return tids


func _make_row(tid: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	var icon: Control = ReadequipIcon.create_icon(tid, 0, cm)
	icon.scale = Vector2(ICON_SCALE, ICON_SCALE)
	row.add_child(icon)
	var name_lbl := Label.new()
	name_lbl.text = cm.get_lstr(String(cm.get_raw_table("Unit").get(str(tid), {}).get("Display Name", str(tid))))
	name_lbl.custom_minimum_size = Vector2(NAME_WIDTH, NAME_HEIGHT)
	row.add_child(name_lbl)
	var btn := Button.new()
	btn.text = "合成"
	btn.pressed.connect(func() -> void: _open_compose(tid))
	row.add_child(btn)
	return row


func _open_compose(tid: int) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var panel := FragmentComposePanel.new("fragmentcompose", {})
	panel.setup_panel(tid, cm, pd)
	panel.composed.connect(_refresh)
	panel.show_window(get_parent())


func _refresh() -> void:
	_fill_list()
