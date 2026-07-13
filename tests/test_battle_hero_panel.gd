extends GutTest
# Phase 4 hero_panel 测试（2026-07-02）。
# 验 BattleHeroPanel：装配（hp_bar/mp_bar/portrait/frame_btn/redmask）+ update state 切换
#   （cast/trigger/switch）+ 死亡变灰 + hp_low redmask + castHandler（frame_btn→unit.cast_manual_skill）。
# MockUnit/MockEngine duck-type（避真 unit cast_manual_skill 完整链复杂，照 test_battle_loot_view 模式）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func after_all() -> void:
	UnitSprite.clear_atlas_cache()


class MockEngine:
	extends RefCounted
	var ticks: int = 0
	var running: bool = true
	var arena_mode: bool = false
	var replay_mode: bool = false


class MockSkill:
	extends RefCounted
	var can_trigger_ret: bool = true
	var will_cast_ret: bool = true
	func can_trigger() -> bool:
		return can_trigger_ret
	func will_cast() -> bool:
		return will_cast_ret


class MockUnit:
	extends RefCounted
	var tid: int = 1
	var stars: int = 1
	var camp: int = 1
	var rank: int = 1
	var info: Dictionary = {"MP Type": "MP"}
	var engine: Variant = null
	var can_cast_manual: bool = false
	var current_skill: Variant = null
	var hp_low: bool = false
	var mp: int = 1000
	var manual_skill: Variant = null
	var alive: bool = true
	var cast_called: bool = false
	var hp: float = 1000.0            # FloatingBar._refresh_percent 访问
	var attribs: Dictionary = {"HP": 1000.0}
	var buff_list: Array = []
	func is_alive() -> bool:
		return alive
	func is_hero() -> bool:
		return true
	func cast_manual_skill() -> void:
		cast_called = true


func _make_panel(u: MockUnit) -> BattleHeroPanel:
	u.engine = MockEngine.new()
	var panel := BattleHeroPanel.new()
	panel.setup(u, cm, null)
	return panel


# 源 HeroPanelCreate :8-78 — 装配 hp_bar/mp_bar/portrait/frame_btn/redmask。
func test_panel_assembles() -> void:
	var u := MockUnit.new()
	var panel := _make_panel(u)
	assert_not_null(panel.hp_bar, "hp_bar 装配（源 :15）")
	assert_not_null(panel.mp_bar, "mp_bar 装配（源 :16）")
	assert_not_null(panel.portrait, "portrait 装配（源 :17）")
	assert_not_null(panel.frame_btn, "frame_btn 装配（源 :38）")
	assert_not_null(panel.redmask, "redmask 装配（源 :72）")
	assert_eq(panel.frame_btn.disabled, true, "初始 frame_btn disabled（源 :62）")
	panel.queue_free()


# 源 update :97-99 — can_cast_manual + running → state cast。
func test_panel_update_cast_state() -> void:
	var u := MockUnit.new()
	u.can_cast_manual = true
	u.mp = 2000   # >= 1000 保持 cast（非 switch）
	var panel := _make_panel(u)
	panel.update(0.0)
	assert_eq(panel._state, "cast", "can_cast_manual+running → state cast（源 :98）")
	assert_eq(panel.frame_btn.disabled, false, "cast → frame_btn enabled（源 :106）")
	panel.queue_free()


# 源 :100-102 — current_skill canTrigger → state trigger。
func test_panel_update_trigger_state() -> void:
	var u := MockUnit.new()
	u.current_skill = MockSkill.new()
	var panel := _make_panel(u)
	panel.update(0.0)
	assert_eq(panel._state, "trigger", "current_skill canTrigger → state trigger（源 :101）")
	panel.queue_free()


# 源 :103-105 — cast + mp<1000 → state switch。
func test_panel_update_switch_state() -> void:
	var u := MockUnit.new()
	u.can_cast_manual = true
	u.mp = 500   # < 1000
	var panel := _make_panel(u)
	panel.update(0.0)
	assert_eq(panel._state, "switch", "cast + mp<1000 → state switch（源 :104）")
	panel.queue_free()


# 源 :123-126 — 死亡变灰 portrait.ori_icon setColor(100,100,100)。
func test_panel_dead_gray() -> void:
	var u := MockUnit.new()
	u.alive = false
	var panel := _make_panel(u)
	panel.update(0.0)
	assert_eq(panel.portrait.ori_icon.modulate, Color(100.0/255.0, 100.0/255.0, 100.0/255.0), "死亡 → portrait 变灰（源 :125）")
	assert_eq(panel.redmask.visible, false, "死亡 → redmask 隐（源 :124）")
	panel.queue_free()


# 源 :122 — hp_low → redmask 显。
func test_panel_hp_low_redmask() -> void:
	var u := MockUnit.new()
	u.hp_low = true
	var panel := _make_panel(u)
	panel.update(0.0)
	assert_eq(panel.redmask.visible, true, "hp_low → redmask 显（源 :122）")
	panel.queue_free()


# 源 :45-58 castHandler — frame_btn pressed → unit.cast_manual_skill + btn disabled。
func test_panel_frame_pressed_casts() -> void:
	var u := MockUnit.new()
	u.can_cast_manual = true
	u.mp = 2000
	var panel := _make_panel(u)
	panel.update(0.0)   # state cast → frame_btn enabled
	assert_eq(panel.frame_btn.disabled, false, "cast state → enabled")
	panel._on_frame_pressed()   # 模拟点击 frame_btn（源 castHandler）
	assert_true(u.cast_called, "frame_pressed → unit.cast_manual_skill（源 :47）")
	assert_eq(panel.frame_btn.disabled, true, "castHandler → frame_btn disabled（源 :48）")
	panel.queue_free()
