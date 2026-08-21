extends GutTest
# 通知开关系统测试（2026-08-21 SetupPanel 二轮）：开关持久化往返 / 到点检测 /
# 当天去重 / 开关关闭过滤 / 回满跨越边界。cfg_path 注入 user:// 隔离文件，
# 测完清理不污染生产 notify.cfg。


func before_each() -> void:
	NotifySettings.cfg_path = "user://notify_test.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://notify_test.cfg"))
	NotifySettings.cfg_path = "user://notify.cfg"


func _td(year: int, month: int, day: int, hour: int, minute: int) -> Dictionary:
	return {"year": year, "month": month, "day": day, "hour": hour, "minute": minute}


func test_switch_default_on_and_roundtrip() -> void:
	assert_true(NotifySettings.get_switch(1), "默认开启（源 getSwitch 首次全开语义）")
	NotifySettings.set_switch(1, false)
	assert_false(NotifySettings.get_switch(1), "关闭持久化")
	NotifySettings.set_switch(1, true)
	assert_true(NotifySettings.get_switch(1), "重新开启持久化")
	assert_true(NotifySettings.get_switch(7), "其他 id 不受影响")


func test_check_time_due_before_and_after() -> void:
	# 9:00 商店刷新（id4）：8:59 未到 → 不弹；9:00 到点 → 弹。
	assert_false(NotifySettings.check_time_due(_td(2026, 8, 21, 8, 59)).has(4), "9:00 前不弹")
	assert_true(NotifySettings.check_time_due(_td(2026, 8, 21, 9, 0)).has(4), "9:00 到点弹")
	# 12:00 领体力（id1）：9:00 时未到。
	assert_false(NotifySettings.check_time_due(_td(2026, 8, 21, 9, 0)).has(1), "12:00 项在 9:00 不弹")
	assert_true(NotifySettings.check_time_due(_td(2026, 8, 21, 12, 0)).has(1), "12:00 到点弹")


func test_check_time_due_day_dedup() -> void:
	var td := _td(2026, 8, 21, 12, 30)
	assert_true(NotifySettings.check_time_due(td).has(1), "首查到点未推 → 弹")
	NotifySettings.mark_fired(1, td)
	assert_false(NotifySettings.check_time_due(td).has(1), "当天已推 → 不再弹")
	# 次日同一时间重置（源 iDate 语义）。
	var next_day := _td(2026, 8, 22, 12, 30)
	assert_true(NotifySettings.check_time_due(next_day).has(1), "跨天重新可弹")


func test_check_time_due_respects_switch() -> void:
	NotifySettings.set_switch(5, false)
	assert_false(NotifySettings.check_time_due(_td(2026, 8, 21, 21, 0)).has(5), "关闭的 21:00 项不弹")
	assert_true(NotifySettings.check_time_due(_td(2026, 8, 21, 20, 55)).has(7), "20:55 竞技场项正常弹")


func test_check_time_due_skips_event_entries() -> void:
	var due: Array[int] = NotifySettings.check_time_due(_td(2026, 8, 21, 23, 59))
	assert_false(due.has(3), "事件型 id3（体力回满）不参与定时检测")
	assert_false(due.has(6), "事件型 id6（技能点回满）不参与定时检测")


func test_crossed_full_boundaries() -> void:
	assert_true(NotifySettings.crossed_full(9, 10, 10), "9→10 跨到满 → 触发")
	assert_false(NotifySettings.crossed_full(10, 10, 10), "已满再恢复 → 不触发（源 once 语义）")
	assert_false(NotifySettings.crossed_full(8, 9, 10), "未到满 → 不触发")
	assert_false(NotifySettings.crossed_full(9, 8, 10), "扣减方向 → 不触发")


func test_entries_lstr_complete() -> void:
	for id: int in range(1, 8):
		assert_ne(NotifySettings.entry_lstr(id), "")
		assert_ne(NotifySettings.entry_fire_lstr(id), "")


# 真实 API 契约守卫：get_time_dict_from_system 只含时分秒，须 merge 日期 dict
# 才能供 check/mark 用（2026-08-21 实机抓出 fired 写 "00000000" 的根因回归守卫）。
func test_real_time_api_contract() -> void:
	var td: Dictionary = Time.get_time_dict_from_system()
	td.merge(Time.get_date_dict_from_system())
	assert_true(td.has("hour") and td.has("minute"), "时分键在")
	assert_true(td.has("year") and td.has("month") and td.has("day"), "年月日键在（merge 后）")
	# 真实结构跑通不崩 + day_key 非全零。
	var due: Array[int] = NotifySettings.check_time_due(td)
	assert_ne(NotifySettings._day_key(td), "00000000", "日期键非全零")
	for id: int in due:
		NotifySettings.mark_fired(id, td)   # 真实日期写盘（下条断言不重复）
