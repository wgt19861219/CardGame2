class_name MarketConfig
extends RefCounted

## 商店 UI/行为配置（Data 层）— 照源 ui/market/marketconfig.lua type_config。
## 单机化：源 canRefresh 是闭包查 player 余额，本项目改 bool 字段（余额校验移至 ShopManager.buy）。
## 坐标字段由 ShopPanel 常量定义（Godot 左上原点），本表只存纹理/货币/价格系数/行为标志。
## 纹理前缀 res://assets/ui/alpha/HVGA/。

const PAY_GOLD: String = "gold"
const PAY_DIAMOND: String = "diamond"
const PAY_CRUSADE: String = "crusadepoint"
const PAY_ARENA: String = "arenapoint"
const PAY_GUILD: String = "guildpoint"

const UI_DIR: String = "res://assets/ui/alpha/HVGA/"
const SHOP_COMMON_ID: int = 1
const SHOP_GOBLIN_ID: int = 2
const SHOP_BLACK_MARKET_ID: int = 3
const SHOP_GUILD_ID: int = 7          # 公会商店（源 marketconfig.lua [7]，payType guildpoint）
const PRICE_MUL_GOBLIN: float = 0.6
const PRICE_MUL_BLACK_MARKET: float = 2.0


static func get_type_config(shop_id: int) -> Dictionary:
	match shop_id:
		SHOP_COMMON_ID:
			return _common()
		SHOP_GOBLIN_ID:
			return _goblin()
		SHOP_BLACK_MARKET_ID:
			return _black_market()
		SHOP_GUILD_ID:
			return _guild()
		_:
			return _common()


static func _common() -> Dictionary:
	return _make("shop_bg.png", "shop_product_bg.png", "shop_head.png", "shop_title_1.png",
			PAY_GOLD, 1.0, true, false, "商店")


static func _goblin() -> Dictionary:
	return _make("shop_bg.png", "shop_product_bg_2.png", "shop_head_2.png", "shop_title_2.png",
			PAY_GOLD, PRICE_MUL_GOBLIN, true, false, "地精商人")


static func _black_market() -> Dictionary:
	return _make("shop_bg.png", "shop_product_bg_2.png", "shop_head_3.png", "shop_title_3.png",
			PAY_DIAMOND, PRICE_MUL_BLACK_MARKET, true, false, "黑市商人")


## 公会商店（源 marketconfig.lua [7]：shop_head_guild 专属皮；商品/刷新币种均 guildpoint——
## ItemGroups 组 137-139 表配置 + refresh_coin_type=guildpoint；商品币种由 ShopManager 走表管道）。
static func _guild() -> Dictionary:
	return _make("shop_bg.png", "shop_product_bg_2.png", "shop_head_guild.png", "shop_title_bg_guild.png",
			PAY_GOLD, 1.0, true, false, "公会商店")


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


# 刷新币种照源 marketconfig.lua type_config[].refresh_coin_type：
# shop 1/2/3 钻石、4 龙鳞、5 角斗士、7 兄弟会（shop 6 starshop 无刷新）。
const REFRESH_COIN_TYPE: Dictionary = {
	1: PAY_DIAMOND,
	2: PAY_DIAMOND,
	3: PAY_DIAMOND,
	4: PAY_CRUSADE,
	5: PAY_ARENA,
	7: PAY_GUILD,
}
# 刷新币种名 LSTR key 照源 refresh_coin_name。
const REFRESH_COIN_NAME_KEY: Dictionary = {
	1: "RECHARGE.DIAMOND",
	2: "RECHARGE.DIAMOND",
	3: "RECHARGE.DIAMOND",
	4: "SHOP.INTERFAX_COINS",
	5: "SHOP.GLADIATOR_COINS",
	7: "marketconfig.1.10.1.002",
}


static func get_refresh_coin_type(shop_id: int) -> String:
	return String(REFRESH_COIN_TYPE.get(shop_id, PAY_DIAMOND))


static func get_refresh_coin_name_key(shop_id: int) -> String:
	return String(REFRESH_COIN_NAME_KEY.get(shop_id, "RECHARGE.DIAMOND"))


# 照源 marketconfig.lua:278-287 getCoinRes 5 键映射（dragon=钻石贴图，龙鳞/角斗士/兄弟会各有专用贴图）。
static func get_coin_res(pay: String) -> String:
	if pay == PAY_GOLD:
		return "shop_gold_icon.png"
	if pay == PAY_DIAMOND:
		return "shop_token_icon.png"
	if pay == PAY_CRUSADE:
		return "money_dragonscale_small.png"
	if pay == PAY_ARENA:
		return "money_arenatoken_small.png"
	if pay == PAY_GUILD:
		return "money_guildtoken_small.png"
	return "shop_token_icon.png"
