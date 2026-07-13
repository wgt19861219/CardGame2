class_name BaseUI
extends Control

## View 层基类：自动订阅 EventBus.data_changed，退出树时退订，治旧版信号泄漏。
## 子类 override _on_data_changed(scope) 处理刷新，无需手动管 connect/disconnect。

var _event_bus: EventBus
var _connected: bool = false

## 注入事件总线并完成订阅。View 场景在 _ready 中调用。
func setup(event_bus: EventBus) -> void:
	_event_bus = event_bus
	_connect_bus()

func _exit_tree() -> void:
	_disconnect_bus()

func _connect_bus() -> void:
	if _connected or _event_bus == null:
		return
	_event_bus.data_changed.connect(_on_data_changed)
	_connected = true

func _disconnect_bus() -> void:
	if not _connected or _event_bus == null:
		return
	if _event_bus.data_changed.is_connected(_on_data_changed):
		_event_bus.data_changed.disconnect(_on_data_changed)
	_connected = false

## 子类 override：收到数据变更时按 scope 刷新。
func _on_data_changed(_scope: StringName) -> void:
	pass
