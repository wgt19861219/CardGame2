extends GutTest

## NpcActor View 装配 + 动作桥单测（A-npc Phase 4）。
## 验证：setup 装配 puppet、sync_actors foreach_npc 装配入 actor_list、BattleNpc.die/set_action 桥接 actor。

const NpcActor = preload("res://scripts/view/battle/npc_actor.gd")
const BattleNpc = preload("res://scripts/systems/battle/battle_npc.gd")


# mock 场景（sync_actors 需：engine/cm/actor_list/main_layer）
class _MockScene extends Node2D:
	var engine: Variant = null
	var cm: Variant = null
	var main_layer: Node2D = null
	var actor_list: Array = []


# mock NPC（duck：position/action_name/action_loop/actor/camp/info/terminated）
class _MockNpc extends RefCounted:
	var position: Vector2 = Vector2(100.0, 200.0)
	var action_name: Variant = "Idle"
	var action_loop: bool = true
	var actor: Variant = null
	var camp: int = 0
	var info: Dictionary = {}
	var terminated: bool = false


class _MockEngine extends RefCounted:
	var events: Array = []   # T4：表现事件队列
	func emit_event(e: Variant) -> void:
		events.append(e)
	var ticks: int = 0
	var npcs: Array = []
	func foreach_npc() -> Array:
		return npcs
	func on_npc_die(_npc: Variant) -> void:
		pass


# mock cm：get_raw_table 返空 → UnitSprite 降级头像（不依赖 FCA 资源，headless 可跑）
class _MockCm extends RefCounted:
	func get_raw_table(_key: String) -> Dictionary:
		return {}


# mock actor：计数 on_start_new_action / on_npc_death（验证 BattleNpc 桥接）
class _MockActor extends RefCounted:
	var start_count: int = 0
	var death_count: int = 0
	func on_start_new_action() -> void:
		start_count += 1
	func on_npc_death() -> void:
		death_count += 1


func test_npc_actor_assembly() -> void:
	var npc := _MockNpc.new()
	var actor: NpcActor = NpcActor.new()
	add_child_autofree(actor)
	actor.setup(npc, _MockCm.new())
	assert_not_null(actor.puppet, "setup 装配 UnitSprite puppet")
	assert_eq(actor.puppet.get_parent(), actor, "puppet 挂 NpcActor 节点")
	assert_eq(actor.model, npc, "model 绑定 npc")


func test_sync_actors_assembles_npc() -> void:
	var scene := _MockScene.new()
	add_child_autofree(scene)
	scene.main_layer = Node2D.new()
	scene.add_child(scene.main_layer)
	scene.cm = _MockCm.new()
	var engine := _MockEngine.new()
	var npc := _MockNpc.new()
	engine.npcs = [npc]
	scene.engine = engine
	NpcActor.sync_actors(scene)
	assert_eq(scene.actor_list.size(), 1, "1 个无 actor 的 npc → 装配 1 NpcActor 入 actor_list")
	assert_not_null(npc.actor, "npc.actor 被赋 NpcActor")
	assert_true(bool(npc.actor.in_scene), "NpcActor.in_scene = true")
	assert_true(npc.actor.has_method("on_start_new_action"), "NpcActor 有 on_start_new_action（动作桥）")
	assert_true(npc.actor.has_method("on_npc_death"), "NpcActor 有 on_npc_death（死亡桥）")
	# 二次 sync 跳过已有 actor 的 npc
	NpcActor.sync_actors(scene)
	assert_eq(scene.actor_list.size(), 1, "已有 actor 的 npc 二次 sync 跳过，不重复装配")


func test_sync_actors_skips_empty_engine() -> void:
	var scene := _MockScene.new()
	add_child_autofree(scene)
	scene.engine = null   # engine 缺失守卫
	NpcActor.sync_actors(scene)
	assert_eq(scene.actor_list.size(), 0, "engine=null → sync_actors 直接返，不装配")


func test_battle_npc_die_bridges_actor() -> void:
	var engine := _MockEngine.new()
	var npc := BattleNpc.new({"Position X": 0.0, "Position Y": 0.0, "Puppet": "x"}, engine, false)
	npc.die()
	var deaths: Array = engine.events.filter(func(e): return e.type == BattleEvent.Type.NPC_DEATH)
	var actions: Array = engine.events.filter(func(e): return e.type == BattleEvent.Type.NEW_ACTION)
	assert_eq(deaths.size(), 1, "die → NPC_DEATH 事件 1 条（源 :87-89）")
	assert_eq(actions.size(), 1, "die setAction(Death) → NEW_ACTION 事件 1 条（源 :110-112）")
	assert_eq(npc.state, BattleNpc.STATE_DYING, "die 后 state = STATE_DYING")


# 集成（Phase 4 视觉验收-装配层）：真实 BattleScene + engine 跑 step → _sync_actors 装配 NpcActor 入 actor_list。
# 验证 battle_scene :240 接线（NpcActor.sync_actors(self)）+ _advance_actor_list Variant 混装推进真实链路。
# 真实视觉（FCA 动画/血条渲染）headless 不可见（memory godot-mcp-screenshot-headless-unreliable），此处验装配闭环。
func test_npc_actor_battle_scene_integration() -> void:
	var cm_real := ConfigManager.new()
	cm_real.load_all()
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(12345)
	var npc := BattleNpc.new({"Puppet": "hero1", "Position X": 100.0, "Position Y": 0.0}, eng, false)
	eng.add_npc(npc)
	var scene := BattleScene.new()
	add_child_autofree(scene)
	scene.setup(eng, cm_real)
	scene.step(0.033)
	assert_eq(scene.actor_list.size(), 1, "1 NPC → _sync_actors 装配 1 NpcActor 入 actor_list（:240 接线生效）")
	assert_not_null(npc.actor, "npc.actor 被赋 NpcActor")
	assert_true(npc.actor.has_method("on_start_new_action"), "NpcActor 动作桥就位")
