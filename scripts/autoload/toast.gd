extends CanvasLayer

## autoload Toast（Step 4.1）：全局弹消息（layer=200）。队列管理，实际 Label 显示在运行时。

const TOAST_LAYER: int = 200

var _queue: Array[String] = []

func _ready() -> void:
	layer = TOAST_LAYER

func show_message(text: String) -> void:
	_queue.append(text)

func pending_count() -> int:
	return _queue.size()

## 取出最早的消息（运行时显示后调用）。
func consume() -> String:
	if _queue.is_empty():
		return ""
	var text: String = _queue[0]
	_queue.remove_at(0)
	return text
