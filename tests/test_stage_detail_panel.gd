extends GutTest
# StageDetailPanel 关卡详情面板测试（P1-2026-07-10：照源 stagedetail 翻译）。
# 重构（2026-07-17）：.tscn instantiate + fill 范式（同 hero_detail），测试递归扫 container→content→%...。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _find_button_recursive(node: Node, text: String) -> bool:
	# SweepBtn 改用独立 Label 子节点 %SweepLabel 承载文字（Button.text 清空，照 hero_detail 范式），
	# 故 Button 自身 + 其 Label 子节点的 text 均扫描。
	if node is Button:
		if (node as Button).text == text:
			return true
		for c in node.get_children():
			if c is Label and (c as Label).text == text:
				return true
		return false
	for c in node.get_children():
		if _find_button_recursive(c, text):
			return true
	return false


func test_panel_assembles_with_enemy_and_award() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	var rng := BattleRng.new(5)
	var panel := StageDetailPanel.new("stagedetail", {})
	panel.setup_panel(1, mgr, pd, rng)
	panel.show_window(root)
	# container 应含 content（.tscn root，含 base 层静态节点 + host）
	assert_eq(panel.container.get_child_count(), 1, "container 含 content（.tscn instantiate）")
	var content: Control = panel.container.get_child(0) as Control
	assert_not_null(content.get_node_or_null("%GoButton"), "GoButton 节点存在")
	assert_not_null(content.get_node_or_null("%EnemyHBox"), "EnemyHBox 节点存在")
	assert_not_null(content.get_node_or_null("%StarHBox"), "StarHBox 节点存在")
	assert_not_null(content.get_node_or_null("%CloseBtn"), "CloseBtn 节点存在")
	# 星已静态化进 %StarHBox（Star1/2/3 TextureRect，按源 createStars :1212-1260）
	var star_box: Node = content.get_node("%StarHBox")
	assert_eq(star_box.get_child_count(), 3, "StarHBox 含 3 颗静态星")
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
	# 递归扫 container 子树找扫荡按钮（.tscn %SweepBtn，3 星时 visible=true + text="扫荡"）
	var has_sweep: bool = _find_button_recursive(panel.container, "扫荡")
	assert_true(has_sweep, "3 星关卡显示扫荡按钮")
	panel.remove_window()
	root.queue_free()
