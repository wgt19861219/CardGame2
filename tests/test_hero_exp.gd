extends GutTest
# Phase 5 英雄经验升级测试（2026-07-02）— 照源 player.lua:1972-1990 addExp via Levels 表。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _new_mgr_with_hero(tid: int = 1) -> HeroManager:
	var mgr := HeroManager.new(cm)
	mgr.add_hero(tid)
	return mgr


func test_exp_partial_no_level() -> void:
	var mgr := _new_mgr_with_hero()
	var hero := mgr.get_hero(1)
	assert_eq(hero.level, 1, "初始 level=1")
	mgr.add_hero_exp(1, 10)  # < 25（level 1→2 需 25）
	assert_eq(hero.level, 1, "经验不足不升级")
	assert_eq(hero.exp, 10, "经验累积")


func test_exp_levelup_once() -> void:
	var mgr := _new_mgr_with_hero()
	var hero := mgr.get_hero(1)
	var leveled: bool = mgr.add_hero_exp(1, 25)  # 恰好 level 1→2
	assert_true(leveled, "升过级")
	assert_eq(hero.level, 2, "level 1→2")
	assert_eq(hero.exp, 0, "升级后经验清零（25-25）")


func test_exp_multi_level() -> void:
	var mgr := _new_mgr_with_hero()
	var hero := mgr.get_hero(1)
	mgr.add_hero_exp(1, 60)  # 25（1→2）+ 30（2→3）= 55，余 5
	assert_eq(hero.level, 3, "连升 2 级")
	assert_eq(hero.exp, 5, "余 5 经验")


func test_exp_zero_no_change() -> void:
	var mgr := _new_mgr_with_hero()
	var hero := mgr.get_hero(1)
	mgr.add_hero_exp(1, 0)
	assert_eq(hero.exp, 0, "0 经验无变化")
