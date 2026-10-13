class_name ActivitiesListPanel
extends PopWindow

## 运营活动列表面板（View 层）— 照源 ui/activitiesList.lua + activitiesListConfig.lua UIRes 翻译。
## 两件套（2026-10-13）：静态 chrome scenes/ui/activities_list_content.tscn；
## 数据行 activities_list_item.tscn 模板 fill（标题/描述）。
## 单机化：源 ask_activity_info 请求 → PlayerData.activity.get_activities 本地组装；
## 单机周常滚动生成无"已结束"组，节标题"进行中"常驻（源 splitInfo 只剩一组）。
## 行点击 → RebateActivitiesPanel 详情（源 ListClick → rebateActivities.create）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/activities_list_content.tscn")
const ITEM_SCENE: PackedScene = preload("res://scenes/ui/activities_list_item.tscn")

# 节标题行（源 itemConfig2 bgtitle 500x15 + titlename op_act_title 18）
const SECTION_HEIGHT: float = 25.0

var _player: PlayerData
var _cm: ConfigManager
var _content: Control = null
var _list_host: VBoxContainer = null
var _acts: Array = []


func setup_panel(p_player: PlayerData) -> void:
	_player = p_player
	_cm = _player.cm
	setup()
	_build_content()


func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	_list_host = _content.get_node("%ListHost") as VBoxContainer
	_refresh_view()


func _refresh_view() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	_acts = _player.activity.get_activities(now, _cm)
	for c in _list_host.get_children():
		_list_host.remove_child(c)
		c.queue_free()
	# 节标题（源 init :54-104 changeItemConfig(2) "进行中"）
	var section := Label.new()
	section.name = "SectionInProgress"
	section.custom_minimum_size = Vector2(490.0, SECTION_HEIGHT)
	section.theme_type_variation = &"ActSectionLabel"
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.text = _cm.get_lstr("ACTIVITIESLIST.IN_PROGRESS") if _cm != null else "进行中"
	_list_host.add_child(section)
	# 数据行（源 init changeItemConfig(1) {title..":", desc}）
	for i in range(_acts.size()):
		var act: Dictionary = _acts[i]
		var row := ITEM_SCENE.instantiate() as Control
		row.name = "ActRow%d" % i
		(row.get_node("%NameLabel") as Label).text = "%s:" % String(act.get("title", ""))
		(row.get_node("%DescLabel") as Label).text = String(act.get("desc", ""))
		_list_host.add_child(row)
		row.gui_input.connect(_on_row_gui_input.bind(i))


# 行点击开详情（源 ListClick :11-20 → rebateActivities.create(info)；eatexp 行手势同款）
func _on_row_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_open_detail(index)


func _open_detail(index: int) -> void:
	if index < 0 or index >= _acts.size():
		return
	var detail := RebateActivitiesPanel.new("rebate_activities", {})
	detail.setup_panel(_player, _acts[index])
	detail.show_window(self)
