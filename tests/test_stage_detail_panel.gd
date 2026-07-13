extends GutTest
# StageDetailPanel 关卡详情面板测试（P1-2026-07-10：照源 stagedetail 翻译）。
# 验证 setup_panel 构建敌人阵容/奖励/体力/进入战斗按钮。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_panel_assembles_with_enemy_and_award() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	var rng := BattleRng.new(5)
	var panel := StageDetailPanel.new("stagedetail", {})
	panel.setup_panel(1, mgr, pd, rng)
	panel.show_window(root)
	# container 应含 title + power + enemy_title + enemy_box + award_title + go_button + close 等节点
	assert_gt(panel.container.get_child_count(), 4, "关卡详情含多个 UI 节点")
	panel.remove_window()
	root.queue_free()


func test_panel_shows_sweep_for_3_star_stage() -> void:
	# 3 星通关的关卡应显示扫荡按钮（照源 createRepeatBattle 3 星条件）
	var root := Node.new()
	add_child(root)
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	# 手动设 3 星解锁扫荡按钮（progress 字典 key=sid value=星数）
	mgr.progress[1] = 3
	var rng := BattleRng.new(5)
	var panel := StageDetailPanel.new("stagedetail", {})
	panel.setup_panel(1, mgr, pd, rng)
	panel.show_window(root)
	# 遍历 container 找扫荡按钮
	var has_sweep := false
	for c in panel.container.get_children():
		if c is Button and (c as Button).text == "扫荡":
			has_sweep = true
			break
	assert_true(has_sweep, "3 星关卡显示扫荡按钮")
	panel.remove_window()
	root.queue_free()
