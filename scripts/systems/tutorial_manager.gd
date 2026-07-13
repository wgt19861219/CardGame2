class_name TutorialManager
extends RefCounted

## 新手引导（Logic 层，Step 4.11）：跨场景步骤状态机。
## 治旧版 tutorial STEP_DONE→0 坑（步骤索引 0/完成边界混淆）。用显式 enum + current_index 避免歧义。

enum State { NOT_STARTED, IN_PROGRESS, DONE }

var steps: Array[StringName] = []
var current_index: int = 0
var state: int = State.NOT_STARTED

func _init(tutorial_steps: Array[StringName] = []) -> void:
	steps = tutorial_steps

func start() -> void:
	if steps.is_empty():
		state = State.DONE
		return
	current_index = 0
	state = State.IN_PROGRESS

## 当前步骤名（无则空）。
func current_step() -> StringName:
	if state != State.IN_PROGRESS or current_index >= steps.size():
		return &""
	return steps[current_index]

## 完成当前步骤，推进下一步；末步完成 → DONE（不回到 0，治旧版坑）。
func complete_current() -> void:
	if state != State.IN_PROGRESS:
		return
	current_index += 1
	if current_index >= steps.size():
		state = State.DONE
		current_index = steps.size()  # 显式越界标记，不回到 0


## 事件驱动推进（源 ed.tutorial.checkDone 等价）：UI 动作调此方法，若当前步骤匹配 step 则完成。
## EE/unlock/SU 等阶段步骤推进用（FT 链也可混用）。返 true 表匹配推进；false 表不匹配无操作。
func try_complete(step: StringName) -> bool:
	if state != State.IN_PROGRESS or current_step() != step:
		return false
	complete_current()
	return true


func is_done() -> bool:
	return state == State.DONE

func skip_all() -> void:
	state = State.DONE
	current_index = steps.size()


## 切换步骤链（多阶段：FT done → EE/unlock/SU 条件触发时调，源 tutorial 多 stage 机制）。
## 重置 index + IN_PROGRESS（空链 → DONE）。保留旧 state 语义（调用方负责时机：FT done 后切 EE）。
func switch_steps(new_steps: Array[StringName]) -> void:
	steps = new_steps
	current_index = 0
	state = State.DONE if new_steps.is_empty() else State.IN_PROGRESS


## 序列化（步骤进度存档）。
func to_dict() -> Dictionary:
	var steps_arr: Array[String] = []
	for s in steps:
		steps_arr.append(String(s))
	return {"current_index": current_index, "state": state, "steps": steps_arr}


## 从字典重建（steps 空→默认 FT 链）。
static func from_dict(data: Dictionary) -> TutorialManager:
	var steps_arr: Array[StringName] = []
	for s in data.get("steps", []):
		steps_arr.append(StringName(String(s)))
	if steps_arr.is_empty():
		steps_arr = TutorialData.DEFAULT_FT_STEPS.duplicate()
	var mgr := TutorialManager.new(steps_arr)
	mgr.current_index = int(data.get("current_index", 0))
	mgr.state = int(data.get("state", State.NOT_STARTED))
	return mgr
