extends GutTest
# Phase 5 shop 商店 Logic 单测（2026-07-05，照源 local_server.lua:1159-1322 + shop.lua:138-154）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_pd() -> PlayerData:
	var pd := PlayerData.new(cm)
	pd.hero_manager.gold = 100000
	pd.diamond = 10000
	return pd


# generate_shop_goods：6 件 + 字段齐全 + payType=gold（源 GOODS_COUNT/payTypeMap）
func test_generate_goods_count() -> void:
	var sm := ShopManager.new(cm)
	var rng := BattleRng.new(12345)
	var goods: Array = sm.generate_shop_goods(1, rng, cm)
	assert_eq(goods.size(), 6, "6 件商品（源 GOODS_COUNT）")
	for g in goods:
		var gd: Dictionary = g
		assert_true(gd.has("id") and gd.has("type") and gd.has("price") and gd.has("amount"), "字段齐全")
		assert_eq(int(gd["amount"]), 1, "amount=1（源 :1199）")
		assert_eq(String(gd["type"]), "gold", "id=1 payType=gold")
		assert_true(int(gd["price"]) >= 10, "price>=MIN_PRICE（源 :1194）")


# price 从 Equip."Buy Price" 读（非 random fallback；源 :1190 读 "Price"，本项目 Equip.json 转换后 "Buy Price"）。
# priceMul=1.0 时 price = max(Buy Price, MIN_PRICE)（floor），验不走 random 50-500。
func test_price_from_buy_price() -> void:
	var sm := ShopManager.new(cm)
	var goods: Array = sm.generate_shop_goods(1, BattleRng.new(12345), cm)
	var checked: int = 0
	for g in goods:
		var gd: Dictionary = g
		var eid: int = int(gd["id"])
		var buy_price: int = int(cm.get_raw_table(&"Equip").get(str(eid), {}).get("Buy Price", 0))
		if buy_price > 0:
			assert_eq(int(gd["price"]), maxi(buy_price, 10), "price = Buy Price（非 random fallback）")
			checked += 1
	assert_true(checked > 0, "至少 1 件验 Buy Price（防全 fallback random）")


# priceMul：地精 id=2 打折（源 :1184 priceMul 0.6；同 seed 洗牌同商品，地精价 ≤ 普通价）
func test_price_mul_goblin() -> void:
	var sm := ShopManager.new(cm)
	var goods1: Array = sm.generate_shop_goods(1, BattleRng.new(12345), cm)
	var goods2: Array = sm.generate_shop_goods(2, BattleRng.new(12345), cm)
	var p1: int = int(goods1[0]["price"])
	var p2: int = int(goods2[0]["price"])
	assert_true(p2 <= p1, "地精 0.6 折 ≤ 普通价")
	assert_true(bool(goods2[0]["is_sale"]), "地精 is_sale=true（源 :1200）")
	assert_false(bool(goods1[0]["is_sale"]), "普通 is_sale=false")


# payType：黑市 id=3 → diamond（源 payTypeMap[3]）
func test_pay_type_black_market() -> void:
	var sm := ShopManager.new(cm)
	var goods: Array = sm.generate_shop_goods(3, BattleRng.new(999), cm)
	assert_eq(String(goods[0]["type"]), "diamond", "黑市 payType=diamond")


# open_shop：生成 + 存 shop_data
func test_open_shop_stores() -> void:
	var sm := ShopManager.new(cm)
	var goods: Array = sm.open_shop(1, BattleRng.new(12345), cm)
	assert_eq(sm.get_goods(1).size(), 6, "open_shop 存 shop_data")
	assert_eq(sm.get_goods(1), goods, "get_goods 返存储列表")


# buy：扣金币 + 加物品 + 标记售罄（源 buyReply addEquip + :1272 amount=0）
func test_buy_gold_success() -> void:
	var sm := ShopManager.new(cm)
	sm.open_shop(1, BattleRng.new(12345), cm)
	var pd := _make_pd()
	var gold_before: int = pd.hero_manager.gold
	var price: int = int(sm.get_goods(1)[0]["price"])
	var item_id: int = int(sm.get_goods(1)[0]["id"])
	assert_true(sm.buy(1, 0, pd, cm), "购买成功")
	assert_eq(pd.hero_manager.gold, gold_before - price, "扣金币 = 商品价")
	assert_eq(int(pd.items.get(item_id, 0)), 1, "加物品进背包")


