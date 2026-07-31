class_name BattleEnterWalk
extends RefCounted

## 战斗入场走路编排（View helper）— 从 BattleScene 拆出控 ≤400（照 BattleResourceAssembler 静态拆分范式）。
## 战斗开场冻结 engine，预创建所有 actor 放场外，走到位后解冻。
## 玩家从左外（offset<0）、敌方从右外（offset>0）走向各自站位。

const PLAYER_OFFSET: float = -300.0   # 玩家入场起点偏移（logic x，场外左）
const ENEMY_OFFSET: float = 300.0     # 敌方入场起点偏移（logic x，场外右）


# 启动入场：冻结 engine，预创建所有 actor 放场外并 start_enter_walk。
# scene 须已 setup（engine/main_layer/_create_actor/_add_actor 就位）。
static func start(scene) -> void:
	if scene.engine == null:
		return
	scene.is_paused = true
	scene._entering = true
	scene._pending_enter_count = 0
	for unit in scene.engine.foreach_alive_unit(BattleEngine.CAMP_BOTH):
		var actor: BattleActor = scene._create_actor(unit)
		if actor == null:
			continue
		unit.actor = actor
		actor.in_scene = true
		scene._add_actor(actor)
		var target: Vector2 = Vector2(float(unit.position.x), float(unit.position.y))
		var offset: float = PLAYER_OFFSET if int(unit.camp) == BattleEngine.CAMP_PLAYER else ENEMY_OFFSET
		actor.enter_walk_finished.connect(scene._on_actor_enter_done)
		scene._pending_enter_count += 1
		actor.start_enter_walk(target, offset)
	# 无单位（空战斗）直接解冻。
	if scene._pending_enter_count == 0:
		scene.is_paused = false
		scene._entering = false


# 单个 actor 入场就位回调；全部就位后解冻 engine，恢复 step 正常流程。
static func on_actor_done(scene) -> void:
	scene._pending_enter_count -= 1
	if scene._pending_enter_count <= 0:
		scene.is_paused = false
		scene._entering = false
