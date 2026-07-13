extends GutTest
# Phase 5.4 VipData 测试（2026-07-02）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_get_vip_info() -> void:
	var info: Dictionary = VipData.get_vip_info(0, cm)
	assert_eq(int(info.get("VIP Level", -1)), 0, "VIP 0 → VIP Level=0")


func test_get_vip_field() -> void:
	var raid_gold: Variant = VipData.get_vip_field(0, "Raid Gold Bonus", cm)
	assert_eq(int(raid_gold), 1, "VIP 0 Raid Gold Bonus=1")


func test_get_vip_info_missing() -> void:
	assert_eq(VipData.get_vip_info(999, cm).size(), 0, "不存在 level → 空")
