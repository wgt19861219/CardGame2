class_name TavernData
extends RefCounted

## 抽卡数据查询 + 产出 Logic（Data 层）。
## 查表照源 tavern.lua（TavernType/TavernBoxType）；产出照源 local_server.lua:1673 tavern_draw handler
## （简单掉落模拟：普通分支每次 1 equip + 30% 英雄碎片；stone 分支按品质 3 个 equip）。
## 免费抽卡照源 tavern.lua isShowFree/getCountdown + player.lua getTavernLeftTimes/useFreeTavern。

const FALLBACK_EQUIP_IDS: Array[int] = [101]              # 源 :1749 equip 表空 fallback
const FALLBACK_HERO_IDS: Array[int] = [1, 2, 3, 4, 5]     # 源 :1752 hero 池空 fallback
const FALLBACK_STONE_QUALITY: Array = [1, 2, 3]           # 源 :1687 boxType 缺失 fallback
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

# 源 box_cd（tavern.lua:19-24 + parameter.lua:29-32）：免费抽后 CD 秒。bronze 600 / gold 165600 / magic 432000。
const BOX_CD: Dictionary = {"Bronze": 600, "Gold": 165600, "MagicSoul": 432000}
# 源 getTavernLeftTimes tl（player.lua:1787-1792）：每日免费次数。bronze 5 / gold 1 / magic 1。
const FREE_TIMES: Dictionary = {"Bronze": 5, "Gold": 1, "MagicSoul": 1}
const SECONDS_PER_MINUTE: int = 60          # 分钟→秒换算（_local_day_key 时区偏移）
const SECONDS_PER_HOUR: int = 3600           # 小时→秒换算（_hms_string 倒计时格式）
const DAY_KEY_YEAR_WEIGHT: int = 10000       # 年份权重（年*10000+月*100+日 → 唯一日序号）
const DAY_KEY_MONTH_WEIGHT: int = 100        # 月份权重
# 源 _has_first_draw 位编码（player.lua:1730-1743 ed.makebits(16,of,16,tf)）：
# 高16位=单抽首抽标记 of / 低16位=十连首抽标记 tf。1=已首抽，0=未首抽。
const FIRST_DRAW_ONCE_SHIFT: int = 16        # 源 ed.bits(ifd,16,16) 高16位 = 单抽标记
const FIRST_DRAW_FLAG: int = 1               # 源 of=1/tf=1（player.lua:1739-1741，置1=已首抽）
const FIRST_DRAW_MASK: int = 0xFFFF          # 16位掩码（ed.bits 取 16 位宽度）

# 源 :1682-1686 stone 分支 boxType → 品质范围。
const STONE_QUALITY_MAP: Dictionary = {
	"stone_green": [1, 2, 3],
	"stone_blue": [3, 4, 5],
	"stone_purple": [4, 5, 6],
}
# 源 tavern.lua:33-38 ex_rank_key：box 小写名 → TavernType 表 key（get_ex_rank 用）。
const EX_RANK_KEY_MAP: Dictionary = {"bronze": "Bronze", "silver": "Silver", "gold": "Gold", "magic": "MagicSoul"}


# ---- 查表（照源 TavernType/TavernBoxType）----

# 源 TavernType 多级查表：type/is_ten/is_free/count → row。
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


# 源 TavernBoxType[chest_group][draw_times] → 宝箱描述（Box Type/Exhibition Rank）。
static func get_tavern_box(chest_group: int, draw_times: int, cm: Variant) -> Dictionary:
	return cm.get_raw_table("TavernBoxType").get(str(chest_group), {}).get(str(draw_times), {})


# 源 tavern.lua:233-237 getExRank：TavernType[ex_rank_key[box]]['true']['false'][0]["Exhibition Rank"]。
# 固定查十连付费层（is_ten=true/is_free=false/count=0），返品质展示阈值（bronze/gold=3，MagicSoul=4）。
# poptavernloot playBurst：物品 quality >= ex_rank 时显示旋转光效（源 createLootAnim :594/624）。
static func get_ex_rank(box: String, cm: Variant) -> int:
	var type_key: String = String(EX_RANK_KEY_MAP.get(box, ""))
	if type_key == "":
		return 0
	var row: Dictionary = cm.get_raw_table("TavernType").get(type_key, {}).get("true", {}).get("false", {}).get("0", {})
	return int(row.get("Exhibition Rank", 0))


# ---- 产出 Logic（照源 local_server.lua:1673 tavern_draw handler）----

