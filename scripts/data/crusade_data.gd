class_name CrusadeData
extends RefCounted

## 远征数据层（Data 层）— 照源 local_server.lua buildCrusadeHeroPools(:2376-2400) + initCrusade 难度曲线(:2416-2429)。
## 纯 static：英雄池构建（Unit.Position Type 分前/中/后 + rng 洗牌）+ 关卡难度曲线（level/stars/rank）。
## CrusadeManager（状态+持久化+战斗）后续接。

const MAX_STAGE: int = 15           # 源 CRUSADE_MAX_STAGE(:2373)
const LEVEL_BASE: int = 80          # 源 stage 1 = level 80
const LEVEL_RANGE: int = 10         # 源 stage 15 = level 90（80+10）
const STARS_BASE: float = 3.0       # 源 :2428 floor(3 + stage*0.13 + 0.5)
const STARS_STAGE_SCALE: float = 0.13
const STARS_MAX: int = 5
const RANK_BASE: float = 2.0        # 源 :2429 floor(2 + stage*0.67 + 0.5)
const RANK_STAGE_SCALE: float = 0.67
const RANK_MAX: int = 12
const ROUND_BIAS: float = 0.5       # 源 floor(...+0.5) 四舍五入
const POS_FRONT: String = "Front"
const POS_MIDDLE: String = "Middle"
const POS_REAR: String = "Rear"
# 源 initCrusade:2410-2412 fallback 池（Position Type 全大写致 find 失败时用，源实际敌人来源）。
const FALLBACK_FRONT: Array[int] = [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34, 37, 40]
const FALLBACK_MIDDLE: Array[int] = [2, 5, 8, 11, 14, 17, 20, 23, 26, 29, 32, 35, 38]
const FALLBACK_REAR: Array[int] = [3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39]


## 源 buildCrusadeHeroPools(:2376-2400)：Unit 表 Position Type 分前/中/后池 + rng 洗牌。
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
	# 源 initCrusade:2409-2412：三池全空（Position Type find 失败）→ fallback 硬编码池。
	if front.is_empty() and middle.is_empty() and rear.is_empty():
		front = FALLBACK_FRONT.duplicate()
		middle = FALLBACK_MIDDLE.duplicate()
		rear = FALLBACK_REAR.duplicate()
	_shuffle(front, rng)
	_shuffle(middle, rng)
	_shuffle(rear, rng)
	return {"front": front, "middle": middle, "rear": rear}


## 源 stageLevel(:2416-2418)：floor(80 + (stage-1)*10/(MAX-1) + 0.5)。
static func stage_level(stage: int) -> int:
	return int(floor(LEVEL_BASE + float(stage - 1) * float(LEVEL_RANGE) / float(MAX_STAGE - 1) + ROUND_BIAS))


## 源 :2428 stars = min(5, floor(3 + stage*0.13 + 0.5))。
static func stage_stars(stage: int) -> int:
	return mini(STARS_MAX, int(floor(STARS_BASE + float(stage) * STARS_STAGE_SCALE + ROUND_BIAS)))


## 源 :2429 rank = min(12, floor(2 + stage*0.67 + 0.5))。
static func stage_rank(stage: int) -> int:
	return mini(RANK_MAX, int(floor(RANK_BASE + float(stage) * RANK_STAGE_SCALE + ROUND_BIAS)))


# 源 :2393-2398 Fisher-Yates 洗牌（math_random → rng 注入，确定性）。
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
