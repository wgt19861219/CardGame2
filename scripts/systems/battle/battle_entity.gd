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
var engine: Variant = null  # engine 引用注入（set_position/is_out_of_stage 读其 stage_rect；T4-B7：actor View 桥字段退役，映射归 battle_scene）


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


# ---- 表现事件发射（阶段三 T4）--------------------------------------------------------
# Logic 层唯一表现出口：经 engine.events 队列，View（battle_scene）逐帧 drain 渲染。
# 替代旧「u.get("actor") + has_method 守卫 + 直调」鸭子链；engine 缺席（headless 裸实体）静默丢弃。

func emit_event(e: BattleEvent) -> void:
	if engine != null:
		engine.emit_event(e)


func emit_popup(text: String, color: String, crit: bool = false, style: String = "damage") -> void:
	emit_event(BattleEvent.popup(self, text, color, crit, style))


func emit_add_effect(effect_name: String, zorder: int = 0) -> void:
	emit_event(BattleEvent.add_effect(self, effect_name, zorder))


func emit_remove_effect(effect_name: String) -> void:
	emit_event(BattleEvent.remove_effect(self, effect_name))


func emit_play_effect(effect_name: String, at: Vector2, p_scale: float = 1.0, p_height: float = 0.0, zorder: int = 0) -> void:
	emit_event(BattleEvent.play_effect(self, effect_name, at, p_scale, p_height, zorder))


func emit_tint(p_r: float, p_g: float, p_b: float) -> void:
	emit_event(BattleEvent.tint(self, Vector3(p_r, p_g, p_b)))


func emit_voice(unit_name: String, suffix: String) -> void:
	emit_event(BattleEvent.voice(self, unit_name, suffix))


func emit_shader_push(token: int, shader_name: String) -> void:
	emit_event(BattleEvent.shader_push(self, token, shader_name))


func emit_shader_remove(token: int) -> void:
	emit_event(BattleEvent.shader_remove(self, token))


func emit_shake(max_height: float, shake_time: float, shake_num: int) -> void:
	emit_event(BattleEvent.shake(self, max_height, shake_time, shake_num))


func emit_gold_drop() -> void:
	emit_event(BattleEvent.gold_drop(self))


func emit_launch(time: float) -> void:
	emit_event(BattleEvent.launch(self, time))


func emit_new_action(action: String, loop: bool) -> void:
	emit_event(BattleEvent.new_action(self, action, loop))


func emit_puppet(action: String, loop: bool) -> void:
	emit_event(BattleEvent.puppet(self, action, loop))


func emit_npc_death() -> void:
	emit_event(BattleEvent.npc_death(self))


func emit_zspeed(v: float) -> void:
	emit_event(BattleEvent.zspeed(self, v))


func terminate() -> void:
	terminated = true


func freeze() -> void:
	frozen_model = true
	if not frozen_actor:
		frozen_actor = true
		emit_tint(FREEZE_TINT, FREEZE_TINT, FREEZE_TINT)


func unfreeze() -> void:
	frozen_model = false
	unfreeze_actor()


func unfreeze_actor() -> void:
	if frozen_actor:
		frozen_actor = false
		emit_tint(UNFREEZE_TINT, UNFREEZE_TINT, UNFREEZE_TINT)  # UnitSprite.tint clamp 到 1.0=WHITE


func set_position(pos: Vector2) -> Vector2:
	if engine == null:
		position = pos
		return position
	var rect: Dictionary = engine.stage_rect
	position.x = clampf(pos.x, float(rect["minX"]), float(rect["maxX"]))
	position.y = clampf(pos.y, float(rect["minY"]), float(rect["maxY"]))
	return position
