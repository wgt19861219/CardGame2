class_name ExcavateHistory
extends RefCounted

## 挖掘战斗历史（Logic 层）— 照源 ui/popwindow/excavatehistory.lua data 结构 + orderData:16。
## 单机化：源 history = 被其他玩家攻击的记录（联机 query_excavate_history 拿）→
## 单机无 others 攻击，改为记录玩家自己的 excavate 战斗（打 monster 结果）。
## vit 单机裁（源 _vatility 防御成功给体力，单机无防御战 → vit=0，vit_button 不显示）。
## 字段名照源（_id/_excavate_id/_result/_enemy_name/_time/_vatility/_self_team/_oppo_team）。

const RESULT_WIN: String = "win"
const RESULT_LOSE: String = "lose"
const ID_START: int = 1
const HISTORY_MAX: int = 50   # 历史上限（避无限增长，照源服务端只返近期若干条）

var _records: Array = []   # 历史 dict 列表
var _next_id: int = ID_START


## 取全部历史（已按 _time 倒序，照 orderData:16）。
func get_all() -> Array:
	var sorted: Array = _records.duplicate(true)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["_time"]) > int(b["_time"]))
	return sorted


## 取单条（按 id，照 excavatebattlereport.pop 按 id 查回放）。
func get_record(record_id: int) -> Dictionary:
	for r in _records:
		if int(r["_id"]) == record_id:
			return r
	return {}


## 加一条战斗记录（照 refreshData battle 后服务端 push history）。
## entry 字段：excavate_id（矿点 type）/ result / enemy_name / time / self_team / oppo_team。
func add(entry: Dictionary) -> void:
	entry["_id"] = _next_id
	_next_id += 1
	entry["_vatility"] = 0   # 单机裁（源防御体力奖励联机，单机无防御战）
	_records.append(entry)
	while _records.size() > HISTORY_MAX:
		_records.remove_at(0)


func to_dict() -> Dictionary:
	return {
		"records": _records.duplicate(true),
		"next_id": _next_id,
	}


static func from_dict(data: Dictionary) -> ExcavateHistory:
	var h := ExcavateHistory.new()
	h._records = data.get("records", [])
	h._next_id = int(data.get("next_id", ID_START))
	return h
