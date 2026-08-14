class_name ConfirmDialog
extends Control

## 确认对话框（Step 4.1.5 原子库）：open/confirm/cancel 状态机 + 回调。
## 治旧版确认框逻辑分散；视觉（按钮/遮罩）在 .tscn 运行时。

enum State { CLOSED, OPEN }

var state: int = State.CLOSED
var _on_confirm: Callable
var _on_cancel: Callable

func open(on_confirm: Callable, on_cancel: Callable = Callable()) -> void:
	state = State.OPEN
	_on_confirm = on_confirm
	_on_cancel = on_cancel

func confirm() -> void:
	if state != State.OPEN:
		return
	state = State.CLOSED
	if _on_confirm.is_valid():
		_on_confirm.call()

func cancel() -> void:
	if state != State.OPEN:
		return
	state = State.CLOSED
	if _on_cancel.is_valid():
		_on_cancel.call()

func is_open() -> bool:
	return state == State.OPEN
