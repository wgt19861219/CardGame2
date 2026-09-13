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
	# FrameworkHud 接管后，状态栏 StyleBoxEmpty 外迁到 framework_hud.gd；
	# main_scene 本身不再有 add_theme_ 调用（count=0）。
	var script_text: String = FileAccess.get_file_as_string("res://scenes/main_menu/main_scene.gd")
	assert_eq(script_text.count("add_theme_"), 0, "add_theme 已外迁到 FrameworkHud，main_scene count=0")

func test_main_scene_line_count() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scenes/main_menu/main_scene.gd")
	var lines: int = script_text.count("\n") + 1
	assert_lte(lines, 400, "main_scene ≤400 行（当前 %d）" % lines)


# ── 公会入口恢复守卫（2026-09-13 用户拍板②：图鉴有背包专属入口，主城建筑恢复公会名义）──

# ENTRIES 数据：id 恢复 guild、title 回 mainres.Guild，无 handbook 残留。
func test_guild_entry_restored() -> void:
	var found: Dictionary = {}
	for e in MainSceneEntries.ENTRIES:
		if String(e["id"]) == "guild":
			found = e
		assert_false(String(e["id"]) == "handbook", "无 handbook 条目残留（已恢复公会名义）")
	assert_false(found.is_empty(), "存在 id= guild 条目")
	assert_eq(String(found["title"]), "mainres.Guild", "guild title=mainres.Guild（显示「公会」）")
	assert_eq(String(found["unlock"]), "Guild", "unlock=Guild 照源 unlock_keys")

# main_scene 路由：match "guild" 分支调 open_guild，无 open_handbook 残留。
func test_main_scene_routes_guild() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scenes/main_menu/main_scene.gd")
	assert_true(script_text.find("\"guild\":") != -1, "match 含 guild 分支")
	assert_true(script_text.find("MainSceneEntryRouter.open_guild(self)") != -1, "guild 分支调 open_guild")
	assert_false(script_text.find("open_handbook") != -1, "无 open_handbook 残留调用")

# open_guild 行为：点击 Toast「公会功能未开放」（公会联机裁剪无面板，对应源未解锁 showToast 语义）。
func test_open_guild_shows_toast() -> void:
	Toast._queue.clear()
	Toast._free_current()
	MainSceneEntryRouter.open_guild(null)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_not_null(Toast._current_label, "Toast 已显示")
	if Toast._current_label != null:
		assert_eq(Toast._current_label.text, "公会功能未开放", "Toast 文案「公会功能未开放」")
	Toast._free_current()
