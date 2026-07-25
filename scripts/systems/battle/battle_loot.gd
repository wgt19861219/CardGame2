class_name BattleLoot
extends RefCounted

## 战斗掉落物（Logic 层）— 照源 loot.lua:65-79（update 物理）翻译（Phase 2.6，2026-07-01）。
## LootCreate 的 CCNode/CCMenuItemImage/CCAction/CCSprite 特效（:8-61）+ onTapped/onAutoCollect
## 的拾取动画（:82-127）是 View，Phase 4 接。Logic：抛物运动 + 边界反弹 + life 衰减 + terminated。
## 协作者：monster.position（出生点）。bound（源 visibleOrigin.x）注入，默认 0。

const GRAVITY: float = -1000.0
const BOUND_LIMIT: float = 785.0
const BOUNCE_FACTOR: float = -1.5
const LIFE_DEFAULT: float = 0.6
const VELOCITY_X_PER_IDX: float = 100.0
const VELOCITY_Y: float = -100.0
const VELOCITY_Z: float = 300.0

var id: Variant = null
var type: Variant = null
var icon: Variant = null
var position: Vector2 = Vector2.ZERO
var height: float = 0.0
var velocity: Vector3 = Vector3.ZERO  # x,y 平面 + z=height 速度（源 velocity[1/2/3]）
var life: float = LIFE_DEFAULT
var terminated: bool = false
var bound: float = 0.0


func _init(p_icon: Variant, p_type: Variant, monster: Variant, idx: int, p_id: Variant) -> void:
	id = p_id
	type = p_type
	icon = p_icon
	position = monster.position
	height = 0.0
	velocity = Vector3(VELOCITY_X_PER_IDX * float(idx), VELOCITY_Y, VELOCITY_Z)
	life = LIFE_DEFAULT
	terminated = false
	bound = 0.0


func update(dt: float) -> void:
	if life <= 0.0 or terminated:
		return
	life -= dt
	if position.x > BOUND_LIMIT - bound and velocity.x > 0.0:
		velocity.x *= BOUNCE_FACTOR
	position.x += velocity.x * dt
	position.y += velocity.y * dt
	height += velocity.z * dt
	velocity.z += GRAVITY * dt
	# node:setPosition（View）Phase 4


func on_tapped() -> void:
	terminated = true
	# ed.playEffect + chest_open/icon 飞向 marker（View）Phase 4


func on_auto_collect() -> void:
	terminated = true
	# ed.playEffect + chest 飞向 marker（View）Phase 4
