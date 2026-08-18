class_name EquipdetailQuery
extends RefCounted

## 装备详情查询（Logic 层）— 照源 equipdetail.lua getEquipData :85-134 + createDetail 获取途径段 :234-294 翻译。
## 查合成配方（Equipcraft Component1-4）/ 可装备英雄（Hero_equip Equip1-6 ID）/ 获取途径（Equip.Drop 1-3 + How To Get）。
## 单机化简化：源 hero_list 过滤依赖 equip_qunty[getStoneid]+display_equipale_hero_rank（拥有魂石+rank 限），
## 本项目查 HeroManager.heroes（已召唤英雄）中能装备的，更严但无 rank 表依赖。差异注释。

const DROP_SLOTS: int = 3
const COMPONENT_SLOTS: int = 4
const EQUIP_SLOTS: int = 6
const DEFAULT_MAX_CHAPTER: int = 13


# 查装备的可合成列表 + 可装备英雄 + 获取途径（源 getEquipData + createDetail getWay 段）。
static func query(equip_id: int, cm: Variant, pd: PlayerData) -> Dictionary:
	return {
		"equip_list": _equip_compose_list(equip_id, cm),
		"hero_list": _hero_equip_list(equip_id, cm, pd),
		"get_way": _get_way_list(equip_id, cm),
		"how_to_get": _how_to_get_text(equip_id, cm),
	}


static func _equip_compose_list(equip_id: int, cm: Variant) -> Array:
	var result: Array = []
	var craft: Dictionary = cm.get_raw_table(&"Equipcraft")
	var equip: Dictionary = cm.get_raw_table(&"Equip")
	for tid_str in craft:
		var row: Dictionary = craft[tid_str]
		var matched: bool = false
		for i in range(1, COMPONENT_SLOTS + 1):
			if int(row.get("Component" + str(i), 0)) == equip_id:
				matched = true
				break
		if not matched:
			continue
		var product_id: int = int(tid_str)
		if product_id == equip_id:
			continue
		var product_row: Dictionary = equip.get(str(product_id), {})
		if bool(product_row.get("Hide", false)):
			continue
		result.append({"id": product_id, "name": String(product_row.get("Name", str(product_id)))})
	return result


# 单机化：源过滤 equip_qunty[getStoneid(k)]>0 + index<=display_equipale_hero_rank（拥有魂石+rank 限）；
# 本项目简化为已召唤英雄（HeroManager.heroes），无 rank 表依赖。源含拥有魂石可召唤的，本项目仅已召唤。
static func _hero_equip_list(equip_id: int, cm: Variant, pd: PlayerData) -> Array:
	var result: Array = []
	var hero_equip: Dictionary = cm.get_raw_table(&"Hero_equip")
	var unit: Dictionary = cm.get_raw_table(&"Unit")
	for tid_str in hero_equip:
		var tid: int = int(tid_str)
		if not pd.hero_manager.heroes.has(tid):
			continue   # 单机化：仅已召唤英雄
		var ranks: Dictionary = hero_equip[tid_str]
		var index: int = 1
		while ranks.has(str(index)):
			var rank_row: Dictionary = ranks[str(index)]
			var matched: bool = false
			for j in range(1, EQUIP_SLOTS + 1):
				if int(rank_row.get("Equip" + str(j) + " ID", 0)) == equip_id:
					matched = true
					break
			if matched:
				result.append({"id": tid, "rank": index, "name": String(unit.get(str(tid), {}).get("Display Name", str(tid)))})
				break
			index += 1
	return result


static func _get_way_list(equip_id: int, cm: Variant) -> Array:
	var result: Array = []
	var equip_row: Dictionary = cm.get_raw_table(&"Equip").get(str(equip_id), {})
	var stage: Dictionary = cm.get_raw_table(&"Stage")
	var max_chapter: int = _max_chapter(cm)
	for i in range(1, DROP_SLOTS + 1):
		var drop_id: int = int(equip_row.get("Drop " + str(i), 0))
		if drop_id <= 0:
			continue
		var stage_row: Dictionary = stage.get(str(drop_id), {})
		var chapter: int = int(stage_row.get("Chapter ID", 0))
		if chapter > max_chapter:
			continue
		var name: String = String(stage_row.get("Stage Name", str(drop_id)))
		# P1-12：照源 :250-252 elite 加"精英"前缀 + :245 getStageIcon 关卡图标（StageRes 移植）
		var is_elite: bool = StageAccount.stage_type(drop_id) == "elite"
		if is_elite:
			name = "精英 " + name
		result.append({"id": drop_id, "name": name, "chapter": chapter, "elite": is_elite, "res": StageRes.get_stage_icon(drop_id, cm)})
	return result


static func _how_to_get_text(equip_id: int, cm: Variant) -> String:
	return String(cm.get_raw_table(&"Equip").get(str(equip_id), {}).get("How To Get", ""))


static func _max_chapter(cm: Variant) -> int:
	var gc: Dictionary = cm.get_raw_table(&"GameConfig")
	if gc.has("MaxChapter"):
		return int(gc["MaxChapter"])
	return DEFAULT_MAX_CHAPTER


