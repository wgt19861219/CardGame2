class_name ShopManager
extends RefCounted

## 商店 Logic（Logic 层）— 照源 local_server.lua:1159-1322（generateShopGoods/open_shop/
## shop_refresh/shop_consume）+ shop.lua:138-154 buyReply（扣货币+加物品）。
## 商品随机生成（Equip 抽 6 件 + priceMul + payType）+ 购买（扣货币+加物品+售罄）+ 手动刷新（扣钻）。
## 单机化：源 net 消息 shop_* → 直调本 Logic；自动刷新时刻（Shop.Refresh Times）暂不实现。

const GOODS_COUNT: int = 6
const MIN_PRICE: int = 10
const DEFAULT_PRICE: int = 100
const PRICE_RAND_MIN: int = 50
const PRICE_RAND_MAX: int = 500
const REFRESH_COST_FALLBACK: int = 50    # GradientPrice 缺失 fallback
const GOBLIN_SHOP_ID: int = 2
const BLACK_MARKET_SHOP_ID: int = 3
const PRICE_MUL_GOBLIN: float = 0.6
const PRICE_MUL_BLACK_MARKET: float = 2.0
const FALLBACK_EQUIP_IDS: Array[int] = [101, 102, 103, 104, 105, 106, 107, 108, 109, 110]

const PAY_TYPE_MAP: Dictionary = {
	3: "diamond",
	4: "crusadepoint",
	5: "arenapoint",
	6: "guildpoint",
}
const PAY_GOLD: String = "gold"
const PAY_DIAMOND: String = "diamond"
const PAY_CRUSADE: String = "crusadepoint"
const PAY_ARENA: String = "arenapoint"
const PAY_GUILD: String = "guildpoint"

var shop_data: Dictionary = {}       # shop_id(int) → Array[goods dict]
var refresh_times: Dictionary = {}   # shop_id(int) → today_times(int，刷新费用梯度）
var cm: Variant = null


func _init(p_cm: Variant = null) -> void:
	cm = p_cm


# 返 Array[{id,type,price,amount,is_sale}]（照源 goods[i]={_id,_type,_price,_amount,_is_sale}）。
func generate_shop_goods(shop_id: int, rng: BattleRng, p_cm: Variant) -> Array:
	var equip_table: Dictionary = p_cm.get_raw_table(&"Equip")
	var equip_ids: Array[int] = _collect_equip_ids(equip_table)
	if equip_ids.is_empty():
		equip_ids = FALLBACK_EQUIP_IDS.duplicate()
	var shuffled: Array[int] = _shuffle(equip_ids, rng)
	var pay_type: String = String(PAY_TYPE_MAP.get(shop_id, PAY_GOLD))
	var price_mul: float = _price_mul(shop_id)
	var goods: Array = []
	var count: int = min(GOODS_COUNT, shuffled.size())
	for i in count:
		var row: Dictionary = equip_table.get(str(shuffled[i]), {})
		var price: int = int(row.get("Buy Price", rng.randi_range(PRICE_RAND_MIN, PRICE_RAND_MAX)))
		price = max(int(price * price_mul), MIN_PRICE)
		goods.append({
			"id": shuffled[i],
			"type": pay_type,
			"price": price,
			"amount": 1,
			"is_sale": shop_id == GOBLIN_SHOP_ID,
		})
	return goods


static func _price_mul(shop_id: int) -> float:
	if shop_id == GOBLIN_SHOP_ID:
		return PRICE_MUL_GOBLIN
	if shop_id == BLACK_MARKET_SHOP_ID:
		return PRICE_MUL_BLACK_MARKET
	return 1.0


static func _collect_equip_ids(equip_table: Dictionary) -> Array[int]:
	var ids: Array[int] = []
	for eid in equip_table.keys():
		var s: String = str(eid)
		if s.is_valid_int():
			ids.append(int(s))
	return ids


static func _shuffle(ids: Array[int], rng: BattleRng) -> Array[int]:
	var out: Array[int] = ids.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


