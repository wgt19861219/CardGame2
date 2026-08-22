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


# create_icon quality 参数覆写表品质（源 createIcon 第三参 quality or value(id,"Quality") :704；
# stagedetail hero 奖励传 4 / herodetail 装备槽配方传 1 两处调用方依赖，2026-08-22 边框错档第二批）。
func test_create_icon_quality_override() -> void:
	# Equip 391 表 Quality=6：不传 → 橙框（表品质）；传 1 → 白框（覆写）
	var plain: Control = ReadequipIcon.create_icon(391, 1, cm)
	var plain_frame := plain.get_child(0) as Sprite2D
	assert_true(String(plain_frame.texture.resource_path).ends_with("equip_frame_orange.png"), "391 不传 quality → 表品质 6 橙框")
	var over: Control = ReadequipIcon.create_icon(391, 1, cm, 0, false, 1)
	var over_frame := over.get_child(0) as Sprite2D
	assert_true(String(over_frame.texture.resource_path).ends_with("equip_frame_white.png"), "quality=1 覆写表品质 6 → 白框（源 :704 参数优先）")
	# hero 传 4 → 紫框（覆写 hero 默认白，源 stagedetail hero 奖励路径）
	var hero_over: Control = ReadequipIcon.create_icon(1, 1, cm, 0, false, 4)
	var hero_frame := hero_over.get_child(0) as Sprite2D
	assert_true(String(hero_frame.texture.resource_path).ends_with("equip_frame_purple.png"), "hero quality=4 覆写默认白 → 紫框")
	plain.free()
	over.free()
	hero_over.free()


# is_hero_id 公共包装（源 ed.itemType(id)=="hero" 调用方分流判定）。
func test_is_hero_id() -> void:
	assert_true(ReadequipIcon.is_hero_id(1, cm), "Unit 1 = Hero")
	assert_false(ReadequipIcon.is_hero_id(101, cm), "Equip 101 非 hero")


# 源 z 序守卫（:740 bg:addChild(equipBg,-2) / :741 addChild(equip,-1)）。
# 1fc781e 补 gocha 漏 z 序：平级后 add 画在 frame 上盖住边框（gocha 97% 不透明、
# frame 中空 78%），2026-08-22 背包反馈回归修复。
func test_create_equip_icon_z_order() -> void:
	var icon: Control = ReadequipIcon.create_icon(101, 1, cm)
	var frame: Sprite2D = icon.get_child(0) as Sprite2D
	var gocha: Sprite2D = icon.get_child(1) as Sprite2D
	var content: Sprite2D = icon.get_child(2) as Sprite2D
	assert_eq(frame.z_index, 0, "frame 边框 z=0 最上（中空透明区透出下层内容）")
	assert_eq(gocha.z_index, -2, "gocha 衬底 z=-2 最底（源 :740）")
	assert_true(gocha.has_meta(&"underlay"), "衬底带 underlay meta（package strip 与 fallback 占位区分）")
	assert_eq(content.z_index, -1, "内容 z=-1（源 :741，框下衬底上）")
	icon.free()
