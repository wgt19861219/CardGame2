class_name ExerciseManager
extends RefCounted

## 时光之穴/英雄试炼（Step 3.3）：薄入口 + 复用远征地图(dungeon_map) + 副本数据。
## 非独立模块（源 exercise 入口分支）。英雄副本组 50005-50007，全周开放，DailyLimit 控制。
## 查询方法（照源 exercise.lua:43-124/1133-1188）服务 UI 装配：em/equip 走 ActStageGroup，
## dungeon 走 ActStageGroupDungeon + StageDungeon（84 关，难度变体已固化入 JSON）。

const HERO_TRIAL_GROUPS: Array[int] = [50005, 50006, 50007]
const DAILY_LIMIT: int = 1

const ENTRY_STAGE: Dictionary = {
	"exp": 20001, "money": 20002, "int": 20003, "agi": 20004, "str": 20005,
	"dg1": 50001, "dg2": 50002, "dg3": 50003, "dg4": 50004,
	"dg5": 50005, "dg6": 50006, "dg7": 50007,
}
const STAGE_SLOTS: int = 8
const DIFFICULTY_COUNT: int = 4
const DIFF_ID_OFFSET: int = 1000
const DEFAULT_VIT: int = 12
const DEFAULT_UNLOCK: int = 1
const VIT_SCALE: Array = [1.0, 1.3, 1.7, 2.0]
const UNLOCK_OFFSET: Array = [0, 5, 10, 15]

enum Mode { HERO_TRIAL, TIME_CAVERN }

var cm: Variant = null                # ConfigManager 注入（查询方法依赖）
var daily_count: Dictionary = {}  # group_id(int) -> 今日次数
var cleared: Dictionary = {}      # group_id(int) -> bool


func setup(p_cm: Variant) -> void:
	cm = p_cm


func daily_used(group_id: int) -> int:
	return int(daily_count.get(group_id, 0))

## 进入英雄副本组：组有效 + 次数检查。
func enter(group_id: int) -> bool:
	if not HERO_TRIAL_GROUPS.has(group_id):
		return false
	if daily_used(group_id) >= DAILY_LIMIT:
		return false
	daily_count[group_id] = daily_used(group_id) + 1
	return true

func complete(group_id: int, won: bool) -> void:
	if won:
		cleared[group_id] = true

func is_cleared(group_id: int) -> bool:
	return bool(cleared.get(group_id, false))

## 模式（复用远征地图 mode 参数）。当前组均为英雄试炼。
func mode_for_group(group_id: int) -> int:
	return Mode.HERO_TRIAL if HERO_TRIAL_GROUPS.has(group_id) else Mode.TIME_CAVERN


# ===== 查询方法（照源 exercise.lua，服务 ExercisePanel UI 装配）=====

func _act_row(key: String) -> Dictionary:
	var sgid: int = int(ENTRY_STAGE.get(key, 0))
	if sgid == 0 or cm == null:
		return {}
	return cm.get_entry(&"ActStageGroup", sgid)

func get_act_info(key: String) -> Dictionary:
	var row: Dictionary = _act_row(key)
	return {
		"name": row.get(&"Group Name", ""),
		"des": row.get(&"Display Time Schedule", ""),
		"amount_limit": int(row.get(&"DailyLimit", 0)),
		"stage": row.get(&"Stages", {}),
		"advise": row.get(&"Display Special Limit", ""),
		"reward": [row.get(&"UI reward1", 0), row.get(&"UI reward2", 0), row.get(&"UI reward3", 0)],
	}

func get_daily_limit(key: String) -> int:
	return int(_act_row(key).get(&"DailyLimit", 0))

func get_cd(key: String) -> int:
	return int(_act_row(key).get(&"CD", 0))

func get_hero_limit(key: String) -> Dictionary:
	var row: Dictionary = _act_row(key)
	return {"type": row.get(&"Limit Type", ""), "detail": row.get(&"Limit Detail", "")}

func get_stages(key: String) -> Array:
	if cm == null:
		return []
	var s: Dictionary = get_act_info(key).get(&"stage", {})
	var stage: Array = []
	for i in range(1, STAGE_SLOTS + 1):
		var sid: int = int(s.get(str(i), 0))
		if sid > 0:
			stage.append({"id": sid, "vit": cm.get_int(&"Stage", sid, &"Vitality Cost")})
	stage.sort_custom(func(a, b): return int(a["id"]) < int(b["id"]))
	return stage

