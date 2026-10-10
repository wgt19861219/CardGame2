extends GutTest
## 23 阶装备掉落全链可达性守卫（2026-10-08 ch203 冰封王座三部曲配套）。
##
## 背景：Hero_equip rank1-23 全部引用装备中，8 件 DL85 基件（442/445/448/451/454/457/
## 460/463）的合成链断点（组件←60 碎片）在 ch203 前零来源（源 Axmol 同样断供）。
## ch203 三本（毒蛇神殿/海加尔山/冰冠堡垒 50022-50030×4 档）掉组件+碎片+万能碎片接通。
## 本测试把「全链可达」口径固化为守卫：直接掉落 ∨ 合成（全部组件可达）∨ 碎片可达，
## 防未来掉落表改动静默重新断链。

const RANK_MIN := 1
const RANK_MAX := 23
const SLOT_MAX := 6
const STAGE_LOOT_SLOTS := 7
const DUNGEON_LOOT_SLOTS := 4
const RAID_LOOT_SLOTS := 10
const CRAFT_SLOTS := 4
const CH203_BASE_MIN := 50022
const CH203_BASE_MAX := 50030
const DIFF_TIERS := [0, 1000, 2000, 3000]  # base + diff2/3/4 偏移
const CH203_GROUPS := [50008, 50009, 50010]
const DL85_BASES := [442, 445, 448, 451, 454, 457, 460, 463]
const DL85_COMPONENTS := [443, 446, 449, 452, 455, 458, 461, 464]
const DL85_FRAGMENTS := [444, 447, 450, 453, 456, 459, 462, 465]
const UNIVERSAL_FRAGMENT := 335
const LICH_KING_STAGE := 50030


func _make_cm() -> ConfigManager:
	var cm := ConfigManager.new()
	cm.load_all()
	return cm


func _collect_sourced(cm: ConfigManager) -> Dictionary:
	"""全部掉落来源并集：Stage.UI reward 1-7 + StageDungeon.Raid Bonus 1-4 + Raid.Special Loot 1-10。"""
	var sourced := {}
	var stage: Dictionary = cm.get_raw_table(&"Stage")
	for row in stage.values():
		for i in range(1, STAGE_LOOT_SLOTS + 1):
			var loot: int = int(row.get("UI reward" + str(i), 0))
			if loot != 0:
				sourced[loot] = true
	var dungeon: Dictionary = cm.get_raw_table(&"StageDungeon")
	for row in dungeon.values():
		for i in range(1, DUNGEON_LOOT_SLOTS + 1):
			var loot: int = int(row.get("Raid Bonus ID " + str(i), 0))
			if loot != 0:
				sourced[loot] = true
	var raid: Dictionary = cm.get_raw_table(&"Raid")
	for row in raid.values():
		for i in range(1, RAID_LOOT_SLOTS + 1):
			var loot: int = int(row.get("Special Loot " + str(i) + " ID", 0))
			if loot != 0:
				sourced[loot] = true
	return sourced


func _is_reachable(item_id: int, cm: ConfigManager, sourced: Dictionary, seen: Dictionary) -> bool:
	"""直接掉落 ∨ 合成（全部组件可达，all 语义）∨ 碎片/万能碎片可达。"""
	if sourced.has(item_id):
		return true
	if seen.has(item_id):
		return false
	seen[item_id] = true
	# 合成路径：Equipcraft 全组件递归可达（all——任一组件断裂即整链断裂）
	var craft: Dictionary = cm.get_raw_table(&"Equipcraft")
	for row in craft.values():
		if int(row.get("Item_ID", 0)) != item_id:
			continue
		var comps: Array = []
		for i in range(1, CRAFT_SLOTS + 1):
			var comp: int = int(row.get("Component" + str(i), 0))
			if comp != 0:
				comps.append(comp)
		if comps.is_empty():
			continue
		var all_ok := true
		for comp in comps:
			if not _is_reachable(comp, cm, sourced, seen.duplicate()):
				all_ok = false
				break
		if all_ok:
			return true
	# 碎片路径：专属碎片与万能碎片均有来源（60 专属 / 30 万能合成，Fragment 表）
	var frag: Dictionary = cm.get_raw_table(&"Fragment")
	for row in frag.values():
		if int(row.get("Item ID", 0)) != item_id:
			continue
		var frag_id: int = int(row.get("Fragment ID", 0))
		var universal: int = int(row.get("Universal Fragment ID", 0))
		var frag_ok: bool = frag_id == 0 or sourced.has(frag_id)
		var universal_ok: bool = universal == 0 or sourced.has(universal)
		if frag_ok and universal_ok:
			return true
	return false


