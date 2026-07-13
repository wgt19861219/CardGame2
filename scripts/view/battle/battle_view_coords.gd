class_name BattleViewCoords
extends RefCounted

## 战斗坐标转换（View 层工具）— 照源 battle_scene.lua:882-886 toViewPosition。
## Logic 坐标 (x, y) + height（离地高度）→ View 像素坐标。
## 源 ed.deepProjectionX=cos(rad(90))≈0 / deepProjectionY=sin(rad(90))=1（tools.lua:16-17），
## 即正交投影：x 不变，y 直接映射为垂直偏移，地面 y=265。

const DEEP_PROJECTION_X: float = 0.0  # 源 math.cos(math.rad(90))，浮点近似 0
const DEEP_PROJECTION_Y: float = 1.0  # 源 math.sin(math.rad(90))
const GROUND_Y: float = 265.0         # 源 :885 地面 y 偏移


# 源 toViewPosition(logical_position, height)（battle_scene.lua:882-886）
# logical_position 源是 [x,y] table；Godot 侧拆 x/y + height（源第 3 参）。
static func to_view_position(logical_x: float, logical_y: float, height: float = 0.0) -> Vector2:
	return Vector2(
		logical_x + logical_y * DEEP_PROJECTION_X,
		GROUND_Y + height + logical_y * DEEP_PROJECTION_Y,
	)
