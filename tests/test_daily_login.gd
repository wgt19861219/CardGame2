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
