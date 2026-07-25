class_name ReadheroHandbook
extends RefCounted

## 英雄图鉴列表与碎片查询（Logic 层）— 照源 readhero.lua 翻译（P0-1 整行卡片重建）。
## 服务 heropackage 图鉴面板：未召唤英雄列表、碎片进度、按位置分类。
## 不依赖 Node/Control（headless 可单测）。查 ConfigManager（Unit/Fragment/HeroStars）+ HeroManager（heroes/fragments）。
## 坐标/资源在 View 层 HeroPackageItem；本类纯数据查询。

const FALLBACK_STONE_ID: int = 335
const HERO_TYPE_ID_MAX: int = 100
# Position Type 实际值是 LSTR key（Unit.json "UNIT.FRONT_ROW"/"UNIT.MIDDLE_ROW"/"UNIT.REAR_ROW"），
# find 匹配 key。旧值 "Front"/"Middle"/"Rear" 匹配不上 "FRONT_ROW" 全大写 → front/middle/back 全空（bug）。
const POS_FRONT: String = "UNIT.FRONT_ROW"
const POS_MIDDLE: String = "UNIT.MIDDLE_ROW"
const POS_REAR: String = "UNIT.REAR_ROW"
# 索引 0 占位，索引 = rank（Lua 1-based → GDScript 0-based 加占位对齐；表本身 22 元素 + 1 占位 = 23）。
const HERO_STAR: Array[int] = [
	0, 0, 0, 1, 0, 1, 2, 0, 1, 2, 3, 4, 0, 1, 2, 3, 4, 0, 1, 2, 3, 4, 5
]
const HERO_MAX_STAR: Array[int] = [
	0, 0, 1, 1, 2, 2, 2, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5
]
const NAME_COLOR_WHITE: Color = Color(254.0 / 255.0, 251.0 / 255.0, 241.0 / 255.0)       # rank 1
const NAME_COLOR_YELLOW: Color = Color(248.0 / 255.0, 255.0 / 255.0, 62.0 / 255.0)       # rank 2-3
const NAME_COLOR_BLUE: Color = Color(96.0 / 255.0, 172.0 / 255.0, 243.0 / 255.0)         # rank 4-6
const NAME_COLOR_PURPLE: Color = Color(1.0, 128.0 / 255.0, 1.0)                          # rank 7-11
const NAME_COLOR_ORANGE: Color = Color(1.0, 152.0 / 255.0, 72.0 / 255.0)                 # rank 12-16
const NAME_COLOR_RED: Color = Color(1.0, 60.0 / 255.0, 60.0 / 255.0)                     # rank >= 17
const NAME_COLOR_DEFAULT: Color = Color(1.0, 1.0, 1.0)                                   # rank<1 兜底
const RANK_YELLOW_MAX: int = 3
const RANK_BLUE_MAX: int = 6
const RANK_PURPLE_MAX: int = 11
const RANK_ORANGE_MAX: int = 16


static func get_stone_id(tid: int, cm: Variant) -> int:
	var fid: Variant = cm.get_raw_table(&"Fragment").get(str(tid), {}).get(&"Fragment ID")
	if fid == null:
		return FALLBACK_STONE_ID
	return int(fid)


static func get_stone_amount(tid: int, cm: Variant, hero_mgr: HeroManager) -> int:
	var sid: int = get_stone_id(tid, cm)
	return int(hero_mgr.fragments.get(sid, 0))


# 已拥有：HeroStars[stars+1]["Upgrade Fragments"]（无上限行返 0，源 :664 return nil）。
static func get_stone_need(tid: int, cm: Variant, hero_mgr: HeroManager) -> int:
	var hero: HeroInstance = hero_mgr.find_hero_by_tid(tid)
	if hero == null:
		var init_star: int = ReadheroData.get_hero_init_stars(tid, cm)
		return int(cm.get_raw_table(&"HeroStars").get(str(init_star), {}).get(&"Summon Fragments", 0))
	var row: Dictionary = cm.get_raw_table(&"HeroStars").get(str(hero.stars + 1), {})
	if row.is_empty():
		return 0
	return int(row.get(&"Upgrade Fragments", 0))


static func get_summon_cost(tid: int, cm: Variant) -> int:
	var init_star: int = ReadheroData.get_hero_init_stars(tid, cm)
	return int(cm.get_raw_table(&"HeroStars").get(str(init_star), {}).get(&"Summon Price", 0))


static func check_stone_enough(tid: int, cm: Variant, hero_mgr: HeroManager) -> bool:
	return get_stone_amount(tid, cm, hero_mgr) >= get_stone_need(tid, cm, hero_mgr)


# 返 Array[int] tid 升序（源 :704-712 冒泡插入排序）。
static func get_miss_list(cm: Variant, hero_mgr: HeroManager) -> Array[int]:
	var list: Array[int] = []
	var raw: Dictionary = cm.get_raw_table(&"Unit")
	for tid_str in raw:
		if not tid_str.is_valid_int():
			continue
		var tid: int = int(tid_str)
		if tid >= HERO_TYPE_ID_MAX:
			continue
		if hero_mgr.find_hero_by_tid(tid) != null:
			continue
		if get_stone_amount(tid, cm, hero_mgr) > 0:
			_insert_sorted_asc(list, tid)
	return list


static func _insert_sorted_asc(list: Array[int], v: int) -> void:
	list.append(v)
	var j: int = list.size() - 1
	while j > 0 and list[j] < list[j - 1]:
		var t: int = list[j]
		list[j] = list[j - 1]
		list[j - 1] = t
		j -= 1


