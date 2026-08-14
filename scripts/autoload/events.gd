extends Node

## autoload 薄包装（全局名 Events）：持有 RefCounted 的 EventBus 实例，供 View 层订阅。
## Logic 层不直接访问本节点，而是通过模块 register 注入的 EventBus 实例工作。
## unlock 公告 UI（队列+单例位+自动消失）已外移 UnlockAnnouncePresenter（View 层，T2）。

const EventBusScript = preload("res://scripts/systems/event_bus.gd")
const UnlockAnnouncePresenter = preload("res://scripts/ui/unlock_announce_presenter.gd")

var bus: EventBus


func _ready() -> void:
	bus = EventBusScript.new()
	var presenter := UnlockAnnouncePresenter.new()
	add_child(presenter)
	presenter.setup(bus)
