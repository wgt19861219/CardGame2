extends GutTest
# 进阶前自动穿戴测试（照源 herodetail/window.lua:706-747 doClickUpgrade needWear 分支补译）。
# 源语义：点进阶时，6 槽中"背包已持有+等级够"（canWear）的槽一键全穿（consumeEquip + hero:equip）；
# 任一槽 isEquiped 之外的非法态（canCraft/notHave/cannotwear）→ 整体拒绝（源弹"穿齐装备"toast）。
# 回归背景：2026-09-05 用户报"船长装备齐全点进阶仍提示要穿齐装备"——迁移时漏译自动穿戴分支。

const HERO_TID := 1  # Hero_equip[1][1] Equip1-6 = 102/102/111/107/108/109
const RANK1_REQ := [102, 102, 111, 107, 108, 109]

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_pd() -> PlayerData:
	var pd := PlayerData.new(cm)
	var inst_id: int = pd.hero_manager.add_hero(HERO_TID)
	pd.hero_manager.get_hero(inst_id).level = 99   # 绕过 Equip Level Requirement（只测穿戴分支）
	return pd


# 6 件全持有 → 一键全穿：返 6 / 槽位对 / 背包各扣 1 / 可进阶
func test_autowear_all_held() -> void:
	var pd := _make_pd()
	var inst_id: int = pd.hero_manager.get_owned_hero_ids()[0]
	for eid in RANK1_REQ:
		pd.add_item(eid, 1)
	var worn: int = EquipCraftManager.autowear_for_upgrade(pd, inst_id)
	assert_eq(worn, 6, "6 件全持有 → 穿 6 件")
	var hero := pd.hero_manager.get_hero(inst_id)
	for slot in range(6):
		assert_eq(int(hero.equip_slots[slot]), RANK1_REQ[slot], "槽 %d 穿上配方装备" % (slot + 1))
		assert_eq(int(pd.items.get(RANK1_REQ[slot], 0)), 0, "槽 %d 装备扣背包 1" % (slot + 1))
	assert_true(pd.hero_manager.can_upgrade_rank(inst_id), "穿齐后可进阶")


# 任一槽未持有 → 整体拒绝：返 -1 / 零穿戴 / 零消耗（源 needWear else 分支 toast+return）
func test_autowear_rejects_when_any_slot_missing() -> void:
	var pd := _make_pd()
	var inst_id: int = pd.hero_manager.get_owned_hero_ids()[0]
	for i in range(5):   # 只备前 5 槽，第 6 槽（111）缺
		pd.add_item(RANK1_REQ[i], 1)
	var worn: int = EquipCraftManager.autowear_for_upgrade(pd, inst_id)
	assert_eq(worn, -1, "任一槽缺失 → 整体拒绝")
	var hero := pd.hero_manager.get_hero(inst_id)
	for slot in range(6):
		assert_eq(int(hero.equip_slots[slot]), 0, "槽 %d 未被动穿（零穿戴）" % (slot + 1))
	assert_eq(int(pd.items.get(RANK1_REQ[0], 0)), 2, "背包零消耗（102 备了 2 件原样保留）")


# 已穿槽跳过（isEquiped）：先手穿 2 件，再备余 4 件 → 返 4
func test_autowear_skips_equipped_slots() -> void:
	var pd := _make_pd()
	var inst_id: int = pd.hero_manager.get_owned_hero_ids()[0]
	for i in range(2):
		pd.add_item(RANK1_REQ[i], 1)
		assert_true(pd.hero_manager.wear_equip(inst_id, i), "前置手穿槽 %d" % (i + 1))
	for i in range(2, 6):
		pd.add_item(RANK1_REQ[i], 1)
	var worn: int = EquipCraftManager.autowear_for_upgrade(pd, inst_id)
	assert_eq(worn, 4, "已穿 2 槽跳过 → 只穿余 4")
	var hero := pd.hero_manager.get_hero(inst_id)
	assert_true(pd.hero_manager.can_upgrade_rank(inst_id), "补齐后可进阶")
	assert_eq(int(pd.items.get(RANK1_REQ[0], 0)), 2, "已穿槽不重复扣背包（手穿不扣，102 两件都在）")
