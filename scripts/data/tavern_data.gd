class_name TavernData
extends RefCounted

## 抽卡数据查询 + 产出 Logic（Data 层）。
## 查表照源 tavern.lua（TavernType/TavernBoxType）；产出照源 local_server.lua:1673 tavern_draw handler
## （简单掉落模拟：普通分支每次 1 equip + 30% 英雄碎片；stone 分支按品质 3 个 equip）。
## 免费抽卡照源 tavern.lua isShowFree/getCountdown + player.lua getTavernLeftTimes/useFreeTavern。

const FALLBACK_EQUIP_IDS: Array[int] = [101]
const FALLBACK_HERO_IDS: Array[int] = [1, 2, 3, 4, 5]
const FALLBACK_STONE_QUALITY: Array = [1, 2, 3]
const COMBO_DRAW_COUNT: int = 10                          # 十连数（源 :1723）
const STONE_DRAW_COUNT: int = 3                           # 灵魂石分支产出数（源 :1706）
const STONE_AMOUNT_MAX: int = 3                           # 灵魂石每个数量上限（源 :1708 rand(1,3)）
const EQUIP_AMOUNT: int = 1                               # 普通分支 equip 数量固定 1（源 :1757）
const SHARD_ROLL_MAX: int = 10                            # 碎片概率分母（源 :1761 rand(1,10)）
const SHARD_ROLL_THRESHOLD: int = 3                       # <=3 命中 = 30%（源 :1761）
const SHARD_AMOUNT_MAX: int = 3                           # 碎片数量上限（源 :1763 rand(1,3)）
const MAGICSOUL_PREVIEW_COUNT: int = 6                    # 魂匣预览英雄数（源 :1663 ask_magicsoul for 1..6）
const MAGICSOUL_HERO_ID_MAX: int = 30                     # 魂匣英雄 ID 上限（源 :1664 math_random(1,30)）
const MAGICSOUL_SPECIAL_ID_MAX: int = 15                  # 每日特别英雄 ID 上限（源 :1667 math_random(1,15)）

const BOX_CD: Dictionary = {"Bronze": 600, "Gold": 165600, "MagicSoul": 432000}
const FREE_TIMES: Dictionary = {"Bronze": 5, "Gold": 1, "MagicSoul": 1}
const SECONDS_PER_MINUTE: int = 60          # 分钟→秒换算（_local_day_key 时区偏移）
const SECONDS_PER_HOUR: int = 3600           # 小时→秒换算（_hms_string 倒计时格式）
const DAY_KEY_YEAR_WEIGHT: int = 10000       # 年份权重（年*10000+月*100+日 → 唯一日序号）
const DAY_KEY_MONTH_WEIGHT: int = 100        # 月份权重
# 高16位=单抽首抽标记 of / 低16位=十连首抽标记 tf。1=已首抽，0=未首抽。
const FIRST_DRAW_ONCE_SHIFT: int = 16
const FIRST_DRAW_FLAG: int = 1
const FIRST_DRAW_MASK: int = 0xFFFF          # 16位掩码（ed.bits 取 16 位宽度）

