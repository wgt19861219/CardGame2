extends GutTest
# ReadequipIcon 装备/英雄图标测试（照源 readequip.lua createIcon）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# Equip 101 Quality=1（white 边框 + Icon）。
func test_create_equip_icon() -> void:
	var icon: Control = ReadequipIcon.create_icon(101, 1, cm)
	assert_gt(icon.get_child_count(), 0, "equip 图标含边框 + icon")


# amount > 1 多一个数量 Label。
func test_create_icon_with_amount() -> void:
	var icon: Control = ReadequipIcon.create_icon(101, 3, cm)
	assert_gt(icon.get_child_count(), 2, "amount>1 含数量 Label（边框+icon+label）")


# tid=1 Coco（Unit Portrait + Hero）→ hero 边框 + Portrait。
func test_create_hero_icon() -> void:
	var icon: Control = ReadequipIcon.create_icon(1, 1, cm)
	assert_gt(icon.get_child_count(), 0, "hero 图标含边框")
