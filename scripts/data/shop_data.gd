class_name ShopData
extends RefCounted

## 商店数据查询（Data 层）— 照源 Shop.lua。
## Shop.json 字段：Expire Time / Goods 1-12 Group / Refresh Times / Shop ID / Shop Name / Unlock Stage。
## 单机化：Goods N Group 引用 ShopGoods 暗表（源 local_server.generateShopGoods 替代——直接随机
## 抽 Equip 6 件），本项目不查 Group；Refresh Times 自动刷新时刻暂不实现（手动刷新扣 GradientPrice）。


# 源 Shop.lua：Shop[id] 整行。
static func get_shop_info(shop_id: int, cm: Variant) -> Dictionary:
	return cm.get_raw_table(&"Shop").get(str(shop_id), {})


# 源 Expire Time（秒；0=永不过期，地精/黑市=3600s）。
static func get_expire(shop_id: int, cm: Variant) -> int:
	return int(get_shop_info(shop_id, cm).get("Expire Time", 0))


# 源 Unlock Stage（商店解锁关卡门控）。
static func get_unlock_stage(shop_id: int, cm: Variant) -> int:
	return int(get_shop_info(shop_id, cm).get("Unlock Stage", 0))


# 源 Shop Name（LSTR key，NPC 名）。
static func get_shop_name(shop_id: int, cm: Variant) -> String:
	return String(get_shop_info(shop_id, cm).get("Shop Name", ""))
