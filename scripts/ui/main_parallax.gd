class_name MainParallax
extends RefCounted

## 主城多层视差控制器（View 层）— 照源 ui/main.lua:195 bgHorizontalScroll + :238 refreshMapPos + :116 doDragMapTouch。
## 4 容器按系数横向视差：top（基准 1）/ middle（sea 0.4）/ bottom（sky 0.3）/ verytop（0.9）。
## top.x ∈ [_map_min_x, 212]（_map_min_x = 800 - mapWidth + 212，源 :1066，可能为负→双向拖），其余层 x = 系数 × top.x（clamp）。源 drag_range.y min=max=0，垂直不动。
## 拖拽直接改 top.x + refresh（其余跟）；松手惯性 Tween（speed × 0.3，CCEaseSineOut 等价）。

const SKY_COEFF: float = 0.3
const SEA_COEFF: float = 0.4
const VERYTOP_COEFF: float = 0.9
const SCREEN_W: float = 960.0       # Godot viewport 宽（源 800 内容在 960 视口，可拖范围 = mapWidth - 视口宽）
const MAP_MAX_X: float = 212.0
const VT_MAX_X: float = 212.0
const VT_MIN_OFFSET: float = 0.0
const SCROLL_GAP: float = 0.6
const INERTIA_FACTOR: float = 0.3
const SCROLL_GAP_DEFAULT: float = 0.2
var _map_min_x: float = 0.0

var _top: Control
var _middle: Control
var _bottom: Control
var _verytop: Control
var _tween: Tween = null


func setup(top: Control, middle: Control, bottom: Control, verytop: Control, map_width: float) -> void:
	_top = top
	_middle = middle
	_bottom = bottom
	_verytop = verytop
	_map_min_x = SCREEN_W - map_width + MAP_MAX_X


# verytop 下界 = 系数×(_map_min_x + minverytop)（源 :261 联动 map_min_x）。
func refresh() -> void:
	var x: float = clampf(_top.position.x, _map_min_x, MAP_MAX_X)
	_top.position.x = x
	_middle.position.x = clampf(SEA_COEFF * x, SEA_COEFF * _map_min_x, SEA_COEFF * MAP_MAX_X)
	_bottom.position.x = clampf(SKY_COEFF * x, SKY_COEFF * _map_min_x, SKY_COEFF * MAP_MAX_X)
	_verytop.position.x = clampf(VERYTOP_COEFF * x, VERYTOP_COEFF * (_map_min_x + VT_MIN_OFFSET), VERYTOP_COEFF * VT_MAX_X)


func scroll_to(dx: float, gap: float = SCROLL_GAP_DEFAULT) -> void:
	var target: float = clampf(dx, _map_min_x, MAP_MAX_X)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = _top.create_tween()
	_tween.tween_method(_set_top_x, _top.position.x, target, gap).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_top_x(x: float) -> void:
	_top.position.x = x
	refresh()


func on_drag_begin() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func on_drag_moved(delta_x: float) -> void:
	_top.position.x += delta_x
	refresh()


func on_drag_end(velocity: float) -> void:
	var target: float = _top.position.x + velocity * INERTIA_FACTOR
	scroll_to(target, SCROLL_GAP)
