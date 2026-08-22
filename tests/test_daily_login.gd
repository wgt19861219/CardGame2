extends GutTest
# DailyLogin 连续登录奖励单测 — 照源 player.lua:224 getLoginFrequency/getLoginRewardStatus +
# local_server.lua:2096 ask_daily_login。

var cm: ConfigManager

func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_first_login_frequency() -> void:
	var mgr := DailyLoginManager.new()
	# last_ts=0 → _is_reset_apart 返 true → frequency+1 = 0+1 = 1（首次登录算第1天）
	assert_eq(mgr.get_login_frequency(1000), 1, "首次登录 frequency=1（last_ts=0 视为跨线）")


func test_reward_status_common_first_time() -> void:
	var mgr := DailyLoginManager.new()
	# last_ts=0 → _is_reset_apart 返 true → "common" 可领
	assert_eq(mgr.get_reward_status(1000), "common", "首次登录可领")


# ── 5:00 重置线（源 time.lua:299 reset_time={h=5,m=0} + :366 checkBOA）──

# 本地今天 h:m 的 ts（_local_date 同口径：+bias 拆、-bias 组）。
func _local_ts(h: int, m: int = 0) -> int:
	var off: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + off)
	d["hour"] = h
	d["minute"] = m
	d["second"] = 0
	return int(Time.get_unix_time_from_datetime_dict(d)) - off


# 同日号跨 5:00 线（3:00→8:00）= 新重置段，frequency+1
func test_reset_line_same_day_cross() -> void:
	var mgr := DailyLoginManager.new()
	mgr.frequency = 3
	mgr.last_login_ts = _local_ts(3, 0)
	assert_eq(mgr.get_login_frequency(_local_ts(8, 0)), 4, "同日 3:00→8:00 跨 5:00 线 frequency+1")
	assert_eq(mgr.get_reward_status(_local_ts(8, 0)), "common", "跨线后可再领")


# 同段未跨线（1:00→4:00 均在 5:00 前）frequency 不变、状态 received
func test_reset_line_same_segment() -> void:
	var mgr := DailyLoginManager.new()
	mgr.frequency = 3
	mgr.status = "all"
	mgr.last_login_ts = _local_ts(1, 0)
	assert_eq(mgr.get_login_frequency(_local_ts(4, 0)), 3, "1:00→4:00 未跨线 frequency 不变")
	assert_eq(mgr.get_reward_status(_local_ts(4, 0)), "received", "同段已领状态保持")


# 异日号同段（昨天 1:00→今天 2:00 均在各自日 5:00 前 before 段）= 跨线（源异日号同段 true）
func test_reset_line_cross_midnight_same_segment() -> void:
	var mgr := DailyLoginManager.new()
	mgr.frequency = 3
	mgr.last_login_ts = _local_ts(2, 0) - 86400 - 3600   # 今天 2:00 往前 25h = 昨天 1:00（before 段）
	var today_2 := _local_ts(2, 0)
	assert_true(int(DailyLoginManager._local_date(mgr.last_login_ts).get("day", 0)) != int(DailyLoginManager._local_date(today_2).get("day", 0)), "构造校验：确为异日号")
	assert_eq(mgr.get_login_frequency(today_2), 4, "昨天 1:00→今天 2:00 异日号同段=跨线 +1")


# 异日号异段（昨天 23:00→今天 2:00：23:00 属"昨日段"、2:00 也属"昨日段"（今日 5:00 前）
# ——源 checkTwoDateod 异日号异段=false，语义自洽：未跨任何 5:00 线不算隔天）
func test_reset_line_cross_midnight_diff_segment_no_reset() -> void:
	var mgr := DailyLoginManager.new()
	mgr.frequency = 3
	mgr.status = "all"
	mgr.last_login_ts = _local_ts(2, 0) - 3 * 3600   # 今天 2:00 往前 3h = 昨天 23:00
	assert_eq(mgr.get_login_frequency(_local_ts(2, 0)), 3, "昨天 23:00→今天 2:00 未跨 5:00 线 frequency 不变")
	assert_eq(mgr.get_reward_status(_local_ts(2, 0)), "received", "同段已领状态保持")


# 月重置（源 checkTwoDateom：较晚者 day==1 且跨线 → frequency=1）
func test_month_reset_on_day1() -> void:
	var off: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var now_local: Dictionary = Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + off)
	var day1_8am := {"year": now_local["year"], "month": now_local["month"], "day": 1, "hour": 8, "minute": 0, "second": 0}
	var day1_8am_ts: int = int(Time.get_unix_time_from_datetime_dict(day1_8am)) - off
	var prev_month_end_23: int = day1_8am_ts - 9 * 3600   # 1 日 8:00 往前 9h = 上月末 23:00（两者均 after 段，跨 1 日 5:00 线）
	var mgr := DailyLoginManager.new()
	mgr.frequency = 7
	mgr.last_login_ts = prev_month_end_23
	assert_eq(int(DailyLoginManager._local_date(day1_8am_ts).get("day", 0)), 1, "构造校验：较晚者 day==1")
	assert_eq(mgr.get_login_frequency(day1_8am_ts), 1, "上月末 23:00→本月 1 日 8:00 跨线且 day==1 月重置 frequency=1")


# 非月初跨月不重置（源：checkTwoDateom false → checkTwoDateod true → frq+1 继续累计）
func test_cross_month_not_day1_keeps_frequency() -> void:
	var off: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var now_local: Dictionary = Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + off)
	var day15_2am := {"year": now_local["year"], "month": now_local["month"], "day": 15, "hour": 2, "minute": 0, "second": 0}
	var day15_2am_ts: int = int(Time.get_unix_time_from_datetime_dict(day15_2am)) - off
	var long_ago: int = day15_2am_ts - 40 * 86400   # 40 天前（必跨月且较晚者 day==15 ≠ 1）
	var mgr := DailyLoginManager.new()
	mgr.frequency = 7
	mgr.last_login_ts = long_ago
	assert_eq(mgr.get_login_frequency(day15_2am_ts), 8, "隔 40 天回来（非月初）不重置，frq+1 继续累计（源语义）")


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
