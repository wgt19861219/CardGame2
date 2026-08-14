class_name UnlockAnnouncePresenter
extends Node

## unlock 公告呈现器（View 层）：订阅 EventBus.feature_unlocked，弹 UnlockAnnounceView 到顶层 overlay。
## 2026-08-14 架构阶段一 T2 自 autoload events.gd 外移（autoload 退纯服务，治 autoload 塞 View）。
## overlay 是 CanvasLayer（screen space，跨场景覆盖 battle/结算/主城，源 announce.lua zorder=500），
## 治 main_scene-only 接入丢 battle 结算内升级公告（PlayerData.check_unlocks 在 take_stage_reward 触发）。
## 单例公告位 + 队列（P2-2026-07-10，防多解锁公告叠加）。

const UnlockAnnounceViewScript = preload("res://scripts/ui/unlock_announce_view.gd")
const ANNOUNCE_LAYER: int = 100
# 公告自动消失时间（秒，照源 announce.lua 公告显示后定时关闭）
const ANNOUNCE_AUTO_DISMISS: float = 3.0

var _overlay: CanvasLayer
var _queue: Array[StringName] = []
var _active: bool = false
var _current_view: Variant = null  # 当前显示的公告 view（dismiss 时销毁）
# 自动消失定时器引用（view 提前销毁时 disconnect 兜底，防 timer 触发已 free 实例）
var _dismiss_timer: SceneTreeTimer = null


func setup(bus: EventBus) -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = ANNOUNCE_LAYER
	add_child(_overlay)
	bus.feature_unlocked.connect(_on_feature_unlocked)


func _on_feature_unlocked(step: StringName) -> void:
	_queue.append(step)
	_try_show_next_announce()


# 队列驱动：当前无公告显示时弹下一个，有则在显示中等待。
# view 可能被提前 free（手动点 shade 关闭 / show_step 空 cfg），用 tree_exited 兜底清状态。
func _try_show_next_announce() -> void:
	if _active or _queue.is_empty():
		return
	_active = true
	var step: StringName = _queue.pop_front()
	var view := UnlockAnnounceViewScript.new()
	_current_view = view
	# view 无论怎么死（手动关闭/空 cfg queue_free/tween 完销毁），tree_exited 都会触发，兜底清状态。
	view.tree_exited.connect(_on_view_freed)
	# show_step 对空 cfg 会 queue_free（此时 tree_exited 已连，会兜底推进队列，不会泄漏 _active）。
	view.show_step(step, _overlay)
	# 自动消失兜底定时器（手动关闭时 view 提前 free → tree_exited → _cancel_dismiss_timer）
	_dismiss_timer = get_tree().create_timer(ANNOUNCE_AUTO_DISMISS)
	_dismiss_timer.timeout.connect(_on_dismissed)


# view 被 free 时兜底（手动关闭/空 cfg）：清状态 + 取消未触发的 timer + 推进队列。
func _on_view_freed() -> void:
	_current_view = null
	_active = false
	_cancel_dismiss_timer()
	_try_show_next_announce()


# 自动消失：view 仍在则销毁（tree_exited 会接着触发 _on_view_freed 完成收尾）。
func _on_dismissed() -> void:
	if _current_view != null and is_instance_valid(_current_view):
		if _current_view.has_method("_destroy"):
			_current_view._destroy()
		elif _current_view is Node:
			_current_view.queue_free()


func _cancel_dismiss_timer() -> void:
	if _dismiss_timer != null and is_instance_valid(_dismiss_timer):
		if _dismiss_timer.timeout.is_connected(_on_dismissed):
			_dismiss_timer.timeout.disconnect(_on_dismissed)
	_dismiss_timer = null
