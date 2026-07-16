class_name ExercisePanel
extends Control

## 试炼入口选择面板（View 层）— 照源 exercise.lua createExerciseButton(:1418) 翻译。
##
## 源结构（exerciseres.lua）：em 场景 = exp+money+cavern（英雄副本）入口；equip 场景 =
## int+agi+str+dg1-4+cavern（时光之穴）入口。入口靠 FCA 动画 + descres 图（act_popup_title_X_1.png）
## 展示，无文字 Label（cavern 标签 :1459/1487 硬编码「英雄副本」/「时光之穴」，dungeon 名用
## ActStageGroupDungeon Group Name）。本项目为 main_scene 两个触发点（em/equip）聚合为单弹窗
## 选具体入口，文字标签为本聚合层可用性简化（源无对应 LSTR，照 :1459 硬编码先例保留中文）。
## 单机化裁剪：源公会等级/开放日 checkExerciseEnabled 恒 true。

# 入口 group ids 照源 exerciseres.lua entry_stage（:7-20）。name 照源 :1459 硬编码先例 + FCA 主题。
const ENTRY_KEYS: Array = [
	{key = "em", name = "英雄副本", groups = [50005, 50006, 50007]},       # 源 :1459 cavern 硬编码
	{key = "equip", name = "装备副本", groups = [50001, 50002, 50003, 50004]},  # 源 equip 场景 4 dungeon
	{key = "exp", name = "经验试炼", groups = [20001]},                     # 源 exp 入口 FCA NagaPriest
	{key = "money", name = "金币试炼", groups = [20002]},                   # 源 money 入口 FCA Tank
	{key = "int", name = "智力试炼", groups = [20003]},                     # 源 int 入口 FCA Golem
	{key = "agi", name = "敏捷试炼", groups = [20004]},                     # 源 agi 入口 FCA DragonBaby
	{key = "str", name = "力量试炼", groups = [20005]},                     # 源 str 入口 FCA DR/Ench/WR
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
	# 标题（源 exercise 场景无文字标题 LSTR，靠 descres 图 act_popup_title 展示，本弹窗加文字标识）
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