func open_shop(shop_id: int, rng: BattleRng, p_cm: Variant) -> Array:
	var goods: Array = generate_shop_goods(shop_id, rng, p_cm)
	shop_data[shop_id] = goods
	return goods


func refresh(shop_id: int, pd: PlayerData, rng: BattleRng, p_cm: Variant) -> bool:
	var cost: int = get_refresh_cost(shop_id, p_cm)
	if pd.diamond < cost:
		return false
	pd.spend_diamond(cost)
	refresh_times[shop_id] = int(refresh_times.get(shop_id, 0)) + 1
	shop_data[shop_id] = generate_shop_goods(shop_id, rng, p_cm)
	return true


func get_refresh_cost(shop_id: int, p_cm: Variant) -> int:
	var today_times: int = int(refresh_times.get(shop_id, 0))
	var row: Dictionary = p_cm.get_raw_table(&"GradientPrice").get(str(today_times + 1), {})
	return int(row.get("Shop " + str(shop_id) + " Refresh", REFRESH_COST_FALLBACK))


func buy(shop_id: int, slot: int, pd: PlayerData, _p_cm: Variant) -> bool:
	var goods: Array = shop_data.get(shop_id, [])
	if slot < 0 or slot >= goods.size():
		return false
	var g: Dictionary = goods[slot]
	if int(g.get("amount", 0)) <= 0:
		return false   # 售罄（源 :1272 goodsItem.amount=0）
	var pay_type: String = String(g.get("type", PAY_GOLD))
	var price: int = int(g.get("price", 0))
	if not _spend(pay_type, price, pd):
		return false
	pd.add_item(int(g["id"]), int(g.get("amount", 1)))
	g["amount"] = 0
	return true


# gold/diamond 特殊（addMoney/spend_diamond track），3 point 走统一 get_point/add_point（源 addPoint）。
static func _spend(pay_type: String, amount: int, pd: PlayerData) -> bool:
	if pay_type == PAY_GOLD:
		if pd.hero_manager.gold < amount:
			return false
		pd.add_point(PAY_GOLD, -amount)
		return true
	if pay_type == PAY_DIAMOND:
		return pd.spend_diamond(amount)
	if pay_type in [PAY_CRUSADE, PAY_ARENA, PAY_GUILD]:
		if pd.get_point(pay_type) < amount:
			return false
		pd.add_point(pay_type, -amount)
		return true
	return false


func get_goods(shop_id: int) -> Array:
	return shop_data.get(shop_id, [])


func get_refresh_times(shop_id: int) -> int:
	return int(refresh_times.get(shop_id, 0))


# ---- 自动刷新时刻（照源 local_server.lua:1219 open_shop 设 ts + up.proto:260 客户端 auto_refresh 触发）----
# _last_auto_refresh_time 持久化在 PlayerData.shop_auto_refresh（ShopManager 临时实例无状态）。

## 该店首次开（pd 无记录）且 Shop.Refresh Times 非空 → 设当前 ts 启用自动刷新。返是否初始化。
func init_auto_refresh(shop_id: int, pd: PlayerData, now_ts: int) -> bool:
	if pd.shop_auto_refresh.has(shop_id):
		return false
	if ShopRefreshTime.get_refresh_times(shop_id, cm).is_empty():
		return false   # Shop6 星际商人 Refresh Times 空，不自动刷新
	pd.shop_auto_refresh[shop_id] = now_ts
	return true


## 客户端 auto_refresh 触发（源 up.proto:260）：now >= 下个刷新点 → 重新生成商品 + 更新 ts。返是否触发。
func check_auto_refresh(shop_id: int, pd: PlayerData, now_ts: int, rng: BattleRng) -> bool:
	var last_ts: int = int(pd.shop_auto_refresh.get(shop_id, 0))
	if last_ts == 0:
		return false   # 未启用自动刷新
	var np: Dictionary = ShopRefreshTime.get_next_point(shop_id, last_ts, now_ts, cm)
	if np.is_empty() or now_ts < int(np["point_ts"]):
		return false
	pd.shop_auto_refresh[shop_id] = now_ts
	shop_data[shop_id] = generate_shop_goods(shop_id, rng, cm)
	return true