# 抽卡产出：draw_type 0=单抽/1=十连/"stone"=灵魂石。返 Array[{id,amount}]。
# 源产出 makebits(11,amount,10,id) 编码 _item_ids 列表，本地单机用 {id,amount} dict 语义等价。
static func roll_tavern_loot(draw_type: Variant, box_type: Variant, rng: Variant, cm: Variant) -> Array:
	var loots: Array = []
	# 源 Lua drawType=="stone" 弱类型比较；GDScript Variant 持 int 时 ==String 报错，str() 统一转字符串
	if str(draw_type) == "stone":
		_roll_stone(loots, str(box_type), rng, cm)
		return loots
	var draw_count: int = COMBO_DRAW_COUNT if draw_type == 1 else 1
	_roll_normal(loots, draw_count, rng, cm)
	return loots


# 收集 equip 表有 Icon 的 id（源 :1729-1737）。
static func _collect_valid_equip_ids(cm: Variant) -> Array[int]:
	var raw: Dictionary = cm.get_raw_table("Equip")
	var ids: Array[int] = []
	for tid_str in raw:
		var row: Dictionary = raw[tid_str]
		if String(row.get("Icon", "")) != "":
			ids.append(int(tid_str))
	return ids


# 收集 Unit 表 Portrait+Hero 的 tid（源 :1738-1745）。
static func _collect_valid_hero_ids(cm: Variant) -> Array[int]:
	var raw: Dictionary = cm.get_raw_table("Unit")
	var ids: Array[int] = []
	for tid_str in raw:
		var row: Dictionary = raw[tid_str]
		if String(row.get("Portrait", "")) != "" and String(row.get("Unit Type", "")) == "Hero":
			ids.append(int(tid_str))
	return ids


# 普通抽卡产出（源 :1721-1764）：drawCount 次 equip（数量 1）+ 30% 英雄碎片（数量 1-3）。
static func _roll_normal(loots: Array, draw_count: int, rng: Variant, cm: Variant) -> void:
	var equip_ids: Array[int] = _collect_valid_equip_ids(cm)
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
	# 30% 概率额外给英雄碎片（源 :1761）
	if int(rng.randi_range(1, SHARD_ROLL_MAX)) <= SHARD_ROLL_THRESHOLD:
		var hid: int = hero_ids[int(rng.randi_range(0, hero_ids.size() - 1))]
		var amount: int = int(rng.randi_range(1, SHARD_AMOUNT_MAX))
		loots.append({"id": hid, "amount": amount})


# 灵魂石分支产出（源 :1681-1715）：按 box_type 品质范围筛 equip，随机 3 个，数量 1-3。
static func _roll_stone(loots: Array, box_type: String, rng: Variant, cm: Variant) -> void:
	var qualities: Array = STONE_QUALITY_MAP.get(box_type, FALLBACK_STONE_QUALITY)
	var raw: Dictionary = cm.get_raw_table("Equip")
	var valid: Array[int] = []
	for tid_str in raw:
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
# 源 :1663-1668 for 1..6 table_insert(math_random(1,30))；heroIds[1]=math_random(1,15) 每日特别。
static func ask_magicsoul(rng: BattleRng) -> Array[int]:
	var ids: Array[int] = []
	for _i in MAGICSOUL_PREVIEW_COUNT:
		ids.append(rng.randi_range(1, MAGICSOUL_HERO_ID_MAX))
	ids[0] = rng.randi_range(1, MAGICSOUL_SPECIAL_ID_MAX)  # 源 :1667 首个每日特别
	return ids


# ---- 免费抽卡（照源 tavern.lua isShowFree/getCountdown + player.lua getTavernLeftTimes/useFreeTavern）----

# 源 player:getTavernRecord（player.lua:1760）：取 box 免费记录。单机化用 box key 直接索引（源用 box_color 查找，等价）。
static func _get_record(pd: PlayerData, box: String) -> Dictionary:
	if not pd.tavern_record.has(box):
		pd.tavern_record[box] = {"left_cnt": 0, "last_get_time": 0, "has_first_draw": 0}
	return pd.tavern_record[box]


# 源 checkTwoDateod（time.lua:323）：跨日判定。源用中国时区 + reset_time BOA 边界；单机化简化为本地自然日比较。
static func _crossed_day(last_ts: int, now: int) -> bool:
	if last_ts <= 0:
		return true   # 源 time2China(0) 与 now 差 >86400 → 跨日（首次/未抽过返满额）
	var off_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return _local_day_key(last_ts, off_min) != _local_day_key(now, off_min)


# 本地自然日序号（年*10000+月*100+日）。偏移本地时区后取 UTC 字典日期。
static func _local_day_key(ts: int, off_min: int) -> int:
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(ts + off_min * SECONDS_PER_MINUTE)
	return int(dt["year"]) * DAY_KEY_YEAR_WEIGHT + int(dt["month"]) * DAY_KEY_MONTH_WEIGHT + int(dt["day"])


