extends GutTest
# ReadequipIcon 星级扩展测试（照源 createIconWithLevel:1202-1231）。
# 动态找 ml>=N 的装备（避硬编码 id 依赖 Equip.json 结构）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _find_equip_with_ml(min_ml: int) -> int:
	var table: Dictionary = cm.get_raw_table("Equip")
	for k in table:
		var ml: int = int(ReadequipData.get_equip_level_exp(int(k), cm).get("ml", 0))
		if ml >= min_ml:
			return int(k)
	return -1


# level=N 不 show_gray → N 颗蓝星（type=y）。
func test_stars_level_only_blue() -> void:
	var eid: int = _find_equip_with_ml(2)
	if eid < 0:
		assert_true(true, "无 ml>=2 装备，skip")
		return
	var icon: Control = ReadequipIcon.create_icon(eid, 1, cm, 2, false)
	var stars: Array = ReadequipIcon.get_stars(icon)
	assert_eq(stars.size(), 2, "level=2 不 show_gray → 2 蓝星")
	for s in stars:
		assert_eq(s["type"], "y", "蓝星 type=y")
	icon.free()


# show_gray=true → level 颗蓝 + (ml-level) 颗灰占位到 ml（源 :1222-1228）。
func test_stars_show_gray_fills_to_ml() -> void:
	var eid: int = _find_equip_with_ml(3)
	if eid < 0:
		assert_true(true, "无 ml>=3 装备，skip")
		return
	var ml: int = int(ReadequipData.get_equip_level_exp(eid, cm).get("ml", 0))
	var icon: Control = ReadequipIcon.create_icon(eid, 1, cm, 2, true)
	var stars: Array = ReadequipIcon.get_stars(icon)
	assert_eq(stars.size(), ml, "show_gray → level 蓝 + (ml-level) 灰 = ml 颗")
	assert_eq(stars[0]["type"], "y", "第1颗蓝（level）")
	assert_eq(stars[1]["type"], "y", "第2颗蓝（level）")
	assert_eq(stars[2]["type"], "n", "第3颗灰（占位，show_gray）")
	icon.free()


# 默认 level=0, show_gray=false → 不画星（兼容现有调用，不破坏 hero_detail/equip_craft 等）。
func test_stars_default_no_stars() -> void:
	var eid: int = _find_equip_with_ml(1)
	if eid < 0:
		assert_true(true, "无 ml>=1 装备，skip")
		return
	var icon: Control = ReadequipIcon.create_icon(eid, 1, cm)
	var stars: Array = ReadequipIcon.get_stars(icon)
	assert_eq(stars.size(), 0, "默认 level=0/show_gray=false 不画星")
	icon.free()


# level=0, show_gray=true → 全灰星占位（ml 颗 type=n，源 :1222-1228 level=0 时全灰）。
func test_stars_zero_level_all_gray() -> void:
	var eid: int = _find_equip_with_ml(2)
	if eid < 0:
		assert_true(true, "无 ml>=2 装备，skip")
		return
	var ml: int = int(ReadequipData.get_equip_level_exp(eid, cm).get("ml", 0))
	var icon: Control = ReadequipIcon.create_icon(eid, 1, cm, 0, true)
	var stars: Array = ReadequipIcon.get_stars(icon)
	assert_eq(stars.size(), ml, "level=0 show_gray=true → 全灰占位 ml 颗")
	for s in stars:
		assert_eq(s["type"], "n", "全灰 type=n")
	icon.free()


# ==== refresh_stars（照源 refreshHeroItemStar:1243-1256）====

# level=0 全灰 ml 颗，refresh_stars(2) → stars[0,1] 灰→蓝（type=y visible=false），stars[2..] 保持灰。
func test_refresh_gray_to_blue() -> void:
	var eid: int = _find_equip_with_ml(3)
	if eid < 0:
		assert_true(true, "无 ml>=3 装备，skip")
		return
	var icon: Control = ReadequipIcon.create_icon(eid, 1, cm, 0, true)
	var ml: int = int(ReadequipData.get_equip_level_exp(eid, cm).get("ml", 0))
	assert_eq(ReadequipIcon.get_stars(icon).size(), ml, "refresh 前 ml 颗全灰")
	ReadequipIcon.refresh_stars(icon, 2)
	var stars: Array = ReadequipIcon.get_stars(icon)
	assert_eq(stars.size(), ml, "refresh 后数量不变（不删灰，加蓝覆盖）")
	assert_eq(String(stars[0]["type"]), "y", "第1颗灰→蓝")
	assert_eq(String(stars[1]["type"]), "y", "第2颗灰→蓝")
	assert_eq(String(stars[2]["type"]), "n", "第3颗保持灰（超出 new_level=2）")
	assert_false((stars[0]["icon"] as CanvasItem).visible, "refresh 新星 visible=false（playEnhanceAnim 点亮前隐藏）")
	icon.free()


# 已蓝星（type=y）refresh 时跳过不替换（源 :1246 if type==n 守卫），icon 引用不变。
func test_refresh_skips_existing_blue() -> void:
	var eid: int = _find_equip_with_ml(4)
	if eid < 0:
		assert_true(true, "无 ml>=4 装备，skip")
		return
	var icon: Control = ReadequipIcon.create_icon(eid, 1, cm, 2, true)
	var blue0 = ReadequipIcon.get_stars(icon)[0]["icon"]
	ReadequipIcon.refresh_stars(icon, 4)
	var stars: Array = ReadequipIcon.get_stars(icon)
	assert_same(stars[0]["icon"], blue0, "已蓝 icon 不替换（源 type=y 跳过）")
	assert_eq(String(stars[2]["type"]), "y", "第3颗灰→蓝")
	assert_eq(String(stars[3]["type"]), "y", "第4颗灰→蓝")
	icon.free()


# new_level 超出 stars.size()（满级后再 refresh）不崩（源 :1245 for 1,l 自然止 + 本项目 break 双保险）。
func test_refresh_beyond_size_safe() -> void:
	var eid: int = _find_equip_with_ml(2)
	if eid < 0:
		assert_true(true, "无 ml>=2 装备，skip")
		return
	var icon: Control = ReadequipIcon.create_icon(eid, 1, cm, 0, true)
	var ml: int = int(ReadequipData.get_equip_level_exp(eid, cm).get("ml", 0))
	ReadequipIcon.refresh_stars(icon, ml + 10)   # 超 ml 不崩
	assert_true(true, "refresh 超 ml 不崩（break 守卫）")
	icon.free()
