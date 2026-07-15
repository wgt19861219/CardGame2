class_name MainParallax
extends RefCounted

## 主城多层视差控制器（View 层）— 照源 ui/main.lua:195 bgHorizontalScroll + :238 refreshMapPos + :116 doDragMapTouch。
## 4 容器按系数横向视差：top（基准 1）/ middle（sea 0.4）/ bottom（sky 0.3）/ verytop（0.9）。
## top.x ∈ [_map_min_x, 212]（_map_min_x = 800 - mapWidth + 212，源 :1066，可能为负→双向拖），其余层 x = 系数 × top.x（clamp）。源 drag_range.y min=max=0，垂直不动。
## 拖拽直接改 top.x + refresh（其余跟）；松手惯性 Tween（speed × 0.3，CCEaseSineOut 等价）。

const SKY_COEFF: float = 0.3        # 源 mainres.sky_coefficient（bottom 层系数）
const SEA_COEFF: float = 0.4        # 源 mainres.sea_coefficient（middle 层系数）
const VERYTOP_COEFF: float = 0.9    # 源 mainres.verytop_coefficient（verytop 层系数）
const SCREEN_W: float = 960.0       # Godot viewport 宽（源 800 内容在 960 视口，可拖范围 = mapWidth - 视口宽）
const MAP_MAX_X: float = 212.0      # 源 drag_range.x.max = offset_x
const VT_MAX_X: float = 212.0       # 源 drag_range.x.maxverytop = offset_x_verytop
const VT_MIN_OFFSET: float = 0.0    # 源 drag_range.x.minverytop = offset_x_verytopmin
const SCROLL_GAP: float = 0.6       # 源 doDragMapTouch ended gap
const INERTIA_FACTOR: float = 0.3   # 源 ended: dx + speed*gap/2 = speed*0.3
const SCROLL_GAP_DEFAULT: float = 0.2   # 源 bgHorizontalScroll addition.gap or 0.2
var _map_min_x: float = 0.0         # 源 :1066 map_min_x = 800 - mapWidth + offset_x（运行时算，可能为负→双向拖）

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
	_map_min_x = SCREEN_W - map_width + MAP_MAX_X   # 源 :1066（mapWidth = grass_left+right 宽）


# 源 refreshMapPos:238-264（y 不动，仅 x）。top.x clamp [_map_min_x, 212]，middle/bottom = 系数×top.x，
# verytop 下界 = 系数×(_map_min_x + minverytop)（源 :261 联动 map_min_x）。
func refresh() -> void:
	var x: float = clampf(_top.position.x, _map_min_x, MAP_MAX_X)
	_top.position.x = x
	_middle.position.x = clampf(SEA_COEFF * x, SEA_COEFF * _map_min_x, SEA_COEFF * MAP_MAX_X)
	_bottom.position.x = clampf(SKY_COEFF * x, SKY_COEFF * _map_min_x, SKY_COEFF * MAP_MAX_X)
	_verytop.position.x = clampf(VERYTOP_COEFF * x, VERYTOP_COEFF * (_map_min_x + VT_MIN_OFFSET), VERYTOP_COEFF * VT_MAX_X)


# 源 bgHorizontalScroll:195-226 Tween 4 容器到 dx（clamp [_map_min_x, 212]）。CCEaseSineOut → TRANS_SINE + EASE_OUT。
func scroll_to(dx: float, gap: float = SCROLL_GAP_DEFAULT) -> void:
	var target: float = clampf(dx, _map_min_x, MAP_MAX_X)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = _top.create_tween()
	_tween.tween_method(_set_top_x, _top.position.x, target, gap).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_top_x(x: float) -> void:
	_top.position.x = x
	refresh()


# 源 doDragMapTouch began:122-128：停 Tween，记录 top 起点（top.x 当前即起点，无需额外存）。
func on_drag_begin() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


# 源 doDragMapTouch moved:144-158：top.x += delta；refresh（源 mx=mapOrix+dx，增量累加等价）。
func on_drag_moved(delta_x: float) -> void:
	_top.position.x += delta_x
	refresh()


# 源 doDragMapTouch ended:159-175：惯性 target = top.x + speed×0.3；scroll_to（gap=0.6）。
func on_drag_end(velocity: float) -> void:
	var target: float = _top.position.x + velocity * INERTIA_FACTOR
	scroll_to(target, SCROLL_GAP)
