class_name BattleViewCoords
extends RefCounted

## 战斗坐标转换（View 层工具）— 照源 battle_scene.lua:882-886 toViewPosition。
## Logic 坐标 (x, y) + height（离地高度）→ View 像素坐标。
## 源 ed.deepProjectionX=cos(rad(90))≈0 / deepProjectionY=sin(rad(90))=1（tools.lua:16-17），
## 即正交投影：x 不变，y 直接映射为垂直偏移，地面 y=265。

const DEEP_PROJECTION_X: float = 0.0  # 源 math.cos(math.rad(90))，浮点近似 0
const DEEP_PROJECTION_Y: float = 1.0  # 源 math.sin(math.rad(90))
const GROUND_Y: float = 265.0         # 源 :885 地面 y（Cocos 800×480 左下）
const OFFSET_X: float = 80.0          # 源 800→Godot 960 居中偏移（to_godot）
const BASE_Y: float = 560.0           # 源 480→Godot 640 翻 Y 基准（to_godot）


# 源 cocos(800×480 左下) → Godot(960×640 左上)：cx+80（居中），560-cy（翻 Y）。
# 同 daily_login_builder/handbook_builder/midas_panel 坐标转换标准（Phase 4 battle 早期漏转，2026-07-14 补）。
static func to_godot(cx: float, cy: float) -> Vector2:
	return Vector2(cx + OFFSET_X, BASE_Y - cy)


# 源 toViewPosition(logical_position, height)（battle_scene.lua:882-886）→ Cocos View 坐标 → Godot（to_godot 套用）。
# logical_position 源是 [x,y] table；Godot 侧拆 x/y + height（源第 3 参）。
static func to_view_position(logical_x: float, logical_y: float, height: float = 0.0) -> Vector2:
	var cocos_x: float = logical_x + logical_y * DEEP_PROJECTION_X
	var cocos_y: float = GROUND_Y + height + logical_y * DEEP_PROJECTION_Y
	return to_godot(cocos_x, cocos_y)
