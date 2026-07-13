extends GutTest
# stage_select_panel 三模式切换测试：normal/elite/guild tab + 关卡过滤 + 章节进度。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_mgr() -> StageManager:
	var mgr := StageManager.new(cm)
	return mgr


func _make_panel() -> StageSelectPanel:
	var pd := PlayerData.new(cm)
	var mgr := _make_mgr()
	var rng := BattleRng.new(12345)
	var panel := StageSelectPanel.new("stageSelect", {})
	panel.setup_panel(mgr, pd, rng)
	return panel


func test_mode_default_normal() -> void:
	var panel := _make_panel()
	assert_eq(panel._mode, "normal", "默认 normal 模式")
	panel.queue_free()


func test_mode_switch_to_elite() -> void:
	var panel := _make_panel()
	panel._on_mode_pressed("elite")
	assert_eq(panel._mode, "elite", "切到 elite 模式")
	panel.queue_free()


func test_mode_switch_to_guild() -> void:
	var panel := _make_panel()
	panel._on_mode_pressed("guild")
	assert_eq(panel._mode, "guild", "切到 guild 模式")
	panel.queue_free()


func test_chapter_of_stage_elite() -> void:
	# 精英关 10001 的 Stage Group 应指向同章 normal 关
	var pd := PlayerData.new(cm)
	var panel := StageSelectPanel.new("stageSelect", {})
	panel.player = pd
	var ch: int = panel._chapter_of_stage(10001)
	assert_true(ch >= 1, "精英关 10001 应能反查到章节")
	panel.queue_free()


func test_normal_progress() -> void:
	var mgr := _make_mgr()
	mgr.progress = {1: 3, 2: 2, 3: 0}
	assert_eq(mgr.get_normal_progress(), 2, "最大通关 normal 应为 2（3 星 0 不计）")


func test_elite_progress_with_group_check() -> void:
	var mgr := _make_mgr()
	# elite 10001 Stage Group=1，需 normal 1 也通关
	mgr.progress = {1: 3, 10001: 3}
	assert_eq(mgr.get_elite_progress(), 10001, "elite 10001 + normal 1 通关→elite progress=10001")
	mgr.progress = {10001: 3}  # normal 1 未通关
	assert_eq(mgr.get_elite_progress(), 0, "normal 未通关→elite 不计")
