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
