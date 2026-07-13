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
	var pd := PlayerData.new(cm)
	pd.vip_level = 0
	assert_eq(pd.is_vip_unlocked("Multiple Midas"), false, "VIP 0 Multiple Midas=false")
