extends GutTest
# Phase 1 数据完整性校验（2026-07-02）。关键表加载 + 关键字段存在。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_core_tables_loaded() -> void:
	for table in ["Unit", "Equip", "Skill", "Stage", "Enhancement", "TavernType", "TavernBoxType", "PlayerLevel", "VIP", "Equipcraft", "HeroStars", "Fragment"]:
		assert_true(cm.has_table(StringName(table)), "表 %s 已加载" % table)


func test_unit_key_fields() -> void:
	var coco: Dictionary = cm.get_raw_table(&"Unit").get("1", {})
	assert_eq(String(coco.get("Portrait", "")), "UI/HERO/Coco.jpg", "Unit 1 Portrait")
	assert_eq(int(coco.get("Initial Stars", -1)), 1, "Unit 1 Initial Stars=1")


func test_equip_key_fields() -> void:
	var e101: Dictionary = cm.get_raw_table(&"Equip").get("101", {})
	assert_almost_eq(float(e101.get("+GS", 0.0)), 2.7, 0.01, "Equip 101 +GS=2.7")
	assert_eq(int(e101.get("Quality", -1)), 1, "Equip 101 Quality=1")
