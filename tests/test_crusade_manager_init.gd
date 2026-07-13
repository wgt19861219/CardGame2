extends GutTest
# Phase 6 CrusadeManager init_crusade 敌人生成测试（2026-07-02）— 照源 initCrusade:2402-2484。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_init_crusade_generates_enemies() -> void:
	var mgr := CrusadeManager.new(cm)
	var rng := BattleRng.new(12345)
	mgr.init_crusade(rng)
	assert_eq(mgr.enemies.size(), CrusadeData.MAX_STAGE, "生成 15 关敌人")
	# 每关 5 敌人（前+中+后）
	var s1: Dictionary = mgr.enemies[1]
	var heroes: Array = s1["heroes"]
	assert_eq(heroes.size(), 5, "stage 1 = 5 敌人")
	assert_true(s1.has("name"), "敌人有名字")
	assert_eq(int(s1["level"]), 80, "stage 1 level=80")


func test_init_crusade_idempotent() -> void:
	var mgr := CrusadeManager.new(cm)
	mgr.init_crusade(BattleRng.new(1))
	var first_size: int = mgr.enemies.size()
	mgr.init_crusade(BattleRng.new(999))  # 再调不改（已生成）
	assert_eq(mgr.enemies.size(), first_size, "已生成则跳过")
	# 第二次用不同种子不改（:2404-2406 早返）
	var s1_name: String = String(mgr.enemies[1]["name"])
	assert_eq(s1_name, String(mgr.enemies[1]["name"]), "名字不变（幂等）")


func test_deterministic_same_seed() -> void:
	var m1 := CrusadeManager.new(cm)
	m1.init_crusade(BattleRng.new(777))
	var m2 := CrusadeManager.new(cm)
	m2.init_crusade(BattleRng.new(777))
	assert_eq(m1.enemies[1]["heroes"], m2.enemies[1]["heroes"], "同种子敌人一致")


func test_persistence_roundtrip() -> void:
	var mgr := CrusadeManager.new(cm)
	mgr.init_crusade(BattleRng.new(42))
	mgr.cur_stage = 3
	var d: Dictionary = mgr.to_dict()
	var restored := CrusadeManager.from_dict(d, cm)
	assert_eq(restored.cur_stage, 3, "持久化 cur_stage")
	assert_eq(restored.enemies.size(), CrusadeData.MAX_STAGE, "持久化 enemies")


func test_init_without_cm_skips() -> void:
	var mgr := CrusadeManager.new()  # cm=null
	mgr.init_crusade(BattleRng.new(1))
	assert_eq(mgr.enemies.size(), 0, "cm null 跳过生成")
