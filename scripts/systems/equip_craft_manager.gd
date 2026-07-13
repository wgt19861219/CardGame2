class_name EquipCraftManager
extends RefCounted

## 装备强化/合成 Logic 层（照源 ui/equipstrengthen.lua + local_server.lua equip_synthesis）。
## 从 PlayerData 抽出（治 LINT005 行数 + 装备 Logic 独立成层）。操作 pd 状态（items/hero_manager/diamond）。
## PlayerData 保留薄代理（enhance_equip/enhance_equip_to_max/synthesize_equip）保持调用方不变 + 照源 ed.player 入口。


# 装备强化（照源 ui/equipstrengthen.lua:495-616 + local_server.lua:1436-1443）。
# 普通强化：材料 Enhance Value×count 累积 exp → Enhancement[Quality].Unit Price×exp 金币
# → 扣金币+材料 → hero.equip_exp[slot] 累积（min 上限）。materials: {item_id(int): count(int)}。
# 失败：槽空/品质 1 ml=0/满级/材料不足/无经验/金币不足。
static func enhance_equip(pd: PlayerData, inst_id: int, slot: int, materials: Dictionary) -> bool:
	var hero: HeroInstance = pd.hero_manager.get_hero(inst_id)
	if hero == null or slot < 0 or slot >= hero.equip_slots.size():
		return false
	var item_id: int = int(hero.equip_slots[slot])
	if item_id <= 0:
		return false
	var le_info: Dictionary = ReadequipData.get_equip_level_exp(item_id, pd.cm)
	var ml: int = int(le_info["ml"])
	if ml <= 0:
		return false   # 源 quality 1 Max Level=0 不可强化
	var max_exp: float = 0.0
	for v in le_info["le"]:
		max_exp += float(v)   # 源 local_server:1429-1432 maxExp=Σ Price_i
	var cur_exp: float = float(hero.equip_exp[slot])
	if cur_exp >= max_exp:
		return false   # 已满级
	var equip_table: Dictionary = pd.cm.get_raw_table(&"Equip")
	var add_exp: float = 0.0
	for mat_id in materials:
		var need: int = int(materials[mat_id])
		if need <= 0 or int(pd.items.get(int(mat_id), 0)) < need:
			return false   # 材料不足
		add_exp += float(equip_table.get(str(int(mat_id)), {}).get("Enhance Value", 0)) * need
	if add_exp <= 0.0:
		return false   # 源 :577 moneyCost<=0 doSpeak NO_MATERIAL_ADDED
	var quality: int = int(equip_table.get(str(item_id), {}).get("Quality", 0))
	var unit_price: float = float(pd.cm.get_raw_table(&"Enhancement").get(str(quality), {}).get("Unit Price", 0))
	var cost: int = int(unit_price * add_exp)
	if pd.hero_manager.gold < cost:
		return false
	pd.hero_manager.add_money(-cost)
	for mat_id in materials:
		var need: int = int(materials[mat_id])
		if need > 0:
			pd.items[int(mat_id)] = int(pd.items[int(mat_id)]) - need
	hero.equip_exp[slot] = min(cur_exp + add_exp, max_exp)
	# 源 record.lua refreshCommonRecord("enhanceLevelup") → 日常任务 EnhanceLevelUp
	if pd.task_manager != null:
		pd.task_manager.record_by_type(pd.cm, "EnhanceLevelUp")
	return true


