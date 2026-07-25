class_name CrusadeData
extends RefCounted

## 远征数据层（Data 层）— 照源 local_server.lua buildCrusadeHeroPools(:2376-2400) + initCrusade 难度曲线(:2416-2429)。
## 纯 static：英雄池构建（Unit.Position Type 分前/中/后 + rng 洗牌）+ 关卡难度曲线（level/stars/rank）。
## CrusadeManager（状态+持久化+战斗）后续接。

const MAX_STAGE: int = 15
const LEVEL_BASE: int = 80
const LEVEL_RANGE: int = 10
const STARS_BASE: float = 3.0
const STARS_STAGE_SCALE: float = 0.13
const STARS_MAX: int = 5
const RANK_BASE: float = 2.0
const RANK_STAGE_SCALE: float = 0.67
const RANK_MAX: int = 12
const ROUND_BIAS: float = 0.5
const POS_FRONT: String = "Front"
const POS_MIDDLE: String = "Middle"
const POS_REAR: String = "Rear"
const FALLBACK_FRONT: Array[int] = [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34, 37, 40]
const FALLBACK_MIDDLE: Array[int] = [2, 5, 8, 11, 14, 17, 20, 23, 26, 29, 32, 35, 38]
const FALLBACK_REAR: Array[int] = [3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39]


## 返 {front, middle, rear}（Array[int] tid）。空池 fallback 由调用方处理（源 :2410-2412）。
static func build_hero_pools(cm: ConfigManager, rng: BattleRng) -> Dictionary:
	var raw: Dictionary = cm.get_raw_table(&"Unit")
	var front: Array[int] = []
	var middle: Array[int] = []
	var rear: Array[int] = []
	for tid_str in raw:
		var row: Dictionary = raw[tid_str]
		var pos_type: String = String(row.get(&"Position Type", ""))
		if pos_type.find(POS_FRONT) >= 0:
			front.append(int(tid_str))
		elif pos_type.find(POS_MIDDLE) >= 0:
			middle.append(int(tid_str))
		elif pos_type.find(POS_REAR) >= 0:
			rear.append(int(tid_str))
	if front.is_empty() and middle.is_empty() and rear.is_empty():
		front = FALLBACK_FRONT.duplicate()
		middle = FALLBACK_MIDDLE.duplicate()
		rear = FALLBACK_REAR.duplicate()
	_shuffle(front, rng)
	_shuffle(middle, rng)
	_shuffle(rear, rng)
	return {"front": front, "middle": middle, "rear": rear}


static func stage_level(stage: int) -> int:
	return int(floor(LEVEL_BASE + float(stage - 1) * float(LEVEL_RANGE) / float(MAX_STAGE - 1) + ROUND_BIAS))


static func stage_stars(stage: int) -> int:
	return mini(STARS_MAX, int(floor(STARS_BASE + float(stage) * STARS_STAGE_SCALE + ROUND_BIAS)))


static func stage_rank(stage: int) -> int:
	return mini(RANK_MAX, int(floor(RANK_BASE + float(stage) * RANK_STAGE_SCALE + ROUND_BIAS)))


static func _shuffle(pool: Array[int], rng: BattleRng) -> void:
	if rng == null:
		return
	var i: int = pool.size() - 1
	while i >= 1:
		var j: int = int(rng.randi_range(0, i))
		var tmp: int = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
		i -= 1