func test_ch203_dungeon_segment_complete() -> void:
	var cm := _make_cm()
	var dungeon: Dictionary = cm.get_raw_table(&"StageDungeon")
	var battle: Dictionary = cm.get_raw_table(&"Battle")
	for base in range(CH203_BASE_MIN, CH203_BASE_MAX + 1):
		for offset in DIFF_TIERS:
			var sid: int = base + offset
			assert_true(dungeon.has(str(sid)), "StageDungeon 应含 ch203 关 %d" % sid)
			assert_true(battle.has(str(sid)), "Battle 应含 ch203 关波次 %d" % sid)


func test_ch203_groups_config() -> void:
	var cm := _make_cm()
	var groups: Dictionary = cm.get_raw_table(&"ActStageGroupDungeon")
	for gid in CH203_GROUPS:
		assert_true(groups.has(str(gid)), "地下城组 %d 应存在" % gid)
		var row: Dictionary = groups.get(str(gid), {})
		assert_eq(int(row.get("DailyLimit", 0)), 1, "组 %d 每日 1 次（照 ch202 高级本）" % gid)
		var stages: Array = row.get("Stages", [])
		assert_eq(stages.size(), 8, "组 %d Stages 8 槽" % gid)
		for i in range(0, 3):
			assert_eq(int(stages[i]), CH203_BASE_MIN + CH203_GROUPS.find(gid) * 3 + i,
				"组 %d 第 %d 关编号连续" % [gid, i])


func test_ch203_sourcing_covers_dl85_chain() -> void:
	var cm := _make_cm()
	var sourced := _collect_sourced(cm)
	for comp in DL85_COMPONENTS:
		assert_true(sourced.has(comp), "DL85 组件 %d 应有直接掉落来源" % comp)
	for frag in DL85_FRAGMENTS:
		assert_true(sourced.has(frag), "DL85 碎片 %d 应有直接掉落来源" % frag)
	assert_true(sourced.has(UNIVERSAL_FRAGMENT), "万能碎片 %d 应有来源（巫妖王关）" % UNIVERSAL_FRAGMENT)
	var dungeon: Dictionary = cm.get_raw_table(&"StageDungeon")
	var lich: Dictionary = dungeon.get(str(LICH_KING_STAGE), {})
	assert_eq(int(lich.get("Raid Bonus ID 1", 0)), UNIVERSAL_FRAGMENT, "巫妖王关槽 1 = 万能碎片")
	assert_eq(int(lich.get("Raid Bonus ID 2", 0)), UNIVERSAL_FRAGMENT, "巫妖王关槽 2 = 万能碎片")


func test_rank1_23_equipment_all_reachable() -> void:
	var cm := _make_cm()
	var sourced := _collect_sourced(cm)
	var hero_equip: Dictionary = cm.get_raw_table(&"Hero_equip")
	var dead := {}
	for uid in hero_equip.values():
		var ranks: Dictionary = uid
		for rk in range(RANK_MIN, RANK_MAX + 1):
			var row: Dictionary = ranks.get(str(rk), {})
			for slot in range(1, SLOT_MAX + 1):
				var eid: int = int(row.get("Equip%d ID" % slot, 0))
				if eid == 0 or dead.has(eid):
					continue
				if not _is_reachable(eid, cm, sourced, {}):
					dead[eid] = rk
	var dead_msgs: Array[String] = []
	for eid in dead:
		dead_msgs.append("rank%d 引用的装备 %d 全链不可达（掉落/合成/碎片均断）" % [dead[eid], eid])
	assert_eq(dead.size(), 0, "rank1-23 全部引用装备应全链可达（ch203 前 8 件 DL85 基件断供）：%s" % ", ".join(dead_msgs))


func test_dl85_bases_craft_chains_resolve() -> void:
	"""8 件 DL85 基件合成链逐件可达（单独点名，断链时失败信息直接指向具体装备名）。"""
	var cm := _make_cm()
	var sourced := _collect_sourced(cm)
	for base in DL85_BASES:
		assert_true(_is_reachable(base, cm, sourced, {}),
			"DL85 基件 %d 合成链应可达" % base)
