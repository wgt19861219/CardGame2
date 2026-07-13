class_name VipData
extends RefCounted

## VIP 数据查询（Data 层）— 照源 VIP 表翻译（Phase 5.4 续，2026-07-02）。


static func get_vip_info(level: int, cm: Variant) -> Dictionary:
	return cm.get_raw_table("VIP").get(str(level), {})


static func get_vip_field(level: int, field: String, cm: Variant) -> Variant:
	return get_vip_info(level, cm).get(field, null)
