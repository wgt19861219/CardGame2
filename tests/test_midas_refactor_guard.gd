extends GutTest
## midas 两件套改造守卫（批 2 Task 6，替代 test_midas_renderer_refactor.gd）。
## midas_renderer.gd 消亡（改写 midas_fills.gd 纯 fill 范式）：
## 静态结构归 tscn（历史行模板/确认弹窗），坐标工具消亡（godot 常量预计算）。


func test_panel_uses_fills_helper() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/midas_panel.gd")
	assert_true(script_text.find("MidasFills") != -1, "引用 MidasFills helper")
	assert_true(script_text.find("MidasRenderer") == -1, "不再引用已消亡的 MidasRenderer")


func test_renderer_file_removed() -> void:
	assert_false(FileAccess.file_exists("res://scripts/ui/midas_renderer.gd"),
		"midas_renderer.gd 已消亡（fills 改写）")
	assert_true(FileAccess.file_exists("res://scripts/ui/midas_fills.gd"),
		"midas_fills.gd 就位（纯 fill 范式）")


func test_renderer_functions_moved_out() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/midas_panel.gd")
	var moved: Array[String] = [
		"_rebuild_history", "_add_history_label", "_add_history_icon", "_add_history_ratio",
		"_make_texture", "_make_label", "_add_nine_patch", "_to_godot", "_center", "_left_mid",
	]
	for fname in moved:
		assert_true(script_text.find("func %s" % fname) == -1, "%s 不在 panel" % fname)


# 坐标换算调用点清零（批 2 硬指标：to_godot 全部进 tscn/常量消除）。
func test_no_runtime_coord_helpers() -> void:
	var panel_text: String = FileAccess.get_file_as_string("res://scripts/ui/midas_panel.gd")
	var fills_text: String = FileAccess.get_file_as_string("res://scripts/ui/midas_fills.gd")
	assert_eq(panel_text.count("to_godot"), 0, "panel 无 to_godot 运行时换算（godot 常量预计算）")
	assert_eq(panel_text.count("MidasRenderer.center"), 0, "panel 无 center 换算")
	assert_eq(fills_text.count("to_godot"), 0, "fills 无 to_godot 换算")


func test_no_translation_comments() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/midas_panel.gd")
	assert_eq(script_text.count("# 源 "), 0, "无翻译注释")


func test_add_theme_only_anim_dynamic() -> void:
	# panel 内仅剩 _create_anim_label 的动态字号 override（48/26 真动态飘字）
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/midas_panel.gd")
	assert_eq(script_text.count("add_theme_"), 1, "panel 仅剩 _create_anim_label 动态字号 override")


func test_panel_line_count() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/midas_panel.gd")
	var lines: int = script_text.count("\n") + 1
	assert_lte(lines, 400, "panel ≤400 行（当前 %d）" % lines)


func test_variation_in_theme() -> void:
	var theme_text: String = FileAccess.get_file_as_string("res://resources/themes/default_theme.tres")
	var variations: Array[String] = [
		"MidasHistoryLabel", "MidasConfirmLabel",
		"MidasNameLabel", "MidasDescLabel", "MidasTimesLabel",
		"MidasCostValueLabel", "MidasAcquireValueLabel",
		"MidasUseBtnLabel", "MidasMultiBtnLabel",
		"MidasUseBtn", "MidasMultiBtn", "MidasConfirmBtn",
	]
	for v in variations:
		assert_true(theme_text.find(v + "/base_type") != -1, "%s variation 已建" % v)


# variation 数值断言（GUT 下节点级 get_theme_font_size 不解析 variation，读 theme 文本表项）。
func test_variation_font_sizes_in_theme() -> void:
	var theme_text: String = FileAccess.get_file_as_string("res://resources/themes/default_theme.tres")
	assert_true(theme_text.find("MidasNameLabel/font_sizes/font_size = 20") != -1, "NameLabel 20（源 size20）")
	assert_true(theme_text.find("MidasHistoryLabel/font_sizes/font_size = 20") != -1,
		"HistoryLabel 20（源 :470/479/501/521 历史 4 label size=20）")
	assert_true(theme_text.find("MidasDescLabel/font_sizes/font_size = 18") != -1, "DescLabel 18（源 size18）")
	assert_true(theme_text.find("MidasTimesLabel/font_sizes/font_size = 16") != -1, "TimesLabel 16（源 size16）")