static func order_miss_list_by_lack(list: Array[int], cm: Variant, hero_mgr: HeroManager) -> void:
	var i: int = 1
	while i < list.size():
		var j: int = i
		while j > 0:
			var pc: float = _lack_ratio(list[j], cm, hero_mgr)
			var ppc: float = _lack_ratio(list[j - 1], cm, hero_mgr)
			if pc > ppc:
				var t: int = list[j]
				list[j] = list[j - 1]
				list[j - 1] = t
			j -= 1
		i += 1


static func _lack_ratio(tid: int, cm: Variant, hero_mgr: HeroManager) -> float:
	var need: int = get_stone_need(tid, cm, hero_mgr)
	if need <= 0:
		return 0.0
	return float(get_stone_amount(tid, cm, hero_mgr)) / float(need)


# 元素 HeroInstance（已拥有，取真实值）或 miss dict（未拥有，level/stars/rank=0）。
static func order_heroes(list: Array) -> Array:
	var i: int = 1
	while i < list.size():
		var j: int = i
		while j > 0:
			var h: Dictionary = _hero_sort_key(list[j])
			var ph: Dictionary = _hero_sort_key(list[j - 1])
			var swap: bool = false
			if h["level"] > ph["level"]:
				swap = true
			elif h["level"] == ph["level"]:
				if h["stars"] > ph["stars"]:
					swap = true
				elif h["stars"] == ph["stars"] and h["rank"] > ph["rank"]:
					swap = true
			if swap:
				var t: Variant = list[j]
				list[j] = list[j - 1]
				list[j - 1] = t
			j -= 1
		i += 1
	return list


# 取排序键（HeroInstance 取真实值；miss dict 全 0，自然沉底）。
static func _hero_sort_key(v: Variant) -> Dictionary:
	if v is HeroInstance:
		var h: HeroInstance = v
		return {"level": h.level, "stars": h.stars, "rank": h.rank}
	return {"level": 0, "stars": 0, "rank": 0}


static func get_all_list(hero_mgr: HeroManager) -> Array:
	var list: Array = []
	for inst_id in hero_mgr.heroes:
		list.append(hero_mgr.heroes[inst_id])
	return order_heroes(list)


# 碎片足够的未拥有插到前面（index 累进，源 :848-849），碎片不足的加到末尾（源 :850-851）。
# 返 Array[Variant]（HeroInstance 或 {tid:int, miss:bool}）。
static func get_all_list_with_miss(cm: Variant, hero_mgr: HeroManager) -> Array:
	var al: Array = get_all_list(hero_mgr)
	var ml: Array[int] = get_miss_list(cm, hero_mgr)
	order_miss_list_by_lack(ml, cm, hero_mgr)
	var index: int = 0
	for tid in ml:
		var h: Dictionary = {"tid": tid, "miss": true}
		if check_stone_enough(tid, cm, hero_mgr):
			al.insert(index, h)
			index += 1
		else:
			al.append(h)
	return al


# 入参 all 是 get_all_list_with_miss 结果（元素 HeroInstance 或 miss dict）。
static func classify_by_pos(all: Array, cm: Variant) -> Dictionary:
	var front: Array = []
	var middle: Array = []
	var back: Array = []
	var raw: Dictionary = cm.get_raw_table(&"Unit")
	for v in all:
		var tid: int = entry_tid(v)
		var pos_type: String = String(raw.get(str(tid), {}).get(&"Position Type", ""))
		if pos_type.find(POS_FRONT) >= 0:
			front.append(v)
		elif pos_type.find(POS_MIDDLE) >= 0:
			middle.append(v)
		elif pos_type.find(POS_REAR) >= 0:
			back.append(v)
	return {"all": all, "front": front, "middle": middle, "back": back}


# heropackage 面板 tab 分类入口（源 getAllList :446 classify("handbook","position")）。
static func classify_handbook(cm: Variant, hero_mgr: HeroManager) -> Dictionary:
	var all: Array = get_all_list_with_miss(cm, hero_mgr)
	return classify_by_pos(all, cm)


# 取条目 tid（HeroInstance.tid 或 miss dict tid）。
static func entry_tid(v: Variant) -> int:
	if v is HeroInstance:
		return (v as HeroInstance).tid
	if v is Dictionary:
		return int((v as Dictionary).get("tid", 0))
	return 0


# 取条目 rank（HeroInstance.rank 或 miss=1）。
static func entry_rank(v: Variant) -> int:
	if v is HeroInstance:
		return (v as HeroInstance).rank
	return 1


# 越界（rank<1 或 >22）返 0，等价源 Lua table[index] 的 nil 被 `or 0` 兜底（readhero.lua:961）。
static func get_hero_star_by_rank(rank: int) -> int:
	if rank < 1 or rank >= HERO_STAR.size():
		return 0
	return HERO_STAR[rank]


static func get_hero_max_star_by_rank(rank: int) -> int:
	if rank < 1 or rank >= HERO_MAX_STAR.size():
		return 0
	return HERO_MAX_STAR[rank]


# 分段递进判定（rank<1 兜底白；rank==1 白；其余按上限递进），避免函数体裸数字 2/4/7/12（Logic 层 LINT001）。
static func get_hero_name_color_by_rank(rank: int) -> Color:
	if rank < 1:
		return NAME_COLOR_DEFAULT
	if rank == 1:
		return NAME_COLOR_WHITE
	if rank <= RANK_YELLOW_MAX:
		return NAME_COLOR_YELLOW
	if rank <= RANK_BLUE_MAX:
		return NAME_COLOR_BLUE
	if rank <= RANK_PURPLE_MAX:
		return NAME_COLOR_PURPLE
	if rank <= RANK_ORANGE_MAX:
		return NAME_COLOR_ORANGE
	return NAME_COLOR_RED
