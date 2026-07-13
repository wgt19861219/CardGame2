class_name BattleRng
extends RefCounted

## 战斗确定性随机源（D2 确定性契约核心）。
## 封装 RandomNumberGenerator 并持 seed，所有战斗随机必须走本类——禁全局 randf/randi。
## 同 seed 产生相同序列，使战斗可确定性回放（Step 1.2 回放依赖）。

var _rng: RandomNumberGenerator

func _init(initial_seed: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = initial_seed

## 返回 [0.0, 1.0) 随机浮点。用于暴击/闪避/buff 抵抗等概率判定。
func randf() -> float:
	return _rng.randf()

## 返回 [from, to] 闭区间随机整数。用于目标索引/层数等离散随机。
func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

## 当前内部状态（用于确定性测试断言/快照）。
func get_seed() -> int:
	return _rng.seed
