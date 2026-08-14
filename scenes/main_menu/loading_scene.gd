extends Control

## 加载场景（View 层 Step 4.2）：启动入口过渡。
## 单机版资源随 PCK 加载，用进度条过渡后切主界面（源 loading.lua 的 Godot 适配）。
## View 纯 UI：进度显示 + 切场景。节点动态建（避 MCP add_node 的 parent path bug）。

const PROGRESS_SPEED: float = 1.0   # 进度增速（约 1s 满）
const PERCENT_FULL: float = 100.0
const PROGRESS_DONE: float = 1.0
const MAIN_SCENE: String = "res://scenes/main_menu/main_scene.tscn"
const BG_TEXTURE: String = "res://assets/ui/alpha/HVGA/bg.jpg"

var _bg: TextureRect
var _bar: ProgressBar
var _label: Label
var _progress: float = 0.0

func _ready() -> void:
	_build_ui()

## 动态建背景 + 进度条 + 百分比（不依赖 .tscn 子节点，治 MCP parent path bug）。
func _build_ui() -> void:
	_bg = TextureRect.new()
	_bg.texture = load(BG_TEXTURE)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.position = Vector2.ZERO
	# 显式全屏 size（不靠 anchors）：loading_scene 根 Control 未设全屏锦点，子节点 anchors 算出 size=0；
	# 加 EXPAND_IGNORE_SIZE 后不再被纹理原始尺寸撑大 → 底图不显示。直接取 viewport size 拉伸铺满（照源 loading.lua:29 bg 铺满屏）。 
	_bg.size = get_viewport_rect().size
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_bar = ProgressBar.new()
	_bar.position = Vector2(330, 580)
	_bar.size = Vector2(300, 20)
	_bar.max_value = int(PERCENT_FULL)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	_label = Label.new()
	_label.position = Vector2(430, 555)
	_label.text = "0%"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

func _process(delta: float) -> void:
	_progress = min(_progress + delta * PROGRESS_SPEED, PROGRESS_DONE)
	_bar.value = _progress * PERCENT_FULL
	_label.text = "%d%%" % int(_progress * PERCENT_FULL)
	if _progress >= PROGRESS_DONE:
		set_process(false)
		SceneManager.change_scene(MAIN_SCENE)