# 难度变体优先查 StageDungeon 实际数据（已固化 84 关），缺则兜底公式（源 :96-97）
func get_dungeon_stages(key: String) -> Array:
	var group_key: int = int(ENTRY_STAGE.get(key, 0))
	if group_key == 0 or cm == null:
		return []
	var group_data: Dictionary = cm.get_raw_table(&"ActStageGroupDungeon").get(str(group_key), {})
	if group_data.is_empty():
		group_data = cm.get_raw_table(&"ActStageGroup").get(str(group_key), {})
	if group_data.is_empty():
		return []
	var st_dungeon: Dictionary = cm.get_raw_table(&"StageDungeon")
	var stages_arr: Array = group_data.get(&"Stages", [])
	var bosses: Array = []
	for boss_id in stages_arr:
		var bid: int = int(boss_id)
		if bid <= 0:
			continue
		var base_data: Dictionary = st_dungeon.get(str(bid), {})
		var base_vit: int = int(base_data.get(&"Vitality Cost", DEFAULT_VIT))
		var base_unlock: int = int(base_data.get(&"Unlock Level", DEFAULT_UNLOCK))
		var diffs: Array = []
		for diff in range(1, DIFFICULTY_COUNT + 1):
			var diff_id: int = bid + (diff - 1) * DIFF_ID_OFFSET
			var stage_data: Dictionary = st_dungeon.get(str(diff_id), {})
			if not stage_data.is_empty():
				diffs.append({
					"id": diff_id,
					"vit": int(stage_data.get(&"Vitality Cost", DEFAULT_VIT)),
					"key_cost": int(stage_data.get(&"Key Cost", 0)),
					"unlock_level": int(stage_data.get(&"Unlock Level", DEFAULT_UNLOCK)),
					"diff": diff,
				})
			else:
				diffs.append({
					"id": diff_id,
					"vit": int(ceil(base_vit * float(VIT_SCALE[diff - 1]))),
					"key_cost": 0,
					"unlock_level": base_unlock + int(UNLOCK_OFFSET[diff - 1]),
					"diff": diff,
				})
		bosses.append({"base_id": bid, "name": String(base_data.get(&"Stage Name", "")), "difficulties": diffs})
	return bosses

# ===== 副本地图（dungeon_map）Logic：照源 ui/dungeon_map.lua:49-125 =====
# dungeon_map Panel 装配 + 解锁/清除判定。get_dungeon_bosses 按 group_id 直查（dungeon_map.getBossesForGroup），
# 与 get_dungeon_stages(key) 差异：① 不经 ENTRY_STAGE ② base_data 多 Stage 表 fallback ③ name 多 "Group Name" fallback
# ④ 缺失分支 unlock_level=base_unlock（不加 offset，照源 dungeon_map.lua:86-93，区别于 exercise.getDungeonStages）。

func get_dungeon_bosses(group_id: int) -> Array:
	if group_id == 0 or cm == null:
		return []
	var group_data: Dictionary = cm.get_raw_table(&"ActStageGroupDungeon").get(str(group_id), {})
	if group_data.is_empty():
		group_data = cm.get_raw_table(&"ActStageGroup").get(str(group_id), {})
	if group_data.is_empty():
		return []
	var st_dungeon: Dictionary = cm.get_raw_table(&"StageDungeon")
	var stage_table: Dictionary = cm.get_raw_table(&"Stage")
	var bosses: Array = []
	for boss_id in group_data.get(&"Stages", []):
		var bid: int = int(boss_id)
		if bid <= 0:
			continue
		var base_data: Dictionary = st_dungeon.get(str(bid), {})
		if base_data.is_empty():
			base_data = stage_table.get(str(bid), {})
		var base_vit: int = int(base_data.get(&"Vitality Cost", base_data.get(&"Vit Cost", DEFAULT_VIT)))
		var base_unlock: int = int(base_data.get(&"Unlock Level", DEFAULT_UNLOCK))
		var boss_name: String = String(base_data.get(&"Stage Name", base_data.get(&"Group Name", "")))
		var diffs: Array = []
		for diff in range(1, DIFFICULTY_COUNT + 1):
			var diff_id: int = bid + (diff - 1) * DIFF_ID_OFFSET
			var stage_data: Dictionary = st_dungeon.get(str(diff_id), {})
			if not stage_data.is_empty():
				diffs.append({
					"id": diff_id,
					"vit": int(stage_data.get(&"Vitality Cost", DEFAULT_VIT)),
					"key_cost": int(stage_data.get(&"Key Cost", 0)),
					"unlock_level": int(stage_data.get(&"Unlock Level", DEFAULT_UNLOCK)),
					"diff": diff,
				})
			else:
				diffs.append({
					"id": diff_id,
					"vit": int(ceil(base_vit * float(VIT_SCALE[diff - 1]))),
					"key_cost": 0,
					"unlock_level": base_unlock,
					"diff": diff,
				})
		bosses.append({"base_id": bid, "name": boss_name, "difficulties": diffs})
	return bosses

static func is_boss_cleared(progress: Dictionary, boss_id: int) -> bool:
	return int(progress.get(boss_id, 0)) > 0

static func is_boss_unlocked(bosses: Array, progress: Dictionary, boss_idx: int) -> bool:
	if boss_idx <= 1:
		return true
	if boss_idx > bosses.size():
		return false
	var prev_boss_idx: int = boss_idx - 1  # 1-based 前一个 boss
	var prev_zero_based: int = prev_boss_idx - 1  # 1-based → 0-based
	return is_boss_cleared(progress, int(bosses[prev_zero_based]["base_id"]))

## group_counts/group_offsets：源模块级 groupBossCounts/groupBossOffset（create() 填充，key=group_idx）。
static func is_group_cleared(bosses: Array, group_counts: Dictionary, group_offsets: Dictionary, progress: Dictionary, group_idx: int) -> bool:
	var count: int = int(group_counts.get(group_idx, 0))
	var offset: int = int(group_offsets.get(group_idx, 0))
	for b in range(1, count + 1):
		var boss_idx: int = offset + b
		if boss_idx > bosses.size():
			return false
		if not is_boss_cleared(progress, int(bosses[boss_idx - 1]["base_id"])):
			return false
	return true

func check_unlock(stage_id: int, player_level: int) -> bool:
	if cm == null:
		return true
	return cm.get_int(&"Stage", stage_id, &"Unlock Level") <= player_level

func is_enabled(_key: String) -> bool:
	return true
