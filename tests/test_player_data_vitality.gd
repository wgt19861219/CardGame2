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
	# 2026-10-12 上限统一 999（旧源 :1798 攒体 9999 口径退役）
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


# ── 999 上限口径（2026-10-12 用户指示：自然恢复上限与买/吃药攒体硬上限统一 999）──

# 满 999 再买：拦截不扣钻（上限统一后新增场景，防白扣）。
func test_buy_vitality_blocked_at_999() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 100
	pd.vitality = 999
	assert_false(VitalityManager.buy(pd), "满 999 拦截购买")
	assert_eq(pd.diamond, 100, "不扣钻")
	assert_eq(pd.vitality, 999, "体力不变")


# 买体力攒到 999 封顶（旧 9999 攒体口径退役）。
func test_buy_vitality_clamps_to_999() -> void:
	var pd := PlayerData.new(cm)
	pd.diamond = 1000
	pd.vitality = 950
	assert_true(VitalityManager.buy(pd), "购买成功")
	assert_eq(pd.vitality, 999, "950+120 clamp 到 999（旧口径 1070）")


# 吃体力药同样 clamp 999（use_tonic_pill 复用 BUY_HARD_CAP）。
func test_tonic_pill_clamps_to_999() -> void:
	var pd := PlayerData.new(cm)
	var tonic_id: int = 0
	var raw: Dictionary = cm.get_raw_table("Equip")
	for tid_str in raw:
		if String(raw[tid_str].get("Category", "")) == "EQUIP.CONSUMABLES" \
				and String(raw[tid_str].get("Consume Type", "")) == "EQUIP.TONIC_PILLS":
			tonic_id = int(tid_str)
			break
	assert_gt(tonic_id, 0, "前置：存在体力药")
	pd.add_item(tonic_id, 1)
	pd.vitality = 990
	var r: Dictionary = VitalityManager.use_tonic_pill(pd, tonic_id, cm)
	assert_true(bool(r.get("ok", false)), "吃药成功")
	assert_eq(pd.vitality, 999, "990+回复 clamp 到 999")
