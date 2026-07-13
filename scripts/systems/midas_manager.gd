class_name MidasManager
extends RefCounted

## 炼金（照源 local_server.lua:1849-1898 midas handler）：钻石→金币批量兑换。
## 成本 GradientPrice[累计次数].Midas（梯度递增）+ 产出 floor(PlayerLevel[level].Midas Money × Midas[idx].Yield)。
## P0-忠实-7 修正：照源 :1868-1883 按 Prob 1..4 加权抽样暴击档位（×1/×2/×3/×10），非只用 Yield 1。
## 钻石不足 totalCost → {ok:false}（源 :1887 空 acquire）。源无每日次数限制（旧版 DAILY_LIMIT=5 是魔改，删）。
## midas_times 累计决定 costIdx（梯度档位）；本项目 MidasManager 不由 GameData 持，会话内有效（持久化待集成）。

const DEFAULT_MIDAS_MONEY: int = 5000   # 源 :1876 PlayerLevel.Midas Money 缺失默认
const DEFAULT_YIELD: float = 1.0        # 源 :1874 Midas."Yield 1" 缺失默认
const REWARD_TYPE_MONEY: int = 1        # 源 :1880 _type=1（金币）
const RATIO_COUNT: int = 4              # 源 Midas 表 Prob/Yield 1..4（4 档暴击）

var config: ConfigManager
var midas_times: int = 0   # 累计兑换次数（源 player.getMidasTimes，决定 GradientPrice/Midas costIdx）


func _init(cm: ConfigManager) -> void:
	config = cm


## 源 :1868-1898 批量兑换 times 次：返 {ok, acquired:[{type,money,ratio}], cost}。
## 暴击：照源 :1880-1882 按 Midas.Prob 1..4 加权抽样 type（1/2/3/4），money = base × Yield[type]。
## ratio 字段供 View 播放暴击动画（源 _type 1=无/2=crip2/3=crip3/4=crip10）。
func exchange(player: PlayerData, times: int) -> Dictionary:
	var player_level: int = player.team_level
	var acquired: Array = []
	var total_cost: int = 0
	var i: int = 1
	while i <= times:
		var cost_idx: int = midas_times + i
		total_cost += int(config.get_raw_table(&"GradientPrice").get(str(cost_idx), {}).get(&"Midas", 0))
		var midas_row: Dictionary = config.get_raw_table(&"Midas").get(str(cost_idx), {})
		var ratio: int = _roll_ratio(midas_row)  # 源 :1880 按 Prob 1..4 抽样
		var yield_rate: float = float(midas_row.get(&"Yield %d" % ratio, midas_row.get(&"Yield 1", DEFAULT_YIELD)))
		var base_money: int = int(config.get_raw_table(&"PlayerLevel").get(str(player_level), {}).get(&"Midas Money", DEFAULT_MIDAS_MONEY))
		acquired.append({"type": REWARD_TYPE_MONEY, "money": int(float(base_money) * yield_rate), "ratio": ratio})
		i += 1
	if player.diamond < total_cost:
		return {"ok": false, "acquired": [], "cost": total_cost}
	player.diamond -= total_cost
	midas_times += times
	# 源 :1893 trackDiamondSpent（活动消费追踪）—— 活动系统单机裁剪（SKIPPED），不接
	return {"ok": true, "acquired": acquired, "cost": total_cost}


## 源 :1880 按 Prob 1..4 加权抽样暴击档位（返回 1/2/3/4）。
## Prob 1=×1(75%)/Prob 2=×2(20%)/Prob 3=×3(4%)/Prob 4=×10(1%)，概率和应=1.0。
func _roll_ratio(midas_row: Dictionary) -> int:
	var rng_val: float = randf()
	var cumulative: float = 0.0
	for ratio in range(1, RATIO_COUNT + 1):
		cumulative += float(midas_row.get(&"Prob %d" % ratio, 0.0))
		if rng_val <= cumulative:
			return ratio
	return 1  # 概率溢出兜底（Prob 和<1 时走默认 ×1）


## 存档序列化（config 不存，from_dict 时重新注入 cm）。
func to_dict() -> Dictionary:
	return {"midas_times": midas_times}


static func from_dict(data: Dictionary, cm: ConfigManager) -> MidasManager:
	var mgr := MidasManager.new(cm)
	mgr.midas_times = int(data.get("midas_times", 0))
	return mgr
