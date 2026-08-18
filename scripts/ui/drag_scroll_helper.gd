class_name DragScrollHelper
extends RefCounted

## ScrollContainer 鼠标/触屏拖拽滚动 helper（2026-08-18 修复轮四）。
## 源手游 draglist 手势语义：按住拖动即滚动（源 draglist.lua drag/moved 分支）；
## Godot 4 ScrollContainer 桌面仅滚轮/滚动条，无拖拽——本 helper 补齐。
## 配套：行点击方须自行做位移判别（press 记录 → release 位移小于 TAP_THRESHOLD 才触发，
## 参考 ranklist_panel._on_row_input），拖动后不触发点击。

const DRAG_START_PX: float = 4.0   # 起滚阈值（防微颤；源 draglist dragMode 判定同语义）
const TAP_THRESHOLD_PX: float = 8.0   # 行点击判定阈值（release 距 press 超此值视为拖动非点击）

## 宿主 _input(event) 转发；state 为宿主持有的 Dictionary（跨帧记 press 基准）。
## 拖动直接写 sc.scroll_vertical（同步滚动，无惯性——源 draglist 手松即停 + dragSpeed
## 惯性本项目不译，披露）。
static func handle_input(sc: ScrollContainer, event: InputEvent, state: Dictionary) -> void:
	if sc == null or not sc.visible:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if sc.get_global_rect().has_point(mb.global_position):
				state["press_y"] = mb.global_position.y
				state["start_scroll"] = sc.scroll_vertical
		elif state.has("press_y"):
			state.erase("press_y")
			state.erase("start_scroll")
	elif event is InputEventMouseMotion and state.has("press_y") \
			and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		var mm := event as InputEventMouseMotion
		_apply_delta(sc, state, mm.global_position.y)
	elif event is InputEventScreenDrag and state.has("press_y"):
		var sd := event as InputEventScreenDrag
		_apply_delta(sc, state, sd.position.y)


static func _apply_delta(sc: ScrollContainer, state: Dictionary, cur_y: float) -> void:
	var dy: float = cur_y - float(state["press_y"])
	if absf(dy) >= DRAG_START_PX:
		sc.scroll_vertical = float(state["start_scroll"]) - dy


## 行点击位移判别：press 时记 position（返 true=已记录）；release 时调 is_tap 判定。
## 行 gui_input 只在本节点矩形内收事件——拖出区的 release 不会到行（天然不触发点击）。
static func is_tap(press_pos: Variant, release_pos: Vector2) -> bool:
	if press_pos is Vector2:
		return (release_pos - (press_pos as Vector2)).length() < TAP_THRESHOLD_PX
	return false
