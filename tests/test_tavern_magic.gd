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


# 源 createIcon({length=38}) 锚点语义：container 是 CCSprite anchor(0.5,0.5)，
# setPosition 定位容器中心、setScale(38/portrait_w) 缩放围绕容器中心。
# wrap（38×38）几何中心 = 源定位点 → ReadheroIcon 缩放后容器中心 Godot(52,52)
# 必须落到 wrap 中心 (19,19)；portrait 视觉中心（贴容器左下，局部 (39,65)）
# 相对 wrap 中心恒偏 (-13,+13)*s（与源一致，非居中）。
# 2026-09-16 魂匣热点图标错位根修：旧实现按"容器中心=视觉中心"且对到 wrap
# 左上角 (0,0)，双重偏差 (-23.75,-14.25) = 实测左偏 24/上偏 10~14。
func test_hero_preview_icon_anchors_container_center() -> void:
	var panel := _make_panel()
	panel._select_pool("MagicSoul")
	assert_true(panel._preview_container.get_child_count() > 0, "预览应含 hero icon")
	var wrap: Control = panel._preview_container.get_child(0)
	var ri: ReadheroIcon = wrap.get_child(0) as ReadheroIcon
	assert_eq(ri.position, Vector2.ZERO, "ReadheroIcon 根节点不应再整体偏移")
	var inner_scale: float = ri.icon.scale.x
	var expect_scale: float = 38.0 / ri._portrait_disp.x
	assert_almost_eq(inner_scale, expect_scale, 0.001,
		"缩放应为 38/portrait_w（源 length/size.width，非 38/104）")
	var expect_inner_pos: Vector2 = wrap.size * 0.5 - ReadheroIcon.CONTAINER_SIZE * 0.5 * inner_scale
	assert_almost_eq(ri.icon.position.x, expect_inner_pos.x, 0.001,
		"缩放后容器中心应落到 wrap 中心 x")
	assert_almost_eq(ri.icon.position.y, expect_inner_pos.y, 0.001,
		"缩放后容器中心应落到 wrap 中心 y")
	panel.queue_free()
