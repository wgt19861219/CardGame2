extends GutTest
# shop_refresh_time 自动刷新时刻计算单测（照源 ui/market/market.lua:137-229）。
# Shop.Refresh Times 表驱动 + _last_auto_refresh_time 持久化（0=不自动刷新）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 构造本地今天 h:m:s 的 ts（today_ts 同口径：+bias 拆本地、组回 -bias；两 Time API 均 UTC）。
func _ts(h: int, m: int = 0, s: int = 0) -> int:
	var off: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + off)
	d["hour"] = h
	d["minute"] = m
	d["second"] = s
	return int(Time.get_unix_time_from_datetime_dict(d)) - off


# get_refresh_times：Shop1 4 点按序 / Shop6 空 / Shop2 1 点
func test_get_refresh_times() -> void:
	assert_eq(ShopRefreshTime.get_refresh_times(1, cm), ["9:00:00", "12:00:00", "18:00:00", "21:00:00"], "Shop1 4 点按序")
	assert_eq(ShopRefreshTime.get_refresh_times(6, cm), [], "Shop6 空")
	assert_eq(ShopRefreshTime.get_refresh_times(2, cm), ["21:00:00"], "Shop2 1 点")


# parse_hms
func test_parse_hms() -> void:
	var p: Dictionary = ShopRefreshTime.parse_hms("9:30:15")
	assert_eq(int(p["hour"]), 9, "hour")
	assert_eq(int(p["min"]), 30, "min")
	assert_eq(int(p["sec"]), 15, "sec")


# next_point：now 早于首点 → today 首点
func test_next_point_today_first() -> void:
	var np: Dictionary = ShopRefreshTime.get_next_point(1, _ts(8, 0), _ts(8, 30), cm)
	assert_eq(String(np["time_str"]), "9:00:00", "today 9:00")
	assert_eq(String(np["period"]), "today", "period today")


# next_point：now 已过首点且 last 更早 → today 该点（应触发刷新）
func test_next_point_passed() -> void:
	var np: Dictionary = ShopRefreshTime.get_next_point(1, _ts(8, 0), _ts(10, 0), cm)
	assert_eq(String(np["time_str"]), "9:00:00", "passed 9:00 today")


# next_point：last 在首点后 → 跨到下个 today 点
func test_next_point_next_today() -> void:
	var np: Dictionary = ShopRefreshTime.get_next_point(1, _ts(10, 0), _ts(10, 30), cm)
	assert_eq(String(np["time_str"]), "12:00:00", "next today 12:00")


# next_point：全点已过 → tomorrow 最早点
func test_next_point_tomorrow() -> void:
	var np: Dictionary = ShopRefreshTime.get_next_point(1, _ts(22, 0), _ts(23, 0), cm)
	assert_eq(String(np["time_str"]), "9:00:00", "tomorrow 9:00")
	assert_eq(String(np["period"]), "tomorrow", "period tomorrow")


# next_point：last==0 或无 Refresh Times → {} 不自动刷新
func test_next_point_no_auto() -> void:
	assert_eq(ShopRefreshTime.get_next_point(1, 0, _ts(10, 0), cm), {}, "last=0 返空")
	assert_eq(ShopRefreshTime.get_next_point(6, _ts(8, 0), _ts(10, 0), cm), {}, "Shop6 无 Refresh Times 返空")


# count_down
func test_count_down() -> void:
	assert_eq(ShopRefreshTime.count_down(1, _ts(8, 0), _ts(8, 30), cm), 1800, "9:00-8:30=1800s")
	assert_eq(ShopRefreshTime.count_down(6, _ts(8, 0), _ts(8, 30), cm), -1, "Shop6 无自动刷新 -1")


# next_desc：含 今天/明天 + HH:MM
func test_next_desc() -> void:
	var desc: String = ShopRefreshTime.next_desc(1, _ts(8, 0), _ts(8, 30), cm)
	assert_true(desc.find("今天") >= 0, "含今天")
	assert_true(desc.find("09:00") >= 0, "含 09:00")
	var desc2: String = ShopRefreshTime.next_desc(1, _ts(22, 0), _ts(23, 0), cm)
	assert_true(desc2.find("明天") >= 0, "tomorrow 含明天")


# time_type：expire 优先；否则 refresh；否则空
func test_time_type() -> void:
	assert_eq(ShopRefreshTime.time_type(1, _ts(23, 0), _ts(8, 0), _ts(10, 0), cm), "expire", "expire 优先")
	assert_eq(ShopRefreshTime.time_type(1, 0, _ts(8, 0), _ts(10, 0), cm), "refresh", "Shop1 有自动刷新")
	assert_eq(ShopRefreshTime.time_type(6, 0, _ts(8, 0), _ts(10, 0), cm), "", "Shop6 无 expire 无 refresh")