# 源 player:getTavernLeftTimes（player.lua:1786）：跨日返满额 tl[type]，同日返 record._left_cnt。
static func get_left_times(pd: PlayerData, box: String, now: int) -> int:
	var rec: Dictionary = _get_record(pd, box)
	if _crossed_day(int(rec.get("last_get_time", 0)), now):
		return int(FREE_TIMES.get(box, 0))
	return int(rec.get("left_cnt", 0))


# 源 tavern.lua:247 getCountdown：box_cd - (now - _last_get_time)。>0 在 CD，0=CD 结束可免费。
static func get_countdown(pd: PlayerData, box: String, now: int) -> int:
	var rec: Dictionary = _get_record(pd, box)
	var cd: int = int(BOX_CD.get(box, 0))
	if cd <= 0:
		return 0
	var dt: int = now - int(rec.get("last_get_time", 0))
	if dt >= cd:
		return 0
	return cd - dt


# 源 tavern.lua:305 isShowFree：getCountdown 返 nil（CD 结束）且 getLeftTimes>0 → true。
static func is_show_free(pd: PlayerData, box: String, now: int) -> bool:
	if get_countdown(pd, box, now) > 0:
		return false
	return get_left_times(pd, box, now) > 0


# 源 player:useFreeTavern（player.lua:1749）：免费抽后 _left_cnt-1（下限 0）+ _last_get_time=now。
static func use_free_tavern(pd: PlayerData, box: String, now: int) -> void:
	var left: int = get_left_times(pd, box, now)
	var rec: Dictionary = _get_record(pd, box)
	rec["left_cnt"] = max(left - 1, 0)
	rec["last_get_time"] = now


# 源 gethmsNString（time.lua:289）+ second2hms：秒转 "HH:MM:SS"（h 不限 24，magic CD 5 天=120:00:00）。
static func _hms_string(seconds: int) -> String:
	var h: int = seconds / SECONDS_PER_HOUR
	var m: int = (seconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE
	var s: int = seconds % SECONDS_PER_MINUTE
	return "%02d:%02d:%02d" % [h, m, s]


# 源 getCountdownText（tavern.lua:264）：CD 中返倒计时；CD 结束 bronze 返"剩余免费次数 D/D"或"今日用完"，其他空。
# 返 {is_counting, text}（照源返 isCount, text 双值）。
static func get_countdown_text(pd: PlayerData, box: String, now: int) -> Dictionary:
	var count: int = get_countdown(pd, box, now)
	if count > 0:
		return {"is_counting": true, "text": _hms_string(count)}
	var text: String = ""
	if box == "Bronze":   # 源 box_chance 仅 bronze/silver 有值，gold/magic CD 结束不显示文字
		var left: int = get_left_times(pd, box, now)
		if left > 0:
			text = "剩余免费次数 %d/%d" % [left, int(FREE_TIMES.get(box, 0))]
		else:
			text = "今日免费次数已用完"
	return {"is_counting": false, "text": text}


# ---- 首抽保底标记（照源 tavern.lua:285 isFirstDraw + player.lua:1730 refreshFirstTavern）----

# 源 isFirstDraw（tavern.lua:285-292）：解码 _has_first_draw 位编码 → {once, ten}（true=未首抽）。
# 源 ed.bits(ifd,16,16)==0 → 单抽未首抽；ed.bits(ifd,0,16)==0 → 十连未首抽。
static func is_first_draw(pd: PlayerData, box: String) -> Dictionary:
	var rec: Dictionary = _get_record(pd, box)
	var ifd: int = int(rec.get("has_first_draw", 0))
	var once_flag: int = (ifd >> FIRST_DRAW_ONCE_SHIFT) & FIRST_DRAW_MASK
	var ten_flag: int = ifd & FIRST_DRAW_MASK
	return {"once": once_flag == 0, "ten": ten_flag == 0}


# 源 isFirstOneDraw（tavern.lua:294-297）：单抽是否首抽（ifd[1]）。
static func is_first_one_draw(pd: PlayerData, box: String) -> bool:
	return bool(is_first_draw(pd, box)["once"])


# 源 isFirstTenDraw（tavern.lua:299-302）：十连是否首抽（ifd[2]）。
static func is_first_ten_draw(pd: PlayerData, box: String) -> bool:
	return bool(is_first_draw(pd, box)["ten"])


# 源 refreshFirstTavern（player.lua:1730-1747）：times=one→of=1，ten→tf=1，makebits(16,of,16,tf) 编码。
# 源在 network.lua:1295 服务端回复后调；单机化由 View 抽卡成功后直调。
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