const STONE_QUALITY_MAP: Dictionary = {
	"stone_green": [1, 2, 3],
	"stone_blue": [3, 4, 5],
	"stone_purple": [4, 5, 6],
}
const EX_RANK_KEY_MAP: Dictionary = {"bronze": "Bronze", "silver": "Silver", "gold": "Gold", "magic": "MagicSoul"}
# ---- 品质分池(原版服务器掉落组的单机化重建,2026-09-07)----
# 原版客户端证据:TavernType 每行带 Chest Group ID 且首抽/累计抽数换组(掉落组全在服务器
# 私有表,客户端零残留);MagicSoul DrawTimes 26 切组 24;gold 十连文案 TAVERNRES.HERO_IS
# "十连抽必得英雄";协议 _new_heroes(新英雄全量下发)/_smash_idx(重复英雄碎魂)。
# 具体数值不可考,按 Equip.Quality 重建;实测各档池非空(76/190/152,首抽 186/105/97)。
const POOL_QUALITY_RANGES: Dictionary = {
	"Bronze": [1, 2],
	"Gold": [3, 4],
	"MagicSoul": [4, 6],
}
const FALLBACK_POOL_QUALITY: Array = [1, 6]        # 未知类型兜底全量(兼容旧调用)
const FIRST_DRAW_QUALITY_BOOST: int = 1            # 首抽池高一档(源首抽独立 Chest Group)
const MAGIC_COMBO_GUARANTEE_COUNT: int = 26        # magic 第 26 次十连起切池(源 DrawTimes 26)
const MAGIC_GUARANTEE_QUALITY: Array = [5, 6]      # 26 次后品质池(源组 24 等价)
const QUALITY_MIN: int = 1
const QUALITY_MAX: int = 6


# ---- 查表（照源 TavernType/TavernBoxType）----

static func get_tavern_info(tavern_type: String, is_ten: bool, is_free: bool, count: int, cm: Variant) -> Dictionary:
	var ten_key: String = "true" if is_ten else "false"
	var free_key: String = "true" if is_free else "false"
	var row: Dictionary = cm.get_raw_table("TavernType").get(tavern_type, {}).get(ten_key, {}).get(free_key, {}).get(str(count), {})
	return row


# 抽卡消耗（Diamond 数）。
static func get_tavern_cost(tavern_type: String, is_ten: bool, is_free: bool, count: int, cm: Variant) -> int:
	var row: Dictionary = get_tavern_info(tavern_type, is_ten, is_free, count, cm)
	return int(row.get("Cost", 0))


# 宝箱组 ID（决定产出池）。
static func get_tavern_chest_group(tavern_type: String, is_ten: bool, is_free: bool, count: int, cm: Variant) -> int:
	var row: Dictionary = get_tavern_info(tavern_type, is_ten, is_free, count, cm)
	return int(row.get("Chest Group ID", 0))


# 扣抽卡消耗（照源 row "Cost Type"：Gold 扣金币 Bronze / Diamond 扣钻石 MagicSoul）。返是否够扣。
static func consume_tavern_cost(pd: PlayerData, row: Dictionary, is_free: bool) -> bool:
	var cost: int = 0 if is_free else int(row.get("Cost", 0))
	if String(row.get("Cost Type", "Diamond")) == "Gold":
		if cost > pd.hero_manager.gold:
			return false
		pd.hero_manager.gold -= cost
	else:
		if cost > pd.diamond:
			return false
		pd.diamond -= cost
	return true


static func get_tavern_box(chest_group: int, draw_times: int, cm: Variant) -> Dictionary:
	return cm.get_raw_table("TavernBoxType").get(str(chest_group), {}).get(str(draw_times), {})


# 固定查十连付费层（is_ten=true/is_free=false/count=0），返品质展示阈值（bronze/gold=3，MagicSoul=4）。
# poptavernloot playBurst：物品 quality >= ex_rank 时显示旋转光效（源 createLootAnim :594/624）。
static func get_ex_rank(box: String, cm: Variant) -> int:
	var type_key: String = String(EX_RANK_KEY_MAP.get(box, ""))
	if type_key == "":
		return 0
	var row: Dictionary = cm.get_raw_table("TavernType").get(type_key, {}).get("true", {}).get("false", {}).get("0", {})
	return int(row.get("Exhibition Rank", 0))


# ---- 产出 Logic（照源 local_server.lua:1673 tavern_draw handler + 品质分池重建 2026-09-07）----

