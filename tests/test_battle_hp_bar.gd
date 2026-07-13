extends GutTest
# Phase 4 HpBar 单条血条测试（2026-07-02）。
# 验 BattleHpBar：create 初始 percent/scale / fore_length 平滑（回血渐增）+ 减血立即 / mp 类型 / hp_low mask。
# MockUnit duck-type BattleUnit 的 hp/mp/attribs/camp/is_alive/hp_low。

class MockUnit:
	extends RefCounted
	var camp: int = 1
	var hp: int = 100
	var mp: int = 50
	var attribs: Dictionary = {"HP": 100, "MP": 100}
	var hp_low: bool = false

	func is_alive() -> bool:
		return true


func test_create_hp_bar_percent() -> void:
	var unit := MockUnit.new()
	unit.hp = 50
	var bar := BattleHpBar.create(unit, "HP")
	add_child(bar)
	assert_almost_eq(bar._percent, 0.5, 0.01, "hp=50/HP=100 → percent 0.5")
	assert_almost_eq(bar._foreground.scale.x, 0.5, 0.01, "foreground scale.x = percent")
	bar.queue_free()


func test_create_mp_bar_percent() -> void:
	var unit := MockUnit.new()
	unit.mp = 25
	var bar := BattleHpBar.create(unit, "Mana")
	add_child(bar)
	assert_almost_eq(bar._percent, 0.25, 0.02, "mp=25/MP=100 → percent 0.25")
	assert_eq(bar._inc_speed, 2.0, "Mana inc_speed = 2.0（源 :36）")
	bar.queue_free()


func test_fore_length_smooths_up_on_heal() -> void:
	var unit := MockUnit.new()
	unit.hp = 100   # percent 1.0（满血）
	var bar := BattleHpBar.create(unit, "HP")
	add_child(bar)
	bar._fore_length = 0.5      # 模拟刚从 50% 回血
	bar._foreground.scale.x = 0.5
	bar.update(0.1)             # HP inc_speed=0.5 → fore 0.5 + 0.5*0.1 = 0.55
	assert_almost_eq(bar._fore_length, 0.55, 0.02, "回血 fore_length 渐增 0.5→0.55")
	bar.queue_free()


func test_fore_length_drops_instant_on_damage() -> void:
	var unit := MockUnit.new()
	unit.hp = 50    # percent 0.5
	var bar := BattleHpBar.create(unit, "HP")
	add_child(bar)
	bar._fore_length = 1.0      # 模拟刚从满血受击
	bar._foreground.scale.x = 1.0
	bar.update(0.016)
	assert_almost_eq(bar._fore_length, 0.5, 0.01, "减血 fore_length 立即跌到 percent（源 :112-115）")
	bar.queue_free()


func test_hp_low_shows_mask() -> void:
	var unit := MockUnit.new()
	unit.hp = 10
	unit.hp_low = true
	var bar := BattleHpBar.create(unit, "HP")
	add_child(bar)
	bar.update(0.016)
	assert_true(bar._mask.visible, "hp_low → mask visible（低血红闪层）")
	bar.queue_free()
