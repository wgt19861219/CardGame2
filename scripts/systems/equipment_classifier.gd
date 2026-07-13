class_name EquipmentClassifier
extends RefCounted

## 装备/物品/碎片分类（Logic 层）— 照源 readequip.classify（readequip.lua:416-480）。
## 适配本项目双容器：PlayerData.items（装备/物品，type=1）→ prop 表；
## HeroManager.fragments（碎片物品 id，type=2）→ fragment 表。
## 输出 both = {prop: {all/equip/scroll/stone/consume}, fragment: {all/equip/scroll/hero}}。
## 每 cell: {id, makeId, amount, category, type, [needAmount]}。
## 单机化：isEquipOpen 无 ban（源 ban_item 黑名单依赖 global_config，本项目不接）。

# ── Equip.json Category 取值（源 LSTR key，与配置字段对齐）──
const CAT_REEL: String = "EQUIP.REEL"                # 卷轴
const CAT_CONSUMABLES: String = "EQUIP.CONSUMABLES"  # 消耗品
const CAT_SOUL_STONE: String = "EQUIP.SOUL_STONE"    # 魂石
const CAT_HERO: String = "BATTLE.HERO"               # 英雄（碎片产物是英雄时按 itemType 设）
const CAT_FRAGMENT: String = "EQUIP.FRAGMENT"        # 碎片（本项目 fragments 容器独立，items 不含）

# type: 1=prop（普通物品，items 容器）, 2=fragment（碎片，fragments 容器）— 源 list[k].type
const TYPE_PROP: int = 1
const TYPE_FRAGMENT: int = 2

# itemType 阈值（源 player.lua itemType：id<100 hero / id<600 equip）
const ITEM_TYPE_HERO_MAX: int = 100


# 照源 classify（readequip.lua:416-480）：返 {prop, fragment} 两张分类表。
# items 按 Equip[id].Category 分 prop；fragments 反查 Fragment 表得 makeId/needAmount/category 分 fragment。
static func classify(pd: PlayerData, cm: Variant) -> Dictionary:
	var prop: Dictionary = _empty_prop()
	var fragment: Dictionary = _empty_fragment()
	# type=1 prop：遍历 items（装备/物品）
	for id in pd.items:
		var amount: int = int(pd.items[id])
		if amount <= 0:   # 源 :462 v.amount > 0 过滤
			continue
		if not _is_equip_open(int(id), cm):
			continue
		var category: String = _value(int(id), &"Category", cm)
		if category == CAT_FRAGMENT:   # 源 type=2；本项目 fragments 容器独立，items 不该有碎片（防御）
			continue
		var cell: Dictionary = {
			"id": int(id), "makeId": int(id), "amount": amount,
			"category": category, "type": TYPE_PROP,
		}
		_push_to_tab(prop, _prop_tab_key(category), cell)
	# type=2 fragment：遍历 fragments，反查 Fragment 表
	var frag_table: Dictionary = cm.get_raw_table(&"Fragment")
	var owned_frags: Dictionary = pd.hero_manager.fragments
	for frag_id in owned_frags:
		var amount: int = int(owned_frags[frag_id])
		if amount <= 0:
			continue
		if not _is_equip_open(int(frag_id), cm):
			continue
		var recipe: Dictionary = _find_fragment_recipe(int(frag_id), frag_table, cm)
		var cell: Dictionary = {
			"id": int(frag_id),
			"makeId": int(recipe.get("makeId", frag_id)),
			"amount": amount,
			"category": String(recipe.get("category", _value(int(frag_id), &"Category", cm))),
			"type": TYPE_FRAGMENT,
			"needAmount": int(recipe.get("needAmount", 0)),
		}
		_push_to_tab(fragment, _fragment_tab_key(String(cell["category"])), cell)
	# orderFragmentList 照源（readequip.lua:397-415）——源 bug：pen=true 恒真 → not pen 恒假 → 永不交换，
	# 排序实际不生效（保持持有顺序）。本项目照源不实现排序，注释标注源 bug。
	return {"prop": prop, "fragment": fragment}


# prop 表 tab 骨架（源 :452-456）。
static func _empty_prop() -> Dictionary:
	return {"all": [], "equip": [], "scroll": [], "stone": [], "consume": []}


# fragment 表 tab 骨架（源 :458-462）。注意 fragment 表无 stone/consume（碎片产物不经这俩 category）。
static func _empty_fragment() -> Dictionary:
	return {"all": [], "equip": [], "scroll": [], "hero": []}


# 源 isEquipOpen（readequip.lua:11-18）：ban_item 黑名单查询。单机化无 global_config，恒 true（留接口）。
static func _is_equip_open(_id: int, _cm: Variant) -> bool:
	return true


# 源 value(id, name)（readequip.lua:39-43）：Equip[id][name] 字段查询。
static func _value(id: int, name: String, cm: Variant) -> String:
	var row: Dictionary = cm.get_raw_table(&"Equip").get(str(id), {})
	return String(row.get(name, ""))


# 源 itemType(id)（player.lua:1206-1217）：id<100 hero / id<600 equip。
static func _item_type(id: int) -> String:
	if id < ITEM_TYPE_HERO_MAX:
		return "hero"
	return "equip"


