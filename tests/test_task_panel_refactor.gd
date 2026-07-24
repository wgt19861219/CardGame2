extends GutTest
## task_panel 重构后回归测试（拆分 3/3，2026-07-24）。
## 验证主控文件已瘦身：引用 helper、无翻译注释、行数 ≤300、func ≤10、已搬出函数全删。
## 另验证 Task 2 留的 variation 运行时生效缺口（Label 色 != 默认白）。

func test_task_panel_uses_helpers() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/task_panel.gd")
	assert_true(script_text.find("TaskQuery") != -1, "引用 TaskQuery helper")
	assert_true(script_text.find("TaskRowBuilder") != -1, "引用 TaskRowBuilder helper")


func test_task_panel_no_translation_comments() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/task_panel.gd")
	assert_eq(script_text.count("# 源 "), 0, "无翻译注释")


func test_task_panel_line_count() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/task_panel.gd")
	var lines: int = script_text.count("\n") + 1
	assert_lte(lines, 300, "task_panel.gd ≤300 行（当前 %d）" % lines)


func test_task_panel_no_moved_functions() -> void:
	# 已搬出的 ~19 函数不应还在主文件
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/task_panel.gd")
	var moved: Array[String] = [
		"get_count", "get_main_progress", "build_main_task", "parse_rewards",
		"count_heroes_by_rank", "count_heroes_by_level", "pid_values",
		"make_task_row", "add_icon", "add_label", "add_reward_icons",
		"add_reward_icon", "add_reward_amt", "add_action_button",
		"make_empty_prompt", "bg_pos", "load_tex", "to_godot", "resolve_fast_target",
	]
	for fname in moved:
		assert_true(script_text.find("func %s" % fname) == -1, "%s 已搬出 task_panel" % fname)


func test_task_panel_func_count_le_10() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/task_panel.gd")
	var func_count: int = script_text.count("\nfunc ") + script_text.count("\nstatic func ")
	assert_lte(func_count, 10, "task_panel func 数 ≤10（当前 %d）" % func_count)


# Task 2 留的缺口：验证 variation 运行时真生效（Label 用了 variation 的色，非默认白）。
# ThemeManager（autoload）_ready 时 get_tree().root.set_theme(default_theme)，root Window 持 theme。
# 生产 panel 是 Window 子树（行在 ScrollContainer 内），沿 Control 链可解析 variation。
# 测试复现：把行挂到 root Window（get_tree().root）—— GUT 测试节点在 Node2D(GutRunner) 下，
# theme 继承在非 Control 节点断裂，故必须挂 root Window 才能模拟生产的 Window 主题链。
func test_variation_runtime_effect() -> void:
	var task: Dictionary = {
		"kind": "task", "name": "测试", "detail": "", "target": 1,
		"progress": 0, "isFinished": false, "icon": "", "reward": [],
	}
	var row: Control = TaskRowBuilder.make_task_row(task, Callable())
	get_tree().root.add_child(row)   # 挂 root Window 模拟生产 Window 主题链
	# 找 name label（应有 theme_type_variation = TaskNameLabel）
	var found_variation: bool = false
	for c in row.get_children():
		if c is Label:
			var lbl: Label = c as Label
			if String(lbl.theme_type_variation) == "TaskNameLabel":
				found_variation = true
				# variation 的色应从 Theme 取（TaskNameLabel = 棕色 (66,45,28)，非默认白）
				var theme_color: Color = lbl.get_theme_color("font_color", "TaskNameLabel")
				assert_ne(theme_color, Color.WHITE, "TaskNameLabel 色 != 默认白（variation 生效）")
				# 进一步断言实际是棕色（确认取到 TaskNameLabel 的值，非其他兜底）
				var expected := Color(66.0 / 255.0, 45.0 / 255.0, 28.0 / 255.0)
				assert_eq(theme_color, expected, "TaskNameLabel 色 = (66,45,28) 棕色（variation 值匹配）")
	assert_true(found_variation, "找到 TaskNameLabel variation 的 Label")
	row.queue_free()
