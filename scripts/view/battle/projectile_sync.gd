class_name ProjectileSync
extends RefCounted

## 投射物同步 helper（View 层）— 照 battle_scene.gd _sync_actors 范式，遍历 engine.projectile_list。
## 创建/复用 ProjectileActor，挂 main_layer + 进 scene.actor_list 统一推进（照源 actor_list 混装模式）。
## Logic 层 BattleProjectile 已有 actor: Variant 字段（battle_entity.gd:21），此处填字段，Logic 不感知 View。

const ProjectileActor = preload("res://scripts/view/battle/projectile_actor.gd")
const ChainActor = preload("res://scripts/view/battle/chain_actor.gd")


## 每 tick 同步：为无 actor 的投射物/链式创建 View 包装；已 terminated 的由 _advance_actor_list 销毁。
## projectile_list 混装 BattleProjectile + BattleChain（照源 addProjectile/add_chain 同 list），
## 按 class_name 分流：BattleChain→ChainActor（连线拉伸+旋转），其余→ProjectileActor（飞行体）。
## scene 持 engine/main_layer/actor_list（鸭子读，不 import BattleScene 类型）。
static func sync(scene: Node) -> void:
	var engine: Variant = scene.engine
	if engine == null:
		return
	var main_layer: Node2D = scene.main_layer
	var actor_list: Array = scene.actor_list
	for proj in engine.projectile_list:
		if bool(proj.terminated):
			continue
		var actor: Variant = proj.actor
		if actor != null:
			continue
		var new_actor: Node2D = null
		if proj is BattleChain:
			new_actor = ChainActor.new()
		else:
			new_actor = ProjectileActor.new()
		new_actor.setup(proj)
		proj.actor = new_actor
		main_layer.add_child(new_actor)
		actor_list.append(new_actor)
