class_name EquipData
extends RefCounted

## 装备静态数据（Data 层）：从 Equip 表加载的核心字段。
## 2.2a 只基础（GS/价格/品质/等级要求）；属性加成（STR/AD 等）应用、强化等级在 2.2b+。

var item_id: int = 0
var quality: int = 1            # 品质 1-5
var gs: float = 0.0             # 战力值（Equip.GS）
var buy_price: int = 0
var sell_price: int = 0         # 出售价（≈Buy 50%）
var level_requirement: int = 1

static func from_config(cm: ConfigManager, eid: int) -> EquipData:
	var data := EquipData.new()
	data.item_id = eid
	data.quality = cm.get_int(&"Equip", eid, &"Quality")
	data.gs = cm.get_float(&"Equip", eid, &"GS")
	data.buy_price = cm.get_int(&"Equip", eid, &"Buy Price")
	data.sell_price = cm.get_int(&"Equip", eid, &"Sell Price")
	data.level_requirement = cm.get_int(&"Equip", eid, &"Level Requirement")
	return data
