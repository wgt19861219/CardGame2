extends CanvasLayer

## autoload Toast（Step 4.1）：全局弹消息（layer=200）。实际 Label 显示在运行时。
## 2026-07-27 补 board 背景板（照源 toast.lua createToast：toast_bg.png Scale9 + 文字，半透明蒙层）。
## 2026-08-30 时长/重复照源 toast.lua:66-78 重做：1s 停留+1s 淡出；新消息替换正在显示的
## （源 showToast removeFromParentAndCleanup 无队列）——旧实现 2s 硬停+队列串行（连点 N 次播
## N×2s）= 用户反馈「达到上限 toast 持续太久」双根因。

const TOAST_LAYER: int = 200
const TOAST_Y: float = 240.0   # 屏幕垂直居中（源 toast.lua:59 bg:setPosition(ccp(400,240)) 直译）
const TOAST_HOLD: float = 1.0   # 停留时长（秒，源 :76 CCDelayTime param.constant or 1）
const TOAST_FADE: float = 1.0   # 淡出时长（秒，源 :77 CCFadeOut 1）
const TOAST_FONT_SIZE: int = 22   # toast 字号
const SCREEN_CENTER_X: float = 400.0   # 屏幕水平中心（800/2，源 ccp(400,240)；position.x 居中基准）
const TOAST_OUTLINE_SIZE: int = 3   # 文字描边粗细（add_theme_constant_override outline_size）
const TOAST_CENTER_RATIO: float = 0.5   # 居中比例（label_w 乘以它算水平偏移）
const TOAST_BG_RES: String = "res://assets/ui/alpha/HVGA/toast_bg.png"
# 源 toast.lua:36 createScale9Sprite capInsets CCRectMake(20, 20, 194, 20)，贴图 306×87 PIL 实测。
# 正确公式（批 1 fde903b）：left=x/bottom=y/right=W-x-w/top=H-y-h → L20/B20/R92/T47（纹理px）。
# patch_margin 须 ÷CS(1.28125) 取整（观感专项锚定口径，同 shortcut 57b17b0）→ L16/T37/R72/B16。
const BOARD_PAD_W: float = 20.0   # board 比文字宽的边距（源 :44 labelSize.width + 20）
const BOARD_PAD_H: float = 40.0   # board 比文字高的边距（源 :44 labelSize.height + 40）
const BOARD_PATCH_L: int = 16
const BOARD_PATCH_T: int = 37
const BOARD_PATCH_R: int = 72
const BOARD_PATCH_B: int = 16
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
	# 源 showToast:60-64 替换语义：新消息顶掉未显示的排队 + 正在显示的（无队列串行）。
	_queue.clear()
	_free_current()
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

## 销毁当前显示中的 board/label（label 是 board 子节点，free board 连带）。
func _free_current() -> void:
	if _current_board != null:
		_current_board.queue_free()
		_current_board = null
		_current_label = null

# 显示循环（照源 :73-78）：HOLD 停留 → FADE 线性淡出（board.modulate 级联 label）→ 消费下一条。
func _process(delta: float) -> void:
	if _current_board != null:
		_timer += delta
		if _timer >= TOAST_HOLD:
			_current_board.modulate.a = 1.0 - clampf((_timer - TOAST_HOLD) / TOAST_FADE, 0.0, 1.0)
		if _timer >= TOAST_HOLD + TOAST_FADE:
			_free_current()
	if _current_board == null and not _queue.is_empty():
		_show_next()

func _show_next() -> void:
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
	_timer = 0.0