# 装备钻石一键满级（照源 ui/equipstrengthen.lua:701-722 upFastStren op_type=2）。
# checkMaxLevel 守卫 → rmbCost=get_fast_stren_cost → spend_diamond → equip_exp[slot]=max_exp。
# 失败：槽空/品质 1 ml=0/满级/钻石不足（源 showHandyDialog toRecharge 充值，单机化返 false）。
static func enhance_equip_to_max(pd: PlayerData, inst_id: int, slot: int) -> bool:
	var hero: HeroInstance = pd.hero_manager.get_hero(inst_id)
	if hero == null or slot < 0 or slot >= hero.equip_slots.size():
		return false
	var item_id: int = int(hero.equip_slots[slot])
	if item_id <= 0:
		return false
	var le_info: Dictionary = ReadequipData.get_equip_level_exp(item_id, pd.cm)
	var ml: int = int(le_info["ml"])
	if ml <= 0:
		return false   # 源 quality 1 Max Level=0 不可强化
	var max_exp: float = 0.0
	for v in le_info["le"]:
		max_exp += float(v)   # 满级总经验（Σ le）
	var cur_exp: float = float(hero.equip_exp[slot])
	if cur_exp >= max_exp:
		return false   # 已满级（源 checkMaxLevel）
	var cost: int = ReadequipData.get_fast_stren_cost(item_id, cur_exp, pd.cm)
	if cost <= 0 or not pd.spend_diamond(cost):
		return false   # 钻石不足（源 _rmb < rmbCost）
	hero.equip_exp[slot] = max_exp
	return true


# 装备合成（照源 local_server:1059-1115 equip_synthesis + collectCraftChain:1026-1057）。
# 递归收集合成链（自动合成可合成前置材料）+ 扣金币+基础材料 + 产出进 items 背包（不绑英雄槽）。
# 单机化：源 net 信任 UI computeCanCraft 预检，本项目 Logic 是唯一入口，craft_recurse 返 ok 对齐预检。
static func synthesize_equip(pd: PlayerData, target_id: int) -> bool:
	var ect: Dictionary = pd.cm.get_raw_table(&"Equipcraft")
	if not ect.has(str(target_id)):
		return false
	var consume: Dictionary = {}
	var allocated: Dictionary = {}
	var rec: Dictionary = craft_recurse(pd, target_id, ect, consume, allocated)
	if not bool(rec["ok"]):
		return false   # 材料（含递归前置）不足
	var total_cost: int = int(rec["cost"])
	if pd.hero_manager.gold < total_cost:
		return false
	pd.hero_manager.add_money(-total_cost)
	for cid in consume:
		pd.items[int(cid)] = int(pd.items[int(cid)]) - int(consume[cid])
	pd.add_item(target_id, 1)
	return true


# 合成链递归（照源 local_server:1032-1053 recurse）：累加 Expense + 遍历 Component，
# 先从 items 取（allocated 防重复计数），不足且 cid 可合成（Components>0）则递归补足。
# 返 {cost, ok}——ok=false 表示某 Component 背包不足且不可递归合成（对齐源 UI computeCanCraft 预检）。
static func craft_recurse(pd: PlayerData, id: int, ect: Dictionary, consume: Dictionary, allocated: Dictionary) -> Dictionary:
	var row: Dictionary = ect.get(str(id), {})
	var components: int = int(row.get("Components", 0))
	if components < 1:
		return {"cost": 0, "ok": true}   # 叶子节点（无配方）默认 ok
	var cost: int = int(row.get("Expense", 0))
	var ok: bool = true
	for i in range(1, components + 1):
		var cid: int = int(row.get("Component" + str(i), 0))
		var need: int = max(int(row.get("Component" + str(i) + " Count", 1)), 1)
		var available: int = max(int(pd.items.get(cid, 0)) - int(allocated.get(cid, 0)), 0)
		var use: int = min(available, need)
		if use > 0:
			consume[cid] = int(consume.get(cid, 0)) + use
			allocated[cid] = int(allocated.get(cid, 0)) + use
		if use < need:
			if int(ect.get(str(cid), {}).get("Components", 0)) > 0:
				var sub: Dictionary = craft_recurse(pd, cid, ect, consume, allocated)
				cost += int(sub["cost"])
				if not bool(sub["ok"]):
					ok = false
			else:
				ok = false   # 背包不足且不可递归合成
	return {"cost": cost, "ok": ok}
