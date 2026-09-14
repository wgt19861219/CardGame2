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


# === 2026-09-14 受控偏离：canCraft 槽自动合成（用户拍板"加自动合成"） ===
# 源 doClickUpgrade 对 canCraft 走 else toast（要求玩家手动点槽合成）；本项目受控增强：
# canCraft 槽（配方存在+等级达标）且材料递归齐备+金币足 → 进阶时自动合成再穿，
# 绿+角标（eti=wear）语义与进阶行为一致。材料/金币不足或 notHave/cannotwear 仍整单拒绝零消耗。
# 回归背景：用户火影 tid=3 rank4 slot0=251（配方 237+221+118+5000 金币）材料齐被拒三次碰壁。

const HUOYING_TID := 3  # Hero_equip[3][4] Equip1-6 = 251/261/182/173/118/207
const HUOYING_RANK4 := [251, 261, 182, 173, 118, 207]

func _make_huoying(only_slot0_open: bool = true) -> PlayerData:
	var pd := PlayerData.new(cm)
	var inst_id: int = pd.hero_manager.add_hero(HUOYING_TID)
	var hero := pd.hero_manager.get_hero(inst_id)
	hero.rank = 4
	hero.level = 48   # ≥251 的 Level Requirement 33
	if only_slot0_open:
		for slot in range(1, 6):   # slot1-5 预先穿好（isEquiped 跳过），聚焦 slot0 合成分支
			hero.equip_slots[slot] = HUOYING_RANK4[slot]
	pd.hero_manager.gold = 99999
	return pd


# canCraft 材料齐+金币足 → 自动合成再穿：返 1 / slot0=251 / 金币扣 Expense / 材料清账
func test_autowear_auto_crafts_when_materials_ready() -> void:
	var pd := _make_huoying()
	var inst_id: int = pd.hero_manager.get_owned_hero_ids()[0]
	pd.add_item(237, 1)
	pd.add_item(221, 1)
	pd.add_item(118, 1)   # 251 配方材料（118 Count=0 → 按 1 计）
	var gold0: int = pd.hero_manager.gold
	var worn: int = EquipCraftManager.autowear_for_upgrade(pd, inst_id)
	assert_eq(worn, 1, "canCraft 材料齐 → 合成+穿上（返 1）")
	var hero := pd.hero_manager.get_hero(inst_id)
	assert_eq(int(hero.equip_slots[0]), 251, "slot0 穿上合成出的 251")
	assert_eq(pd.hero_manager.gold, gold0 - 5000, "金币扣配方 Expense 5000")
	assert_eq(int(pd.items.get(237, 0)), 0, "材料 237 清账")
	assert_eq(int(pd.items.get(221, 0)), 0, "材料 221 清账")
	assert_eq(int(pd.items.get(118, 0)), 0, "材料 118 清账（合成产出 251 又被穿上）")
	assert_true(pd.hero_manager.can_upgrade_rank(inst_id), "6 槽齐 → 可进阶")


# 材料不齐 → 整单拒绝零消耗（源 notHave 同语义，合成材料也是背包资产）
func test_autowear_auto_craft_rejects_missing_material() -> void:
	var pd := _make_huoying()
	var inst_id: int = pd.hero_manager.get_owned_hero_ids()[0]
	pd.add_item(237, 1)   # 缺 221/118
	var gold0: int = pd.hero_manager.gold
	var worn: int = EquipCraftManager.autowear_for_upgrade(pd, inst_id)
	assert_eq(worn, -1, "材料不齐 → 整单拒绝")
	assert_eq(pd.hero_manager.gold, gold0, "金币零消耗")
	assert_eq(int(pd.items.get(237, 0)), 1, "材料零消耗")
	assert_eq(int(pd.hero_manager.get_hero(inst_id).equip_slots[0]), 0, "槽零穿戴")


# 金币不足 → 整单拒绝零消耗
func test_autowear_auto_craft_rejects_insufficient_gold() -> void:
	var pd := _make_huoying()
	var inst_id: int = pd.hero_manager.get_owned_hero_ids()[0]
	pd.add_item(237, 1)
	pd.add_item(221, 1)
	pd.add_item(118, 1)
	pd.hero_manager.gold = 4999   # < Expense 5000
	var worn: int = EquipCraftManager.autowear_for_upgrade(pd, inst_id)
	assert_eq(worn, -1, "金币不足 → 整单拒绝")
	assert_eq(pd.hero_manager.gold, 4999, "金币零消耗")
	assert_eq(int(pd.items.get(237, 0)), 1, "材料零消耗")
	assert_eq(int(pd.items.get(118, 0)), 1, "材料零消耗")


# 跨槽预算联动：118 既是 slot0 合成材料又是 slot4 直穿装备，持有 1 件总需 2 → 拒绝零消耗
# （防执行时序性超扣——历史存量 items 负数即此类超扣痕迹）
func test_autowear_budget_shared_between_craft_and_wear() -> void:
	var pd := _make_huoying(false)   # slot1-5 不预穿，slot4 走 canWear
	var inst_id: int = pd.hero_manager.get_owned_hero_ids()[0]
	var hero := pd.hero_manager.get_hero(inst_id)
	for slot in [1, 2, 3, 5]:   # 预穿 slot1/2/3/5，留 slot0（合成）与 slot4（直穿）争 118
		hero.equip_slots[slot] = HUOYING_RANK4[slot]
	pd.add_item(261, 1)   # 无关槽材料齐备避免干扰（slot4=118 才是预算主角）
	pd.add_item(237, 1)
	pd.add_item(221, 1)
	pd.add_item(118, 1)   # 总持有 1：slot0 合成要 1 + slot4 直穿要 1 = 2 > 1
	var worn: int = EquipCraftManager.autowear_for_upgrade(pd, inst_id)
	assert_eq(worn, -1, "118 总需 2 > 持有 1 → 整单拒绝")
	assert_eq(int(pd.items.get(118, 0)), 1, "118 保留原样（零消耗）")
	assert_eq(int(hero.equip_slots[0]), 0, "槽零穿戴")
	assert_eq(int(hero.equip_slots[4]), 0, "槽零穿戴")
