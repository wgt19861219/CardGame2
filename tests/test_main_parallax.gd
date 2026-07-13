extends GutTest
# MainParallax 视差（照源 ui/main.lua:238 refreshMapPos + :195 bgHorizontalScroll + :116 doDragMapTouch）。
# 4 容器按系数：top（基准 1）/ middle（sea 0.4）/ bottom（sky 0.3）/ verytop（0.9），top.x∈[0,212]。

var _parallax: MainParallax
var _top: Control
var _middle: Control
var _bottom: Control
var _verytop: Control


func before_each() -> void:
	_top = Control.new()
	_middle = Control.new()
	_bottom = Control.new()
	_verytop = Control.new()
	add_child(_top)
	add_child(_middle)
	add_child(_bottom)
	add_child(_verytop)
	_parallax = MainParallax.new()
	_parallax.setup(_top, _middle, _bottom, _verytop)


func after_each() -> void:
	_parallax = null
	for c in [_top, _middle, _bottom, _verytop]:
		if c != null:
			c.free()


# 源 refreshMapPos:238-264：top.x=100 → middle=0.4×100=40 / bottom=0.3×100=30 / verytop=0.9×100=90。
func test_refresh_coefficients() -> void:
	_top.position.x = 100.0
	_parallax.refresh()
	assert_almost_eq(_top.position.x, 100.0, 0.01, "top 不变（基准）")
	assert_almost_eq(_middle.position.x, 40.0, 0.01, "middle = sea 0.4 × 100")
	assert_almost_eq(_bottom.position.x, 30.0, 0.01, "bottom = sky 0.3 × 100")
	assert_almost_eq(_verytop.position.x, 90.0, 0.01, "verytop = 0.9 × 100")


# 源 refreshMapPos clamp（:210-213）：top.x 超 212 → clamp 212，其余按系数×212。
func test_refresh_clamp_max() -> void:
	_top.position.x = 300.0
	_parallax.refresh()
	assert_almost_eq(_top.position.x, 212.0, 0.01, "top clamp 到 max 212")
	assert_almost_eq(_middle.position.x, 84.8, 0.01, "middle = 0.4 × 212")
	assert_almost_eq(_bottom.position.x, 63.6, 0.01, "bottom = 0.3 × 212")
	assert_almost_eq(_verytop.position.x, 190.8, 0.01, "verytop = 0.9 × 212")


# 源 clamp 下界：top.x 负 → clamp 0，其余全 0。
func test_refresh_clamp_min() -> void:
	_top.position.x = -50.0
	_parallax.refresh()
	assert_almost_eq(_top.position.x, 0.0, 0.01, "top clamp 到 min 0")
	assert_almost_eq(_middle.position.x, 0.0, 0.01, "middle = 0.4 × 0")
	assert_almost_eq(_bottom.position.x, 0.0, 0.01, "bottom = 0")
	assert_almost_eq(_verytop.position.x, 0.0, 0.01, "verytop = 0")


# 源 doDragMapTouch moved:144-158：top.x += delta，refresh 让其余按系数跟。
func test_drag_moved_accumulates() -> void:
	_parallax.on_drag_begin()
	_parallax.on_drag_moved(100.0)   # top 0 → 100
	assert_almost_eq(_top.position.x, 100.0, 0.01, "top += delta 100")
	assert_almost_eq(_middle.position.x, 40.0, 0.01, "middle 跟 0.4×100")
	assert_almost_eq(_bottom.position.x, 30.0, 0.01, "bottom 跟 0.3×100")
	assert_almost_eq(_verytop.position.x, 90.0, 0.01, "verytop 跟 0.9×100")


# on_drag_moved 累加超 max → clamp（拖超范围截断）。
func test_drag_moved_clamp() -> void:
	_parallax.on_drag_begin()
	_parallax.on_drag_moved(500.0)   # top 0 → 500 → clamp 212
	assert_almost_eq(_top.position.x, 212.0, 0.01, "top clamp 212")
	assert_almost_eq(_verytop.position.x, 190.8, 0.01, "verytop = 0.9×212")
