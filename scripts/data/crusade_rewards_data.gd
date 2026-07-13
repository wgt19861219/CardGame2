class_name CrusadeRewardsData
extends RefCounted

## 远征奖励数据（Data 层）— 照源 CrusadeRewards 表多级查表（2026-07-02）。
## 结构：CrusadeRewards[stage][wave][vip_valid(0/1)] = {Amount N, ID N, Type N, Gold Ratio, Reset Times, VIP Valid, Wave ID}。
## 奖励类型：CrusadePoint（远征币）/ ChestBox（宝箱）/ Item 等。

const SLOT_COUNT: int = 5  # 奖励槽 Amount/ID/Type 1-5
const TABLE_NAME := &"CrusadeRewards"


## 源多级查表 CrusadeRewards[stage][wave][vip_valid(0/1)]。
static func get_reward_info(cm: ConfigManager, stage: int, wave: int, vip_valid: bool) -> Dictionary:
	var raw: Dictionary = cm.get_raw_table(TABLE_NAME)
	var vip_key: String = "1" if vip_valid else "0"
	return raw.get(str(stage), {}).get(str(wave), {}).get(vip_key, {})


## Gold Ratio（金币系数）。
static func get_gold_ratio(cm: ConfigManager, stage: int, wave: int, vip_valid: bool) -> float:
	return float(get_reward_info(cm, stage, wave, vip_valid).get("Gold Ratio", 0.0))


## 奖励槽列表（每项 {type, id, amount}），跳过 amount<=0。
static func get_reward_slots(cm: ConfigManager, stage: int, wave: int, vip_valid: bool) -> Array[Dictionary]:
	var info: Dictionary = get_reward_info(cm, stage, wave, vip_valid)
	var slots: Array[Dictionary] = []
	var i: int = 1
	while i <= SLOT_COUNT:
		var amount: int = int(info.get("Amount " + str(i), 0))
		if amount > 0:
			slots.append({
				"type": String(info.get("Type " + str(i), "")),
				"id": int(info.get("ID " + str(i), 0)),
				"amount": amount,
			})
		i += 1
	return slots
