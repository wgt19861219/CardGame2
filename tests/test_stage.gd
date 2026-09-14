extends GutTest
# Step 3.1 PVE 关卡单测：解锁 + 星数 max + 掉落生成(确定性) + 扫荡。

var cm: ConfigManager

func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()

func test_stage_data_loads() -> void:
	var data := StageData.from_config(cm, 1)
	assert_eq(data.stage_id, 1)
	assert_true(data.vitality_cost > 0, "关卡 1 应有体力消耗")

func test_unlock_respects_player_level() -> void:
	var mgr := StageManager.new(cm)
	var data := StageData.from_config(cm, 1)
	# 等级不足不解锁
	assert_false(mgr.is_unlocked(1, 0), "等级不足不解锁")
	# 等级足（关卡1 unlock_level 通常 1）
	assert_true(mgr.is_unlocked(1, data.unlock_level), "等级足解锁")

func test_exit_stage_stars_take_max() -> void:
	var mgr := StageManager.new(cm)
	# 首次 3 星
	var r1 := mgr.exit_stage(1, 3, true)
	assert_eq(r1["stars"], 3)
	# 再战 2 星，取 max=3
	var r2 := mgr.exit_stage(1, 2, true)
	assert_eq(r2["stars"], 3, "星数取 max(历史,本次)不降")
	# 失败不变
	var r3 := mgr.exit_stage(1, 0, false)
	assert_eq(r3["stars"], 3, "失败不降星")

func test_exit_stage_gives_rewards_on_win() -> void:
	var mgr := StageManager.new(cm)
	var r := mgr.exit_stage(1, 3, true)
	assert_true(int(r["exp"]) > 0 or int(r["money"]) > 0, "胜利应给奖励")
	var r2 := mgr.exit_stage(1, 3, false)
	assert_eq(int(r2["exp"]), 0, "失败无奖励")

func test_generate_loots_deterministic() -> void:
	var mgr := StageManager.new(cm)
	var l1 := mgr.generate_loots(1, BattleRng.new(42))
	var l2 := mgr.generate_loots(1, BattleRng.new(42))
	assert_eq(l1, l2, "同 seed 掉落一致（确定性）")

func test_sweep_no_gate_matches_source_logic() -> void:
	# 源 Logic handler（local_server.lua:1593）不检查 stars/通关——门槛由 UI doClickSweep 把关。
	# player=null 时 sweep 纯算奖励（照源 handler），未通关也返奖励。
	var mgr := StageManager.new(cm)
	var data := StageData.from_config(cm, 1)
	var r := mgr.sweep(1, 3)
	# 源 sweep :1602-1634 每次 loot 用 getStageRewards(×10) 累加 times 次 → exp = Exp Reward × 10 × times
	assert_eq(int(r["exp"]), data.exp_reward * 10 * 3, "扫荡奖励 = 单次(×10) × times（不检查 stars）")


func test_sweep_consumes_vitality_and_coin() -> void:
	# 源 sweep 回复处理 :4784 addVitality(-power*times) + :4786 useSweepTimes(times)
	var mgr := StageManager.new(cm)
	var data := StageData.from_config(cm, 1)
	var pd := PlayerData.new(cm)
	pd.team_level = 80   # 固定初态：2026-09-14 sweep 入账补全后经验会触发升级回体力（Vitality Reward），lv80 需 6000 exp 不升级
	pd.vitality = data.vitality_cost * 3 + 10   # 足 3 次 + 余量
	pd.add_item(PlayerData.SWEEP_COIN_ID, 5)
	var v_before := pd.vitality
	var c_before := pd.get_sweep_times()
	var r := mgr.sweep(1, 3, BattleRng.new(7), pd)
	assert_true(bool(r["ok"]), "扫荡成功")
	assert_eq(pd.vitality, v_before - data.vitality_cost * 3, "扣体力 = vitality_cost × times")
	assert_eq(pd.get_sweep_times(), c_before - 3, "扣扫荡券 × times")


func test_sweep_reject_no_vitality() -> void:
	var mgr := StageManager.new(cm)
	var data := StageData.from_config(cm, 1)
	var pd := PlayerData.new(cm)
	pd.vitality = data.vitality_cost * 3 - 1   # 不足 3 次
	pd.add_item(PlayerData.SWEEP_COIN_ID, 5)
	var r := mgr.sweep(1, 3, null, pd)
	assert_false(bool(r["ok"]), "体力不足拒绝")
	assert_eq(str(r.get("reason", "")), "no_vitality", "reason=no_vitality")
	assert_eq(pd.vitality, data.vitality_cost * 3 - 1, "体力未扣（先查后扣）")
	assert_eq(pd.get_sweep_times(), 5, "扫荡券未扣")


