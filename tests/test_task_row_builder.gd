extends GutTest
## TaskRowBuilder 渲染 helper 单测。

func test_make_task_row_structure() -> void:
	var task: Dictionary = {
		"kind": "task", "name": "测试任务", "detail": "详情", "target": 5,
		"progress": 3, "isFinished": false, "icon": "", "reward": [],
	}
	var row: Control = TaskRowBuilder.make_task_row(task, Callable())
	assert_not_null(row)
	assert_eq(row.name, "TaskRow")
	assert_true(row.get_child_count() > 0)
	row.free()

func test_make_task_row_completed_shows_complete_button() -> void:
	var task: Dictionary = {
		"kind": "task", "name": "T", "detail": "", "target": 5,
		"progress": 5, "isFinished": false, "icon": "", "reward": [],
	}
	var row: Control = TaskRowBuilder.make_task_row(task, Callable())
	var has_btn: bool = false
	for c in row.get_children():
		if c is TextureButton:
			has_btn = true
	assert_true(has_btn, "完成态显示领奖按钮")
	row.free()

func test_make_task_row_daily_wires_on_fast() -> void:
	# 日常任务"前往"按钮应调用 on_fast 回调（非 Callable() 空回调）。
	# 回归守护：Task 2 make_task_row 漏接 on_fast 致日常前往按钮变 Callable() 失效。
	var fast_called: Array[bool] = [false]
	var task: Dictionary = {
		"kind": "dailyjob", "name": "T", "detail": "", "target": 5,
		"progress": 0, "isFinished": false, "icon": "", "reward": [],
	}
	var on_fast: Callable = func() -> void: fast_called[0] = true
	var row: Control = TaskRowBuilder.make_task_row(task, Callable(), "", "前往", on_fast)
	# 找日常按钮（非完成态，TextureButton）并模拟点击
	for c in row.get_children():
		if c is TextureButton:
			(c as TextureButton).emit_signal("pressed")
	assert_true(fast_called[0], "日常前往按钮触发 on_fast 回调")
	row.free()


func test_make_empty_prompt() -> void:
	var lbl: Label = TaskRowBuilder.make_empty_prompt("task")
	assert_not_null(lbl)
	assert_true(lbl.text.length() > 0)
	lbl.free()

func test_row_builder_no_translation_comments() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/task_row_builder.gd")
	assert_eq(script_text.count("# 源 "), 0, "无翻译注释")

func test_row_builder_no_add_theme_override() -> void:
	# spec Q5 路径1：彻底归零
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/task_row_builder.gd")
	assert_eq(script_text.count("add_theme_"), 0, "无 add_theme override（全走 Theme variation）")

func test_row_builder_uses_theme_variation() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/task_row_builder.gd")
	assert_true(script_text.find("theme_type_variation") != -1, "Label 用 theme_type_variation")
	assert_true(script_text.find("TaskProgressDoneLabel") != -1, "progress done variation")
	assert_true(script_text.find("TaskProgressTodoLabel") != -1, "progress todo variation")


# P0-3：源 task.lua:324 doPressInList bg setScale(0.98)。ROW_PRESS_SCALE 常量 0.98 + bg pivot 居中。
func test_row_press_scale_constant() -> void:
	assert_almost_eq(TaskRowBuilder.ROW_PRESS_SCALE.x, 0.98, 0.001, "row press scale x=0.98 照源")
	assert_almost_eq(TaskRowBuilder.ROW_PRESS_SCALE.y, 0.98, 0.001, "row press scale y=0.98 照源")


# bg pivot 居中（Control scale 绕中心，源 anchor 0.5,0.5 等价）。
func test_row_bg_pivot_centered() -> void:
	var task: Dictionary = {
		"kind": "task", "name": "T", "detail": "", "target": 5,
		"progress": 5, "isFinished": false, "icon": "", "reward": [],
	}
	var row: Control = TaskRowBuilder.make_task_row(task, Callable())
	var bg: TextureRect = row as TextureRect
	assert_almost_eq(bg.pivot_offset.x, float(TaskRowBuilder.BG_W) * 0.5, 0.5, "bg pivot x 居中")
	assert_almost_eq(bg.pivot_offset.y, float(TaskRowBuilder.BG_H) * 0.5, 0.5, "bg pivot y 居中")
	row.free()


# action button 连 button_down/up 信号驱动 bg scale（源 doPressInList 通过整 layer 拦截，
# 项目 bg mouse_filter=IGNORE，借子按钮信号驱动等价视觉反馈）。
func test_row_action_button_wires_press_signals() -> void:
	var task: Dictionary = {
		"kind": "task", "name": "T", "detail": "", "target": 5,
		"progress": 5, "isFinished": false, "icon": "", "reward": [],
	}
	var row: Control = TaskRowBuilder.make_task_row(task, Callable())
	var btn: TextureButton = null
	for c in row.get_children():
		if c is TextureButton:
			btn = c as TextureButton
			break
	assert_not_null(btn, "行含 action button")
	assert_true(btn.button_down.is_connected(TaskRowBuilder._tween_row_scale), "button_down 连 _tween_row_scale")
	assert_true(btn.button_up.is_connected(TaskRowBuilder._tween_row_scale), "button_up 连 _tween_row_scale")
	row.free()
