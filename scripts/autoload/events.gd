extends Node

## autoload 薄包装（全局名 Events）：持有 RefCounted 的 EventBus 实例，供 View 层订阅。
## Logic 层不直接访问本节点，而是通过模块 register 注入的 EventBus 实例工作。
## unlock 公告 UI（队列+单例位+自动消失）已外移 UnlockAnnouncePresenter（View 层，T2）。

const EventBusScript = preload("res://scripts/systems/event_bus.gd")
const UnlockAnnouncePresenter = preload("res://scripts/ui/unlock_announce_presenter.gd")

var bus: EventBus


func _ready() -> void:
	bus = EventBusScript.new()
	# 2026-08-20 用户指示：通关升级「功能解锁公告」暂不弹（与剧情触发一并禁用）。
	# Logic 侧 check_unlocks 记录 tutorial_record 不受影响；恢复弹窗时取消下方注释即可。
	# var presenter := UnlockAnnouncePresenter.new()
	# add_child(presenter)
	# presenter.setup(bus)
