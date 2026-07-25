class_name BattleEntity
extends RefCounted

## 战斗实体基类（Logic 层）— 照源 entity.lua 翻译（Phase 2.2，2026-06-30）。
## 单位/投射物/NPC 共用：position/velocity/direction/frozen/terminated + 基础移动/碰撞/出界/冻结。
## actor tint（freeze/unfreeze）是 View 层副作用（Phase 4 接 Actor）。

const FREEZE_TINT: float = 0.4
const UNFREEZE_TINT: float = 2.5

var camp: int = 0
var radius: float = 0.0
var position: Vector2 = Vector2.ZERO
var previous_position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var height: float = 0.0
var direction: int = 1
var frozen_model: bool = false
var frozen_actor: bool = false
var terminated: bool = false
var actor: Variant = null  # View 层 Actor 引用（Phase 4）；Logic 不用
var engine: Variant = null  # engine 引用注入（set_position/is_out_of_stage 读其 stage_rect）


func update(dt: float) -> void:
	position += velocity * dt
	if velocity.x * direction < 0:
		direction *= -1


func is_out_of_stage() -> bool:
	if engine == null:
		return false
	var rect: Dictionary = engine.stage_rect
	return position.x < float(rect["minX"]) or position.x > float(rect["maxX"]) \
		or position.y < float(rect["minY"]) or position.y > float(rect["maxY"])


func collide_with(another: BattleEntity) -> bool:
	var rsum: float = radius + another.radius
	return position.distance_squared_to(another.position) < rsum * rsum


func terminate() -> void:
	terminated = true


func freeze() -> void:
	frozen_model = true
	if not frozen_actor:
		frozen_actor = true
		if actor != null and actor.has_method("tint"):
			actor.tint(FREEZE_TINT, FREEZE_TINT, FREEZE_TINT)


func unfreeze() -> void:
	frozen_model = false
	unfreeze_actor()


func unfreeze_actor() -> void:
	if frozen_actor:
		frozen_actor = false
		if actor != null and actor.has_method("tint"):
			actor.tint(UNFREEZE_TINT, UNFREEZE_TINT, UNFREEZE_TINT)  # UnitSprite.tint clamp 到 1.0=WHITE


func set_position(pos: Vector2) -> Vector2:
	if engine == null:
		position = pos
		return position
	var rect: Dictionary = engine.stage_rect
	position.x = clampf(pos.x, float(rect["minX"]), float(rect["maxX"]))
	position.y = clampf(pos.y, float(rect["minY"]), float(rect["maxY"]))
	return position
