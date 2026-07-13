extends GutTest
# Step 2 PlayerData.tutorial_records 持久化测试（照源 ed.player:getTutorialRecord/setTutorialRecord）。
# unlock step 完成记录（step_id → times），独立于 tutorial_manager 线性 steps 链。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_get_tutorial_record_default_zero() -> void:
	var pd := PlayerData.new(cm)
	assert_eq(pd.get_tutorial_record(54), 0, "未设记录 → 0（未完成）")


func test_set_tutorial_record() -> void:
	var pd := PlayerData.new(cm)
	pd.set_tutorial_record(54)  # unlockSkillUpgrade id=54
	assert_eq(pd.get_tutorial_record(54), 1, "set 默认 1 次")
	pd.set_tutorial_record(87, 3)  # unlockCrusade id=87
	assert_eq(pd.get_tutorial_record(87), 3, "set 指定次数")


func test_tutorial_records_persistence_roundtrip() -> void:
	var pd := PlayerData.new(cm)
	pd.set_tutorial_record(54)
	pd.set_tutorial_record(87, 2)
	pd.set_tutorial_record(91)  # unlockExcavate
	var saved: Dictionary = pd.to_dict()
	# 模拟 JSON 反序列化污染：int key → str，value → float
	var tainted: Dictionary = {}
	for k in saved["tutorial_records"]:
		tainted[str(k)] = float(saved["tutorial_records"][k])
	saved["tutorial_records"] = tainted
	var pd2 := PlayerData.from_dict(saved, cm)
	assert_eq(pd2.get_tutorial_record(54), 1, "round-trip unlockSkillUpgrade=1")
	assert_eq(pd2.get_tutorial_record(87), 2, "round-trip unlockCrusade=2")
	assert_eq(pd2.get_tutorial_record(91), 1, "round-trip unlockExcavate=1")
	assert_eq(pd2.get_tutorial_record(999), 0, "未记录的 step → 0")


func test_tutorial_records_empty_save() -> void:
	# 旧存档无 tutorial_records 键 → from_dict 默认空，不崩（向后兼容）
	var pd := PlayerData.new(cm)
	var saved: Dictionary = pd.to_dict()
	saved.erase("tutorial_records")
	var pd2 := PlayerData.from_dict(saved, cm)
	assert_eq(pd2.get_tutorial_record(54), 0, "旧存档无 tutorial_records 键 → 默认 0")
	pd2.set_tutorial_record(50)
	assert_eq(pd2.get_tutorial_record(50), 1, "加载后 set 正常")
