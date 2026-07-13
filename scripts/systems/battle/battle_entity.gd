class_name BattleEntity
extends RefCounted

## 战斗实体基类（Logic 层）— 照源 entity.lua 翻译（Phase 2.2，2026-06-30）。
## 单位/投射物/NPC 共用：position/velocity/direction/frozen/terminated + 基础移动/碰撞/出界/冻结。
## 源调全局 ed.engine.stage_rect（entity.lua:42,88）→ Godot 侧持 engine 引用注入（确定性多实例，替代全局）。
## actor tint（freeze/unfreeze）是 View 层副作用（Phase 4 接 Actor）。

const FREEZE_TINT: float = 0.4   # 源 entity.lua:62 tint(0.4,0.4,0.4) 变暗
const UNFREEZE_TINT: float = 2.5  # 源 entity.lua:80 tint(2.5,2.5,2.5) 恢复亮色

var camp: int = 0
var radius: float = 0.0
var position: Vector2 = Vector2.ZERO
var previous_position: Vector2 = Vector2.ZERO  # 源 unit.update:902 pp（engine.add_unit 已用；View 双缓冲插值 Phase 4）
var velocity: Vector2 = Vector2.ZERO
var height: float = 0.0
var direction: int = 1
var frozen_model: bool = false
var frozen_actor: bool = false
var terminated: bool = false
var actor: Variant = null  # View 层 Actor 引用（Phase 4）；Logic 不用
var engine: Variant = null  # engine 引用注入（set_position/is_out_of_stage 读其 stage_rect）


# 源 Entity update（entity.lua:27-35）：位置按 velocity 推进 + direction 翻转
func update(dt: float) -> void:
	position += velocity * dt
	if velocity.x * direction < 0:
		direction *= -1


# 源 isOutOfStage（entity.lua:38-44）
func is_out_of_stage() -> bool:
	if engine == null:
		return false
	var rect: Dictionary = engine.stage_rect
	return position.x < float(rect["minX"]) or position.x > float(rect["maxX"]) \
		or position.y < float(rect["minY"]) or position.y > float(rect["maxY"])


# 源 collideWith（entity.lua:47-50）：距离平方 < (r1+r2)²
func collide_with(another: BattleEntity) -> bool:
	var rsum: float = radius + another.radius
	return position.distance_squared_to(another.position) < rsum * rsum


# 源 terminate（entity.lua:53-55）
func terminate() -> void:
	terminated = true


# 源 freeze（entity.lua:58-66）：frozen_model=true + frozen_actor tint(0.4) 变暗。
func freeze() -> void:
	frozen_model = true
	if not frozen_actor:
		frozen_actor = true
		if actor != null and actor.has_method("tint"):
			actor.tint(FREEZE_TINT, FREEZE_TINT, FREEZE_TINT)


# 源 unfreeze（entity.lua:69-72）
func unfreeze() -> void:
	frozen_model = false
	unfreeze_actor()


# 源 unfreezeActor（entity.lua:75-82）：frozen_actor=false + tint(2.5) 恢复亮色。
func unfreeze_actor() -> void:
	if frozen_actor:
		frozen_actor = false
		if actor != null and actor.has_method("tint"):
			actor.tint(UNFREEZE_TINT, UNFREEZE_TINT, UNFREEZE_TINT)  # UnitSprite.tint clamp 到 1.0=WHITE


# 源 setPosition（entity.lua:87-91）：钳制到 stage_rect
func set_position(pos: Vector2) -> Vector2:
	if engine == null:
		position = pos
		return position
	var rect: Dictionary = engine.stage_rect
	position.x = clampf(pos.x, float(rect["minX"]), float(rect["maxX"]))
	position.y = clampf(pos.y, float(rect["minY"]), float(rect["maxY"]))
	return position
