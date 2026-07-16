extends GutTest
# DailyLoginPanel + DailyLoginBuilder 测试（2026-07-14 重建）。
# 数据层（build_reward_data 查表 / month_day_amount）+ View 层（chrome 装配 / 网格渲染 / 状态色 / 领奖交互）。
# 照源 ui/popwindow/dailylogin.lua create + createRewardItem + getRewardData + getRewardStatus。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# ── 数据层 build_reward_data（照源 getRewardData :147-181）──

func test_build_reward_data_returns_month_days() -> void:
	var data: Array = DailyLoginBuilder.build_reward_data(cm)
	assert_gt(data.size(), 0, "查表返当月>=1天")
	var first: Dictionary = data[0]
	for key in ["type", "id", "amount", "vip", "day"]:
		assert_true(first.has(key), "每条含 " + key)
	assert_eq(int(first["day"]), 1, "首条 day=1")


func test_build_reward_data_day_consecutive() -> void:
	var data: Array = DailyLoginBuilder.build_reward_data(cm)
	for i in range(data.size()):
		assert_eq(int(data[i]["day"]), i + 1, "day 连续递增")


func test_month_day_amount_with_sample() -> void:
	# 源 :96-108：从 1 递增直到无 Reward Type
	var sample := {"1": {"Reward Type": "Gold"}, "2": {"Reward Type": "Item"}, "3": {"x": 1}}
	assert_eq(DailyLoginBuilder.month_day_amount(sample), 2, "前 2 天有 Reward Type，第 3 天无 → 2")


# ── View 层装配 + 交互 ──

func _make_panel() -> DailyLoginPanel:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	var panel := DailyLoginPanel.new("dailylogin", {})
	panel.setup_panel(pd)
	panel.show_window(root)
	return panel


func test_panel_builds_chrome_and_grid() -> void:
	var panel: DailyLoginPanel = _make_panel()
	assert_gt(panel._data_list.size(), 0, "数据列表非空")
	assert_eq(panel._cells.size(), panel._data_list.size(), "cell 数 = 天数")
	assert_not_null(panel._subhead_num, "累计签到 Label 存在")
	panel.remove_window()
	panel.get_parent().queue_free()


func test_first_login_one_common_rest_future() -> void:
	var panel: DailyLoginPanel = _make_panel()
	# 首次 freq=1 status=common → day1=common，其余 future（源 getRewardStatus :119-136）
	assert_eq(panel._cell_statuses.count("common"), 1, "首次登录恰 1 个 common(当日)")
	if panel._data_list.size() > 1:
		assert_eq(panel._cell_statuses.count("future"), panel._data_list.size() - 1, "其余 future")
	assert_eq(panel._cell_statuses.count("past"), 0, "首次无 past")
	panel.remove_window()
	panel.get_parent().queue_free()


func test_claim_marks_day_past() -> void:
	var panel: DailyLoginPanel = _make_panel()
	var mgr: DailyLoginManager = panel._mgr
	var now: int = int(Time.get_unix_time_from_system())
	var freq: int = mgr.get_login_frequency(now)
	# 直接调 Logic 层领奖（不经 panel._claim 避免 Toast autoload 副作用）
	mgr.claim_reward(panel._player, cm, now)
	var st: String = panel._cell_status(freq, mgr.get_login_frequency(now), mgr.get_reward_status(now))
	assert_eq(st, "past", "领后当日格变 past(已领)")
	assert_eq(mgr.get_reward_status(now), "received", "mgr 状态 received")
	panel.remove_window()
	panel.get_parent().queue_free()


func test_cell_status_future_beyond_freq() -> void:
	var panel: DailyLoginPanel = _make_panel()
	# day > freq → future（源 :132-134）
	assert_eq(panel._cell_status(999, 1, "common"), "future", "远未来 future")
	panel.remove_window()
	panel.get_parent().queue_free()


# ── LSTR 化（照源 dailylogin.lua :7/:448/:662/:697/:862 + syncDate :893）──

func test_daily_login_lstr_keys_exist() -> void:
	# 验证 daily login 使用的 LSTR key 全部存在（get_lstr 返非 key 本身 = 存在）
	var keys: Array[String] = [
		"DAILYLOGIN.AWARDS_DESCRIPTION",
		"DAILYLOGIN.THIS_MONTH_HAS_A_TOTAL_ATTENDANCE",
		"DAILYLOGIN.TIMES",
		"DAILYLOGIN._D_MONTHLY_ATTENDANCE_AWARDS",
		"DAILYLOGIN.FAILED_TO_RECEIVE",
		"DAILYLOGIN.RECEIVE_THIS_AWARD_AT__D_ATTENDANCE_THIS_MONTH",
	]
	for key in keys:
		var val: String = cm.get_lstr(key)
		assert_ne(val, key, "LSTR key 存在: " + key)
		assert_false(val.is_empty(), "LSTR value 非空: " + key)


func test_panel_title_uses_lstr_month() -> void:
	# 验证标题 LSTR 含 %d 占位符（源 syncDate :893 DAILYLOGIN._D_MONTHLY_ATTENDANCE_AWARDS）
	var fmt: String = cm.get_lstr("DAILYLOGIN._D_MONTHLY_ATTENDANCE_AWARDS")
	assert_true(fmt.find("%d") >= 0, "标题 LSTR 含 %d 月占位符")
	var month: int = int(Time.get_datetime_dict_from_system().get("month", 1))
	assert_eq(fmt % month, "%d月签到奖励" % month, "标题 LSTR 格式化正确")
