class_name ExercisePanel
extends Control

## 试炼入口选择面板（View 层）— 源 exercise.lua。
##
## 框架（蒙层/frame/close/title）照源 degreeWindow.create(:694-786) 直译进
## scenes/ui/exercise_content.tscn；7 入口按钮为聚合层发明（源主场景 createExerciseButton(:1418)
## 是 FCA 动画入口，em/equip 两触发点直进 dungeon_map，无按钮对应物），本项目聚合为单弹窗
## 选具体入口。文字标签为本聚合层可用性简化（源无对应 LSTR，照 :1459 硬编码先例保留中文）。
## 单机化裁剪：源公会等级/开放日 checkExerciseEnabled 恒 true。
##
## 两件套范式（批 1 Task 1，2026-08-15）：完整静态树进 content tscn（无脚本），
## 本文件只做业务 + 信号 connect（零静态节点构造）。panel 是 Control 非 PopWindow，
## content 挂 panel 自身（无 container 中间层）。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/exercise_content.tscn")

# 入口 group ids 照源 exerciseres.lua entry_stage(:7-20)；btn 指向 tscn 静态按钮（%唯一名）。
# 按钮文字进 tscn（静态树单一来源），此处只留 key→groups→按钮 的绑定映射。
const ENTRY_KEYS: Array = [
	{key = "em", groups = [50005, 50006, 50007], btn = "%EmBtn"},
	{key = "equip", groups = [50001, 50002, 50003, 50004], btn = "%EquipBtn"},
	{key = "exp", groups = [20001], btn = "%ExpBtn"},
	{key = "money", groups = [20002], btn = "%MoneyBtn"},
	{key = "int", groups = [20003], btn = "%IntBtn"},
	{key = "agi", groups = [20004], btn = "%AgiBtn"},
	{key = "str", groups = [20005], btn = "%StrBtn"},
]

var _on_entry_selected: Callable  # 回调：func(key: String, groups: Array[int])
var _prev_identity: String = ""   # 打开前 HudOverlay identity（_exit_tree 恢复用）


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var content := CONTENT_SCENE.instantiate() as Control
	add_child(content)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(queue_free)
	for entry in ENTRY_KEYS:
		var btn := content.get_node(String(entry.btn)) as BaseButton
		btn.pressed.connect(_on_entry_pressed.bind(entry))
	# HudOverlay 切 identity=exercise（Control 非 PopWindow，无 setup_panel，从 GameData 取）。
	# 先记录打开前 identity（task 快跳反射链进来时为 "task"），关闭恢复该值而非硬编码 main，
	# 否则外层面板还在显示时 main 版含头像 HUD 顶层恢复 → 头像透显（2026-08-20 排查轮）。
	_prev_identity = HudOverlay.get_identity()
	HudOverlay.apply_identity("exercise")


func _exit_tree() -> void:
	# 恢复打开前 identity；仅当 identity 仍归 exercise 时恢复（选副本时 dungeonMap 已接管，
	# 不越权覆盖）。exercise 是 Control 非 PopWindow，走 _exit_tree 而非 remove_window。
	if HudOverlay.get_identity() == "exercise":
		HudOverlay.apply_identity(_prev_identity)


func set_entry_callback(cb: Callable) -> void:
	_on_entry_selected = cb


func _on_entry_pressed(entry: Dictionary) -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	# 先出树交还 identity 再回调开 dungeonMap（顺序反了双错：dungeonMap 会记录到已死的
	# "exercise"；本面板 _exit_tree 的恢复会盖掉 dungeonMap 的 identity → 头像透过副本地图）。
	if is_inside_tree():
		get_parent().remove_child(self)
	queue_free()
	if _on_entry_selected.is_valid():
		_on_entry_selected.call(String(entry.key), entry.groups)
