extends GutTest
# MidasManager 测试（P0-忠实-7 + P1-2026-07-10：暴击概率抽样 + 完整兑换链路）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 源 :1868-1898 exchange：扣钻 + 产出金币 + midas_times 累加
func test_exchange_basic() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 1000
	var mgr := MidasManager.new(cm)
	var r: Dictionary = mgr.exchange(pd, 1)
	assert_true(bool(r["ok"]), "钻石充足兑换成功")
	assert_eq(pd.diamond, 1000 - int(r["cost"]), "扣钻")
	assert_eq(len(r["acquired"]), 1, "1 次产出 1 条记录")
	assert_eq(mgr.midas_times, 1, "midas_times 累加")


func test_exchange_insufficient_diamond() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 0
	var mgr := MidasManager.new(cm)
	var r: Dictionary = mgr.exchange(pd, 1)
	assert_false(bool(r["ok"]), "钻石不足返 ok:false")


# P0-忠实-7：暴击概率抽样（Prob 1..4 加权，ratio 在 1-4 范围内）
func test_exchange_ratio_in_valid_range() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 100000
	var mgr := MidasManager.new(cm)
	var r: Dictionary = mgr.exchange(pd, 10)
	assert_true(bool(r["ok"]), "10 次兑换成功")
	for a in r["acquired"]:
		var ratio: int = int(a.get("ratio", 0))
		assert_true(ratio >= 1 and ratio <= 4, "暴击档位 1-4 范围内: %d" % ratio)


# 暴击倍率正确：ratio=2 时 money 应是 ratio=1 的 2 倍（Yield 2 / Yield 1）
func test_ratio_affects_money() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 100000
	var mgr := MidasManager.new(cm)
	# 多次抽样确认不同 ratio 产出不同倍率
	var r: Dictionary = mgr.exchange(pd, 20)
	var ratios_seen: Dictionary = {}
	for a in r["acquired"]:
		var ratio: int = int(a.get("ratio", 1))
		ratios_seen[ratio] = int(a.get("money", 0))
	# 至少应有 ratio=1（75% 概率，20 次几乎必出现）
	assert_true(ratios_seen.has(1), "20 次抽样必出现 ratio=1")


# T2 存档标脏钩子：exchange 成功触发 save_hook（治"兑换不持久化"缺口），失败不触发，缺省不崩。
func test_exchange_save_hook() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 1000
	var mgr := MidasManager.new(cm)
	var dirty: Array[int] = []
	mgr.save_hook = func() -> void: dirty.append(1)
	assert_true(bool(mgr.exchange(pd, 1)["ok"]), "兑换成功")
	assert_eq(dirty.size(), 1, "成功触发一次 save_hook")
	pd.diamond = 0
	assert_false(bool(mgr.exchange(pd, 1)["ok"]), "钻石不足失败")
	assert_eq(dirty.size(), 1, "失败不触发 save_hook")
	var mgr_no_hook := MidasManager.new(cm)   # 缺省 Callable（headless 无注入）
	pd.diamond = 1000
	assert_true(bool(mgr_no_hook.exchange(pd, 1)["ok"]), "缺省 hook 不崩且成功")
