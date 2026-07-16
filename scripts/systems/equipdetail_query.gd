class_name EquipdetailQuery
extends RefCounted

## 装备详情查询（Logic 层）— 照源 equipdetail.lua getEquipData :85-134 + createDetail 获取途径段 :234-294 翻译。
## 查合成配方（Equipcraft Component1-4）/ 可装备英雄（Hero_equip Equip1-6 ID）/ 获取途径（Equip.Drop 1-3 + How To Get）。
## 单机化简化：源 hero_list 过滤依赖 equip_qunty[getStoneid]+display_equipale_hero_rank（拥有魂石+rank 限），
## 本项目查 HeroManager.heroes（已召唤英雄）中能装备的，更严但无 rank 表依赖。差异注释。

const DROP_SLOTS: int = 3   # 源 Drop 1-3 固定 3 字段（createDetail :235 `for i = 1, 3`）
const COMPONENT_SLOTS: int = 4   # 源 Component1-4（getEquipData :89 `for i = 1, 4`）
const EQUIP_SLOTS: int = 6   # 源 Equip1-6 ID（getEquipData :110 `for j = 1, 6`）
const DEFAULT_MAX_CHAPTER: int = 13   # 源 ed.GameConfig.MaxChapter fallback（GameConfig 表无值时）


# 查装备的可合成列表 + 可装备英雄 + 获取途径（源 getEquipData + createDetail getWay 段）。
static func query(equip_id: int, cm: Variant, pd: PlayerData) -> Dictionary:
	return {
		"equip_list": _equip_compose_list(equip_id, cm),
		"hero_list": _hero_equip_list(equip_id, cm, pd),
		"get_way": _get_way_list(equip_id, cm),
		"how_to_get": _how_to_get_text(equip_id, cm),
	}


# 源 getEquipData :87-101：Equipcraft 中 Component1-4==equip_id 的产物装备（合成该装备的上级装备）。
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
			continue   # 源 :90 not getDataTable("equip")[k].Hide
		result.append({"id": product_id, "name": String(product_row.get("Name", str(product_id)))})
	return result


# 源 getEquipData :102-133：Hero_equip 中 Equip1-6 ID==equip_id 的英雄。
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
				break   # 源 :126 break（每英雄只取首个匹配 rank）
			index += 1
	return result


# 源 createDetail :234-268：Equip.Drop 1-3 → Stage 名（普通/精英），过滤 Chapter>MaxChapter（Hide Stage）。
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
			continue   # 源 :239 Hide Stage > MaxChapter
		var name: String = String(stage_row.get("Stage Name", str(drop_id)))
		# P1-12：照源 :250-252 elite 加"精英"前缀 + :245 getStageIcon 关卡图标（StageRes 移植）
		var is_elite: bool = StageAccount.stage_type(drop_id) == "elite"
		if is_elite:
			name = "精英 " + name
		result.append({"id": drop_id, "name": name, "chapter": chapter, "elite": is_elite, "res": StageRes.get_stage_icon(drop_id, cm)})
	return result


# 源 createDetail :270-288：Equip["How To Get"] 文本（金色阴影标签）。
static func _how_to_get_text(equip_id: int, cm: Variant) -> String:
	return String(cm.get_raw_table(&"Equip").get(str(equip_id), {}).get("How To Get", ""))


# 源 ed.GameConfig.MaxChapter（Drop 过滤阈值）。
static func _max_chapter(cm: Variant) -> int:
	var gc: Dictionary = cm.get_raw_table(&"GameConfig")
	if gc.has("MaxChapter"):
		return int(gc["MaxChapter"])
	return DEFAULT_MAX_CHAPTER


# === 英雄背包 plusSign/canDealTag 查询（源 ui/heroitem.lua:218-248）===
# 服务 HeroPackageItem._create_equips 的空槽 + 号显示判定。

# 源 heroitem.lua:219-223 — 空 slot 该 rank 应穿装备 id：hero_equip[tid][rank]["Equip{slot} ID"]。
# slot 1-6（源 Lua i=1..6）；无配置或越界返 0（视为无 + 号提示）。
static func get_slot_expected_equip(hero: HeroInstance, slot: int, cm: Variant) -> int:
	if hero == null or slot < 1 or slot > EQUIP_SLOTS:
		return 0
	var rank_row: Dictionary = cm.get_raw_table(&"Hero_equip").get(str(hero.tid), {}).get(str(hero.rank), {})
	return int(rank_row.get("Equip" + str(slot) + " ID", 0))


# 源 tools.lua:573-595 isEquipCraftable（简化版，与 equip_craft_panel._is_craftable 对齐）：
# 已持有 (pd.items[eid]>0) → true（源 :576 has 优先，直接可穿）；
# 否则配方 Components>0 → true（源递归判材料，本项目简化仅判配方存在，差异注释）。
# pd=null 时跳过持有检查（View 未持 PlayerData 引用时降级）。
static func is_equip_craftable(eid: int, cm: Variant, pd: PlayerData) -> bool:
	if eid <= 0:
		return false
	if pd != null and int(pd.items.get(eid, 0)) > 0:
		return true
	return int(EquipcraftData.get_recipe(eid, cm).get("Components", 0)) > 0


# 源 tools.lua:805-809 canWearEquip — hero.level >= Equip[eid]["Level Requirement"]。
# 返 {can, hlv, elv}（源 Lua 多返回值，本项目 Dictionary）。
static func can_wear_equip(hero: HeroInstance, eid: int, cm: Variant) -> Dictionary:
	if hero == null or eid <= 0:
		return {"can": false, "hlv": 0, "elv": 0}
	var elv: int = int(cm.get_raw_table(&"Equip").get(str(eid), {}).get(&"Level Requirement", 0))
	return {"can": hero.level >= elv, "hlv": hero.level, "elv": elv}
