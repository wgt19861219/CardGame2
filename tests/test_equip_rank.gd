extends GutTest
# 装备进阶单测（照源运行时门槛：UI canHeroUpgrade :688-699 槽非空 + doClickUpgrade :706-716
# isEquiped/canWear 放行 + main.lua:1561 服务端仅 rank<max）：
# rank 进阶需 6 槽穿齐 + 上限 + 重置 Init。

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

# 2026-09-14 修复回归：源 doClickUpgrade :706-716 对 isEquiped 槽直接放行（不比对配方 ID），
# 服务端 main.lua:1561 仅校验 rank<max；player.lua:2058 canUpgrade 的"已穿==配方"是
# 从未被调用的死代码，误照译致用户存档六槽全穿（某槽为非配方装备）点进阶被拒。
func test_can_upgrade_rank_allows_worn_off_recipe_gear() -> void:
	var mgr := HeroManager.new(cm)
	var inst_id := mgr.add_hero(1)
	_wear_full_gear(mgr, inst_id)
	var hero := mgr.get_hero(inst_id)
	hero.equip_slots[3] = 219  # 模拟存档残留：穿着非本 rank 配方装备
	assert_true(mgr.can_upgrade_rank(inst_id), "6 槽全穿（含非配方装备）→ 可进阶（源 isEquiped 放行）")
	assert_true(mgr.upgrade_rank(inst_id), "进阶应成功")

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
	var init_row: Dictionary = cm.get_raw_table(&"Hero_equip").get("1", {}).get(str(hero.rank), {})
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


# 战斗力 GS（单一事实来源，2026-09-08 定稿）：hero.gs = 战斗单位全属性加权 gs
# （源 recalcHeroGs=UnitCreate 属性加权；废除旧近似公式 5+Σ Equip.GS×EquipLevel+技能×10——
# 不含等级/星级/附魔强化，升级升星附魔均不反映）。
func test_recalc_gs_base_no_gear() -> void:
	var mgr := HeroManager.new(cm)
	var inst_id := mgr.add_hero(1)
	var hero := mgr.get_hero(inst_id)
	assert_gt(hero.gs, 0, "无装备 GS=全属性加权（等级/星级基础属性仍计入）")

func test_recalc_gs_increases_with_gear() -> void:
	var mgr := HeroManager.new(cm)
	var inst_id := mgr.add_hero(1)
	var hero := mgr.get_hero(inst_id)
	var gs0: int = hero.gs
	_wear_full_gear(mgr, inst_id)
	assert_gt(hero.gs, gs0, "穿齐后 GS > 裸装（装备属性计入加权战力）")

func test_wear_equip_updates_hero_gs() -> void:
	var mgr := HeroManager.new(cm)
	var inst_id := mgr.add_hero(1)
	var hero := mgr.get_hero(inst_id)
	var gs0: int = hero.gs
	_wear_full_gear(mgr, inst_id)
	assert_true(hero.gs > gs0, "穿齐后 hero.gs 更新（>初始5）")
