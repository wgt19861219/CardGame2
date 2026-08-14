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
var _current_announce_view: Variant = null  # 当前显示的公告 view（dismiss 时销毁）
# 自动消失定时器引用（view 提前销毁时 disconnect 兜底，防 timer 触发已 free 实例）
var _dismiss_timer: SceneTreeTimer = null


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


# 队列驱动：当前无公告显示时弹下一个，有则在显示中等待。
# view 可能被提前 free（手动点 shade 关闭 / show_step 空 cfg），用 tree_exited 兜底清状态。
func _try_show_next_announce() -> void:
	if _announce_active or _announce_queue.is_empty():
		return
	_announce_active = true
	var step: StringName = _announce_queue.pop_front()
	var view := UnlockAnnounceViewScript.new()
	_current_announce_view = view
	# view 无论怎么死（手动关闭/空 cfg queue_free/tween 完销毁），tree_exited 都会触发，兜底清状态。
	view.tree_exited.connect(_on_announce_view_freed)
	# show_step 对空 cfg 会 queue_free（此时 tree_exited 已连，会兜底推进队列，不会泄漏 _announce_active）。
	view.show_step(step, _announce_overlay)
	# 自动消失兜底定时器（手动关闭时 view 提前 free → tree_exited → _cancel_dismiss_timer）
	_dismiss_timer = get_tree().create_timer(ANNOUNCE_AUTO_DISMISS)
	_dismiss_timer.timeout.connect(_on_announce_dismissed)


# view 被 free 时兜底（手动关闭/空 cfg）：清状态 + 取消未触发的 timer + 推进队列。
func _on_announce_view_freed() -> void:
	_current_announce_view = null
	_announce_active = false
	_cancel_dismiss_timer()
	_try_show_next_announce()


# 自动消失：view 仍在则销毁（tree_exited 会接着触发 _on_announce_view_freed 完成收尾）。
func _on_announce_dismissed() -> void:
	if _current_announce_view != null and is_instance_valid(_current_announce_view):
		if _current_announce_view.has_method("_destroy"):
			_current_announce_view._destroy()
		elif _current_announce_view is Node:
			_current_announce_view.queue_free()


func _cancel_dismiss_timer() -> void:
	if _dismiss_timer != null and is_instance_valid(_dismiss_timer):
		if _dismiss_timer.timeout.is_connected(_on_announce_dismissed):
			_dismiss_timer.timeout.disconnect(_on_announce_dismissed)
	_dismiss_timer = null