# 售罄不可再买（源 :1272 amount=0 → shop_consume fail）
func test_buy_soldout() -> void:
	var sm := ShopManager.new(cm)
	sm.open_shop(1, BattleRng.new(12345), cm)
	var pd := _make_pd()
	assert_true(sm.buy(1, 0, pd, cm), "首次购买成功")
	assert_eq(int(sm.get_goods(1)[0]["amount"]), 0, "amount 标 0")
	assert_false(sm.buy(1, 0, pd, cm), "售罄不可再买")


# 金币不足失败
func test_buy_no_gold() -> void:
	var sm := ShopManager.new(cm)
	sm.open_shop(1, BattleRng.new(12345), cm)
	var pd := PlayerData.new(cm)   # gold=0
	assert_false(sm.buy(1, 0, pd, cm), "金币不足失败")


# P2 shop 支付：arenapoint（竞技场币）扣费（源 shop_consume payType=5）
func test_spend_arenapoint() -> void:
	var pd := _make_pd()
	pd.arena_point = 500
	assert_true(ShopManager._spend(ShopManager.PAY_ARENA, 200, pd), "arenapoint 余额足 → 扣成功")
	assert_eq(pd.arena_point, 300, "arenapoint 扣 200 剩 300")
	assert_false(ShopManager._spend(ShopManager.PAY_ARENA, 400, pd), "arenapoint 余额不足 → 失败")


# P2 shop 支付：guildpoint（公会币）扣费（源 shop_consume payType=6）
func test_spend_guildpoint() -> void:
	var pd := _make_pd()
	pd.guildpoint = 300
	assert_true(ShopManager._spend(ShopManager.PAY_GUILD, 100, pd), "guildpoint 余额足 → 扣成功")
	assert_eq(pd.guildpoint, 200, "guildpoint 扣 100 剩 200")
	assert_false(ShopManager._spend(ShopManager.PAY_GUILD, 500, pd), "guildpoint 余额不足 → 失败")


# refresh：扣钻 + 重新生成 + refresh_times+1（源 doClickRefresh + GradientPrice）
func test_refresh() -> void:
	var sm := ShopManager.new(cm)
	sm.open_shop(1, BattleRng.new(12345), cm)
	var pd := _make_pd()
	var dia_before: int = pd.diamond
	var cost: int = sm.get_refresh_cost(1, cm)
	assert_true(sm.refresh(1, pd, BattleRng.new(999), cm), "刷新成功")
	assert_eq(pd.diamond, dia_before - cost, "扣刷新钻")
	assert_eq(sm.get_refresh_times(1), 1, "刷新次数+1")
	assert_eq(sm.get_goods(1).size(), 6, "刷新后仍 6 件")


# refresh：钻石不足失败
func test_refresh_no_diamond() -> void:
	var sm := ShopManager.new(cm)
	sm.open_shop(1, BattleRng.new(12345), cm)
	var pd := PlayerData.new(cm)   # diamond=0
	assert_false(sm.refresh(1, pd, BattleRng.new(1), cm), "钻石不足刷新失败")


# get_refresh_cost：GradientPrice[today_times+1]["Shop N Refresh"]（源 getShopRefreshCost）
func test_refresh_cost_gradient() -> void:
	var sm := ShopManager.new(cm)
	var cost0: int = sm.get_refresh_cost(1, cm)   # today_times=0 → GradientPrice["1"]["Shop 1 Refresh"]=50
	assert_eq(cost0, 50, "首次刷新 50 钻（GradientPrice[1]）")


# ---- starshop（神秘星辰商店，照源 local_server:351 generateStarGoods + :1286 shop_star_consume）----

# generate_star_goods：5 件 + types {0,0,1,1,2} + stone_id 8/9/10 + prices 50/100/200（源 :351-365）
func test_generate_star_goods() -> void:
	var goods: Array = ShopManager.generate_star_goods()
	assert_eq(goods.size(), 5, "5 件商品（源 types 5 元素）")
	for g in goods:
		var gd: Dictionary = g
		assert_true(gd.has("stone_id") and gd.has("stone_amount") and gd.has("box"), "字段齐全")
		assert_eq(int(gd["amount"]), 1, "amount=1")
	assert_eq(int(goods[0]["stone_id"]), 8, "type 0 → stone_id 8（绿）")
	assert_eq(int(goods[2]["stone_id"]), 9, "type 1 → stone_id 9（蓝）")
	assert_eq(int(goods[4]["stone_id"]), 10, "type 2 → stone_id 10（紫）")
	assert_eq(int(goods[0]["stone_amount"]), 50, "绿 50 灵魂石（源 prices[0]=50）")
	assert_eq(int(goods[2]["stone_amount"]), 100, "蓝 100 灵魂石")
	assert_eq(int(goods[4]["stone_amount"]), 200, "紫 200 灵魂石")