# === 英雄背包 plusSign/canDealTag 查询（源 ui/heroitem.lua:218-248）===
# 服务 HeroPackageItem._create_equips 的空槽 + 号显示判定。

# slot 1-6（源 Lua i=1..6）；无配置或越界返 0（视为无 + 号提示）。
static func get_slot_expected_equip(hero: HeroInstance, slot: int, cm: Variant) -> int:
	if hero == null or slot < 1 or slot > EQUIP_SLOTS:
		return 0
	var rank_row: Dictionary = cm.get_raw_table(&"Hero_equip").get(str(hero.tid), {}).get(str(hero.rank), {})
	return int(rank_row.get("Equip" + str(slot) + " ID", 0))


# 已持有 (pd.items[eid]>0) → true（源 :576 has 优先，直接可穿）；
# 否则配方 Components>0 → true（源递归判材料，本项目简化仅判配方存在，差异注释）。
# pd=null 时跳过持有检查（View 未持 PlayerData 引用时降级）。
static func is_equip_craftable(eid: int, cm: Variant, pd: PlayerData) -> bool:
	if eid <= 0:
		return false
	if pd != null and int(pd.items.get(eid, 0)) > 0:
		return true
	return int(EquipcraftData.get_recipe(eid, cm).get("Components", 0)) > 0


# 返 {can, hlv, elv}（源 Lua 多返回值，本项目 Dictionary）。
static func can_wear_equip(hero: HeroInstance, eid: int, cm: Variant) -> Dictionary:
	if hero == null or eid <= 0:
		return {"can": false, "hlv": 0, "elv": 0}
	var elv: int = int(cm.get_raw_table(&"Equip").get(str(eid), {}).get(&"Level Requirement", 0))
	return {"can": hero.level >= elv, "hlv": hero.level, "elv": elv}


# 快捷栏 heroPackage 红点的单英雄单槽判定（源 readhero.lua:734-750 checkEquipableProp
# 内层条件 eid>0 and not hasEquipment and isEquipCraftable and canWearEquip 的等价收口；
# framework.lua checkHeroPackageTag 是其全英雄聚合）。与 get_hero_equip_state 共用判据：
# eti=="wear" 含"已持有可穿"(canWear) 与"可合成可穿"(canCraft+wear) 两支，
# 已穿戴(isEquiped)/未解锁/不可穿/不可合成均 false。slot 0-based。
# 2026-08-18：快捷栏聚合与英雄卡片红点共用本函数（同一判定拆粒度，勿复制两份）。
static func is_slot_ready_to_wear(hero: HeroInstance, slot: int, cm: Variant, pd: PlayerData) -> bool:
	return String(get_hero_equip_state(hero, slot, cm, pd)["eti"]) == "wear"


# 英雄装备槽状态判定（照源 herodetail/controller.lua:207-233 getHeroEquipState）。
# 服务 HeroDetailEquipSlots 状态角标（源 createEquipTag:1051-1061 etires[eti]）。
# 复用 get_slot_expected_equip / is_equip_craftable / can_wear_equip，零新建依赖。
# slot 是 0-based（适配 hero.equip_slots[slot]）；内部 get_slot_expected_equip 转 1-based。
#
# 角标规则（源 etires 映射：wear=绿+ herodetail-equipadd / cannotwear=黄+ herodetail_icon_plus_yellow）：
#   - eid==0（未解锁）/ ceid>0（已穿戴）→ 无角标
#   - 有配方未装，按"可穿戴 + 可合成 + 持有"三维判定：
#     · 持有>0 + 可穿 → 绿+（canWear）
#     · 持有>0 + 不可穿 → 黄+（cannotwear）
#     · 持有=0 + 可合成 + 可穿 → 绿+（canCraft+wear）
#     · 持有=0 + 可合成 + 不可穿 → 黄+（canCraft+cannotwear）
#     · 持有=0 + 不可合成 → 无角标（notHave，源不画）
# 注：can_wear_equip 判 Level Requirement（hero.level >= equip 的等级要求）。
static func get_hero_equip_state(hero: HeroInstance, slot: int, cm: Variant, pd: PlayerData) -> Dictionary:
	if hero == null:
		return {"ett": "ignore", "eti": ""}
	var eid: int = get_slot_expected_equip(hero, slot + 1, cm)
	var ceid: int = int(hero.equip_slots[slot]) if slot >= 0 and slot < hero.equip_slots.size() else 0
	if eid == 0:
		return {"ett": "ignore", "eti": ""}   # 未解锁槽：无角标
	if ceid > 0:
		return {"ett": "isEquiped", "eti": ""}   # 已穿戴：无角标
	# 有配方未装（ceid==0 and eid>0）
	var ea: int = int(pd.items.get(eid, 0)) if pd != null else 0
	var can_wear: bool = can_wear_equip(hero, eid, cm)["can"]
	if ea == 0:
		# 未持有：看可合成
		if is_equip_craftable(eid, cm, pd):
			return {"ett": "canCraft", "eti": "wear" if can_wear else "cannotwear"}
		return {"ett": "notHave", "eti": ""}   # 没持有+不可合成：源不画角标
	# 已持有：看可穿戴
	return {"ett": ("canWear" if can_wear else "cannotwear"), "eti": ("wear" if can_wear else "cannotwear")}


