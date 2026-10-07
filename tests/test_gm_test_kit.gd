extends GutTest
# GmManager.grant_test_kit 一键测试物资包测试（2026-10-06，设置弹窗 GM 按钮配套）。
# 2026-10-07 瘦身：仅金币/钻石/体力 999/消耗品，去掉等级/关卡/全英雄/灵魂石——
# 断言覆盖"给了什么"与"不再给什么"两侧。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _new_player() -> PlayerData:
	return PlayerData.new(cm)


func test_grant_test_kit_package() -> void:
	var pd := _new_player()
	var heroes_before: int = pd.hero_manager.heroes.size()
	var progress_before: int = pd.stage_manager.progress.size()
	var max_normal_before: int = pd.stage_manager.max_normal
	var items_before: int = pd.items.size()
	var r: Dictionary = GmManager.grant_test_kit(pd)
	# 给了：金币/钻石/体力 999
	assert_eq(pd.hero_manager.gold, GmManager.TEST_GOLD, "金币拉满")
	assert_eq(pd.diamond, GmManager.TEST_DIAMOND, "钻石拉满")
	assert_eq(pd.vitality, 999, "体力保底 999")
	# 给了：消耗品 8 种 ×99（体力药 3 + 经验药 4 + 扫荡券 1）
	assert_eq(pd.items.size(), items_before + 8, "消耗品新增 8 种（新号默认 8 种初始物品）")
	assert_eq(int(pd.items.get(336, 0)), 99, "章鱼丸子×99")
	assert_eq(int(pd.items.get(289, 0)), 99, "奥尔良烤翅×99")
	assert_eq(int(pd.items.get(217, 0)), 99, "孜然羊肉串×99")
	assert_eq(int(pd.items.get(169, 0)), 99, "经验药水×99")
	assert_eq(int(pd.items.get(218, 0)), 99, "经验奶油×99")
	assert_eq(int(pd.items.get(290, 0)), 99, "芝士经验×99")
	assert_eq(int(pd.items.get(440, 0)), 99, "顶级经验药×99")
	assert_eq(int(pd.items.get(390, 0)), 99, "扫荡券×99")
	# 不再给：战队等级/关卡/英雄/灵魂石（对照 2026-10-06 旧版行为）
	assert_eq(pd.team_level, 1, "战队等级不动（新号仍 1）")
	assert_eq(pd.hero_manager.heroes.size(), heroes_before, "英雄数不变")
	assert_eq(pd.stage_manager.progress.size(), progress_before, "关卡进度不变")
	assert_eq(pd.stage_manager.max_normal, max_normal_before, "max_normal 不变")
	assert_eq(int(pd.items.get(124, 0)), 0, "不发灵魂石（船长 124）")
	# 返回摘要
	assert_eq(int(r.get("vitality", 0)), 999, "摘要含体力")


func test_grant_test_kit_idempotent_max_semantics() -> void:
	# 幂等（max 只升不降）：已有更高资源不回退；重复点击安全（物品叠加可再点）
	var pd := _new_player()
	pd.hero_manager.gold = 99999999   # 高于 TEST_GOLD
	pd.vitality = 5000                # 高于 TEST_VITALITY
	GmManager.grant_test_kit(pd)
	assert_eq(pd.hero_manager.gold, 99999999, "已有更高金币不回退（max 语义）")
	assert_eq(pd.vitality, 5000, "已有更高体力不回退（max 语义）")
	var heroes_before: int = pd.hero_manager.heroes.size()
	GmManager.grant_test_kit(pd)
	assert_eq(pd.hero_manager.heroes.size(), heroes_before, "重复发放英雄数不变")
	assert_eq(int(pd.items.get(336, 0)), 99 + 99, "消耗品累加（add_item 叠加，可再点）")
