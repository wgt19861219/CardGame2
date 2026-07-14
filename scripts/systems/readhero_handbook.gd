class_name ReadheroHandbook
extends RefCounted

## 英雄图鉴列表与碎片查询（Logic 层）— 照源 readhero.lua 翻译（P0-1 整行卡片重建）。
## 服务 heropackage 图鉴面板：未召唤英雄列表、碎片进度、按位置分类。
## 不依赖 Node/Control（headless 可单测）。查 ConfigManager（Unit/Fragment/HeroStars）+ HeroManager（heroes/fragments）。
## 坐标/资源在 View 层 HeroPackageItem；本类纯数据查询。

const FALLBACK_STONE_ID: int = 335            # 源 getStoneid :646 fid or 335
const HERO_TYPE_ID_MAX: int = 100             # 源 player.lua:1472 unitType id<100="hero"
const POS_FRONT: String = "Front"             # 源 classifyByPos find T(LSTR("UNIT.FRONT_ROW"))
const POS_MIDDLE: String = "Middle"
const POS_REAR: String = "Rear"


# 源 getStoneid :642-648 — Fragment[tid]["Fragment Id"]，缺失 fallback 335。
static func get_stone_id(tid: int, cm: Variant) -> int:
	var fid: Variant = cm.get_raw_table(&"Fragment").get(str(tid), {}).get(&"Fragment ID")
	if fid == null:
		return FALLBACK_STONE_ID
	return int(fid)


# 源 getStoneAmount :649-653 — player.equip_qunty[stone_id]；本项目 hero_mgr.fragments 容器。
static func get_stone_amount(tid: int, cm: Variant, hero_mgr: HeroManager) -> int:
	var sid: int = get_stone_id(tid, cm)
	return int(hero_mgr.fragments.get(sid, 0))


# 源 getStoneNeed :654-671 — 未拥有：HeroStars[Initial Stars]["Summon Fragments"]；
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


# 源 getSummonCost :678-683 — HeroStars[Initial Stars]["Summon Price"]。
static func get_summon_cost(tid: int, cm: Variant) -> int:
	var init_star: int = ReadheroData.get_hero_init_stars(tid, cm)
	return int(cm.get_raw_table(&"HeroStars").get(str(init_star), {}).get(&"Summon Price", 0))


# 源 checkStoneEnough :684-693 — amount >= need。
static func check_stone_enough(tid: int, cm: Variant, hero_mgr: HeroManager) -> bool:
	return get_stone_amount(tid, cm, hero_mgr) >= get_stone_need(tid, cm, hero_mgr)


# 源 getMissList :694-715 — Unit 表遍历 unitType=="hero"(id<100) 且未拥有 且碎片>0，升序插入排序。
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


# 源 :704-712 插入排序升序（list[j] < list[j-1] 则向上交换）。
static func _insert_sorted_asc(list: Array[int], v: int) -> void:
	list.append(v)
	var j: int = list.size() - 1
	while j > 0 and list[j] < list[j - 1]:
		var t: int = list[j]
		list[j] = list[j - 1]
		list[j - 1] = t
		j -= 1


# 源 orderMissListByLack :716-731 — 按 amount/need 比例降序插入排序（比例高=越接近召唤，排前）。
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


# 源 orderHeroFunction (tools.lua:819-847) — level desc → stars desc → rank desc 插入排序。
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


# 源 getAllList :830-838 — orderHeroes() 拷贝（player.heroes → orderHeroFunction）。
static func get_all_list(hero_mgr: HeroManager) -> Array:
	var list: Array = []
	for inst_id in hero_mgr.heroes:
		list.append(hero_mgr.heroes[inst_id])
	return order_heroes(list)


# 源 getAllListWithMiss :839-856 — 已拥有排序 + 未拥有插序：
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


# 源 classifyByPos :884-901 — Unit["Position Type"] 分前/中/后。
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


# 源 classify("handbook","position") :920-938 — getAllListWithMiss + classifyByPos。
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
