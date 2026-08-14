class_name NpcActor
extends Node2D

## NPC actor（View 包装）— 照源 npc.lua:128-240 NpcActorCreate 翻译（Phase 4，A-npc）。
## NPC = 场景装饰实体（城堡/旗子）+ 英雄召唤单位（TitanHead 双头 npc_up/down），进 engine.npc_list。
## 与 BattleActor 区别：无血条、无 interp 插值、无 knockup，仅 position 同步 + FCA puppet + 通用动作。
## puppet 复用 UnitSprite（FCA 序列帧，play_action 通用接口 = 源 puppet:setAction+setLoop）。
## 入 actor_list 复用 _advance_actor_list 推进（源 actor_list 混装 UnitActor+NpcActor，:791-812 统一推进）。

const UnitSprite = preload("res://scripts/view/battle/unit_sprite.gd")
const BattleViewCoords = preload("res://scripts/view/battle/battle_view_coords.gd")

var model: Variant = null    # BattleNpc（duck：position/action_name/action_loop/terminated）
var puppet: Variant = null   # UnitSprite（FCA 动画；Variant 避 preload :Script 注解推断坑）
var in_scene: bool = false   # 入场标记（源 :144，sync_actors 置 true）


func setup(p_model: Variant, p_cm: Variant) -> void:
	model = p_model
	puppet = UnitSprite.new()
	add_child(puppet)
	puppet.setup(model, p_cm)
	update_view()


# _dt 可选参兼容 _advance_actor_list 的 update_view(dt) 调用（NPC 不用 dt，无插值/无 walk）。
func update_view(_dt: float = 0.0) -> void:
	if model == null:
		return
	var pos: Vector2 = Vector2(float(model.position.x), float(model.position.y))
	position = BattleViewCoords.to_view_position(pos.x, pos.y, 0.0)
	z_index = -int(pos.y)


# NPC 无战斗动作分发（Birth/Idle/Idle2 全走通用）；Death 由 on_npc_death 单独淡出。
func on_start_new_action() -> void:
	if puppet == null or model == null:
		return
	apply_action_named(String(model.action_name), bool(model.action_loop))


## T4 事件分发入口（动作来自事件快照，见 battle_actor.apply_action_named 注）。
func apply_action_named(action: String, loop: bool) -> void:
	if puppet == null:
		return
	puppet.play_action(action, loop)


func on_npc_death() -> void:
	if puppet != null:
		puppet.play_death()


# 为无 actor 的 npc 建 NpcActor + 入 actor_list + 挂 main_layer。scene 各字段由 battle_scene 传。
static func sync_actors(scene: Node) -> void:
	var engine: Variant = scene.engine
	if engine == null:
		return
	var cm: Variant = scene.cm
	for npc in engine.foreach_npc():
		if scene._actors_by_unit.get(npc) != null:
			continue
		var actor: NpcActor = NpcActor.new()
		actor.setup(npc, cm)
		scene._actors_by_unit[npc] = actor
		actor.in_scene = true
		scene.actor_list.append(actor)
		scene.main_layer.add_child(actor)
