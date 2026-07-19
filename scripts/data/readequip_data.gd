class_name ReadequipData
extends RefCounted

## 装备数据查询（Data 层）— 照源 readequip.lua 翻译（Phase 5.2 起步，2026-07-02）。
## get_hero_item：装备槽 item_id 查询（getEquipLevel 链基础，源 readequip.getHeroItem）。
## HeroInstance.equip_slots: Array[int] item_id（0=空）。

const STREN_HEALTH_RATIO: int = 19  # 源 parameter.lua:39 stren_health_ratio（getHeroEquiphp 用）


# hero.equip_exp(Array[float]) → exp_map(slot→exp) 供 get_hero_equip_gs/hp（桥接 HeroInstance 与查询）。
static func get_exp_map_from_hero(hero: HeroInstance) -> Dictionary:
	var m: Dictionary = {}
	if hero == null:
		return m
	for i in range(hero.equip_exp.size()):
		m[i] = float(hero.equip_exp[i])
	return m


# 源 readequip.getHeroItem(hid, slot, hero) — hero.equip_slots[slot] item_id（0=空/无效）。
static func get_hero_item(hero: HeroInstance, slot: int) -> int:
	if hero == null or slot < 0 or slot >= hero.equip_slots.size():
		return 0
	return int(hero.equip_slots[slot])


# 源 equip 表 "+GS"（getHeroEquipgs sum(equip["+GS"] * level) 用）。
static func get_equip_gs(item_id: int, cm: Variant) -> float:
	var row: Dictionary = cm.get_raw_table("Equip").get(str(item_id), {})
	return float(row.get("+GS", 0.0))


# 源 equip 表属性（+STR/+HP/+AD/+AGI 等，getHeroEquiphp/属性面板用）。
static func get_equip_attrib(item_id: int, attrib: String, cm: Variant) -> float:
	var row: Dictionary = cm.get_raw_table("Equip").get(str(item_id), {})
	return float(row.get(attrib, 0.0))


# 源 readequip.getAttList :48-59：遍历 att_name，Equip 表基础属性 !=0。
static func get_att_list(item_id: int, cm: Variant) -> Dictionary:
	var att: Dictionary = {}
	for key in BaseresData.ATT_NAME:
		var val: float = get_equip_attrib(item_id, key, cm)
		if val != 0.0:
			att[key] = val
	return att


# 源 readequip.getAddAttList :61-72：Equip 表 "+key" × level >0。
static func get_add_att_list(item_id: int, level: int, cm: Variant) -> Dictionary:
	var att: Dictionary = {}
	for key in BaseresData.ATT_NAME:
		var val: float = get_equip_attrib(item_id, "+" + key, cm) * float(level)
		if val > 0.0:
			att[key] = val
	return att


# 源 readequip.value :39-42：Equip 表字段值（Name/Description/Category/Comment 等）。
static func value(item_id: int, field: String, cm: Variant) -> Variant:
	var row: Dictionary = cm.get_raw_table("Equip").get(str(item_id), {})
	return row.get(field, null)


# 源 readequip.getDescription :74-130 formatList：STR==INT==AGI → ALL_ATT 合并（三属性相等显示"全属性"）。
static func _format_list(list: Dictionary) -> void:
	var s: float = float(list.get("STR", 0))
	var i: float = float(list.get("INT", 0))
	var a: float = float(list.get("AGI", 0))
	if s == i and s == a:
		list["ALL_ATT"] = s
		list.erase("STR")
		list.erase("INT")
		list.erase("AGI")


# 源 readequip.getDescription :74-130：组合属性描述行（attList/addList/sufList）。
# 返 [{att, add, suffix}, ...]：att="力量 +100", add="+5"（强化加成）, suffix="%"。供 equipboard att_bg 显示。
static func get_description(item_id: int, level: int, cm: Variant) -> Array:
	var att: Dictionary = get_att_list(item_id, cm)
	var add: Dictionary = get_add_att_list(item_id, level, cm)
	_format_list(att)
	_format_list(add)
	var rows: Array = []
	var all_att: float = float(att.get("ALL_ATT", 0))
	if all_att > 0.0:   # 源 :96-107 ALL_ATT 优先（三属性相等合并）
		var cn: String = BaseresData.get_att_pre("ALL_ATT", cm)
		var add_all: float = float(add.get("ALL_ATT", 0))
		rows.append({"att": cn + " +" + str(int(all_att)), "add": (" +" + str(int(add_all))) if add_all > 0 else "", "suffix": ""})
	for key in BaseresData.ATT_NAME:   # 源 :108-128 单属性
		var v: float = float(att.get(key, 0))
		if v == 0.0:
			continue
		var cn: String = BaseresData.get_att_pre(key, cm)
		var element: String = ""
		if cn != "":
			element = cn + (" +" if v > 0 else " ") + str(int(v))
		elif v > 0 or float(add.get(key, 0)) > 0:
			element = str(int(v))
		var add_v: float = float(add.get(key, 0))
		if add_v != 0.0:
			rows.append({"att": element, "add": " +" + str(int(add_v)), "suffix": BaseresData.get_att_suffix(key)})
		else:
			rows.append({"att": element + BaseresData.get_att_suffix(key), "add": "", "suffix": ""})
	return rows