# 抽卡产出：draw_type 0=单抽/1=十连/"stone"=灵魂石。返 Array[{id,amount}]。
# tavern_type 驱动品质分池；is_first 首抽高一档；magic_combo_count>=26 切保底池。
static func roll_tavern_loot(draw_type: Variant, box_type: Variant, rng: Variant, cm: Variant,
		tavern_type: String = "", is_first: bool = false, magic_combo_count: int = 0) -> Array:
	var loots: Array = []
	if str(draw_type) == "stone":
		_roll_stone(loots, str(box_type), rng, cm)
		return loots
	var draw_count: int = COMBO_DRAW_COUNT if draw_type == 1 else 1
	_roll_normal(loots, draw_count, rng, cm, tavern_type, is_first, magic_combo_count)
	return loots


# 箱子品质池范围：常规池 → 首抽 +1 档 → magic 26 次保底池覆盖，clamp 到 [1,6]。
static func _quality_range(tavern_type: String, is_first: bool, magic_combo_count: int) -> Array:
	var q_range: Array = POOL_QUALITY_RANGES.get(tavern_type, FALLBACK_POOL_QUALITY).duplicate()
	if is_first:
		q_range = [int(q_range[0]) + FIRST_DRAW_QUALITY_BOOST, int(q_range[1]) + FIRST_DRAW_QUALITY_BOOST]
	if tavern_type == "MagicSoul" and magic_combo_count >= MAGIC_COMBO_GUARANTEE_COUNT:
		q_range = MAGIC_GUARANTEE_QUALITY.duplicate()
	return [clampi(int(q_range[0]), QUALITY_MIN, QUALITY_MAX), clampi(int(q_range[1]), QUALITY_MIN, QUALITY_MAX)]


# 收集 equip 表有 Icon 的 id（源 :1729-1737）+ 品质范围过滤（分池重建 2026-09-07）。
# 源 :1731 type(k)=="number" 滤除非数字 key——Equip 表混有 "equip.2.0.0.xxx" 策划模板行
# （359/722），int() 截断成 0 进池会以 49.7% 概率产出查表无行的 id=0 → 图标空白
# （2026-09-07 抽卡空白图标根修）。JSON key 恒 String，is_valid_int 等价源的 number 判定。
static func _collect_valid_equip_ids(cm: Variant, min_q: int = QUALITY_MIN, max_q: int = QUALITY_MAX) -> Array[int]:
	var raw: Dictionary = cm.get_raw_table("Equip")
	var ids: Array[int] = []
	for tid_str in raw:
		if not String(tid_str).is_valid_int():
			continue
		var row: Dictionary = raw[tid_str]
		if String(row.get("Icon", "")) == "":
			continue
		var q: int = int(row.get("Quality", 1))
		if q < min_q or q > max_q:
			continue
		ids.append(int(tid_str))
	return ids


# 收集 Unit 表 Portrait+Hero 的 tid（源 :1738-1745）。非数字 key 过滤同上（防御性对齐源）。
static func _collect_valid_hero_ids(cm: Variant) -> Array[int]:
	var raw: Dictionary = cm.get_raw_table("Unit")
	var ids: Array[int] = []
	for tid_str in raw:
		if not String(tid_str).is_valid_int():
			continue
		var row: Dictionary = raw[tid_str]
		if String(row.get("Portrait", "")) != "" and String(row.get("Unit Type", "")) == "Hero":
			ids.append(int(tid_str))
	return ids


