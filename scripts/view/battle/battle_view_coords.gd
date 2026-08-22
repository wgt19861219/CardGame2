class_name BattleViewCoords
extends RefCounted

## 战斗坐标转换（View 层工具）— 照源 battle_scene.lua:882-886 toViewPosition。
## Logic 坐标 (x, y) + height（离地高度）→ View 像素坐标。
## 即正交投影：x 不变，y 直接映射为垂直偏移，地面 y=265。
##
## 职责边界（2026-07-31 战斗 HUD 重构后）：本类仅服务**战斗世界对象**（B 类坐标）——
## actor 站位/行走、特效播放、伤害飘字、掉落物等跟随镜头、含离地高度正交投影的对象。
## HUD 固定界面（A 类：血条/按钮/面板/标记）已改用 Godot 原生锚点/容器（battle_hud.tscn），
## 不再经本类转换。

const DEEP_PROJECTION_X: float = 0.0
const DEEP_PROJECTION_Y: float = 1.0
const GROUND_Y: float = 265.0   # 源世界地面逻辑高度（cocos 坐标），不随 viewport 迁移
const OFFSET_X: float = 0.0
const BASE_Y: float = 480.0


# Cocos 800×480（左下原点）→ Godot 800×480（左上原点）转换。
# 战斗 HUD 层（A 类）已改 Godot 原生坐标不再调用本方法；仍被部分 UI 面板
# （equip_craft/pop_tavern_loot/story_view）及 battle_loot_view 飞行动画使用。
static func to_godot(cx: float, cy: float) -> Vector2:
	return Vector2(cx + OFFSET_X, BASE_Y - cy)


# logical_position 源是 [x,y] table；Godot 侧拆 x/y + height（源第 3 参）。
# 仅 B 类战斗世界对象调用（actor/特效/飘字/掉落）。
static func to_view_position(logical_x: float, logical_y: float, height: float = 0.0) -> Vector2:
	var cocos_x: float = logical_x + logical_y * DEEP_PROJECTION_X
	var cocos_y: float = GROUND_Y + height + logical_y * DEEP_PROJECTION_Y
	return to_godot(cocos_x, cocos_y)