# 源 readequip.getEquipLevelExp :244-260 — Enhancement[Equip.Quality] → le(Price_i 累积) + ml(Max Level)。
static func get_equip_level_exp(item_id: int, cm: Variant) -> Dictionary:
	var equip_row: Dictionary = cm.get_raw_table("Equip").get(str(item_id), {})
	var quality: int = int(equip_row.get("Quality", 0))
	if quality <= 0:
		return {"le": [], "ml": 0}
	var erow: Dictionary = cm.get_raw_table("Enhancement").get(str(quality), {})
	var ml: int = int(erow.get("Max Level", 0))
	var le: Array = []
	for i in range(1, ml + 1):
		le.append(float(erow.get("Price " + str(i), 0.0)))
	return {"le": le, "ml": ml}


# 源 readequip.getEquipLevel :262-278 — exp 累积算 level（exp < le 累积 → level i；末位→ml）。
# 返 {level, exp_in_level, max_level, level_total}（源 return level, exp-te, ml, le[i]）。
static func get_equip_level(item_id: int, exp: float, cm: Variant) -> Dictionary:
	var info: Dictionary = get_equip_level_exp(item_id, cm)
	var le: Array = info.get("le", [])
	var ml: int = int(info.get("ml", 0))
	if le.is_empty():
		return {"level": 0, "exp_in_level": 0.0, "max_level": 0, "level_total": 0.0}
	var te: float = 0.0
	for i in range(le.size()):
		var pte: float = te + float(le[i])
		if exp < pte:
			return {"level": i, "exp_in_level": exp - te, "max_level": ml, "level_total": float(le[i])}
		te = pte
	var last_total: float = float(le[ml - 1]) if ml > 0 else 0.0
	return {"level": ml, "exp_in_level": last_total, "max_level": ml, "level_total": last_total}


# 源 equipstrengthen.getFastStrenCost :1294-1304 — 钻石一键满级成本（Data 层工具，UI 显示 + Logic 扣钻石共用）。
# up=Enhancement[Quality]["One-Click Unit Price"]；当前级剩余(me-e) + 后续完整级 Σ le。
# 源 1-based le[k]=第k级；本项目 0-based le[k]=第k+1级 → 后续遍历 range(level+1, ml) 等价源 for i=l+2,ml。
static func get_fast_stren_cost(item_id: int, exp: float, cm: Variant) -> int:
	var equip_row: Dictionary = cm.get_raw_table("Equip").get(str(item_id), {})
	var quality: int = int(equip_row.get("Quality", 0))
	if quality <= 0:
		return 0
	var erow: Dictionary = cm.get_raw_table("Enhancement").get(str(quality), {})
	var up: float = float(erow.get("One-Click Unit Price", 0))
	var lvl_info: Dictionary = get_equip_level(item_id, exp, cm)
	var ml: int = int(lvl_info["max_level"])
	if ml <= 0:
		return 0
	var level: int = int(lvl_info["level"])
	var e: float = float(lvl_info["exp_in_level"])
	var me: float = float(lvl_info["level_total"])
	var cost: float = up * (me - e)
	var le: Array = get_equip_level_exp(item_id, cm)["le"]
	for k in range(level + 1, ml):   # 源 for i=l+2,ml（1-based）→ 0-based le[level+1..ml-1]
		cost += up * float(le[k])
	return int(cost)


# 源 readequip.getHeroEquipgs :50-65 — sum(equip[item]["+GS"] * getEquipLevel(item, exp))。
# exp_map: slot→exp（未来装备强化 exp 系统填；默认空 exp=0 → level 0 未强化）。
# 注：源 getHeroEquipgs 算"强化 gs"（+GS × 强化等级），装备基础 gs 在 attribs（rebuild）。
static func get_hero_equip_gs(hero: HeroInstance, cm: Variant, exp_map: Dictionary = {}) -> float:
	if hero == null:
		return 0.0
	var total: float = 0.0
	for slot in range(hero.equip_slots.size()):
		var item_id: int = get_hero_item(hero, slot)
		if item_id <= 0:
			continue
		var exp: float = float(exp_map.get(slot, 0.0))
		var level: int = int(get_equip_level(item_id, exp, cm)["level"])
		total += get_equip_gs(item_id, cm) * float(level)
	return total


# 源 readequip.getHeroEquiphp :66-84 — sum(ratio*equip["+STR"]*level + equip["+HP"]*level)。
# ratio = STREN_HEALTH_RATIO(19)。exp_map 同 get_hero_equip_gs（slot→exp）。
static func get_hero_equip_hp(hero: HeroInstance, cm: Variant, exp_map: Dictionary = {}) -> float:
	if hero == null:
		return 0.0
	var total: float = 0.0
	for slot in range(hero.equip_slots.size()):
		var item_id: int = get_hero_item(hero, slot)
		if item_id <= 0:
			continue
		var exp: float = float(exp_map.get(slot, 0.0))
		var level: int = int(get_equip_level(item_id, exp, cm)["level"])
		var str_v: float = get_equip_attrib(item_id, "+STR", cm)
		var hp_v: float = get_equip_attrib(item_id, "+HP", cm)
		total += float(STREN_HEALTH_RATIO) * str_v * float(level) + hp_v * float(level)
	return total
