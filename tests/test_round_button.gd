extends GutTest
# RoundButton 圆形触摸 hit test（照源 mainres touchCenter/touchRadius，has_point 重写）。

# 中心 + 边缘内点 → true。
func test_has_point_inside() -> void:
	var btn := RoundButton.new()
	btn.size = Vector2(200, 200)   # radius = size.x * 0.5 = 100，center = (100, 100)
	assert_true(btn.has_point(Vector2(100, 100)), "中心点在圆内")
	assert_true(btn.has_point(Vector2(150, 100)), "距中心 50 < 100 在圆内")
	btn.free()


# 圆外点 → false。
func test_has_point_outside() -> void:
	var btn := RoundButton.new()
	btn.size = Vector2(200, 200)
	assert_false(btn.has_point(Vector2(211, 100)), "距中心 111 > 100 圆外")
	btn.free()


# touch_center 偏移圆心。
func test_has_point_touch_center() -> void:
	var btn := RoundButton.new()
	btn.size = Vector2(200, 200)
	btn.touch_center = Vector2(50, 0)   # center 偏移到 (150, 100)
	assert_true(btn.has_point(Vector2(150, 100)), "偏移圆心在圆内")
	assert_false(btn.has_point(Vector2(39, 100)), "距偏移圆心 111 > 100 圆外")
	btn.free()
