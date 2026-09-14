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
		return false
	var max_exp: float = 0.0
	for v in le_info["le"]:
		max_exp += float(v)
	var cur_exp: float = float(hero.equip_exp[slot])
	if cur_exp >= max_exp:
		return false   # 已满级
	var equip_table: Dictionary = pd.cm.get_raw_table(&"Equip")
	var add_exp: float = 0.0
	for mat_id in materials:
		var need: int = int(materials[mat_id])
		if need <= 0 or int(pd.items.get(int(mat_id), 0)) < need:
			return false   # 材料不足
		var mat_equip: Dictionary = equip_table.get(str(int(mat_id)), {})
		add_exp += float(mat_equip.get("Enhance Value", mat_equip.get("Exp", 0))) * need
	if add_exp <= 0.0:
		return false
	var quality: int = int(equip_table.get(str(item_id), {}).get("Quality", 0))
	var unit_price: float = float(pd.cm.get_raw_table(&"Enhancement").get(str(quality), {}).get("Unit Price", 0))
	# 玩家放超量材料时 cost 必须按截断后经验算，否则多扣金币（满级前 add_exp > max_exp-cur_exp 的情况）。
	var eff_exp: float = min(add_exp, max_exp - cur_exp)
	var cost: int = int(unit_price * eff_exp)
	if pd.hero_manager.gold < cost:
		return false
	pd.hero_manager.add_money(-cost)
	for mat_id in materials:
		var need: int = int(materials[mat_id])
		if need > 0:
			pd.items[int(mat_id)] = int(pd.items[int(mat_id)]) - need
	hero.equip_exp[slot] = min(cur_exp + add_exp, max_exp)
	pd.hero_manager.recalc_hero_gs(hero)   # 强化改变单位属性 → 重算战力（源 main.lua:1236 落地后 recalcHeroGs）
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
		return false
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
	pd.hero_manager.recalc_hero_gs(hero)   # 同上：一键满级改变单位属性 → 重算战力
	return true


# 进阶前自动穿戴（照源 herodetail/window.lua:706-747 doClickUpgrade needWear 分支补译，
# 2026-09-05 漏译根修：用户报"装备齐全点进阶仍提示穿齐装备"）。
# 源语义：逐槽 getHeroEquipState——isEquiped 跳过；canWear（背包持有 + Equip Level Requirement 达标）
# 收集进 needWear；其余任一（canCraft/notHave/cannotwear）→ toast"穿齐装备"+return（整体拒绝，零消耗）。
# 全就绪 → 逐槽 consumeEquip(eid,1)（纯扣背包）+ hero:equip(slot)，再继续发进阶。
# 2026-09-14 受控偏离（用户拍板"加自动合成"）：canCraft 槽（配方存在+等级达标）且材料递归齐备
# +金币足 → 自动合成再穿（源要求手动点槽合成，此处增强使绿+角标 eti=wear 语义与进阶行为一致；
# 材料或金币不足仍整单拒绝零消耗）。
# 返值：>=0 = 实穿槽数（可继续进阶）；-1 = 存在无法就绪的槽（调用方弹"穿齐装备"）。
static func autowear_for_upgrade(pd: PlayerData, inst_id: int) -> int:
	var hm: HeroManager = pd.hero_manager
	var hero: HeroInstance = hm.get_hero(inst_id)
	if hero == null:
		return -1
	var ect: Dictionary = pd.cm.get_raw_table(&"Equipcraft")
	var wear_slots: Array[int] = []    # 背包已可穿的槽
	var craft_slots: Array[int] = []   # 需先合成的槽
	var planned: Dictionary = {}       # item_id -> 跨槽计划消耗总数（craft_recurse 的 allocated 联动）
	var planned_cost: int = 0          # 跨槽合成金币预算
	# 第一遍：逐槽定性 + 零消耗预检（任一槽不可就绪 → 整单拒绝，材料/金币/槽全不动）
	for slot in range(HeroManager.EQUIP_SLOT_COUNT):
		var ett: String = String(EquipdetailQuery.get_hero_equip_state(hero, slot, pd.cm, pd)["ett"])
		if ett == "isEquiped":
			continue
		var eid: int = EquipdetailQuery.get_slot_expected_equip(hero, slot + 1, pd.cm)
		if ett == "canWear":
			if int(pd.items.get(eid, 0)) - int(planned.get(eid, 0)) < 1:
				return -1   # 跨槽同 id 争用超量（预算联动）
			planned[eid] = int(planned.get(eid, 0)) + 1
			wear_slots.append(slot)
			continue
		if ett == "canCraft":
			# 照源 isEquipCraftable 递归语义预检材料（craft_recurse 只读 pd；allocated=planned
			# 使合成材料消耗与直穿预算共用账本，防执行时序性超扣）
			var rec: Dictionary = craft_recurse(pd, eid, ect, {}, planned)
			if not bool(rec["ok"]) or hm.gold - planned_cost < int(rec["cost"]):
				return -1
			planned_cost += int(rec["cost"])
			craft_slots.append(slot)
			continue
		return -1   # notHave/cannotwear/ignore
	# 第二遍：全部可就绪才执行——先合成（真扣材料+金币，产出进背包），再统一穿戴
	for slot in craft_slots:
		var eid: int = EquipdetailQuery.get_slot_expected_equip(hero, slot + 1, pd.cm)
		if not synthesize_equip(pd, eid):
			return -1   # 防御：预检过理论必成
	var all_slots: Array[int] = craft_slots.duplicate()
	all_slots.append_array(wear_slots)
	for slot in all_slots:
		var eid: int = EquipdetailQuery.get_slot_expected_equip(hero, slot + 1, pd.cm)
		pd.items[eid] = int(pd.items.get(eid, 0)) - 1
		hm.wear_equip(inst_id, slot)
	return all_slots.size()


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
