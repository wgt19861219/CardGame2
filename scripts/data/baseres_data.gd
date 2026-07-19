class_name BaseresData
extends RefCounted

## 装备属性显示数据（照源 ui/parameter/baseres.lua）。
## att_name 属性 key 列表（createAttList 遍历顺序）/ att_pre key→LSTR key 前缀 / att_suffix key→后缀。

# 源 baseres.lua:5-27 att_name（属性 key 列表）
const ATT_NAME: Array[String] = [
	"STR", "INT", "AGI", "HP", "AD", "AP", "ARM", "MR", "CRIT", "MCRIT",
	"HPS", "MPS", "DODG", "ARMP", "MRI", "LFS", "CDR", "HEAL", "HIT", "SKL", "SILR"
]

# 源 baseres.lua:80-104 att_pre（key → LSTR key，显示时 cm.get_lstr 解析）
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

# 源 baseres.lua:105-114 att_suffix（key → 后缀；SILR 源 LSTR baseres.1.10.1.006 本项目无 → 降级空）
const ATT_SUFFIX: Dictionary = {
	"ARMP": "", "MRI": "", "CDR": "%", "HEAL": "%", "HPR": "", "MPR": "",
	"SKL": " ", "SILR": ""
}

# 源 baseres.lua:115-121 enhance_level_res（附魔等级 → LSTR key，1-based index：1=普通/2=高级/3=专家级/4=宗师级/5=传说）。
# 源 initBar:1051 / createExpBar:1143 / getLevelText:1330 用 res.enhance_level_res[level] 取等级文字。
const ENHANCE_LEVEL_LSTR: Array[String] = [
	"BASERES.COMMON_ENCHANT",
	"BASERES.SENIOR_ENCHANTING",
	"BASERES.EXPERT_ENCHANTING",
	"BASERES.GRAND_MASTER_ENCHANTING",
	"BASERES.LEGENDARY_ENCHANTING",
]


# 源 baseres att_pre：key → 中文前缀（get_lstr 解析 LSTR key）。
static func get_att_pre(key: String, cm: Variant) -> String:
	var lstr_key: String = String(ATT_PRE_LSTR.get(key, ""))
	if lstr_key.is_empty():
		return ""
	return String(cm.get_lstr(lstr_key))


# 源 baseres att_suffix：key → 后缀字面。
static func get_att_suffix(key: String) -> String:
	return String(ATT_SUFFIX.get(key, ""))


# 源 baseres enhance_level_res[level]：附魔等级文字（普通/高级/专家级/宗师级/传说）。
# 源 getLevelText:1330 `res.enhance_level_res[level] or ""`；initBar/createExpBar 同查表。
# level 0→空串（由调用方走 EQUIPINFO.UNENCHANTED 分支）；越界返空串（源 `or ""` 容错）。
static func get_enhance_level_text(level: int, cm: Variant) -> String:
	if level <= 0 or level > ENHANCE_LEVEL_LSTR.size():
		return ""
	return String(cm.get_lstr(ENHANCE_LEVEL_LSTR[level - 1]))
