extends GutTest
## main_scene 入口外迁后回归测试。


func test_main_scene_uses_router_helper() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scenes/main_menu/main_scene.gd")
	assert_true(script_text.find("MainSceneEntryRouter") != -1, "引用 MainSceneEntryRouter helper")

func test_thin_wrappers_retained_for_reflection() -> void:
	# 审查 C2：7 个被 FAST_ROUTE 反射调的方法必须保留薄包装
	var script_text: String = FileAccess.get_file_as_string("res://scenes/main_menu/main_scene.gd")
	var reflection_methods: Array[String] = [
		"_open_stage_select", "_open_exercise_panel", "_open_ladder",
		"_open_hero", "_open_midas", "_open_tavern", "_open_crusade",
	]
	for m in reflection_methods:
		assert_true(script_text.find("func %s" % m) != -1, "%s 薄包装保留（FAST_ROUTE 反射需要）" % m)

func test_direct_outsource_functions_removed() -> void:
	# 13 个直外迁方法应已从 main_scene 删除
	var script_text: String = FileAccess.get_file_as_string("res://scenes/main_menu/main_scene.gd")
	var removed: Array[String] = [
		"_open_avatar", "_open_name", "_open_equip_strengthen", "_open_daily_login",
		"_open_handbook", "_open_task", "_open_ranklist", "_open_package",
		"_open_shop", "_open_star_shop", "_open_dungeon_groups", "_open_mailbox", "_open_excavate",
	]
	for fname in removed:
		assert_true(script_text.find("func %s" % fname) == -1, "%s 已搬出 main_scene" % fname)

func test_open_stage_select_by_stage_kept() -> void:
	# 审查 I5：public API 被 HeroDetailEquipSlots StringName 反射调，名字不可改
	var script_text: String = FileAccess.get_file_as_string("res://scenes/main_menu/main_scene.gd")
	assert_true(script_text.find("func open_stage_select_by_stage") != -1, "open_stage_select_by_stage 保留（反射 public API）")

func test_no_translation_comments() -> void:
	# 复审 R1：grep pattern 覆盖 # 源 / ## 源 / 照源 / 源: 全格式
	var script_text: String = FileAccess.get_file_as_string("res://scenes/main_menu/main_scene.gd")
	var lines: PackedStringArray = script_text.split("\n")
	for line in lines:
		var stripped: String = line.strip_edges()
		if stripped.find("资源") != -1:
			continue   # 功能性"源"字（资源），不算翻译注释
		assert_false(stripped.find("# 源") != -1 or stripped.find("## 源") != -1 or stripped.find("照源") != -1, "无翻译注释: %s" % stripped)

func test_add_theme_only_statusbar_exception() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scenes/main_menu/main_scene.gd")
	assert_eq(script_text.count("add_theme_"), 1, "add_theme 仅状态栏 StyleBoxEmpty 例外")

func test_main_scene_line_count() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scenes/main_menu/main_scene.gd")
	var lines: int = script_text.count("\n") + 1
	assert_lte(lines, 400, "main_scene ≤400 行（当前 %d）" % lines)
