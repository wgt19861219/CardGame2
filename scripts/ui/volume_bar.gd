class_name VolumeBar
extends Control

## 音量滑条控件（跨域通用 View 工具）— 底槽 + 填充两贴图叠放，region 按比例裁剪填充
## （裁剪式进度显示，不拉伸变形）。交互：整命中区点击/拖动横向定位 → value_changed(ratio)。
## 宿主初值赋值走 set_value（静默不发信号，防宿主回调回环）；用户交互才 emit。
## 命中区高度可大于条体（行高全高易点按），条体在命中区内垂直居中。
##
## 首用（2026-09-19 用户指示「背景音和音效分开设置+音量调节」）：setup_panel 双通道音量条。
## 贴图 loading_bar 对（槽 _bg 暗金凹槽 + 条体亮青蓝高光）——VisualCoding 选型：与
## main_vit_tips 暖棕框同族原配嵌套对（414×33 同画布同心），宽高比 12.5≈目标近零形变。

signal value_changed(ratio: float)

const BAR_BG_RES: String = "res://assets/ui/alpha/HVGA/loading_bar_bg.png"
const BAR_FILL_RES: String = "res://assets/ui/alpha/HVGA/loading_bar.png"
const BAR_SIZE: Vector2 = Vector2(190.0, 15.0)   # 条体显示尺寸（点）

var _bg: TextureRect = null
var _fill: TextureRect = null
var _ratio: float = 1.0


func _init(hit_height: float = BAR_SIZE.y) -> void:
	# 命中区默认=条体高；宿主行内可传行高（55）提升点按容差，条体仍居中绘制。
	custom_minimum_size = Vector2(BAR_SIZE.x, hit_height)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	size = custom_minimum_size   # 非容器宿主兜底（命中区≠0）；容器宿主随后由布局覆盖
	_bg = _make_rect(BAR_BG_RES)
	add_child(_bg)
	_fill = _make_rect(BAR_FILL_RES)
	_wrap_atlas(_fill)   # TextureRect 无裁剪属性（region_*/texture_rect 均为误记），AtlasTexture 裁剪
	add_child(_fill)
	# 显式 position/size（anchor 全 0 无联动）：实机诊断锚定方案被 AtlasTexture region 变更
	# 通知链重置（fill anchor 0.5→0、高塌 0，bg 反而正常）——黑盒规避，不逆向引擎机制。
	var bar_y: float = (custom_minimum_size.y - BAR_SIZE.y) * 0.5
	_bg.position = Vector2(0.0, bar_y)
	_bg.size = BAR_SIZE
	_fill.position = Vector2(0.0, bar_y)
	_fill.size = Vector2(BAR_SIZE.x * _ratio, BAR_SIZE.y)
	_refresh_fill()


# 宿主初值/外部驱动入口（静默）：不 emit，宿主自己负责调 AudioPlayer。
func set_value(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	_refresh_fill()


func get_value() -> float:
	return _ratio


# 点击按下 / 按住拖动定位（drag focus：press 被本控件接收后，motion 持续路由到此）。
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_point_to_ratio(mb.position.x)
			accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_point_to_ratio(mm.position.x)
			accept_event()


func _point_to_ratio(local_x: float) -> void:
	if size.x <= 0.0:
		return   # 未布局防除零
	var before: float = _ratio
	_ratio = clampf(local_x / size.x, 0.0, 1.0)
	if is_equal_approx(_ratio, before):
		return
	_refresh_fill()
	value_changed.emit(_ratio)


# 裁剪式填充：AtlasTexture.region 显示源纹理左段 ratio 比例，fill.size 宽同步 × ratio
# ——裁剪区与显示区宽高比恒等比，条体图案不变形；画布内透明留边照常参与，槽条同心。
func _refresh_fill() -> void:
	if _fill == null or not (_fill.texture is AtlasTexture):
		return
	var atlas: AtlasTexture = _fill.texture
	atlas.region = Rect2(0.0, 0.0, atlas.atlas.get_width() * _ratio, atlas.atlas.get_height())
	_fill.size = Vector2(BAR_SIZE.x * _ratio, BAR_SIZE.y)


# TextureRect 无纹理裁剪属性（Sprite2D 的 region_* 不适用）——包一层 AtlasTexture
# （编辑器同款机制），初始 region=全图，后续 _refresh_fill 动态改 region。
func _wrap_atlas(rect: TextureRect) -> void:
	var tex: Texture2D = rect.texture
	if tex == null or tex is AtlasTexture:
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(Vector2.ZERO, tex.get_size())
	rect.texture = atlas


func _make_rect(res: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = load(res) as Texture2D
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
