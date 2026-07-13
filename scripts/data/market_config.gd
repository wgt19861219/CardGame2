class_name MarketConfig
extends RefCounted

## 商店 UI/行为配置（Data 层）— 照源 ui/market/marketconfig.lua type_config。
## 单机化：源 canRefresh 是闭包查 player 余额，本项目改 bool 字段（余额校验移至 ShopManager.buy）。
## 坐标字段由 ShopPanel 常量定义（Godot 左上原点），本表只存纹理/货币/价格系数/行为标志。
## 纹理前缀 res://assets/ui/alpha/HVGA/。

const PAY_GOLD: String = "gold"             # 源 payType gold（id=1/2）
const PAY_DIAMOND: String = "diamond"       # 源 payTypeMap[3]=diamond（黑市 id=3）
const PAY_CRUSADE: String = "crusadepoint"  # 源 payTypeMap[4]（远征商店 id=4）
const PAY_ARENA: String = "arenapoint"      # 源 payTypeMap[5]（竞技场商店 id=5）
const PAY_GUILD: String = "guildpoint"      # 源 payTypeMap[6]（公会商店 id=6）

const UI_DIR: String = "res://assets/ui/alpha/HVGA/"
const SHOP_COMMON_ID: int = 1              # 源 type_config[1] 普通商人
const SHOP_GOBLIN_ID: int = 2              # 源 type_config[2] 地精商人
const SHOP_BLACK_MARKET_ID: int = 3        # 源 type_config[3] 黑市商人
const PRICE_MUL_GOBLIN: float = 0.6        # 源 :1184 地精价格系数
const PRICE_MUL_BLACK_MARKET: float = 2.0  # 源 :1184 黑市价格系数


# 源 marketconfig.lua type_config[id]（id=1/2/3；4/5/6 各场景内部 push 非主城入口，starshop 下阶段）。
static func get_type_config(shop_id: int) -> Dictionary:
	match shop_id:
		SHOP_COMMON_ID:
			return _common()
		SHOP_GOBLIN_ID:
			return _goblin()
		SHOP_BLACK_MARKET_ID:
			return _black_market()
		_:
			return _common()


# 源 type_config[1]：普通商人（金币商店）。
static func _common() -> Dictionary:
	return _make("shop_bg.png", "shop_product_bg.png", "shop_head.png", "shop_title_1.png",
			PAY_GOLD, 1.0, true, false, "商店")


# 源 type_config[2]：地精商人（金币，priceMul 0.6 折，源 local_server:1184）。
static func _goblin() -> Dictionary:
	return _make("shop_bg.png", "shop_product_bg_2.png", "shop_head_2.png", "shop_title_2.png",
			PAY_GOLD, PRICE_MUL_GOBLIN, true, false, "地精商人")


# 源 type_config[3]：黑市商人（钻石，priceMul 2.0，源 :1184）。
static func _black_market() -> Dictionary:
	return _make("shop_bg.png", "shop_product_bg_2.png", "shop_head_3.png", "shop_title_3.png",
			PAY_DIAMOND, PRICE_MUL_BLACK_MARKET, true, false, "黑市商人")


static func _make(frame_res: String, product_res: String, head_res: String, title_res: String,
		pay_type: String, price_mul: float, can_refresh: bool, will_auto_exit: bool,
		title_text: String) -> Dictionary:
	return {
		"frameRes": frame_res,
		"productBgRes": product_res,
		"headRes": head_res,
		"titleRes": title_res,        # 标题纹理（本项目 shop_title_1/2/3.png 缺 → ShopPanel Label 降级）
		"noneTagRes": "shop_none_tag.png",  # 售罄标签（缺图 → Label 降级）
		"payType": pay_type,
		"priceMul": price_mul,
		"canRefresh": can_refresh,
		"willAutoExit": will_auto_exit,
		"titleText": title_text,      # 标题降级文本
	}


# 源 marketconfig.getCoinRes：gold→shop_gold_icon，其他货币→shop_token_icon。
static func get_coin_res(pay: String) -> String:
	if pay == PAY_GOLD:
		return "shop_gold_icon.png"
	return "shop_token_icon.png"
