extends GutTest
# Phase 4 FloatingBar 浮动血条测试（2026-07-02）。
# 验 BattleFloatingBar：HP percent / Shield 从 buff_list 累加 value / can_be_seen / Group add+update。
# MockUnit duck-type hp/attribs/camp/is_alive/buff_list；MockBuff duck-type shield。

class MockUnit:
	extends RefCounted
	var camp: int = 1
	var hp: int = 50
	var attribs: Dictionary = {"HP": 100, "MP": 100}
	var buff_list: Array = []

	func is_alive() -> bool:
		return true


class MockBuff:
	extends RefCounted
	var shield: float = 0.0


func test_create_hp_floating_bar_percent() -> void:
	var unit := MockUnit.new()
	unit.hp = 50
	var bar := BattleFloatingBar.create(unit, "HP")
	add_child(bar)
	assert_almost_eq(bar._percent, 0.5, 0.01, "HP hp=50/100 → percent 0.5")
	assert_true(bar.can_be_seen(), "percent>0 → can_be_seen")
	bar.queue_free()


func test_create_shield_value_from_buffs() -> void:
	var unit := MockUnit.new()
	unit.buff_list = [_make_buff(30.0), _make_buff(20.0)]
	var bar := BattleFloatingBar.create(unit, "Shield")
	add_child(bar)
	# Shield value = sum(buff.shield) = 50；value_max 跟涨到 50 → percent 1.0
	assert_almost_eq(bar._value, 50.0, 0.01, "Shield value 累加 buff.shield 30+20=50")
	bar.queue_free()


func test_shield_percent_when_max_exceeds_value() -> void:
	var unit := MockUnit.new()
	unit.buff_list = [_make_buff(30.0)]   # value=30
	var bar := BattleFloatingBar.create(unit, "Shield")
	add_child(bar)
	# 首次 _value(30) > _value_max(0 初始) → max=30 → percent 1.0；buff 失效后 value→0 max 保持→percent 0
	assert_almost_eq(bar._percent, 1.0, 0.01, "Shield 首次满（value 涨则 max 跟涨）")
	unit.buff_list = []   # shield 消失
	bar.update(0.016)
	assert_almost_eq(bar._percent, 0.0, 0.01, "Shield 消失 → value=0 → percent 0（源 :579-581）")
	assert_false(bar.can_be_seen(), "percent=0 → 不可见")
	bar.queue_free()


func test_group_add_and_update() -> void:
	var unit := MockUnit.new()
	var hp_bar := BattleFloatingBar.create(unit, "HP")
	var shield_bar := BattleFloatingBar.create(unit, "Shield")
	add_child(hp_bar)
	add_child(shield_bar)
	var group := BattleFloatingBar.create_group()
	group.add_bar("HP", hp_bar)
	group.add_bar("Shield", shield_bar)
	group.update(0.016)   # 各 bar update + 共享 hide_timer 控显，不崩
	assert_true(hp_bar.can_be_seen(), "HP bar 可见")
	hp_bar.queue_free()
	shield_bar.queue_free()


func _make_buff(shield_val: float) -> MockBuff:
	var b := MockBuff.new()
	b.shield = shield_val
	return b
