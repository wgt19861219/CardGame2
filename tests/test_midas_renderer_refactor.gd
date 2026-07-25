extends GutTest
## midas_panel 渲染外迁后回归测试。

func test_panel_uses_renderer_helper() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/midas_panel.gd")
	assert_true(script_text.find("MidasRenderer") != -1, "引用 MidasRenderer helper")

func test_renderer_functions_moved_out() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/midas_panel.gd")
	var moved: Array[String] = [
		"_rebuild_history", "_add_history_label", "_add_history_icon", "_add_history_ratio",
		"_make_texture", "_make_label", "_add_nine_patch", "_to_godot", "_center", "_left_mid",
	]
	for fname in moved:
		assert_true(script_text.find("func %s" % fname) == -1, "%s 已搬出 panel" % fname)

func test_no_translation_comments() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/midas_panel.gd")
	assert_eq(script_text.count("# 源 "), 0, "无翻译注释")

func test_add_theme_only_anim_dynamic() -> void:
	# panel 内仅剩 _create_anim_label 的动态字号 override（48/26 真动态）
	# separation 随 _rebuild_history 搬 helper 了，panel 内 separation override = 0
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/midas_panel.gd")
	assert_eq(script_text.count("add_theme_"), 1, "panel 仅剩 _create_anim_label 动态字号 override")

func test_panel_line_count() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/midas_panel.gd")
	var lines: int = script_text.count("\n") + 1
	assert_lte(lines, 400, "panel ≤400 行（当前 %d）" % lines)

func test_variation_in_theme() -> void:
	var theme_text: String = FileAccess.get_file_as_string("res://resources/themes/default_theme.tres")
	assert_true(theme_text.find("MidasHistoryLabel") != -1, "MidasHistoryLabel variation 已建")
	assert_true(theme_text.find("MidasConfirmLabel") != -1, "MidasConfirmLabel variation 已建")
