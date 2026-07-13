class_name StageData
extends RefCounted

## 关卡静态数据（Data 层）：从 Stage 表加载。掉落 7 槽 + 概率。

const DROP_SLOT_COUNT: int = 7
const DEFAULT_DROP_PROB: int = 100  # 源 generateLoots :392 UI reward Pro 缺失默认 100（普通通关高掉率）
const SWEEP_DEFAULT_PROB: int = 34  # 源 sweep local_server.lua:1614 UI reward Pro 缺省 34（扫荡低掉率防滥用）
const DUNGEON_ID_MIN: int = 50001   # 源 local_server.lua:455 isDungeonStage 新段
const DUNGEON_ID_MAX: int = 53021   # 源 :455（21 base × 4 diff = 84 关，最大 53021）
# 源 local_server.lua:456-461 旧段兼容（40001-43021，旧 dungeon 段保留）
const DUNGEON_OLD_RANGES: Array = [[40001, 40021], [41001, 41021], [42001, 42021], [43001, 43021]]


## 源 local_server.lua:453-462 isDungeonStage：副本关 id 在新段（50001-53021）或旧段（40001-43021）。
## Data 层自含判定（不依赖 Systems/stage_account，治分层）；副本关读 StageDungeon 表。
static func is_dungeon_stage(sid: int) -> bool:
	if sid >= DUNGEON_ID_MIN and sid <= DUNGEON_ID_MAX:
		return true
	for rng in DUNGEON_OLD_RANGES:
		if sid >= int(rng[0]) and sid <= int(rng[1]):
			return true
	return false

var stage_id: int = 0
var chapter_id: int = 0
var vitality_cost: int = 0
var vit_return: int = 0
var unlock_level: int = 1
var require_stage: int = 0
var require_stars: int = 0
var exp_reward: int = 0
var money_reward: int = 0
var monster_level: int = 0  # 源 Stage."Monster Level"（敌人等级）
var difficulty: int = 0     # 源 StageDungeon."Difficulty"（副本难度 1-4，stage_account goldByDiff 用）
var key_stage: bool = false  # 源 Stage."Key Stage"（结算 isKeyStage 分支，stageaccount:50）
var waves: int = 1           # 源 Stage."Waves"（结算背景图取最后一波，stageaccount:192）
var heroexp_reward: int = 0  # 源 Stage."Heroexp Reward"（上场英雄经验总量，stageaccount:79）
var fail_exp_reward: int = 0  # 源 Stage."Fail Exp Reward"（失败 excavate 给经验，stageaccount:26）
var drops: Array[Dictionary] = []  # {item_id, probability(0-100)}；Pro 缺省 100（generateLoots 普通通关）
var sweep_drops: Array[Dictionary] = []  # 扫荡掉落，probability Pro 缺省 34（照源 sweep :1614，同 7 槽仅缺省不同）

static func from_config(cm: ConfigManager, sid: int) -> StageData:
	var data := StageData.new()
	data.stage_id = sid
	# 源 battleprepare.lua:363-366：副本关读 StageDungeon 表（dungeon 关在 Stage 表无）。
	var table: StringName = &"StageDungeon" if is_dungeon_stage(sid) else &"Stage"
	# 全字段直读 raw_table 容错（Lua nil 安全范式，源 generateLoots :391-393）：
	# StageDungeon 表无 Money Reward（dungeon 不给金币）+ diff 变体可能缺 Vit Return/Fail Exp Reward，
	# get_int 字段缺失 push_error 对副本关过严，统一 raw_table.get 默认 0。
	var stage_row: Dictionary = cm.get_raw_table(table).get(str(sid), {})
	data.chapter_id = int(stage_row.get("Chapter ID", 0))
	data.vitality_cost = int(stage_row.get("Vitality Cost", 0))
	data.vit_return = int(stage_row.get("Vit Return", 0))
	data.unlock_level = int(stage_row.get("Unlock Level", 1))
	data.require_stage = int(stage_row.get("Require Stage", 0))
	data.require_stars = int(stage_row.get("Require Stars", 0))
	data.exp_reward = int(stage_row.get("Exp Reward", 0))
	data.money_reward = int(stage_row.get("Money Reward", 0))
	data.monster_level = int(stage_row.get("Monster Level", 0))
	data.difficulty = int(stage_row.get("Difficulty", 0))
	data.key_stage = bool(stage_row.get("Key Stage", false))
	data.waves = int(stage_row.get("Waves", 1))
	data.heroexp_reward = int(stage_row.get("Heroexp Reward", 0))
	data.fail_exp_reward = int(stage_row.get("Fail Exp Reward", 0))
	var i: int = 1
	while i <= DROP_SLOT_COUNT:
		var item_id: int = int(stage_row.get("UI reward" + str(i), 0))
		if item_id != 0:
			var pro_key: String = "UI reward" + str(i) + " Pro"
			# 源 generateLoots :392 Pro 缺省 100（普通通关）/ sweep :1614 Pro 缺省 34（扫荡防滥用），同字段不同缺省
			data.drops.append({"item_id": item_id, "probability": int(stage_row.get(pro_key, DEFAULT_DROP_PROB))})
			data.sweep_drops.append({"item_id": item_id, "probability": int(stage_row.get(pro_key, SWEEP_DEFAULT_PROB))})
		i += 1
	return data