# open_star_shop：生成 + 存 shop_data["starshop"]
func test_open_star_shop() -> void:
	var sm := ShopManager.new(cm)
	sm.open_star_shop()
	assert_eq(sm.get_star_goods().size(), 5, "open_star_shop 存 5 件")


# buy_star：扣灵魂石 + 产出 equip + 售罄（源 shop_star_consume + tavern_draw stone）
func test_buy_star_success() -> void:
	var sm := ShopManager.new(cm)
	sm.open_star_shop()
	var pd := PlayerData.new(cm)
	pd.items[8] = 100   # 绿灵魂石 100（够 50）
	var r: Dictionary = sm.buy_star(0, pd, BattleRng.new(12345), cm)   # slot 0 = 绿
	assert_true(bool(r["ok"]), "兑换成功")
	assert_eq(int(pd.items.get(8, 0)), 50, "扣 50 绿灵魂石")
	assert_eq(int(sm.get_star_goods()[0]["amount"]), 0, "售罄 amount=0")
	assert_true((r["loots"] as Array).size() > 0, "产出 equip 列表非空")


# buy_star 灵魂石不足
func test_buy_star_no_resource() -> void:
	var sm := ShopManager.new(cm)
	sm.open_star_shop()
	var pd := PlayerData.new(cm)
	pd.items[8] = 10   # 绿灵魂石 10（不够 50）
	var r: Dictionary = sm.buy_star(0, pd, BattleRng.new(1), cm)
	assert_false(bool(r["ok"]), "灵魂石不足失败")
	assert_true(bool(r.get("no_resource", false)), "no_resource 标志")


# buy_star 售罄不可再兑
func test_buy_star_soldout() -> void:
	var sm := ShopManager.new(cm)
	sm.open_star_shop()
	var pd := PlayerData.new(cm)
	pd.items[8] = 100
	assert_true(bool(sm.buy_star(0, pd, BattleRng.new(1), cm)["ok"]), "首次成功")
	var r: Dictionary = sm.buy_star(0, pd, BattleRng.new(1), cm)
	assert_false(bool(r["ok"]), "售罄不可再兑")
	assert_true(bool(r.get("soldout", false)), "soldout 标志")


# ---- 自动刷新时刻（照源 local_server.lua:1219 + up.proto:260 auto_refresh）----

# 构造本地今天 h:m:s 的 ts（today_ts 同口径：+bias 拆本地、组回 -bias；两 Time API 均 UTC
# ——2026-08-22 巡检同步：旧 epoch-UTC 基准与修复后本地口径 today_ts 失配 8h）。
func _ts(h: int, m: int = 0, s: int = 0) -> int:
	var off: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + off)
	d["hour"] = h
	d["minute"] = m
	d["second"] = s
	return int(Time.get_unix_time_from_datetime_dict(d)) - off


# init_auto_refresh：首次开店设 ts（源 local_server:1219）；已有不重设；Shop6 Refresh Times 空不设
func test_init_auto_refresh() -> void:
	var sm := ShopManager.new(cm)
	var pd := _make_pd()
	assert_true(sm.init_auto_refresh(1, pd, 100000), "Shop1 首次 init 设 ts")
	assert_eq(int(pd.shop_auto_refresh.get(1, 0)), 100000, "Shop1 ts 已存")
	assert_false(sm.init_auto_refresh(1, pd, 200000), "已有记录不重设")
	assert_eq(int(pd.shop_auto_refresh.get(1, 0)), 100000, "ts 不变")
	assert_false(sm.init_auto_refresh(6, pd, 100000), "Shop6 Refresh Times 空不 init")
	assert_false(pd.shop_auto_refresh.has(6), "Shop6 无记录")


