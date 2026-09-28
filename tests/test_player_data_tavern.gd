extends GutTest
# Phase 5.3 PlayerData.draw_tavern 抽卡消耗测试（2026-07-02）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_draw_tavern_cost() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 500   # MagicSoul Cost=400
	var r: Dictionary = pd.draw_tavern("MagicSoul", true, false, 0, cm)
	assert_eq(bool(r["ok"]), true, "钻石 500 >= Cost 400 → ok")
	assert_eq(int(r["chest_group"]), 23, "chest_group=23")
	assert_eq(pd.diamond, 100, "扣 400 后剩 100")


func test_draw_tavern_insufficient() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 100   # < 400
	var r: Dictionary = pd.draw_tavern("MagicSoul", true, false, 0, cm)
	assert_eq(bool(r["ok"]), false, "钻石不足 → ok=false")
	assert_eq(pd.diamond, 100, "不扣")


func test_draw_tavern_free() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 100
	var r: Dictionary = pd.draw_tavern("MagicSoul", true, true, 0, cm)   # is_free
	assert_eq(bool(r["ok"]), true, "免费 → ok=true")
	assert_eq(pd.diamond, 100, "免费不扣")


# Bronze 金币单抽（源 TavernType Bronze false.false.0 Cost=10000 Cost Type=Gold，照源扣金币非钻石）
func test_draw_tavern_bronze_gold() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 50000
	pd.diamond = 5000
	var r: Dictionary = pd.draw_tavern("Bronze", false, false, 0, cm)
	assert_eq(bool(r["ok"]), true, "Bronze 单抽 ok")
	assert_eq(pd.hero_manager.gold, 40000, "扣 10000 金币（Cost Type=Gold）")
	assert_eq(pd.diamond, 5000, "Bronze 不扣钻石（Cost Type=Gold）")


# Bronze 金币不足失败（不扣钻石）
func test_draw_tavern_bronze_insufficient() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 5000   # < 10000
	pd.diamond = 5000
	var r: Dictionary = pd.draw_tavern("Bronze", false, false, 0, cm)
	assert_eq(bool(r["ok"]), false, "金币不足 ok=false")
	assert_eq(pd.hero_manager.gold, 5000, "不扣金币")
	assert_eq(pd.diamond, 5000, "不扣钻石")


func test_draw_tavern_full() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 500
	var rng := BattleRng.new(12345)
	var r: Dictionary = pd.draw_tavern_full("MagicSoul", true, false, 0, rng)
	assert_eq(bool(r["ok"]), true, "draw_tavern_full ok")
	assert_true(int(r["loots"].size()) >= 10, "十连产出 >=10 物品（源 _item_ids）")
	assert_false(pd.items.is_empty(), "产出进 items 背包")
	assert_eq(pd.diamond, 100, "扣 Cost 400 后剩 100")


func test_is_vip_unlocked() -> void:
	# 单机去 VIP 限制（2026-09-08）：特权查询按特权档（满级）判，与显示 vip_level 解耦。
	# VIP.json 满级 Multiple Midas=true → VIP0 显示也解锁。
	var pd := PlayerData.new(cm)
	pd.vip_level = 0
	assert_eq(pd.is_vip_unlocked("Multiple Midas"), true, "特权档满级 Multiple Midas=true（与 vip_level 解耦）")


# ---- 新英雄/重复碎魂(原版 _new_heroes/_smash_idx 单机化,2026-09-07)----

# 未拥有英雄 → add_hero 入库;重复英雄 → 转魂石(源 _smash_idx 语义)。
func test_new_hero_and_duplicate_fragment() -> void:
	var pd := PlayerData.new(cm)
	pd._settle_tavern_loot([{"id": 1, "amount": 2}])
	assert_eq(pd.hero_manager.heroes.size(), 1, "未拥有英雄 tid=1 → add_hero")
	pd._settle_tavern_loot([{"id": 1, "amount": 2}])
	assert_eq(pd.hero_manager.heroes.size(), 1, "重复英雄不再入库")
	var frag_id: int = pd._fragment_id_for_hero(1)
	assert_eq(pd.hero_manager.fragment_count(frag_id), 2, "重复英雄转魂石 ×2（单账本 items）")


# magic 十连端到端（2026-09-16 魂匣重建）：大量今日热点魂石 + 本周英雄整卡（未拥有
# 入库/已拥有转魂石由 _settle 分流），不再走装备品质池（用户报「介绍能获大量英雄或
# 灵魂石，实际同黄金池」根修）。
func test_draw_full_magic_soul_flow() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 100000
	var r: Dictionary = pd.draw_tavern_full("MagicSoul", true, false, 0, BattleRng.new(5))
	assert_true(bool(r["ok"]), "magic 十连 ok")
	var loots: Array = r["loots"]
	var soul_count: int = 0
	var hero_count: int = 0
	var soul_gained: int = 0
	for loot in loots:
		if int(loot["id"]) >= 100:
			soul_count += 1
			soul_gained += int(loot["amount"])
		else:
			hero_count += 1
	assert_eq(soul_count, 10, "十连主位 10 个全为魂石")
	assert_eq(hero_count, 1, "附加 1 个本周英雄整卡位")
	assert_true(soul_gained >= 10, "魂石总量 >=10（大量灵魂石，实得 %d）" % soul_gained)
	# 魂石结算进 items（单账本，int 键；十连同 id 累计）
	var soul_id: int = int(loots[0]["id"])
	var expect_total: int = 0
	for loot in loots:
		if int(loot["id"]) == soul_id:
			expect_total += int(loot["amount"])
	assert_eq(int(pd.items.get(soul_id, 0)), expect_total, "首位魂石入 items 账本（同 id 累计）")


# P1-7（2026-09-28 审查）：获得新英雄图鉴记录统一下沉到 HeroManager.add_hero
# （PlayerData 注入 handbook 钩子）——抽卡/碎片合成/碎片召唤三路径曾漏记。
func test_add_hero_records_handbook_via_hook() -> void:
	var pd := PlayerData.new(cm)
	pd.apply_default_data()   # 初始英雄已记录图鉴（collected_heroes 非空）
	assert_ne(pd.hero_manager.handbook, null, "PlayerData 注入 handbook 钩子")
	var tid: int = _pick_tid_not_collected(pd)
	assert_false(pd.handbook.has_hero(tid), "前置：该 tid 尚未收集（避免与初始英雄重叠）")
	pd.hero_manager.add_hero(tid)
	assert_true(pd.handbook.has_hero(tid), "add_hero 自动记录图鉴（下沉钩子）")


func _pick_tid_not_collected(pd: PlayerData) -> int:
	for tid_str in cm.get_raw_table("Unit"):
		var tid: int = int(tid_str)
		if not pd.handbook.has_hero(tid):
			return tid
	return 1
