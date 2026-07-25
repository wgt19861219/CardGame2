extends Node

## autoload 薄包装（全局名 Events）：持有 RefCounted 的 EventBus 实例，供 View 层订阅。
## Logic 层不直接访问本节点，而是通过模块 register 注入的 EventBus 实例工作。

const EventBusScript = preload("res://scripts/systems/event_bus.gd")
const UnlockAnnounceViewScript = preload("res://scripts/ui/unlock_announce_view.gd")
# unlock 公告 CanvasLayer 顶层（跨场景覆盖 battle/结算/主城，源 announce.lua zorder=500）。
# 治 main_scene-only 接入丢 battle 结算内升级公告（PlayerData.check_unlocks 在 take_stage_reward 触发）。
const ANNOUNCE_LAYER: int = 100
# 公告自动消失时间（秒，照源 announce.lua 公告显示后定时关闭）
const ANNOUNCE_AUTO_DISMISS: float = 3.0

var bus: EventBus
var _announce_overlay: CanvasLayer
# P2-2026-07-10：单例公告位 + 队列（防多解锁公告叠加）
var _announce_queue: Array[StringName] = []
var _announce_active: bool = false


func _ready() -> void:
	bus = EventBusScript.new()
	_announce_overlay = CanvasLayer.new()
	_announce_overlay.layer = ANNOUNCE_LAYER
	add_child(_announce_overlay)
	bus.feature_unlocked.connect(_on_feature_unlocked)


# unlock 公告全局触发：PlayerData.check_unlocks → bus.feature_unlocked → 弹 UnlockAnnounceView 到 overlay。
# overlay 是 CanvasLayer（screen space，跨场景，Control/Node2D 场景都能显示）。
# P2-2026-07-10：维护单例公告位 + 队列，防多解锁同时触发叠加多个 panel。
func _on_feature_unlocked(step: StringName) -> void:
	_announce_queue.append(step)
	_try_show_next_announce()


# 队列驱动：当前无公告显示时弹下一个，有则在显示中等待
func _try_show_next_announce() -> void:
	if _announce_active or _announce_queue.is_empty():
		return
	_announce_active = true
	var step: StringName = _announce_queue.pop_front()
	var view := UnlockAnnounceViewScript.new()
	view.show_step(step, _announce_overlay)
	get_tree().create_timer(ANNOUNCE_AUTO_DISMISS).timeout.connect(_on_announce_dismissed)


# 公告消失后推进队列
func _on_announce_dismissed() -> void:
	_announce_active = false
	_try_show_next_announce()