# check_auto_refresh：到点触发刷新 + 更新 ts；未到点不触发（源 up.proto:260）
func test_check_auto_refresh_trigger() -> void:
	var sm := ShopManager.new(cm)
	var pd := _make_pd()
	sm.open_shop(1, BattleRng.new(12345), cm)
	var now_ts: int = _ts(10, 0)       # now=10:00
	var last_ts: int = _ts(8, 0)       # last=8:00 → 9:00 点已过且 last<9:00 → 触发
	pd.shop_auto_refresh[1] = last_ts
	assert_true(sm.check_auto_refresh(1, pd, now_ts, BattleRng.new(999)), "到 9:00 点触发刷新")
	assert_eq(int(pd.shop_auto_refresh.get(1, 0)), now_ts, "ts 更新为 now")
	assert_eq(sm.get_goods(1).size(), 6, "刷新后仍 6 件")


# check_auto_refresh：未到下个点不触发
func test_check_auto_refresh_not_yet() -> void:
	var sm := ShopManager.new(cm)
	var pd := _make_pd()
	sm.open_shop(1, BattleRng.new(12345), cm)
	pd.shop_auto_refresh[1] = _ts(10, 0)   # last=10:00 → 9:00 已刷，下个 12:00 未到
	assert_false(sm.check_auto_refresh(1, pd, _ts(10, 30), BattleRng.new(1)), "未到 12:00 不触发")


# check_auto_refresh：未启用（last=0）不触发
func test_check_auto_refresh_disabled() -> void:
	var sm := ShopManager.new(cm)
	var pd := _make_pd()
	sm.open_shop(1, BattleRng.new(12345), cm)
	assert_false(sm.check_auto_refresh(1, pd, _ts(10, 0), BattleRng.new(1)), "last=0 未启用不触发")


# get_next_refresh_desc：Shop1 有 Refresh Times 返非空；Shop6 空返 ""
func test_next_refresh_desc() -> void:
	var sm := ShopManager.new(cm)
	var pd := _make_pd()
	pd.shop_auto_refresh[1] = _ts(8, 0)
	var desc: String = sm.get_next_refresh_desc(1, pd, _ts(10, 30))
	# now 10:30 → 下个 12:00/18:00/21:00 之一
	assert_true(desc.length() > 0, "Shop1 有 desc")
	pd.shop_auto_refresh[6] = _ts(8, 0)
	assert_eq(sm.get_next_refresh_desc(6, pd, _ts(10, 30)), "", "Shop6 无 Refresh Times desc 空")


# 持久化：to_dict/from_dict 保留 shop_auto_refresh
func test_persist_shop_auto_refresh() -> void:
	var pd := _make_pd()
	pd.shop_auto_refresh[1] = 111111
	pd.shop_auto_refresh[2] = 222222
	var d: Dictionary = pd.to_dict()
	var pd2: PlayerData = PlayerData.from_dict(d, cm)
	assert_eq(int(pd2.shop_auto_refresh.get(1, 0)), 111111, "from_dict 恢复 shop1 ts")
	assert_eq(int(pd2.shop_auto_refresh.get(2, 0)), 222222, "from_dict 恢复 shop2 ts")


# check_auto_refresh 连续触发（模拟 _process 跨多个 Refresh Times 点）
func test_check_auto_refresh_sequence() -> void:
	var sm := ShopManager.new(cm)
	var pd := _make_pd()
	sm.open_shop(1, BattleRng.new(12345), cm)
	pd.shop_auto_refresh[1] = _ts(8, 0)   # last=8:00
	assert_true(sm.check_auto_refresh(1, pd, _ts(10, 0), BattleRng.new(1)), "10:00 过 9:00 点触发")
	assert_eq(int(pd.shop_auto_refresh[1]), _ts(10, 0), "last 更新为 10:00")
	assert_false(sm.check_auto_refresh(1, pd, _ts(10, 30), BattleRng.new(1)), "10:30 未到 12:00 不触发")
	assert_true(sm.check_auto_refresh(1, pd, _ts(12, 30), BattleRng.new(2)), "12:30 过 12:00 点触发")
	assert_eq(int(pd.shop_auto_refresh[1]), _ts(12, 30), "last 更新为 12:30")


# ---- 停留到期（照源 Shop.Expire Time + shop.lua:686-694 到期分支）----

# get_expire_time：地精(2)/黑市(3)/星际(6)=3600，普通(1)=0（源 Shop.lua）
func test_get_expire_time() -> void:
	assert_eq(ShopManager.get_expire_time(1, cm), 0, "普通店 Expire=0（永不过期）")
	assert_eq(ShopManager.get_expire_time(2, cm), 3600, "地精 Expire=3600")
	assert_eq(ShopManager.get_expire_time(3, cm), 3600, "黑市 Expire=3600")
	assert_eq(ShopManager.get_expire_time(6, cm), 3600, "星际 Expire=3600")


