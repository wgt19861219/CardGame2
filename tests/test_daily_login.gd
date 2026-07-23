extends GutTest
# DailyLogin 连续登录奖励单测 — 照源 player.lua:224 getLoginFrequency/getLoginRewardStatus +
# local_server.lua:2096 ask_daily_login。

var cm: ConfigManager

func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_first_login_frequency() -> void:
	var mgr := DailyLoginManager.new()
	# last_ts=0 → _is_consecutive_day 返 true → frequency+1 = 0+1 = 1（首次登录算第1天）
	assert_eq(mgr.get_login_frequency(1000), 1, "首次登录 frequency=1（last_ts=0 视为连续")


func test_reward_status_common_first_time() -> void:
	var mgr := DailyLoginManager.new()
	# last_ts=0 → _is_consecutive_day 返 true → "common" 可领
	assert_eq(mgr.get_reward_status(1000), "common", "首次登录可领")


func test_claim_reward_success() -> void:
	var mgr := DailyLoginManager.new()
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	var now: int = int(Time.get_unix_time_from_system())
	var r: Dictionary = mgr.claim_reward(pd, cm, now)
	assert_true(bool(r.get("ok", false)), "首次领取成功")
	# 二次领应失败（已领）
	var r2: Dictionary = mgr.claim_reward(pd, cm, now)
	assert_false(bool(r2.get("ok", false)), "同日二次领取失败")


func test_claim_reward_updates_status() -> void:
	var mgr := DailyLoginManager.new()
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	var now: int = int(Time.get_unix_time_from_system())
	mgr.claim_reward(pd, cm, now)
	assert_eq(mgr.get_reward_status(now), "received", "领后状态 received")


# A5 修复测试：源 :2152 status=2(common) 即便 VIP 达标也不双倍（漏 status==1 前置是原 bug）
func test_claim_reward_status_2_no_double_regardless_vip() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var row: Dictionary = DailyLoginManager._find_reward_row(cm, 1)
	if row.is_empty():
		assert_true(true, "当月无 frequency=1 数据，跳过")
		return
	var rtype: String = String(row.get("Reward Type", ""))
	var base_amount: int = int(row.get("Reward Amount", 0))
	var mgr := DailyLoginManager.new()
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	pd.vip_level = 99  # 远超任何 vip_req，验证「status=2 不双倍」是 status 决定非 VIP 决定
	var r: Dictionary = mgr.claim_reward(pd, cm, now, 2)  # status=2 common
	assert_true(bool(r.get("ok", false)), "status=2 领取成功")
	var expected: int = 1 if rtype == "Hero" else base_amount
	assert_eq(int(r.get("amount", 0)), expected, "status=2 common：VIP 达标仍单倍（源 :2152 status==1 前置）")


# A5 修复测试：源 :2152 status=1(all) + VIP 达标 → 双倍
func test_claim_reward_status_1_double_when_vip_met() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var row: Dictionary = DailyLoginManager._find_reward_row(cm, 1)
	if row.is_empty():
		assert_true(true, "当月无 frequency=1 数据，跳过")
		return
	var rtype: String = String(row.get("Reward Type", ""))
	var vip_req: int = int(row.get("Double Reward VIP Level", 0))
	var base_amount: int = int(row.get("Reward Amount", 0))
	if rtype == "Hero" or vip_req == 0:
		assert_true(true, "Hero 类型 / vip_req=0 无法验证 VIP 双倍，跳过")
		return
	var mgr := DailyLoginManager.new()
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	pd.vip_level = vip_req  # 正好达标
	var r: Dictionary = mgr.claim_reward(pd, cm, now, 1)  # status=1 all
	assert_true(bool(r.get("ok", false)), "status=1 领取成功")
	assert_eq(int(r.get("amount", 0)), base_amount * 2, "status=1 + VIP 达标 → 双倍（源 :2152-2153）")
