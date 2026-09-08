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


# 单机去 VIP 限制（2026-09-08）：特权档 = VIP 表最高档，特权查询与显示 vip_level 解耦。
func test_get_max_level() -> void:
	var max_lv: int = VipData.get_max_level(cm)
	assert_gt(max_lv, 0, "VIP 表最高档 > 0")
	assert_eq(int(VipData.get_vip_field(max_lv, "VIP Level", cm)), max_lv, "最高档 VIP Level 自洽")
	assert_eq(VipData.get_vip_info(max_lv + 1, cm).size(), 0, "最高档+1 不存在（连续编号边界）")


func test_privilege_vip_level_decoupled_from_display() -> void:
	var pd := PlayerData.new(cm)
	pd.vip_level = 0   # 显示层保持 0（无 VIP 角标）
	assert_eq(pd.privilege_vip_level(), VipData.get_max_level(cm), "特权档恒为最高档，与 vip_level 无关")


# 特权档生效守卫：满级 Elite Reset / Buy Vit Max / Max Skill Points 数值可查且高于 VIP0 档。
func test_privilege_fields_raise_limits() -> void:
	var max_lv: int = VipData.get_max_level(cm)
	assert_gt(int(VipData.get_vip_field(max_lv, "Elite Reset", cm)),
		int(VipData.get_vip_field(0, "Elite Reset", cm)), "特权档精英重置上限高于 VIP0")
	assert_gt(int(VipData.get_vip_field(max_lv, "Buy Vit Max", cm)),
		int(VipData.get_vip_field(0, "Buy Vit Max", cm)), "特权档买体力上限高于 VIP0")
	assert_gt(int(VipData.get_vip_field(max_lv, "Max Skill Points", cm)),
		int(VipData.get_vip_field(0, "Max Skill Points", cm)), "特权档技能点上限高于 VIP0")
