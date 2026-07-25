class_name BattleViewCoords
extends RefCounted

## 战斗坐标转换（View 层工具）— 照源 battle_scene.lua:882-886 toViewPosition。
## Logic 坐标 (x, y) + height（离地高度）→ View 像素坐标。
## 即正交投影：x 不变，y 直接映射为垂直偏移，地面 y=265。

const DEEP_PROJECTION_X: float = 0.0
const DEEP_PROJECTION_Y: float = 1.0
const GROUND_Y: float = 265.0
const OFFSET_X: float = 80.0
const BASE_Y: float = 560.0


# 同 daily_login_builder/handbook_builder/midas_panel 坐标转换标准（Phase 4 battle 早期漏转，2026-07-14 补）。
static func to_godot(cx: float, cy: float) -> Vector2:
	return Vector2(cx + OFFSET_X, BASE_Y - cy)


# logical_position 源是 [x,y] table；Godot 侧拆 x/y + height（源第 3 参）。
static func to_view_position(logical_x: float, logical_y: float, height: float = 0.0) -> Vector2:
	var cocos_x: float = logical_x + logical_y * DEEP_PROJECTION_X
	var cocos_y: float = GROUND_Y + height + logical_y * DEEP_PROJECTION_Y
	return to_godot(cocos_x, cocos_y)
