extends Node

## autoload SceneManager（Step 4.1）：场景切换 + 切换锁。
## 锁防重复切换（治旧版切换锁卡死）；切换中请求排队，完成后消费。
## change_scene 对外同步返回 bool（是否立即受理）；异步切换+解锁内化，避免调用方 await 负担。

var _locked: bool = false
var _current_scene_path: String = ""
var _pending: String = ""

## 请求切换场景。锁住时排队，返回是否立即受理（同步）。
## 运行时（在树中）实际切换 + 下一帧解锁；测试（独立 Node）只设锁，由 on_scene_loaded 手动解锁。
func change_scene(path: String) -> bool:
	if _locked:
		_pending = path
		return false
	_locked = true
	_current_scene_path = path
	if is_inside_tree():
		get_tree().change_scene_to_file(path)
		call_deferred("_schedule_unlock")  # 间接启动协程，避免 fire-and-forget warning
	return true

## 下一帧解锁 + 消费排队（运行时异步路径，由 call_deferred 触发）。
func _schedule_unlock() -> void:
	await get_tree().process_frame
	_consume_pending()

## 解锁 + 消费排队请求（同步）。运行时由 _schedule_unlock 调用，测试由 on_scene_loaded 调用。
func _consume_pending() -> void:
	_locked = false
	if _pending != "":
		var next_path := _pending
		_pending = ""
		change_scene(next_path)  # 同步递归，重新上锁受理下一个

## 场景加载完成回调（测试用：手动解锁 + 消费排队）。
func on_scene_loaded() -> void:
	_consume_pending()

func is_locked() -> bool:
	return _locked

func current_scene_path() -> String:
	return _current_scene_path
