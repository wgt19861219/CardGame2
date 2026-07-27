class_name ExercisePanel
extends Control

## 试炼入口选择面板（View 层）— 照源 exercise.lua createExerciseButton(:1418) 翻译。
##
## int+agi+str+dg1-4+cavern（时光之穴）入口。入口靠 FCA 动画 + descres 图（act_popup_title_X_1.png）
## 展示，无文字 Label（cavern 标签 :1459/1487 硬编码「英雄副本」/「时光之穴」，dungeon 名用
## ActStageGroupDungeon Group Name）。本项目为 main_scene 两个触发点（em/equip）聚合为单弹窗
## 选具体入口，文字标签为本聚合层可用性简化（源无对应 LSTR，照 :1459 硬编码先例保留中文）。
## 单机化裁剪：源公会等级/开放日 checkExerciseEnabled 恒 true。
##
## 重构（2026-07-18，hero_detail 范式）：chrome（bg/title/close/EntryGrid 容器）静态化进
## scenes/ui/exercise_content.tscn（位置/size 编辑器可视化调）；入口按钮数据驱动，
## 保留 procedural 挂 %EntryGrid（挂 meta + bind 回调）。panel 是 Control 非 PopWindow，
## content 挂 panel 自身（无 container 中间层）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/exercise_content.tscn")

# 入口 group ids 照源 exerciseres.lua entry_stage（:7-20）。name 照源 :1459 硬编码先例 + FCA 主题。
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
	# HudOverlay 切 identity=exercise（Control 非 PopWindow，无 setup_panel，从 GameData 取）。
	HudOverlay.apply_identity("exercise")


func _exit_tree() -> void:
	# exercise 是 Control 非 PopWindow，_exit_tree 恢复 HudOverlay identity=main。
	HudOverlay.apply_identity("main")


func set_entry_callback(cb: Callable) -> void:
	_on_entry_selected = cb


# 建 UI：chrome（bg/title/close/EntryGrid 容器）从 .tscn instantiate（位置/size 可视化），
# 入口按钮 procedural 挂 %EntryGrid（数据驱动，挂 meta + bind 回调）。
func _build_ui() -> void:
	var content := CONTENT_SCENE.instantiate()
	add_child(content)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(queue_free)
	var grid: GridContainer = content.get_node("%EntryGrid") as GridContainer
	for entry in ENTRY_KEYS:
		var btn := Button.new()
		btn.text = String(entry.name)
		btn.custom_minimum_size = Vector2(180, 50)
		btn.set_meta("entry", entry)
		btn.pressed.connect(_on_entry_pressed.bind(entry))
		grid.add_child(btn)


func _on_entry_pressed(entry: Dictionary) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	if _on_entry_selected.is_valid():
		_on_entry_selected.call(String(entry.key), entry.groups)
	queue_free()
