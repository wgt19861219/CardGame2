extends GutTest
# Phase 6 StageData 关卡查询测试（2026-07-02）。旧版 from_config 实例模式。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_from_config() -> void:
	var sd := StageData.from_config(cm, -27)
	assert_eq(sd.stage_id, -27, "stage_id=-27")
	assert_eq(sd.chapter_id, -1, "Chapter ID=-1")


func test_from_config_drops() -> void:
	var sd := StageData.from_config(cm, -27)
	assert_not_null(sd, "StageData 创建")
	# drops 结构验证（-27 特殊 stage 可能空槽）
	for d in sd.drops:
		assert_true(d.has("item_id"), "drop 含 item_id")
		assert_true(d.has("probability"), "drop 含 probability")