# prop category → tab key（源 :463-471）。PARTS/SYNTHETICS/其他归 equip。
static func _prop_tab_key(category: String) -> String:
	if category == CAT_REEL:
		return "scroll"
	if category == CAT_CONSUMABLES:
		return "consume"
	if category == CAT_SOUL_STONE:
		return "stone"
	return "equip"


# fragment category → tab key（源同 :463-471，但 fragment 表无 stone/consume 分支 → 全归 equip）。
# 碎片产物 category 经 itemType 重设（BATTLE.HERO 或 Equip[makeId].Category）。
static func _fragment_tab_key(category: String) -> String:
	if category == CAT_HERO:
		return "hero"
	if category == CAT_REEL:
		return "scroll"
	return "equip"


# 插入 all + 具体 tab（源 :472-474 both[v.type].all + 对应子 tab）。
static func _push_to_tab(table: Dictionary, tab_key: String, cell: Dictionary) -> void:
	(table[tab_key] as Array).append(cell)
	(table["all"] as Array).append(cell)


# 反查 Fragment 表：Fragment[tid]["Fragment ID"]==frag_id（源 :425-440 cinfo 遍历）。
# 返 {makeId: tid, needAmount: Fragment Count, category: 按 itemType(tid)}。无匹配返 {}。
static func _find_fragment_recipe(frag_id: int, frag_table: Dictionary, cm: Variant) -> Dictionary:
	for tid_str in frag_table:
		var row: Dictionary = frag_table[tid_str]
		if int(row.get(&"Fragment ID", 0)) != frag_id:
			continue
		var make_id: int = int(tid_str)
		var category: String = CAT_HERO if _item_type(make_id) == "hero" else _value(make_id, &"Category", cm)
		return {
			"makeId": make_id,
			"needAmount": int(row.get(&"Fragment Count", 0)),
			"category": category,
		}
	return {}


# ── handbook 图鉴 12 tag 属性分类（照源 readequip.classifyEquip :481-537）──
# Category 过滤值（源 :500）：仅 PARTS（部件）/SYNTHETICS（合成物）入图鉴（卷轴/消耗品/魂石排除）。
const CAT_PARTS: String = "EQUIP.PARTS"
const CAT_SYNTHETICS: String = "EQUIP.SYNTHETICS"
# 12 属性 tag（源 equip 表 keys :482-495，ALL 单独）。CRIT 兼并 MCRIT（源 :502-515）。
const HANDBOOK_TAGS: Array[String] = ["STR", "AGI", "INT", "HP", "AD", "AP", "ARM", "CRIT", "HPS", "MPS", "HEAL"]


# 照源 classifyEquip :481-537：返 {ALL,STR,AGI,INT,HP,AD,AP,ARM,CRIT,HPS,MPS,HEAL: [{id,name,lr}]}。
# 装备按非零基础属性归入对应 tag（CRIT 兼并 MCRIT），Category∈{PARTS,SYNTHETICS} 且非 Hide，
# Display Level≤满级（canDisplay :20-22）。每 tag 按 {lr,id} 升序（orderEquips :317）。
# name 存 LSTR key（源 v.Name），View 层 get_lstr 转中文显示。
static func classify_equip(cm: Variant, team_level_max: int) -> Dictionary:
	var tabs: Dictionary = _empty_handbook_tabs()
	var raw: Dictionary = cm.get_raw_table(&"Equip")
	for id_str in raw:
		var key_str := String(id_str)
		if not key_str.is_valid_int():   # 源 :497 type(k)=="number"；目标 raw key 全 String（含 name 反索引），仅数字 String 是 id
			continue
		var id: int = int(key_str)
		if not _is_equip_open(id, cm):
			continue
		var row: Dictionary = raw[id_str]
		var lr: int = int(row.get(&"Display Level", 1))
		if lr > team_level_max:   # 源 canDisplay :20-22 (lv or 1) <= team_level_max
			continue
		var category: String = String(row.get(&"Category", ""))
		if category != CAT_PARTS and category != CAT_SYNTHETICS:
			continue
		if bool(row.get(&"Hide", false)):   # 源 :499 isHide
			continue
		var name_lstr: String = String(row.get(&"Name", ""))
		var cell: Dictionary = {"id": id, "name": name_lstr, "lr": lr}
		for tk in HANDBOOK_TAGS:
			var push: bool = false
			if tk == "CRIT":
				push = int(row.get(&"CRIT", 0)) > 0 or int(row.get(&"MCRIT", 0)) > 0
			else:
				push = int(row.get(tk, 0)) > 0
			if push:
				(tabs[tk] as Array).append(cell)
		(tabs["ALL"] as Array).append(cell)
	for tk in ["ALL"] + HANDBOOK_TAGS:
		_order_equips_lr_id(tabs[tk])
	return tabs


static func _empty_handbook_tabs() -> Dictionary:
	var d: Dictionary = {"ALL": []}
	for tk in HANDBOOK_TAGS:
		d[tk] = []
	return d


# 源 orderEquips :317-345（多字段 {"lr","id"} 升序插入排序）。sort_custom + method ref 等价。
static func _order_equips_lr_id(list: Array) -> void:
	list.sort_custom(_less_lr_id)


static func _less_lr_id(a: Dictionary, b: Dictionary) -> bool:
	if int(a["lr"]) != int(b["lr"]):
		return int(a["lr"]) < int(b["lr"])
	return int(a["id"]) < int(b["id"])
