class_name InstanceManager
extends RefCounted

## 副本管理（Logic 层，Step 3.2，Axmol 新增）：副本组进度 + 次数限制 + 难度奖励 + 宝箱掉落。
## Boss 三波战斗复用 BattleEngine（上层 wave_index 调度）。迷雾源未实现（设计后续）。

const MAX_DAILY_COUNT: int = 2  # 每组每日次数（源 ActStageGroup DailyLimit）
const DIFFICULTY_REWARDS: Array[int] = [2000, 4000, 6000, 8000]  # 普通/精英/英雄/噩梦 通关金币
const CHEST_DROP_BASE_RATE: float = 0.3  # 宝箱基础掉落率（难度递减）
const CHEST_DROP_REDUCTION_PER_DIFF: float = 0.05  # 每级难度掉落率递减
const CHEST_DROP_MIN_RATE: float = 0.1  # 宝箱最低掉落率

var config: ConfigManager
var cleared: Dictionary = {}   # group_id(int) -> bool
var daily_count: Dictionary = {}  # group_id(int) -> 今日次数

func _init(cm: ConfigManager) -> void:
	config = cm

func daily_used(group_id: int) -> int:
	return int(daily_count.get(group_id, 0))

## 进入副本：次数检查 + 计数。返回是否可进。
func enter_instance(group_id: int) -> bool:
	if daily_used(group_id) >= MAX_DAILY_COUNT:
		return false
	daily_count[group_id] = daily_used(group_id) + 1
	return true

## 结算：胜利发放难度奖励 + 标记通关。
func exit_instance(group_id: int, difficulty: int, won: bool) -> Dictionary:
	if won:
		cleared[group_id] = true
		return {"money": _difficulty_reward(difficulty), "won": true}
	return {"money": 0, "won": false}

## 宝箱掉落：难度越高概率越低（源 0.3→0.15），确定性 rng。
func generate_chest_loot(difficulty: int, rng: BattleRng) -> bool:
	var rate: float = CHEST_DROP_BASE_RATE
	var reduction: float = float(difficulty - 1) * CHEST_DROP_REDUCTION_PER_DIFF
	rate = max(rate - reduction, CHEST_DROP_MIN_RATE)
	return rng.randf() < rate

func is_cleared(group_id: int) -> bool:
	return bool(cleared.get(group_id, false))

func _difficulty_reward(difficulty: int) -> int:
	if difficulty < 1 or difficulty > DIFFICULTY_REWARDS.size():
		return 0
	return DIFFICULTY_REWARDS[difficulty - 1]
