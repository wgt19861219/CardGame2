extends GutTest
# Phase 4 popup 飘字测试（2026-07-02，2026-07-09 更新 color 参数）。
# 验 BattlePopup.create(text, unit, crit, style, color, ui_layer)：null unit 返 null /
# damage label + 位置 / color 键→RGB 映射（crit 不影响颜色，只影响动作）/ 四 style 创建不崩。
# MockUnit duck-type BattleUnit 的 position/height（popup 仅需这两字段）。

class MockUnit:
	extends RefCounted
	var position: Vector2 = Vector2(100, 0)
	var height: float = 0.0


func test_null_unit_returns_null() -> void:
	var layer := Node2D.new()
	add_child(layer)
	var p: Variant = BattlePopup.create("x", null, false, "damage", "white", layer)
	assert_null(p, "null unit 应返 null")
	layer.queue_free()


func test_damage_popup_position_and_label() -> void:
	var unit := MockUnit.new()
	var layer := Node2D.new()
	add_child(layer)
	var p: Variant = BattlePopup.create("100", unit, false, "damage", "orange", layer)
	assert_not_null(p, "damage popup 应创建")
	assert_eq(p._label.text, "100", "label 文本 = 伤害值")
	# _play_damage 设 position = to_view_position(100, 0, 75) = (100, 340)
	var expected: Vector2 = BattleViewCoords.to_view_position(100.0, 0.0, 75.0)
	assert_eq(p.position, expected, "damage popup 位置 = 单位头顶 75")
	p.queue_free()
	layer.queue_free()


func test_color_key_resolves_modulate() -> void:
	var unit := MockUnit.new()
	var layer := Node2D.new()
	add_child(layer)
	# color 键决定颜色（源色键→RGB 映射），crit 不影响颜色（只影响动作 scale/dist）
	var p_orange: Variant = BattlePopup.create("-50", unit, false, "damage", "orange", layer)
	assert_eq(p_orange._label.modulate, Color(1.0, 0.6, 0.15), "orange 键 → 橙色")
	p_orange.queue_free()
	var p_green: Variant = BattlePopup.create("+50", unit, false, "heal", "green", layer)
	assert_eq(p_green._label.modulate, Color(0.3, 0.95, 0.35), "green 键 → 绿色")
	p_green.queue_free()
	# crit 与非 crit 同 color → 同色（源 color 决定颜色，crit 仅动作加成）
	var p_crit: Variant = BattlePopup.create("-50", unit, true, "damage", "orange", layer)
	assert_eq(p_crit._label.modulate, Color(1.0, 0.6, 0.15), "crit 同 color 同色（crit 仅影响动作）")
	p_crit.queue_free()
	layer.queue_free()


func test_all_styles_create_without_error() -> void:
	var unit := MockUnit.new()
	var layer := Node2D.new()
	add_child(layer)
	for style in ["damage", "heal", "gold", "text"]:
		var p: Variant = BattlePopup.create("1", unit, true, style, "white", layer)
		assert_not_null(p, style + " style 应创建不崩")
		if p != null:
			p.queue_free()
	layer.queue_free()
