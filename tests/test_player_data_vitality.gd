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
	assert_true(pd.buy_vitality(), "买体力成功")
	assert_eq(pd.diamond, 50, "扣 50 钻")
	assert_eq(pd.vitality, 120, "+120 体力")
	assert_eq(pd.vitality_today_buy, 1, "today_buy +1")


func test_buy_vitality_insufficient_diamond() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 49   # < 50
	assert_false(pd.buy_vitality(), "钻石不足 → 失败")
	assert_eq(pd.diamond, 49, "不扣")


func test_buy_vitality_persistence() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 100
	pd.buy_vitality()
	var d: Dictionary = pd.to_dict()
	assert_eq(int(d["vitality_today_buy"]), 1, "today_buy 持久化")
	var restored := PlayerData.from_dict(d, cm)
	assert_eq(restored.vitality_today_buy, 1, "读档恢复 today_buy")


func test_buy_vitality_stockpile() -> void:
	# 源 :1798 买体力上限 9999（允许囤积），区别于自然恢复上限 120
	var pd := PlayerData.new(cm)
	pd.diamond = 100
	pd.vitality = 100
	assert_true(pd.buy_vitality(), "买体力成功")
	assert_eq(pd.vitality, 220, "vitality=100 +120 = 220（不被自然恢复 120 上限卡）")


func test_can_buy_vitality_within_limit() -> void:
	var pd := PlayerData.new(cm)
	pd.vitality_today_buy = 0   # VIP[0]["Buy Vit Max"]=1，未达上限
	assert_true(pd.can_buy_vitality(), "today_buy=0 < VIP 上限 → 可买")


func test_can_buy_vitality_at_vip_limit() -> void:
	# 照源 player.lua:603 canBuyVitality：today_buy >= VIP["Buy Vit Max"] → 不可买
	var pd := PlayerData.new(cm)
	var limit: int = int(VipData.get_vip_field(pd.vip_level, "Buy Vit Max", cm))
	assert_eq(limit, 1, "VIP[0] 当日买体力上限=1")
	pd.vitality_today_buy = limit
	assert_false(pd.can_buy_vitality(), "today_buy=limit 达 VIP 上限 → 不可买")
	pd.vitality_today_buy = limit - 1
	assert_true(pd.can_buy_vitality(), "today_buy=limit-1 → 可买")
