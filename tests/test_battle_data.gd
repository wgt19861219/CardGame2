extends GutTest
# Phase 6 BattleData 测试（2026-07-02）— 照源 battle_engine.lua setupBattle 读 Battle 表敌人配置。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_modify_semantics() -> void:
	# 源 modify（:179-186）：modifier=0 → default=100 → old×100/100
	assert_eq(BattleData._modify(1.0, 0.0), 1.0, "modifier=0 取 default 100 → 1.0")
	assert_eq(BattleData._modify(1.0, 40.0), 0.4, "HP% 40 → 0.4")
	assert_eq(BattleData._modify(1.0, 50.0), 0.5, "DPS% 50 → 0.5")
	# boss size default=120
	assert_eq(BattleData._modify(1.0, 0.0, 120.0), 1.2, "BOSS SIZE% 0 → default 120 → 1.2")


func test_stage1_two_monsters() -> void:
	var monsters: Array = BattleData.from_config(cm, 1).get_monsters()
	assert_eq(monsters.size(), 2, "stage 1 wave 1 = 2 敌人（101/102）")
	assert_eq(int(monsters[0]["tid"]), 101, "敌人 0 tid=101")
	assert_eq(int(monsters[1]["tid"]), 102, "敌人 1 tid=102")
	assert_eq(int(monsters[0]["level"]), 1, "敌人 0 level=1")
	assert_eq(int(monsters[0]["stars"]), 1, "敌人 0 stars=1")
	assert_eq(float(monsters[0]["hp_mod"]), 0.4, "敌人 0 HP% 40 → hp_mod 0.4")
	assert_eq(float(monsters[0]["dps_mod"]), 0.5, "敌人 0 DPS% 50 → dps_mod 0.5")
	assert_eq(int(monsters[0]["money"]), 36, "敌人 0 money=36")


func test_pvp_placeholder_no_monsters() -> void:
	# stage -27 实时对战占位：配置存在但 Monster 全 0
	var bd := BattleData.from_config(cm, -27)
	assert_true(bd.has_monsters(), "PVP 占位 battle_info 存在")
	assert_eq(bd.get_monsters().size(), 0, "PVP 占位无实际敌人")


func test_missing_stage_empty() -> void:
	var bd := BattleData.from_config(cm, 999999)
	assert_false(bd.has_monsters(), "不存在 stage 无配置")
	assert_eq(bd.get_monsters().size(), 0, "不存在 stage get_monsters 空")
