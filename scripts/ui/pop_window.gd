class_name PopWindow
extends Control

## 弹窗 MVC 基类（View 层）— 照源 ui/popwindow/popwindow.lua 翻译（Phase 7 起步，2026-07-02）。
## Control 全屏 + shade ColorRect（黑半透遮罩）+ container（内容层）+ show/remove + 生命周期回调。
## onEnterHandlers/onExitHandlers。Godot：shade mouse_filter STOP(swallow)/IGNORE + _enter_tree/_exit_tree。

const DEFAULT_SHADE_COLOR: Color = Color(0.0, 0.0, 0.0, 150.0 / 255.0)

var identity: String = ""
var param: Dictionary = {}
var shade_layer: ColorRect = null
var container: Control = null
var _on_enter_handlers: Array[Callable] = []
var _on_exit_handlers: Array[Callable] = []
var _swallow: bool = true


func _init(p_identity: String = "", p_param: Dictionary = {}) -> void:
	identity = p_identity
	param = p_param


func setup() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	shade_layer = ColorRect.new()
	shade_layer.color = DEFAULT_SHADE_COLOR
	shade_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade_layer.mouse_filter = Control.MOUSE_FILTER_STOP if _swallow else Control.MOUSE_FILTER_IGNORE
	add_child(shade_layer)
	container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade_layer.add_child(container)


func show_window(parent: Node) -> void:
	if parent == null:
		return
	if shade_layer == null:
		setup()
	parent.add_child(self)
	for h in _on_enter_handlers:
		h.call()


func remove_window() -> void:
	for h in _on_exit_handlers:
		h.call()
	queue_free()


func register_on_enter(handler: Callable) -> void:
	_on_enter_handlers.append(handler)


func register_on_exit(handler: Callable) -> void:
	_on_exit_handlers.append(handler)


func set_swallow(swallow: bool) -> void:
	_swallow = swallow
	if shade_layer != null:
		shade_layer.mouse_filter = Control.MOUSE_FILTER_STOP if _swallow else Control.MOUSE_FILTER_IGNORE
