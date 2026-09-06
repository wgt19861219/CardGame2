extends GutTest
## hero_detail_panel 装备槽外迁后回归测试。

func test_panel_uses_equip_helper() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/hero_detail_panel.gd")
	assert_true(script_text.find("HeroDetailEquipSlots") != -1, "引用 HeroDetailEquipSlots helper")

func test_equip_functions_moved_out() -> void:
	# 5 装备函数应已搬出 panel
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/hero_detail_panel.gd")
	var moved: Array[String] = [
		"_show_equips", "_create_equip_slot_icon", "_make_equip_click_handler",
		"_open_equip_craft", "_on_equip_craft_jump",
	]
	for fname in moved:
		assert_true(script_text.find("func %s" % fname) == -1, "%s 已搬出 panel" % fname)

func test_refresh_gs_after_wear_kept() -> void:
	# refresh_gs_after_wear 留 panel（职责边界纠正）
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/hero_detail_panel.gd")
	assert_true(script_text.find("func refresh_gs_after_wear") != -1, "refresh_gs_after_wear 留 panel")

func test_skill_dead_constants_removed() -> void:
	# 9 SKILL 坐标死代码常量删除
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/hero_detail_panel.gd")
	var dead: Array[String] = [
		"SKILL_ORI_HEIGHT", "SKILL_BD_HEIGHT", "SKILL_ICON_COCOS_X", "SKILL_NAME_COCOS_X",
		"SKILL_LVL_COCOS_X", "SKILL_BTN_COCOS_X", "SKILL_NAME_DY", "SKILL_LVL_DY", "SKILL_BTN_DY",
	]
	for c in dead:
		assert_true(script_text.find(c) == -1, "死代码常量 %s 已删" % c)

func test_skill_count_kept() -> void:
	# SKILL_COUNT 被 _fill_skills 使用，保留
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/hero_detail_panel.gd")
	assert_true(script_text.find("SKILL_COUNT") != -1, "SKILL_COUNT 保留（_fill_skills 用）")

func test_no_translation_comments() -> void:
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/hero_detail_panel.gd")
	assert_eq(script_text.count("# 源 "), 0, "无翻译注释")

func test_no_add_theme_override() -> void:
	# 滚动条隐藏 2026-09-06 收敛到全局 theme（VScrollBar/HScrollBar 空样式），
	# panel 层 add_theme_* 清零（原 4 处滚动条 stylebox 例外退役）。
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/hero_detail_panel.gd")
	assert_eq(script_text.count("add_theme_"), 0, "panel 零 add_theme 运行时套样式")

func test_panel_line_count() -> void:
	# 阈值 450→500（2026-07-28 用户确认）→510（2026-09-02 进阶光效悬空引用修复 +4 行）：
	# panel 作为多功能协调中心（base/tab 切换 + 装备槽 + 升星/进阶/觉醒 + 技能升级 +
	# skill point 信息栏 + 英雄翻页 + card close/旋转），协调逻辑与 panel 状态强耦合不宜
	# 外迁。上限防失控（<550 View 门槛，逼近时 fill 下沉）。
	var script_text: String = FileAccess.get_file_as_string("res://scripts/ui/hero_detail_panel.gd")
	var lines: int = script_text.count("\n") + 1
	assert_lte(lines, 510, "panel ≤510 行（当前 %d）" % lines)
