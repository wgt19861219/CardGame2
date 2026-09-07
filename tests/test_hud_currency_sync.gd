extends GutTest
# HudOverlay 货币自动同步(2026-09-07 抽卡扣费货币栏不刷根修):
# 扣费/入账点分散在 Data 层多处(抽卡/商店/升星/技能/进阶/技能点/卖出/发奖),
# 无全局货币信号——HUD _process 每帧对比缓存值,变化即 _refresh_status,
# 一处覆盖全部现在与未来的货币变化场景。

func test_currency_change_triggers_resync() -> void:
	HudOverlay._built = true
	HudOverlay._last_gold = -1
	HudOverlay._last_diamond = -1
	var old_player: Variant = GameData.player
	var pd := PlayerData.new(ConfigManager.new())
	GameData.player = pd
	pd.diamond = 80000
	pd.hero_manager.gold = 500000
	HudOverlay._process(0.0)   # 首帧:缓存旧值(-1≠现值)→ 同步
	assert_eq(HudOverlay._last_diamond, 80000, "首帧同步 diamond 缓存")
	assert_eq(HudOverlay._last_gold, 500000, "首帧同步 gold 缓存")
	pd.diamond = 76000   # 抽卡扣费
	pd.hero_manager.gold = 410000
	HudOverlay._process(0.0)   # 值变 → 再同步
	assert_eq(HudOverlay._last_diamond, 76000, "扣费后 diamond 缓存更新")
	assert_eq(HudOverlay._last_gold, 410000, "扣费后 gold 缓存更新")
	# 还原全局状态(避免污染其它测试)
	GameData.player = old_player
	HudOverlay._built = false
	HudOverlay._last_gold = -1
	HudOverlay._last_diamond = -1
