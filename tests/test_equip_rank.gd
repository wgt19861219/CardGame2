extends GutTest
# 装备进阶单测（照源 player.lua:2059-2083 canUpgrade/upgrade）：rank 进阶需 6 槽穿齐 + 上限 + 重置 Init。

var cm: ConfigManager

func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()

# 辅助：穿齐当前 rank 的 6 槽（满足 can_upgrade_rank 前置）。
func _wear_full_gear(mgr: HeroManager, inst_id: int) -> void:
	for slot in range(6):
		mgr.wear_equip(inst_id, slot)

func test_can_upgrade_rank_requires_full_gear() -> void:
	var mgr := HeroManager.new(cm)
	var inst_id := mgr.add_hero(1)
	assert_false(mgr.can_upgrade_rank(inst_id), "6 槽未穿齐 → 不可进阶")
	_wear_full_gear(mgr, inst_id)
	assert_true(mgr.can_upgrade_rank(inst_id), "6 槽穿齐 → 可进阶")

func test_upgrade_rank_increments() -> void:
	var mgr := HeroManager.new(cm)
	var inst_id := mgr.add_hero(1)
	var hero := mgr.get_hero(inst_id)
	_wear_full_gear(mgr, inst_id)
	var r := hero.rank
	assert_true(mgr.upgrade_rank(inst_id), "进阶应成功")
	assert_eq(hero.rank, r + 1, "rank +1")

func test_upgrade_rank_resets_to_init() -> void:
	# 源 upgrade：rank+1 后 _items 重置为 {_item_id=0,_exp=0}，再穿 hero_equip[tid][new_rank]["Init{i} ID"]
	var mgr := HeroManager.new(cm)
	var inst_id := mgr.add_hero(1)
	_wear_full_gear(mgr, inst_id)
	mgr.upgrade_rank(inst_id)
	var hero := mgr.get_hero(inst_id)
	var init_row: Dictionary = cm.get_raw_table(&"hero_equip").get("1", {}).get(str(hero.rank), {})
	for slot in range(6):
		var init_id: int = int(init_row.get("Init" + str(slot + 1) + " ID", 0))
		assert_eq(int(hero.equip_slots[slot]), init_id, "slot %d 重置为 Init 装备" % slot)

func test_upgrade_rank_fails_without_full_gear() -> void:
	var mgr := HeroManager.new(cm)
	var inst_id := mgr.add_hero(1)
	assert_false(mgr.upgrade_rank(inst_id), "未穿齐进阶失败")

func test_upgrade_rank_caps_at_22() -> void:
	# 源 player.lua:2066 canUpgrade `return self._rank < 22`（玩家装备 rank 进阶上限 22；
	# Hero_equip 表 23 档是数据，rank 23 玩家不可达，照源）。
	var mgr := HeroManager.new(cm)
	var inst_id := mgr.add_hero(1)
	var hero := mgr.get_hero(inst_id)
	hero.rank = 22  # 上限（源 _rank < 22）
	assert_false(mgr.upgrade_rank(inst_id), "rank 22 为上限，不可再进阶（源 _rank<22）")


# 战斗力 GS（照源 main.lua:1750 + player.lua:1490 _gs=5）：基础 5 + sum(Equip.GS × Hero_equip.EquipLevel)。
func test_calc_gs_base_no_gear() -> void:
	var mgr := HeroManager.new(cm)
	var inst_id := mgr.add_hero(1)
	var hero := mgr.get_hero(inst_id)
	assert_eq(mgr.calc_gs(hero), 5, "无装备 GS=5（基础）")

func test_calc_gs_increases_with_gear() -> void:
	var mgr := HeroManager.new(cm)
	var inst_id := mgr.add_hero(1)
	var hero := mgr.get_hero(inst_id)
	_wear_full_gear(mgr, inst_id)
	assert_true(mgr.calc_gs(hero) > 5, "穿齐后 GS > 5（基础+装备贡献）")

func test_wear_equip_updates_hero_gs() -> void:
	var mgr := HeroManager.new(cm)
	var inst_id := mgr.add_hero(1)
	var hero := mgr.get_hero(inst_id)
	var gs0: int = hero.gs
	_wear_full_gear(mgr, inst_id)
	assert_true(hero.gs > gs0, "穿齐后 hero.gs 更新（>初始5）")