# init_expire：地精开店设 expire_end=now+3600；普通店不设；已记录不重设
func test_init_expire() -> void:
	var sm := ShopManager.new(cm)
	var pd := _make_pd()
	assert_true(sm.init_expire(2, pd, 100000), "地精首次 init 设 expire_end")
	assert_eq(int(pd.shop_expire_end.get(2, 0)), 100000 + 3600, "expire_end=now+3600")
	assert_false(sm.init_expire(2, pd, 200000), "已记录不重设")
	assert_eq(int(pd.shop_expire_end.get(2, 0)), 100000 + 3600, "expire_end 不变")
	assert_false(sm.init_expire(1, pd, 100000), "普通店 Expire=0 不 init")
	assert_false(pd.shop_expire_end.has(1), "普通店无记录")


# check_expire：到期前 false，到期后 true；普通店永 false
func test_check_expire() -> void:
	var sm := ShopManager.new(cm)
	var pd := _make_pd()
	pd.shop_expire_end[2] = 100000 + 3600   # 地精 expire_end
	assert_false(sm.check_expire(2, pd, 100000), "开店未到期")
	assert_false(sm.check_expire(2, pd, 100000 + 3599), "到期前 1s")
	assert_true(sm.check_expire(2, pd, 100000 + 3600), "到期点 true")
	assert_true(sm.check_expire(2, pd, 100000 + 3700), "过期 true")
	assert_false(sm.check_expire(1, pd, 999999), "普通店无 expire_end 永 false")


# get_expire_remaining/get_expire_desc：剩余秒 + HH:MM:SS（源 gethmsNString）
func test_expire_remaining_desc() -> void:
	var sm := ShopManager.new(cm)
	var pd := _make_pd()
	pd.shop_expire_end[2] = 100000 + 3600
	assert_eq(sm.get_expire_remaining(2, pd, 100000), 3600, "剩余 3600s")
	assert_eq(sm.get_expire_remaining(1, pd, 100000), -1, "普通店不限时返 -1")
	assert_eq(sm.get_expire_desc(2, pd, 100000), "01:00:00", "3600s → 01:00:00")
	assert_eq(sm.get_expire_desc(2, pd, 100000 + 1800), "00:30:00", "1800s → 00:30:00")
	assert_eq(sm.get_expire_desc(2, pd, 100000 + 3600), "", "到期返空")


# clear_expire：清除记录（到期关面板后调，再点重计）
func test_clear_expire() -> void:
	var sm := ShopManager.new(cm)
	var pd := _make_pd()
	pd.shop_expire_end[2] = 100000 + 3600
	sm.clear_expire(2, pd)
	assert_false(pd.shop_expire_end.has(2), "清除后无记录")
	assert_false(sm.check_expire(2, pd, 999999), "清除后 check_expire false")
	assert_true(sm.init_expire(2, pd, 200000), "清除后可重新 init（再点重计）")


# get_time_type：expire 优先于 refresh（源 checkShopTimeType:222-229）
func test_time_type_expire_priority() -> void:
	var sm := ShopManager.new(cm)
	var pd := _make_pd()
	pd.shop_auto_refresh[2] = _ts(8, 0)   # 同时有自动刷新
	pd.shop_expire_end[2] = _ts(10, 0) + 3600   # 且停留中
	assert_eq(sm.get_time_type(2, pd, _ts(10, 0)), "expire", "停留中 expire 优先")
	pd.shop_expire_end.erase(2)
	assert_eq(sm.get_time_type(2, pd, _ts(10, 0)), "refresh", "无 expire 则 refresh")


# 持久化：to_dict/from_dict 保留 shop_expire_end
func test_persist_shop_expire_end() -> void:
	var pd := _make_pd()
	pd.shop_expire_end[2] = 111111
	pd.shop_expire_end[3] = 222222
	var d: Dictionary = pd.to_dict()
	var pd2: PlayerData = PlayerData.from_dict(d, cm)
	assert_eq(int(pd2.shop_expire_end.get(2, 0)), 111111, "from_dict 恢复 shop2 expire_end")
	assert_eq(int(pd2.shop_expire_end.get(3, 0)), 222222, "from_dict 恢复 shop3 expire_end")
