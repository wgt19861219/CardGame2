extends CanvasLayer

## autoload Toast（Step 4.1）：全局弹消息（layer=200）。队列管理，实际 Label 显示在运行时。

const TOAST_LAYER: int = 200
const TOAST_Y: float = 320.0   # 屏幕垂直居中附近
const TOAST_DURATION: float = 2.0   # 显示时长（秒）
const TOAST_FONT_SIZE: int = 22   # toast 字号
const SCREEN_CENTER_X: float = 480.0   # 屏幕水平中心（960/2，position.x 居中基准）
const TOAST_OUTLINE_SIZE: int = 3   # 文字描边粗细（add_theme_constant_override outline_size）
const TOAST_CENTER_RATIO: float = 0.5   # 居中比例（label_w 乘以它算水平偏移）

var _queue: Array[String] = []
var _current_label: Label = null
var _timer: float = 0.0

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

# 简易显示循环：队列非空时取下一条显示，TOAST_DURATION 秒后消失取下一条。
func _process(delta: float) -> void:
	if _current_label != null:
		_timer -= delta
		if _timer <= 0.0:
			_current_label.queue_free()
			_current_label = null
	if _current_label == null and not _queue.is_empty():
		var text: String = consume()
		_current_label = Label.new()
		_current_label.text = text
		_current_label.add_theme_font_size_override("font_size", TOAST_FONT_SIZE)
		_current_label.add_theme_color_override("font_color", Color.WHITE)
		_current_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_current_label.add_theme_constant_override("outline_size", TOAST_OUTLINE_SIZE)
		# size.x 在 add_child 前为 0（未入树未布局），用 get_combined_minimum_size 取真实宽度居中。
		# CanvasLayer 非 Control 容器、不跑锚点布局，故不用 set_anchors_preset，直接 position 定位。
		var label_w: float = _current_label.get_combined_minimum_size().x
		_current_label.position = Vector2(SCREEN_CENTER_X - label_w * TOAST_CENTER_RATIO, TOAST_Y)
		_current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_current_label)
		_timer = TOAST_DURATION