func test_sweep_reject_no_sweep_coin() -> void:
	var mgr := StageManager.new(cm)
	var data := StageData.from_config(cm, 1)
	var pd := PlayerData.new(cm)
	pd.vitality = data.vitality_cost * 3   # 体力足
	pd.add_item(PlayerData.SWEEP_COIN_ID, 2)   # 扫荡券不足 3
	var r := mgr.sweep(1, 3, null, pd)
	assert_false(bool(r["ok"]), "扫荡券不足拒绝")
	assert_eq(str(r.get("reason", "")), "no_sweep_coin", "reason=no_sweep_coin")
	assert_eq(pd.vitality, data.vitality_cost * 3, "体力未扣（扫荡券先查）")
	assert_eq(pd.get_sweep_times(), 2, "扫荡券未扣")


func test_sweep_pay_consumes_diamond() -> void:
	# 源 doClickSweep :145-148 扫荡券不足(times>tLimit)→pay 钻石扫；回复 :4788 _rmb-=cost
	var mgr := StageManager.new(cm)
	var data := StageData.from_config(cm, 1)
	var pd := PlayerData.new(cm)
	pd.vitality = data.vitality_cost * 3 + 10
	pd.diamond = 100
	var r := mgr.sweep(1, 3, BattleRng.new(7), pd, "pay")
	assert_true(bool(r["ok"]), "钻石扫成功")
	assert_eq(pd.diamond, 100 - 3, "扣钻石 = SWEEP_DIAMOND_PRICE(1) × times(3)")
	assert_eq(pd.get_sweep_times(), 0, "pay 不扣扫荡券")


func test_sweep_pay_reject_no_diamond() -> void:
	var mgr := StageManager.new(cm)
	var data := StageData.from_config(cm, 1)
	var pd := PlayerData.new(cm)
	pd.vitality = data.vitality_cost * 3
	pd.diamond = 2   # 不足 3
	var r := mgr.sweep(1, 3, null, pd, "pay")
	assert_false(bool(r["ok"]), "钻石不足拒绝")
	assert_eq(str(r.get("reason", "")), "no_diamond", "reason=no_diamond")
	assert_eq(pd.diamond, 2, "钻石未扣（spend_diamond 不足返 false 不扣）")
	assert_eq(pd.vitality, data.vitality_cost * 3, "体力未扣（先查后扣）")


func test_exit_stage_money_x10() -> void:
	# 源 local_server:412 getStageRewards 普通关 money/exp = 表值 × 10（exit_stage 返回值对称，匹配 take_stage_reward 实际发放）
	var mgr := StageManager.new(cm)
	var data := StageData.from_config(cm, 1)
	var r := mgr.exit_stage(1, 3, true)
	assert_eq(int(r["exp"]), data.exp_reward * 10, "普通关结算 exp × 10")
	assert_eq(int(r["money"]), data.money_reward * 10, "普通关结算 money × 10")


func test_sweep_drops_default_34_when_pro_missing() -> void:
	# 源 generateLoots :392 Pro 缺省 100 / sweep :1614 Pro 缺省 34（同 "UI reward i Pro" 字段，仅缺省不同）。
	# 遍历真实 Stage 表找一个有 rewardId 但缺 Pro 的槽，验证缺省差异（Stage 表 3745 无 Pro vs 1199 有 Pro）。
	var raw: Dictionary = cm.get_raw_table("Stage")
	var found: bool = false
	for sid in raw.keys():
		var row: Dictionary = raw[sid]
		for i in range(1, StageData.DROP_SLOT_COUNT + 1):
			var pro_key: String = "UI reward" + str(i) + " Pro"
			if int(row.get("UI reward" + str(i), 0)) != 0 and not row.has(pro_key):
				var data := StageData.from_config(cm, int(sid))
				assert_eq(int(data.drops[i - 1]["probability"]), StageData.DEFAULT_DROP_PROB, "drops Pro 缺省 100（generateLoots）")
				assert_eq(int(data.sweep_drops[i - 1]["probability"]), StageData.SWEEP_DEFAULT_PROB, "sweep_drops Pro 缺省 34（照源 sweep :1614）")
				found = true
				break
		if found:
			break
	assert_true(found, "Stage 表存在 Pro 缺失槽位")


func test_sweep_drops_same_slots_as_drops() -> void:
	# sweep_drops 与 drops 同 7 槽解析，仅 Pro 缺省不同；项数与 item_id 必须一致（sweep 用 sweep_drops 非 drops）。
	var data := StageData.from_config(cm, 1)
	assert_eq(data.sweep_drops.size(), data.drops.size(), "sweep_drops 与 drops 项数一致")
	for i in range(data.drops.size()):
		assert_eq(int(data.sweep_drops[i]["item_id"]), int(data.drops[i]["item_id"]), "同槽 item_id 一致")
