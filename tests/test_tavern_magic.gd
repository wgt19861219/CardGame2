extends GutTest
# tavern_panel Magic 魂匣预览测试。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_panel() -> TavernPanel:
	var pd := PlayerData.new(cm)
	var rng := BattleRng.new(12345)
	var panel := TavernPanel.new("tavern", {})
	panel.setup_panel(pd, rng)
	return panel


func test_preview_container_assembles() -> void:
	var panel := _make_panel()
	assert_not_null(panel._preview_container, "预览容器应装配")
	panel.queue_free()


func test_magic_preview_shows_on_select() -> void:
	var panel := _make_panel()
	panel._select_pool("MagicSoul")
	assert_true(panel._preview_container.visible, "MagicSoul tab 应显示预览")
	assert_true(panel._preview_container.get_child_count() > 0, "预览应含 hero icon 子节点")
	panel.queue_free()


func test_non_magic_preview_hidden() -> void:
	var panel := _make_panel()
	panel._select_pool("Bronze")
	assert_false(panel._preview_container.visible, "Bronze tab 应隐藏 Magic 预览")
	panel.queue_free()
