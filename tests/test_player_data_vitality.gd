extends GutTest
# PlayerData.buy_vitality 买体力 + VIP 上限测试（照源 local_server:1793 + player.lua:605）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_buy_vitality_success() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 100
	pd.vitality = 0
	assert_true(VitalityManager.buy(pd), "买体力成功")
	assert_eq(pd.diamond, 50, "扣 50 钻")
	assert_eq(pd.vitality, 120, "+120 体力")
	assert_eq(pd.vitality_today_buy, 1, "today_buy +1")


func test_buy_vitality_insufficient_diamond() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 49   # < 50
	assert_false(VitalityManager.buy(pd), "钻石不足 → 失败")
	assert_eq(pd.diamond, 49, "不扣")


func test_buy_vitality_persistence() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 100
	VitalityManager.buy(pd)
	var d: Dictionary = pd.to_dict()
	assert_eq(int(d["vitality_today_buy"]), 1, "today_buy 持久化")
	var restored := PlayerData.from_dict(d, cm)
	assert_eq(restored.vitality_today_buy, 1, "读档恢复 today_buy")


func test_buy_vitality_stockpile() -> void:
	# 源 :1798 买体力上限 9999（允许囤积），区别于自然恢复上限 120
	var pd := PlayerData.new(cm)
	pd.diamond = 100
	pd.vitality = 100
	assert_true(VitalityManager.buy(pd), "买体力成功")
	assert_eq(pd.vitality, 220, "vitality=100 +120 = 220（不被自然恢复 120 上限卡）")


func test_can_buy_vitality_within_limit() -> void:
	var pd := PlayerData.new(cm)
	pd.vitality_today_buy = 0   # 特权档（满级）Buy Vit Max=16，未达上限
	assert_true(VitalityManager.can_buy(pd), "today_buy=0 < VIP 上限 → 可买")


func test_can_buy_vitality_at_vip_limit() -> void:
	# 照源 player.lua:603 canBuyVitality：today_buy >= VIP["Buy Vit Max"] → 不可买
	# 单机去 VIP 限制：上限按特权档（满级）取值
	var pd := PlayerData.new(cm)
	var limit: int = int(VipData.get_vip_field(pd.privilege_vip_level(), "Buy Vit Max", cm))
	assert_eq(limit, int(VipData.get_vip_field(VipData.get_max_level(cm), "Buy Vit Max", cm)), "特权档当日买体力上限（满级）")
	VitalityManager.can_buy(pd)   # 先落当日锚（2026-09-17 跨日清零接入；日锚 0 视作新的一天会清计数）
	pd.vitality_today_buy = limit
	assert_false(VitalityManager.can_buy(pd), "today_buy=limit 达 VIP 上限 → 不可买")
	pd.vitality_today_buy = limit - 1
	assert_true(VitalityManager.can_buy(pd), "today_buy=limit-1 → 可买")


# T2 存档标脏钩子：buy_vitality 成功触发 save_hook，失败不触发，缺省 Callable 不崩。
func test_buy_vitality_save_hook() -> void:
	var pd := PlayerData.new(cm)
	var dirty: Array[int] = []
	pd.save_hook = func() -> void: dirty.append(1)
	pd.diamond = 100
	assert_true(VitalityManager.buy(pd), "买体力成功")
	assert_eq(dirty.size(), 1, "成功触发一次 save_hook（存档标脏内聚 Logic）")
	pd.vitality_today_buy = 0   # 重置 VIP 次数限制
	pd.diamond = 10
	assert_false(VitalityManager.buy(pd), "钻石不足失败")
	assert_eq(dirty.size(), 1, "失败不触发 save_hook")
	var pd_no_hook := PlayerData.new(cm)   # 缺省 Callable（headless 无注入）
	pd_no_hook.diamond = 100
	assert_true(VitalityManager.buy(pd_no_hook), "缺省 hook 不崩且成功")
