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


# ==================== 批4 Task 7 两件套收尾守卫（2026-08-17）====================

const CONTENT_SCENE_PATH: String = "res://scenes/ui/task_content.tscn"
const THEME_PATH: String = "res://resources/themes/default_theme.tres"


# 源 task.lua:864-877 title：fontinfo ui_normal_button + size 24 + ccc3(250,205,16)，
# 与 eatexp title（eatexplist.lua:57-72）完全同签名 → 复用 EatexpTitleLabel
# （fontconfigs.lua:23 ui_normal_button = size17 白 + shadow(63,5,0)偏移(0,2)，size/color 被覆盖）。
func test_content_title_uses_eatexp_title_variation() -> void:
	var content: Control = (load(CONTENT_SCENE_PATH) as PackedScene).instantiate() as Control
	var title: Label = content.get_node("%Title") as Label
	assert_eq(String(title.theme_type_variation), "EatexpTitleLabel",
		"面板大标题复用 EatexpTitleLabel（源样式同签名：24 号金 + (63,5,0) 阴影）")
	content.free()


# 两件套 SOP：字号/颜色走 theme_type_variation，tscn 内 theme_override 样式清零。
func test_content_tscn_no_theme_style_override() -> void:
	var tscn_text: String = FileAccess.get_file_as_string(CONTENT_SCENE_PATH)
	assert_eq(tscn_text.count("theme_override_colors"), 0, "tscn 无 font_color override（走 variation）")
	assert_eq(tscn_text.count("theme_override_font_sizes"), 0, "tscn 无 font_size override（走 variation）")
	assert_eq(tscn_text.count("theme_override_constants/separation"), 0,
		"tscn 无 separation override（全局 VBox separation 默认 8 冗余）")


# 段标题（MainTitleLabel/DailyTitleLabel）为合并双列表的迁移发明补充 UI
# （源为 task/dailyTask 两独立窗口各有 title），样式走 TaskSectionLabel variation。
func test_content_section_titles_use_task_section_variation() -> void:
	var content: Control = (load(CONTENT_SCENE_PATH) as PackedScene).instantiate() as Control
	for node_name: String in ["%MainTitleLabel", "%DailyTitleLabel"]:
		var lbl: Label = content.get_node(node_name) as Label
		assert_eq(String(lbl.theme_type_variation), "TaskSectionLabel",
			"%s 段标题走 TaskSectionLabel variation" % node_name)
	content.free()


# GUT 下 get_theme_font_size 不解析 variation → 数值断言读 tres 文本表项（批内惯例）。
func test_theme_registers_task_section_label() -> void:
	var theme_text: String = FileAccess.get_file_as_string(THEME_PATH)
	assert_true(theme_text.find("TaskSectionLabel/base_type") != -1, "theme 注册 TaskSectionLabel")
	assert_true(theme_text.find("TaskSectionLabel/font_sizes/font_size = 20") != -1,
		"TaskSectionLabel 20 号（小于面板大标题 24，分区层级）")


# FAST_ROUTE 反射链守卫：task_panel._on_fast 经 TaskQuery.FAST_ROUTE（7 个去重方法名）
# has_method/call 字符串调用 main_scene——main_scene 侧改名即断 task fast jump 链。
func test_fast_route_reflection_methods_exist_in_main_scene() -> void:
	var main_scene_text: String = FileAccess.get_file_as_string("res://scenes/main_menu/main_scene.gd")
	var methods: Array[String] = []
	for ttype: String in TaskQuery.FAST_ROUTE:
		var m: String = String(TaskQuery.FAST_ROUTE[ttype])
		if not methods.has(m):
			methods.append(m)
	assert_eq(methods.size(), 7, "FAST_ROUTE 去重方法数 = 7")
	for m: String in methods:
		assert_true(main_scene_text.find("func %s(" % m) != -1,
			"main_scene 定义 %s（反射链防断）" % m)


# variation 生效守卫已由 test_variation_runtime_effect 覆盖；
# 此处补 tscn 段标题 variation 在 theme 有注册色（防删除断样式）。
func test_theme_task_section_label_has_color() -> void:
	var theme_text: String = FileAccess.get_file_as_string(THEME_PATH)
	assert_true(theme_text.find("TaskSectionLabel/colors/font_color") != -1,
		"TaskSectionLabel 有 font_color（与面板 title 同金色调）")


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
