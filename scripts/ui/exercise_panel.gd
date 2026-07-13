class_name ExercisePanel
extends Control

## 试炼入口选择面板 — 照源 exercise.lua createExerciseButton(:1418) 翻译。
## 源在主场景背景上画 7 个入口按钮 + cavern（时光之穴/英雄试炼），本项目用独立弹窗。
## 7 入口：em(英雄副本 50005-7) / equip(装备副本 50001-4) / str/agi/int/exp/money(资源副本 20001-5)。
## 单机化裁剪：源开放日限制 checkExerciseEnabled 恒 true。

const ENTRY_KEYS: Array = [
	{key = "em", name = "英雄副本", groups = [50005, 50006, 50007]},
	{key = "equip", name = "装备副本", groups = [50001, 50002, 50003, 50004]},
	{key = "exp", name = "经验试炼", groups = [20001]},
	{key = "money", name = "金币试炼", groups = [20002]},
	{key = "int", name = "智力试炼", groups = [20003]},
	{key = "agi", name = "敏捷试炼", groups = [20004]},
	{key = "str", name = "力量试炼", groups = [20005]},
]

var _on_entry_selected: Callable  # 回调：func(key: String, groups: Array[int])


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func set_entry_callback(cb: Callable) -> void:
	_on_entry_selected = cb


func _build_ui() -> void:
	# 背景
	var bg := ColorRect.new(); bg.color = Color(0.1, 0.1, 0.15, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	# 标题
	var title := Label.new(); title.text = "试炼"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 20); title.size = Vector2(800, 30)
	title.add_theme_font_size_override("font_size", 24)
	add_child(title)
	# 关闭按钮
	var close := Button.new(); close.text = "×"; close.position = Vector2(750, 10); close.size = Vector2(40, 40)
	close.pressed.connect(queue_free); add_child(close)
	# 入口按钮列表（GridContainer 2 列）
	var grid := GridContainer.new(); grid.columns = 2
	grid.position = Vector2(200, 80); grid.size = Vector2(400, 300)
	for entry in ENTRY_KEYS:
		var btn := Button.new()
		btn.text = String(entry.name)
		btn.custom_minimum_size = Vector2(180, 50)
		btn.set_meta("entry", entry)
		btn.pressed.connect(_on_entry_pressed.bind(entry))
		grid.add_child(btn)
	add_child(grid)


func _on_entry_pressed(entry: Dictionary) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	if _on_entry_selected.is_valid():
		_on_entry_selected.call(String(entry.key), entry.groups)
	queue_free()