# 普通抽卡产出（源 :1721-1764）：drawCount 次 equip（数量 1）+ 英雄位（gold 十连必得，
# 其余 30% 概率；数量 1-3）。品质池按箱子/首抽/magic 计数（见 _quality_range）。
static func _roll_normal(loots: Array, draw_count: int, rng: Variant, cm: Variant,
		tavern_type: String, is_first: bool, magic_combo_count: int) -> void:
	var q_range: Array = _quality_range(tavern_type, is_first, magic_combo_count)
	var equip_ids: Array[int] = _collect_valid_equip_ids(cm, int(q_range[0]), int(q_range[1]))
	if equip_ids.is_empty():
		equip_ids = FALLBACK_EQUIP_IDS
	var hero_ids: Array[int] = _collect_valid_hero_ids(cm)
	if hero_ids.is_empty():
		hero_ids = FALLBACK_HERO_IDS
	var i: int = 0
	while i < draw_count:
		var eid: int = equip_ids[int(rng.randi_range(0, equip_ids.size() - 1))]
		loots.append({"id": eid, "amount": EQUIP_AMOUNT})
		i += 1
	# 英雄位：gold 十连必得（源 TAVERNRES.HERO_IS "十连抽必得英雄"），其余 30%（源 :1761）。
	var hero_guaranteed: bool = draw_count == COMBO_DRAW_COUNT and tavern_type == "Gold"
	if hero_guaranteed or int(rng.randi_range(1, SHARD_ROLL_MAX)) <= SHARD_ROLL_THRESHOLD:
		var hid: int = hero_ids[int(rng.randi_range(0, hero_ids.size() - 1))]
		var amount: int = int(rng.randi_range(1, SHARD_AMOUNT_MAX))
		loots.append({"id": hid, "amount": amount})


# 灵魂石分支产出（源 :1681-1715）：按 box_type 品质范围筛 equip，随机 3 个，数量 1-3。
# 源 :1677 type(k)=="number" 滤除非数字 key（同 _collect_valid_equip_ids 根修，2026-09-07）。
static func _roll_stone(loots: Array, box_type: String, rng: Variant, cm: Variant) -> void:
	var qualities: Array = STONE_QUALITY_MAP.get(box_type, FALLBACK_STONE_QUALITY)
	var raw: Dictionary = cm.get_raw_table("Equip")
	var valid: Array[int] = []
	for tid_str in raw:
		if not String(tid_str).is_valid_int():
			continue
		var row: Dictionary = raw[tid_str]
		if String(row.get("Icon", "")) == "":
			continue
		var q: int = int(row.get("Quality", 1))
		for tq in qualities:
			if q == int(tq):
				valid.append(int(tid_str))
				break
	if valid.is_empty():
		valid = FALLBACK_EQUIP_IDS
	var i: int = 0
	while i < STONE_DRAW_COUNT:
		var eid: int = valid[int(rng.randi_range(0, valid.size() - 1))]
		var amount: int = int(rng.randi_range(1, STONE_AMOUNT_MAX))
		loots.append({"id": eid, "amount": amount})
		i += 1


# ---- 魂匣预览（照源 local_server.lua:1660-1669 ask_magicsoul handler）----

# 魂匣预览：返回 6 个随机英雄 ID（首个每日特别 1-15，其余 1-30）。纯随机无持久化（源同）。
# ask_magicsoul handler 单机化：View 切 MagicSoul tab 时直调（源走 local_server dispatch）。
static func ask_magicsoul(rng: BattleRng) -> Array[int]:
	var ids: Array[int] = []
	for _i in MAGICSOUL_PREVIEW_COUNT:
		ids.append(rng.randi_range(1, MAGICSOUL_HERO_ID_MAX))
	ids[0] = rng.randi_range(1, MAGICSOUL_SPECIAL_ID_MAX)
	return ids


# ---- 免费抽卡（照源 tavern.lua isShowFree/getCountdown + player.lua getTavernLeftTimes/useFreeTavern）----

static func _get_record(pd: PlayerData, box: String) -> Dictionary:
	if not pd.tavern_record.has(box):
		pd.tavern_record[box] = {"left_cnt": 0, "last_get_time": 0, "has_first_draw": 0}
	return pd.tavern_record[box]


static func _crossed_day(last_ts: int, now: int) -> bool:
	if last_ts <= 0:
		return true
	var off_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return _local_day_key(last_ts, off_min) != _local_day_key(now, off_min)


