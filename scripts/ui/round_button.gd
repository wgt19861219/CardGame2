class_name RoundButton
extends Button

## 圆形触摸按钮（View 层 Step 13.5）— 照源 ui/main.lua getMainButtonTouchConfig + btRegisterClick。
## 源 mainres 每按钮配 touchCenter（圆心相对按钮 pos 的偏移）+ touchRadius（半径）。重写 has_point 实现圆形 hit test。
## size = 2 × touchRadius（方形），确保圆形完整在 Control 边界内（Godot Control 鼠标交互限于 size 矩形）。
## touchCenter 多为小值（-15..40），圆形中心 = size/2 + touch_center。

var touch_center: Vector2 = Vector2.ZERO   # 源 mainres.touchCenter（相对按钮中心偏移）


func has_point(point: Vector2) -> bool:
	var center: Vector2 = size * 0.5 + touch_center
	return point.distance_to(center) <= size.x * 0.5
