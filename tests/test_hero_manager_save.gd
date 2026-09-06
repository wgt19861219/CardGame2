extends GutTest
# HeroManager 存档序列化测试：equip_slots 必须随 to_dict/from_dict 往返保留。
# 回归背景：2026-09-05 曾漏序列化 equip_slots，读档后 6 槽全空 → can_upgrade_rank
# 误判"未穿齐装备"，进阶按钮永远弹"英雄穿齐了装备才可以进阶"。

const HERO_TID := 1  # Hero_equip[1][1] Equip1-6 = 102/102/111/107/108/109

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 穿齐 6 槽 → to_dict → from_dict → 装备与进阶资格完整保留
func test_equip_slots_roundtrip_preserves_upgrade_eligibility() -> void:
	var mgr := HeroManager.new(cm)
	var inst_id: int = mgr.add_hero(HERO_TID)
	var row: Dictionary = cm.get_raw_table(&"Hero_equip").get("1", {}).get("1", {})
	for slot in range(6):
		mgr.get_hero(inst_id).equip_slots[slot] = int(row.get("Equip" + str(slot + 1) + " ID", 0))
	assert_true(mgr.can_upgrade_rank(inst_id), "前置：穿齐后可进阶")

	var data := mgr.to_dict()
	var mgr2 := HeroManager.from_dict(data, cm)
	var hero2 := mgr2.get_hero(inst_id)
	for slot in range(6):
		assert_eq(
			int(hero2.equip_slots[slot]),
			int(row.get("Equip" + str(slot + 1) + " ID", 0)),
			"读档后槽 %d 装备保留" % (slot + 1)
		)
	assert_true(mgr2.can_upgrade_rank(inst_id), "读档后仍可进阶（回归主断言）")