## 下次自动刷新描述（源 getShopNextAutoRefreshPointDesc:179-198），委托 ShopRefreshTime。
func get_next_refresh_desc(shop_id: int, pd: PlayerData, now_ts: int) -> String:
	var last_ts: int = int(pd.shop_auto_refresh.get(shop_id, 0))
	return ShopRefreshTime.next_desc(shop_id, last_ts, now_ts, cm)


## 时间类型（源 checkShopTimeType:222-229），委托 ShopRefreshTime。expire_end 从 pd 读（init_expire 设）。
func get_time_type(shop_id: int, pd: PlayerData, now_ts: int) -> String:
	var last_ts: int = int(pd.shop_auto_refresh.get(shop_id, 0))
	var expire_end: int = get_expire_end(shop_id, pd)
	return ShopRefreshTime.time_type(shop_id, expire_end, last_ts, now_ts, cm)


# ---- 停留到期（照源 Shop.Expire Time + shop.lua:686-694 到期分支）----
# 开店起计 expire_end=now+Expire Time，ShopPanel._process 每秒 check。
# 到期动作改裁决（2026-09-14 用户裁决）：不关面板，直接刷新商品+重计停留
# （原单机化方案 B 到期 showTalk(Expire)+关面板+清记录）。

const EXPIRE_TIME_KEY: StringName = &"Expire Time"
const SECS_PER_HOUR: int = 3600
const SECS_PER_MIN: int = 60


## 读 Shop.Expire Time（秒）。0=不限时（源 Shop.lua getShopExpireTime et==0 返 nil）。
static func get_expire_time(shop_id: int, p_cm: Variant) -> int:
	var row: Dictionary = p_cm.get_raw_table(&"Shop").get(str(shop_id), {})
	return int(row.get(EXPIRE_TIME_KEY, 0))


## 开店设 expire_end（源 local_server:1316 open_shop 设 _expire_time=now+Expire Time）。
## Expire Time>0 且（未记录或记录已过期）→ expire_end=now+Expire Time；停留期内已有记录不重置。
## 过期重计（2026-09-14）：expire_end 持久化，隔超 Expire Time 再开视为新一轮停留重起表
## （源 NPC 到期消失后再现即新一轮；否则残留过期记录开面板即触发到期分支）。
func init_expire(shop_id: int, pd: PlayerData, now_ts: int) -> bool:
	var et: int = get_expire_time(shop_id, cm)
	if et <= 0:
		return false
	var old_end: int = int(pd.shop_expire_end.get(shop_id, 0))
	if old_end > now_ts:
		return false   # 停留期内不重置（源 NPC 停留期固定）
	pd.shop_expire_end[shop_id] = now_ts + et
	return true


## expire_end_ts（0=不限时/未开）。
func get_expire_end(shop_id: int, pd: PlayerData) -> int:
	return int(pd.shop_expire_end.get(shop_id, 0))


## 剩余秒（expire_end-now，可负=已到期）。不限时返 -1（源 getShopExpireTime et==0 返 nil）。
func get_expire_remaining(shop_id: int, pd: PlayerData, now_ts: int) -> int:
	var ee: int = get_expire_end(shop_id, pd)
	if ee == 0:
		return -1
	return ee - now_ts


## 到期检查（源 shop.lua:686 tc<0 and state=="expire"）。返 true=已到期（expire_end>0 且 now>=expire_end）。
func check_expire(shop_id: int, pd: PlayerData, now_ts: int) -> bool:
	var ee: int = get_expire_end(shop_id, pd)
	if ee == 0:
		return false
	return now_ts >= ee


## 到期倒计时 HH:MM:SS（源 shop.lua:662 ed.gethmsNString(time)）。到期/不限时返 ""。
func get_expire_desc(shop_id: int, pd: PlayerData, now_ts: int) -> String:
	var r: int = get_expire_remaining(shop_id, pd, now_ts)
	if r <= 0:
		return ""
	return _hms_str(r)


