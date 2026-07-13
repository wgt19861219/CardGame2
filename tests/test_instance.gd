extends GutTest
# Step 3.2 副本单测：次数限制 + 难度奖励 + 通关 + 宝箱掉落(确定性)。

var cm: ConfigManager

func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()

func test_enter_respects_daily_limit() -> void:
	var mgr := InstanceManager.new(cm)
	assert_true(mgr.enter_instance(50001), "首次进入")
	assert_true(mgr.enter_instance(50001), "第二次进入")
	assert_false(mgr.enter_instance(50001), "第三次超次数限制")

func test_exit_gives_difficulty_reward() -> void:
	var mgr := InstanceManager.new(cm)
	var r1 := mgr.exit_instance(50001, 1, true)
	assert_eq(int(r1["money"]), 2000, "普通难度奖励 2000")
	var r4 := mgr.exit_instance(50002, 4, true)
	assert_eq(int(r4["money"]), 8000, "噩梦难度奖励 8000")

func test_exit_defeat_no_reward() -> void:
	var mgr := InstanceManager.new(cm)
	var r := mgr.exit_instance(50001, 1, false)
	assert_eq(int(r["money"]), 0, "失败无奖励")

func test_clear_marked_on_win() -> void:
	var mgr := InstanceManager.new(cm)
	assert_false(mgr.is_cleared(50001))
	mgr.exit_instance(50001, 1, true)
	assert_true(mgr.is_cleared(50001), "胜利标记通关")

func test_chest_loot_deterministic() -> void:
	var mgr := InstanceManager.new(cm)
	var r1 := mgr.generate_chest_loot(1, BattleRng.new(42))
	var r2 := mgr.generate_chest_loot(1, BattleRng.new(42))
	assert_eq(r1, r2, "同 seed 宝箱掉落一致（确定性）")

func test_module_registry_compatible() -> void:
	# InstanceModule 符合 ModuleRegistry 约定
	var mod := InstanceModule.new()
	var reg := ModuleRegistry.new()
	reg.add(&"Instance", mod)  # 不应 assert 失败（有 register + get_dependencies）
	assert_true(reg.validate().is_empty(), "InstanceModule 应通过校验")
