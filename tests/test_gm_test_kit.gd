extends GutTest
# GmManager.grant_test_kit 一键测试物资包测试（2026-10-06，设置弹窗 GM 按钮配套）。
# 用途：模拟器测试包新号缺资源没法复测玩法（觉醒 50 碎片/进阶材料/体力药）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _new_player() -> PlayerData:
	return PlayerData.new(cm)


func test_grant_test_kit_full_package() -> void:
	var pd := _new_player()
	var r: Dictionary = GmManager.grant_test_kit(pd, cm)
	# 资源
	assert_eq(pd.hero_manager.gold, GmManager.TEST_GOLD, "金币拉满")
	assert_eq(pd.diamond, GmManager.TEST_DIAMOND, "钻石拉满")
	assert_eq(pd.vitality, 9999, "体力攒体 9999 硬上限")
	assert_eq(pd.team_level, GmManager.MAX_UNLOCK_LEVEL, "战队等级 80")
	# 全英雄 + 练度（54 英雄，Unit 表 Hero+Portrait 口径）
	assert_eq(pd.hero_manager.heroes.size(), 54, "全英雄 54")
	var coco: HeroInstance = null
	for inst_id in pd.hero_manager.heroes:
		var h: HeroInstance = pd.hero_manager.heroes[inst_id]
		if h.tid == 1:
			coco = h
		assert_eq(h.level, 90, "tid=%d level 90" % h.tid)
		assert_eq(h.stars, 5, "tid=%d stars 5" % h.tid)
		assert_eq(h.rank, 12, "tid=%d rank 12（金装起点）" % h.tid)
	assert_not_null(coco, "船长（tid=1）在列")
	if coco != null:
		var worn: int = 0
		for slot in coco.equip_slots:
			if int(slot) > 0:
				worn += 1
		assert_eq(worn, 5, "rank12 穿 5 配方槽（槽1 无配方跳过）")
	# 测试道具：专属灵魂石（tid1→124）+ 体力药 + 扫荡券
	assert_eq(int(pd.items.get(124, 0)), 99, "船长灵魂石 124×99（觉醒 50 够）")
	assert_eq(int(pd.items.get(336, 0)), 99, "章鱼丸子×99")
	assert_eq(int(pd.items.get(390, 0)), 99, "扫荡券×99")
	# 关卡解锁（stage_manager 由 PlayerData 构造自带）
	assert_true(pd.stage_manager.progress.size() > 0, "普通+精英关全 3 星解锁")
	assert_eq(pd.stage_manager.max_normal, GmManager.MAX_NORMAL_STAGES, "max_normal 解锁")
	# 返回摘要
	assert_eq(int(r.get("heroes", 0)), 54, "摘要含英雄数")


func test_grant_test_kit_idempotent_max_semantics() -> void:
	# 幂等（max 只升不降）：已有更高资源不回退；重复点击安全
	var pd := _new_player()
	pd.hero_manager.gold = 99999999   # 高于 TEST_GOLD
	GmManager.grant_test_kit(pd, cm)
	assert_eq(pd.hero_manager.gold, 99999999, "已有更高金币不回退（max 语义）")
	var before: int = pd.hero_manager.heroes.size()
	GmManager.grant_test_kit(pd, cm)
	assert_eq(pd.hero_manager.heroes.size(), before, "重复发放英雄数不变")
	assert_eq(int(pd.items.get(124, 0)), 99 + 99, "碎片累加（add_item 叠加，可再点）")
