extends GutTest
# PlayerData Crusade 持久化集成测试（2026-07-02）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_ensure_crusade_initializes() -> void:
	var pd := PlayerData.new(cm)
	assert_eq(pd.crusade_manager.enemies.size(), 0, "新档 enemies 空")
	pd.ensure_crusade(BattleRng.new(12345))
	assert_eq(pd.crusade_manager.enemies.size(), CrusadeData.MAX_STAGE, "ensure 后生成 15 关")


func test_crusade_persistence_roundtrip() -> void:
	var pd := PlayerData.new(cm)
	pd.ensure_crusade(BattleRng.new(42))
	pd.crusade_manager.cur_stage = 5
	var d: Dictionary = pd.to_dict()
	# crusade_manager 键存在
	assert_true(d.has("crusade_manager"), "to_dict 含 crusade_manager")
	var restored := PlayerData.from_dict(d, cm)
	assert_eq(restored.crusade_manager.cur_stage, 5, "cur_stage 持久化")
	assert_eq(restored.crusade_manager.enemies.size(), CrusadeData.MAX_STAGE, "enemies 持久化")


func test_ensure_crusade_idempotent() -> void:
	var pd := PlayerData.new(cm)
	pd.ensure_crusade(BattleRng.new(1))
	var s1_name: String = String(pd.crusade_manager.enemies[1]["name"])
	pd.ensure_crusade(BattleRng.new(999))  # 再 ensure 不改（已生成）
	assert_eq(String(pd.crusade_manager.enemies[1]["name"]), s1_name, "已生成则 ensure 幂等")