# 本地自然日序号（年*10000+月*100+日）。偏移本地时区后取 UTC 字典日期。
static func _local_day_key(ts: int, off_min: int) -> int:
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(ts + off_min * SECONDS_PER_MINUTE)
	return int(dt["year"]) * DAY_KEY_YEAR_WEIGHT + int(dt["month"]) * DAY_KEY_MONTH_WEIGHT + int(dt["day"])


static func get_left_times(pd: PlayerData, box: String, now: int) -> int:
	var rec: Dictionary = _get_record(pd, box)
	if _crossed_day(int(rec.get("last_get_time", 0)), now):
		return int(FREE_TIMES.get(box, 0))
	return int(rec.get("left_cnt", 0))


static func get_countdown(pd: PlayerData, box: String, now: int) -> int:
	var rec: Dictionary = _get_record(pd, box)
	var cd: int = int(BOX_CD.get(box, 0))
	if cd <= 0:
		return 0
	var dt: int = now - int(rec.get("last_get_time", 0))
	if dt >= cd:
		return 0
	return cd - dt


static func is_show_free(pd: PlayerData, box: String, now: int) -> bool:
	if get_countdown(pd, box, now) > 0:
		return false
	return get_left_times(pd, box, now) > 0


static func use_free_tavern(pd: PlayerData, box: String, now: int) -> void:
	var left: int = get_left_times(pd, box, now)
	var rec: Dictionary = _get_record(pd, box)
	rec["left_cnt"] = max(left - 1, 0)
	rec["last_get_time"] = now


static func _hms_string(seconds: int) -> String:
	var h: int = seconds / SECONDS_PER_HOUR
	var m: int = (seconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE
	var s: int = seconds % SECONDS_PER_MINUTE
	return "%02d:%02d:%02d" % [h, m, s]


# 返 {is_counting, text}（照源返 isCount, text 双值）。
static func get_countdown_text(pd: PlayerData, box: String, now: int) -> Dictionary:
	var count: int = get_countdown(pd, box, now)
	if count > 0:
		return {"is_counting": true, "text": _hms_string(count)}
	var text: String = ""
	if box == "Bronze":
		var left: int = get_left_times(pd, box, now)
		if left > 0:
			text = "剩余免费次数 %d/%d" % [left, int(FREE_TIMES.get(box, 0))]
		else:
			text = "今日免费次数已用完"
	return {"is_counting": false, "text": text}


# ---- 首抽保底标记（照源 tavern.lua:285 isFirstDraw + player.lua:1730 refreshFirstTavern）----

static func is_first_draw(pd: PlayerData, box: String) -> Dictionary:
	var rec: Dictionary = _get_record(pd, box)
	var ifd: int = int(rec.get("has_first_draw", 0))
	var once_flag: int = (ifd >> FIRST_DRAW_ONCE_SHIFT) & FIRST_DRAW_MASK
	var ten_flag: int = ifd & FIRST_DRAW_MASK
	return {"once": once_flag == 0, "ten": ten_flag == 0}


static func is_first_one_draw(pd: PlayerData, box: String) -> bool:
	return bool(is_first_draw(pd, box)["once"])


static func is_first_ten_draw(pd: PlayerData, box: String) -> bool:
	return bool(is_first_draw(pd, box)["ten"])


static func refresh_first_tavern(pd: PlayerData, box: String, is_ten: bool) -> void:
	var rec: Dictionary = _get_record(pd, box)
	var ifd: int = int(rec.get("has_first_draw", 0))
	var once_flag: int = (ifd >> FIRST_DRAW_ONCE_SHIFT) & FIRST_DRAW_MASK
	var ten_flag: int = ifd & FIRST_DRAW_MASK
	if is_ten:
		ten_flag = FIRST_DRAW_FLAG
	else:
		once_flag = FIRST_DRAW_FLAG
	rec["has_first_draw"] = (once_flag << FIRST_DRAW_ONCE_SHIFT) | ten_flag
