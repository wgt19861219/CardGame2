class_name BattleUnitEquip
extends RefCounted

## 单位装备加载（Logic 层）— 照源 unit.lua:147-175 翻译（Phase 2.2续-F，2026-07-02）。
## 从 battle_unit.gd 拆出（≤300 行铁律；battle_unit.gd 已 401 行）。全静态，u 为 BattleUnit（duck-type：
##   info/rank/level/equips/config/proto/cm）。
## 两条互斥路径：A) estimate_max_rank → hero_equip 默认装备（bot/arena 英雄）；
##   B) not estimate_rank → proto._items 玩家真实装备。怪物 estimate_rank → equips=[]。
## equips 每项 = Equip 整行 + {level}（源 wraptable），rebuild:452-460 消费 equip[attr]/["+attr"]/["level"]。

const HERO_EQUIP_SLOT_COUNT: int = 6
const DEFAULT_EQUIP_EXP: float = 2000.0
const EQUIP_TABLE := &"Equip"
const HERO_EQUIP_TABLE := &"Hero_equip"
const LEVEL_REQ_FIELD := &"Level Requirement"
const EQUIP_ID_SUFFIX := " ID"


static func load_equips(u: Variant, cm: ConfigManager) -> void:
	u.equips = []
	if bool(u.config.get("estimate_max_rank", false)):
		_load_default_equips(u, cm)
	elif not bool(u.config.get("estimate_rank", false)):
		_load_player_equips(u, cm)
	# else（estimate_rank 怪物）：equips=[] 不加载


static func _load_default_equips(u: Variant, cm: ConfigManager) -> void:
	var unit_id: int = int(u.info.get("ID", u.tid))
	var items: Dictionary = _lookup_hero_equip(cm, unit_id, int(u.rank))
	if items.is_empty():
		return
	var i: int = 1
	while i <= HERO_EQUIP_SLOT_COUNT:
		var eid: int = int(items.get(StringName("Equip" + str(i) + EQUIP_ID_SUFFIX), 0))
		if eid > 0:
			var req_lv: int = cm.get_int(EQUIP_TABLE, eid, LEVEL_REQ_FIELD)
			if req_lv <= int(u.level):
				var equip_info: Dictionary = cm.get_entry(EQUIP_TABLE, eid)
				var elv: int = int(ReadequipData.get_equip_level(eid, DEFAULT_EQUIP_EXP, cm).get("level", 0))
				u.equips.append(_wrap_equip(equip_info, elv))
		i += 1


static func _load_player_equips(u: Variant, cm: ConfigManager) -> void:
	var items: Array = u.proto.get("_items", [])
	for item in items:
		var id: int = int(item.get("_item_id", 0))
		if id > 0:
			var equip_info: Dictionary = cm.get_entry(EQUIP_TABLE, id)
			var exp: float = float(item.get("_exp", 0.0))
			var elv: int = int(ReadequipData.get_equip_level(id, exp, cm).get("level", 0))
			u.equips.append(_wrap_equip(equip_info, elv))


static func _wrap_equip(equip_info: Dictionary, level: int) -> Dictionary:
	var wrapped: Dictionary = equip_info.duplicate()
	wrapped["level"] = level
	return wrapped


static func _lookup_hero_equip(cm: ConfigManager, unit_id: int, rank: int) -> Dictionary:
	var raw: Dictionary = cm.get_raw_table(HERO_EQUIP_TABLE)
	var unit_rows: Dictionary = raw.get(str(unit_id), {})
	return unit_rows.get(str(rank), {})
