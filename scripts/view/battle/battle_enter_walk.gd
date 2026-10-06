class_name BattleEnterWalk
extends RefCounted

## 战斗入场走路编排（View helper）— 从 BattleScene 拆出控 ≤400（照 BattleResourceAssembler 静态拆分范式）。
## 战斗开场冻结 engine，预创建所有 actor 放场外，走到位后解冻。
## 玩家从左外（offset<0）、敌方从右外（offset>0）走向各自站位。

const PLAYER_OFFSET: float = -300.0   # 玩家入场起点偏移（logic x，场外左）
const ENEMY_OFFSET: float = 300.0     # 敌方入场起点偏移（logic x，场外右）
const WALK_TIMEOUT_MARGIN: float = 2.0  # 超时兜底倍率（覆盖慢速单位/低端机卡顿帧）


# 启动入场：冻结 engine，预创建所有 actor 放场外并 start_enter_walk。
# scene 须已 setup（engine/main_layer/_create_actor/_add_actor 就位）。
static func start(scene) -> void:
	if scene.engine == null:
		return
	scene.is_paused = true
	scene._entering = true
	scene._pending_enter_count = 0
	var max_wait: float = 0.0
	for unit in scene.engine.foreach_alive_unit(BattleEngine.CAMP_BOTH):
		var actor: BattleActor = scene._create_actor(unit)
		if actor == null:
			continue
		scene._actors_by_unit[unit] = actor
		actor.in_scene = true
		scene._add_actor(actor)
		var target: Vector2 = Vector2(float(unit.position.x), float(unit.position.y))
		var offset: float = PLAYER_OFFSET if int(unit.camp) == BattleEngine.CAMP_PLAYER else ENEMY_OFFSET
		actor.enter_walk_finished.connect(scene._on_actor_enter_done)
		scene._pending_enter_count += 1
		actor.start_enter_walk(target, offset)
		var ws: float = float(unit.info.get("Walk Speed", 0.0))
		if ws > 0.0:
			max_wait = maxf(max_wait, absf(offset) / (ws * BattleActor.ENTER_WALK_SPEEDER))
	# 无单位（空战斗）直接解冻。
	if scene._pending_enter_count == 0:
		scene.is_paused = false
		scene._entering = false
		scene.engine.running = true
		scene.engine.enabled = true
		return
	_arm_enter_timeout(scene, max_wait)


# 超时兜底（2026-10-06 高速空场治理）：理论走路时长 × margin 内未全员到位 → 强制吸附
# 到位解冻（actor.force_arrive 自守卫幂等）。任何位移 bug 再致 enter_walk_finished 不发射
# 时，战斗不再永久冻结（空场只能重开）。照源 battle_scene.lua:418-441 timer 编排必切波思想。
# 兜底节点挂 scene 子节点：scene 释放时随之释放、信号自动断开（lambda 捕获 scene 会在
# scene 先亡时触发引擎 "Lambda capture was freed" 错误，GUT error 监听会抓，不可用）。
static func _arm_enter_timeout(scene, max_wait: float) -> void:
	if scene == null or not scene.is_inside_tree() or max_wait <= 0.0:
		return
	var guard := TimeoutGuard.new(scene)
	scene.add_child(guard)
	guard.arm(max_wait * WALK_TIMEOUT_MARGIN)


class TimeoutGuard extends Node:
	var host: Node = null

	func _init(p_host: Node) -> void:
		host = p_host

	func arm(wait: float) -> void:
		get_tree().create_timer(wait).timeout.connect(_on_timeout)

	func _on_timeout() -> void:
		if host == null or not is_instance_valid(host) or not bool(host._entering):
			return
		for actor in host.actor_list:
			if actor is BattleActor:
				actor.force_arrive()   # 仍在走路的吸附到位（emit 走正常计数解冻）
		if bool(host._entering):
			# 信号链异常（如连接丢失）致计数不归零 → 直接解冻（同 start 空Units路径）
			host._entering = false
			host.is_paused = false
			host.engine.running = true
			host.engine.enabled = true


# 单个 actor 入场就位回调；全部就位后解冻 engine，恢复 step 正常流程。
static func on_actor_done(scene) -> void:
	scene._pending_enter_count -= 1
	if scene._pending_enter_count <= 0:
		scene.is_paused = false
		scene._entering = false
		scene.engine.running = true
		scene.engine.enabled = true