## 清除 expire 记录（StarShopPanel 到期关面板后调；shop_panel 到期刷新改为 init_expire 重计，不再清）。
func clear_expire(shop_id: int, pd: PlayerData) -> void:
	pd.shop_expire_end.erase(shop_id)


static func _hms_str(secs: int) -> String:
	var h: int = secs / SECS_PER_HOUR
	var m: int = (secs % SECS_PER_HOUR) / SECS_PER_MIN
	var s: int = secs % SECS_PER_MIN
	return "%02d:%02d:%02d" % [h, m, s]


# ---- starshop（神秘星辰商店，照源 local_server:351 generateStarGoods + :1286 shop_star_consume）----
# 灵魂石货币（hero id 8/9/10，源 player.lua:1178 itemType id<100="hero" → createIcon 走
# Unit.Portrait 英雄头像分支；本项目合并 items 通用背包）。商品 icon 用 box_1/2/3 照源。

const STAR_STONE_IDS: Array[int] = [8, 9, 10]
const STAR_TYPES: Array[int] = [0, 0, 1, 1, 2]
const STAR_PRICES: Array[int] = [50, 100, 200]
const STAR_BOX_TYPES: Array[String] = ["stone_green", "stone_blue", "stone_purple"]
const STARSHOP_KEY: String = "starshop"
const STONE_DRAW_TYPE: String = "stone"
# starshop 恒 30 天停留（源 local_server:331/2671/2689 _expire_time=now+30*86400 三处写死；
# starshop need_open=false 不走 open_shop → 不用 Shop6.Expire Time 表值 3600，该表值系普通店口径）
const STARSHOP_SHOP_ID: int = 6
const STARSHOP_EXPIRE_SECS: int = 30 * 86400


## starshop 停留到期初始化（照源初始档 _sshop._expire_time）：未记录则设 now+30 天。
## 复用 pd.shop_expire_end[6] + get_expire_desc/check_expire/clear_expire 通用管道。
func init_starshop_expire(pd: PlayerData, now_ts: int) -> void:
	if not pd.shop_expire_end.has(STARSHOP_SHOP_ID):
		pd.shop_expire_end[STARSHOP_SHOP_ID] = now_ts + STARSHOP_EXPIRE_SECS


static func generate_star_goods() -> Array:
	var goods: Array = []
	for i in STAR_TYPES.size():
		var t: int = STAR_TYPES[i]
		goods.append({
			"type": t,
			"amount": 1,
			"stone_id": STAR_STONE_IDS[t],
			"stone_amount": STAR_PRICES[t],
			"box": STAR_BOX_TYPES[t],
		})
	return goods


# starshop 开店：expire 初始化 + 生成 + 存 shop_data["starshop"]。
func open_star_shop(pd: PlayerData) -> Array:
	init_starshop_expire(pd, int(Time.get_unix_time_from_system()))
	var goods: Array = generate_star_goods()
	shop_data[STARSHOP_KEY] = goods
	return goods


# 返 {ok, loots, box, soldout, no_resource}（loots:Array[{id,amount}]）。
func buy_star(slot: int, pd: PlayerData, rng: BattleRng, p_cm: Variant) -> Dictionary:
	var goods: Array = shop_data.get(STARSHOP_KEY, [])
	if slot < 0 or slot >= goods.size():
		return {"ok": false}
	var g: Dictionary = goods[slot]
	if int(g.get("amount", 0)) <= 0:
		return {"ok": false, "soldout": true}
	var stone_id: int = int(g["stone_id"])
	var stone_amount: int = int(g["stone_amount"])
	if int(pd.items.get(stone_id, 0)) < stone_amount:
		return {"ok": false, "no_resource": true}
	pd.items[stone_id] = int(pd.items[stone_id]) - stone_amount
	var box: String = String(g["box"])
	var loots: Array = TavernData.roll_tavern_loot(STONE_DRAW_TYPE, box, rng, p_cm)
	for loot in loots:
		pd.add_item(int(loot["id"]), int(loot["amount"]))
	g["amount"] = 0
	return {"ok": true, "loots": loots, "box": box}


func get_star_goods() -> Array:
	return shop_data.get(STARSHOP_KEY, [])
