class_name VipData
extends RefCounted

## VIP 数据查询（Data 层）— 照源 VIP 表翻译（Phase 5.4 续，2026-07-02）。
## 含 area unlock/show vip 查询（照源 playerlimit.lua:88-105，P1-C5 magic 门控）。

const SHOW_VIP_OFFSET: int = 2


static func get_vip_info(level: int, cm: Variant) -> Dictionary:
	return cm.get_raw_table("VIP").get(str(level), {})


static func get_vip_field(level: int, field: String, cm: Variant) -> Variant:
	return get_vip_info(level, cm).get(field, null)


# 找不到返回 index（=max+1），调用方按 ulv > vip 判未解锁。
static func get_area_unlock_vip(key: String, cm: Variant) -> int:
	var vip_table: Dictionary = cm.get_raw_table("VIP")
	var index: int = 0
	while vip_table.has(str(index)):
		if bool(vip_table[str(index)].get(key, false)):
			return index
		index += 1
	return index


# 未达 unlock-2 → 隐藏；达 unlock-2 → 显示（灰显）；达 unlock → 可用。
static func get_area_show_vip(key: String, cm: Variant) -> int:
	return maxi(get_area_unlock_vip(key, cm) - SHOW_VIP_OFFSET, 0)

