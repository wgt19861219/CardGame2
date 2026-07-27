extends CanvasLayer

## autoload Toast（Step 4.1）：全局弹消息（layer=200）。队列管理，实际 Label 显示在运行时。
## 2026-07-27 补 board 背景板（照源 toast.lua createToast：toast_bg.png Scale9 + 文字，半透明蒙层）。

const TOAST_LAYER: int = 200
const TOAST_Y: float = 320.0   # 屏幕垂直居中附近
const TOAST_DURATION: float = 2.0   # 显示时长（秒）
const TOAST_FONT_SIZE: int = 22   # toast 字号
const SCREEN_CENTER_X: float = 480.0   # 屏幕水平中心（960/2，position.x 居中基准）
const TOAST_OUTLINE_SIZE: int = 3   # 文字描边粗细（add_theme_constant_override outline_size）
const TOAST_CENTER_RATIO: float = 0.5   # 居中比例（label_w 乘以它算水平偏移）
const TOAST_BG_RES: String = "res://assets/ui/alpha/HVGA/toast_bg.png"
# 源 toast.lua:36 createScale9Sprite capInsets CCRectMake(20, 20, 194, 20)
const BOARD_PAD_W: float = 20.0   # board 比文字宽的边距（源 :44 labelSize.width + 20）
const BOARD_PAD_H: float = 40.0   # board 比文字高的边距（源 :44 labelSize.height + 40）
const BOARD_PATCH_L: int = 20
const BOARD_PATCH_T: int = 20
const BOARD_PATCH_R: int = 20
const BOARD_PATCH_B: int = 20
const HALF: float = 0.5   # 居中比例 / 边距减半
const BOARD_OFFSET_Y: float = 2.0   # 源 board:setPosition(0,-2) label 在 board 内略上偏
const OUTLINE_DOUBLE: float = 2.0   # 描边上下两侧 ×2

var _queue: Array[String] = []
var _current_label: Label = null
var _current_board: NinePatchRect = null
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

# 简易显示循环：队列非空时取下一条显示，TOAST_DURATION 秅后消失取下一条。
func _process(delta: float) -> void:
	if _current_label != null:
		_timer -= delta
		if _timer <= 0.0:
			_current_label.queue_free()
			_current_label = null
			if _current_board != null:
				_current_board.queue_free()
				_current_board = null
	if _current_label == null and not _queue.is_empty():
		var text: String = consume()
		_current_label = Label.new()
		_current_label.text = text
		_current_label.add_theme_font_size_override("font_size", TOAST_FONT_SIZE)
		_current_label.add_theme_color_override("font_color", Color.WHITE)
		_current_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_current_label.add_theme_constant_override("outline_size", TOAST_OUTLINE_SIZE)
		# Label 入树前 get_combined_minimum_size 不准（字体未布局），用 Font 精确量文字尺寸。
		var font: Font = _current_label.get_theme_default_font()
		var label_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT_SIZE).x if font != null else float(text.length()) * float(TOAST_FONT_SIZE)
		var label_h: float = float(TOAST_FONT_SIZE) + TOAST_OUTLINE_SIZE * OUTLINE_DOUBLE
		var label_size: Vector2 = Vector2(label_w, label_h)
		# board 背景板（照源 createToast :36-44 toast_bg.png Scale9，尺寸比文字大一圈）
		_current_board = NinePatchRect.new()
		_current_board.texture = load(TOAST_BG_RES) as Texture2D
		_current_board.patch_margin_left = BOARD_PATCH_L
		_current_board.patch_margin_top = BOARD_PATCH_T
		_current_board.patch_margin_right = BOARD_PATCH_R
		_current_board.patch_margin_bottom = BOARD_PATCH_B
		_current_board.size = Vector2(label_size.x + BOARD_PAD_W, label_size.y + BOARD_PAD_H)
		_current_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# board 居中于屏幕（label 在 board 内居中）
		_current_board.position = Vector2(SCREEN_CENTER_X - _current_board.size.x * TOAST_CENTER_RATIO, TOAST_Y - BOARD_PAD_H * HALF)
		add_child(_current_board)
		# label 放 board 内居中（源 board:setPosition(0,-2)，label 在 board 中心）
		_current_label.position = Vector2(BOARD_PAD_W * HALF, BOARD_PAD_H * HALF - BOARD_OFFSET_Y)
		_current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_current_board.add_child(_current_label)
		_timer = TOAST_DURATION
