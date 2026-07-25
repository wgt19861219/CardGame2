class_name MerchantTalkData
extends RefCounted

## 商店 NPC 对话选词（Data 层）— 照源 ui/market/market.lua:285-324 getTalkContent。
## 读 MerchantTalk 表，按 Event(key) 收集 Talk bi..ei，random 选一条 + 避重复。
## 地精(2)/黑市(3) refresh 态用 Talk 7-12（源 :288-290）；starshop 直接传 id 6（源 id=="starshop"→6）。
## time_type 由调用方算好传入（照源 checkShopTimeType，依赖持久 _last_auto_refresh_time）。

const MERCHANT_TALK_TABLE: StringName = &"MerchantTalk"
const TALK_DEFAULT_BI: int = 1
const TALK_DEFAULT_EI: int = 6
const TALK_REFRESH_BI: int = 7
const TALK_REFRESH_EI: int = 12

static var _pre_talk_key: String = ""
static var _pre_talk_id: int = -1


static func reset_talk_state() -> void:
	_pre_talk_key = ""
	_pre_talk_id = -1


## 选一条对话文案。返 "" 表示该 shop/event 无台词（如 Shop1 Purchase 源本无 Talk，照源返空）。
static func get_talk_content(shop_id: int, key: String, time_type: String, rng: BattleRng, cm: Variant) -> String:
	var bi: int = TALK_DEFAULT_BI
	var ei: int = TALK_DEFAULT_EI
	if (shop_id == MarketConfig.SHOP_GOBLIN_ID or shop_id == MarketConfig.SHOP_BLACK_MARKET_ID) and time_type == "refresh":
		bi = TALK_REFRESH_BI
		ei = TALK_REFRESH_EI
	var talk_info: Dictionary = cm.get_raw_table(MERCHANT_TALK_TABLE).get(str(shop_id), {})
	if talk_info.is_empty():
		return ""
	var event_info: Dictionary = talk_info.get(key, {})
	if event_info.is_empty():
		return ""
	var talks: Array = []
	for i in range(bi, ei + 1):
		var s: Variant = event_info.get("Talk " + str(i), null)
		if s != null:
			talks.append(String(s))
	if talks.is_empty():
		return ""
	rng.randi_range(1, talks.size())
	var pick: int = rng.randi_range(1, talks.size()) - 1   # 转 0-based
	if key == _pre_talk_key and pick == _pre_talk_id and talks.size() > 1:
		pick = pick - 1 if pick == talks.size() - 1 else pick + 1
	_pre_talk_key = key
	_pre_talk_id = pick
	return String(talks[pick])
