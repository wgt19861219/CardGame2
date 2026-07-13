class_name HandbookManager
extends RefCounted

## 图鉴（Step 3.7）：收集进度（已获得英雄/装备记录）。

var collected_heroes: Array[int] = []
var collected_equips: Array[int] = []

func record_hero(tid: int) -> void:
	if not collected_heroes.has(tid):
		collected_heroes.append(tid)

func record_equip(item_id: int) -> void:
	if not collected_equips.has(item_id):
		collected_equips.append(item_id)

func hero_count() -> int:
	return collected_heroes.size()

func equip_count() -> int:
	return collected_equips.size()

func has_hero(tid: int) -> bool:
	return collected_heroes.has(tid)


func has_equip(item_id: int) -> bool:
	return collected_equips.has(item_id)


## 存档序列化。
func to_dict() -> Dictionary:
	return {
		"collected_heroes": collected_heroes.duplicate(),
		"collected_equips": collected_equips.duplicate(),
	}


static func from_dict(data: Dictionary) -> HandbookManager:
	var mgr := HandbookManager.new()
	var h_arr: Array = data.get("collected_heroes", [])
	for tid in h_arr:
		mgr.collected_heroes.append(int(tid))
	var e_arr: Array = data.get("collected_equips", [])
	for eid in e_arr:
		mgr.collected_equips.append(int(eid))
	return mgr
