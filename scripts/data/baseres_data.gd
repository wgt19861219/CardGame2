class_name BaseresData
extends RefCounted

## 装备属性显示数据（照源 ui/parameter/baseres.lua）。
## att_name 属性 key 列表（createAttList 遍历顺序）/ att_pre key→LSTR key 前缀 / att_suffix key→后缀。

const ATT_NAME: Array[String] = [
	"STR", "INT", "AGI", "HP", "AD", "AP", "ARM", "MR", "CRIT", "MCRIT",
	"HPS", "MPS", "DODG", "ARMP", "MRI", "LFS", "CDR", "HEAL", "HIT", "SKL", "SILR"
]

const ATT_PRE_LSTR: Dictionary = {
	"STR": "BASERES.STRENGTH_", "INT": "BASERES.INTELLIGENCE_", "AGI": "BASERES.AGILITY_",
	"HP": "BASERES.MAXIMUM_HP_", "AD": "BASERES.PHYSICAL_ATTACK_", "AP": "BASERES.MAGIC_STRENGTH_",
	"ARM": "BASERES.PHYSICAL_ARMOR_", "MR": "BASERES.MAGIC_RESISTANCE_",
	"CRIT": "BASERES.PHYSICAL_CRIT_", "MCRIT": "BASERES.MAGIC_CRIT_",
	"HPS": "BASERES.HP_REPLIES_", "MPS": "BASERES.ENERGY_RECOVERY_",
	"DODG": "BASERES.DODGE_", "ARMP": "BASERES.PHYSICAL_ARMOR_PENETRATION",
	"MRI": "BASERES.IGNORE_MAGIC_RESISTANCE", "LFS": "BASERES.VAMPIRE_LEVEL_",
	"CDR": "BASERES.REDUCE_ENERGY_CONSUMPTION", "HEAL": "BASERES.IMPROVE_THERAPEUTIC_SKILL_EFFECT",
	"HPR": "BASERES.HEAL_AFTER_EACH_BATTLE", "MPR": "BASERES.REPLENISH_ENERGY_AFTER_EACH_BATTLE",
	"HIT": "baseres.1.10.1.004", "SKL": "baseres.1.10.1.005", "SILR": "",
	"ALL_ATT": "BASERES.STRENGTH_INTELLIGENCE_AGILITY"
}

const ATT_SUFFIX: Dictionary = {
	"ARMP": "", "MRI": "", "CDR": "%", "HEAL": "%", "HPR": "", "MPR": "",
	"SKL": " ", "SILR": ""
}

const ENHANCE_LEVEL_LSTR: Array[String] = [
	"BASERES.COMMON_ENCHANT",
	"BASERES.SENIOR_ENCHANTING",
	"BASERES.EXPERT_ENCHANTING",
	"BASERES.GRAND_MASTER_ENCHANTING",
	"BASERES.LEGENDARY_ENCHANTING",
]


static func get_att_pre(key: String, cm: Variant) -> String:
	var lstr_key: String = String(ATT_PRE_LSTR.get(key, ""))
	if lstr_key.is_empty():
		return ""
	return String(cm.get_lstr(lstr_key))


static func get_att_suffix(key: String) -> String:
	return String(ATT_SUFFIX.get(key, ""))


# level 0→空串（由调用方走 EQUIPINFO.UNENCHANTED 分支）；越界返空串（源 `or ""` 容错）。
static func get_enhance_level_text(level: int, cm: Variant) -> String:
	if level <= 0 or level > ENHANCE_LEVEL_LSTR.size():
		return ""
	return String(cm.get_lstr(ENHANCE_LEVEL_LSTR[level - 1]))
