class_name BattleWaveAdvancer
extends RefCounted

## 战斗场景波次切换（View helper）— 从 BattleScene 拆出控 ≤400。
## static 方法第一参 scene，照 equip_strengthen_anim.gd 静态拆分范式。
## 主类 _on_next_wave_requested 信号回调委托本类。


# + 刷 wave_mark。玩家 actor/UI 复用（源 :498 reset skipUI=true）；新敌人 actor 由 _sync_actors 下次 tick 装配。
# 切波后双方都重新入场走路（玩家从左屏外、敌人从右屏外走到各自站位），而非漂到站位。
static func advance_wave(scene) -> void:
	if scene.engine == null:
		return
	var auto: bool = scene.auto_combat
	_remove_enemy_actors(scene)
	for effect in scene.effect_list:
		if effect is Node:
			effect.queue_free()
	scene.effect_list.clear()
	for child in scene.background_layer.get_children():
		child.queue_free()
	BattleEngineWaves.next_battle(scene.engine, scene.cm)
	scene.battle_info = BattleData.from_config(scene.cm, _current_lookup_id(scene), int(scene.engine.wave_id)).battle_info
	scene._create_wave_mark()
	scene._create_background()
	scene.auto_combat = auto
	# 重置波次清完标志 + 恢复战斗（新 wave 开始）。
	scene.engine.wave_clear = false
	scene._wave_clear_handled = false
	# 收集保留的玩家 actor（_remove_enemy_actors 保留玩家，但其 model 指向旧 unit 引用）。
	# next_battle → reset_battle → add_unit 重建了玩家 unit（actor=null），需把保留的旧 actor 重绑到新 unit。
	var player_actors: Array = []
	for actor in scene.actor_list:
		if actor is BattleActor and int(actor.model.camp) == BattleEngine.CAMP_PLAYER:
			player_actors.append(actor)
	# 双方入场走路（玩家从左屏外、敌人从右屏外走到站位），冻结 engine，全部就位后解冻。
	_enter_wave_units(scene, player_actors)


# 玩家向右走向屏外（gotoNextBattle 起点）：从 battle_scene 下沉（2026-09-05，LINT005 行数），
# 返回 maxtime（最远单位走到位时长，供编排 timer ÷ 档位倍率后等待）。
static func start_player_walk(scene) -> float:
	var maxtime: float = 0.0
	if scene.engine == null:
		return maxtime
	# 出屏目标 x（>屏宽 800 对应 logic x>800，取 WAVE_WALK_OFFSCREEN_X=1050 确保出屏；
	# 停在屏缘附近会半露右边缘，切波瞬移到站位时被看见）。
	var target_x: float = BattleActor.WAVE_WALK_OFFSCREEN_X
	for unit in scene.engine.foreach_alive_unit(BattleEngine.CAMP_PLAYER):
		var wa: Variant = scene._actors_by_unit.get(unit)
		if wa != null and wa.has_method("goto_next_battle"):
			# 传 target_x 作停止点（双保险：到位回调 + await maxtime 任一先到都能停）。
			wa.goto_next_battle(float(unit.info.get("Walk Speed", 0.0)), target_x)
		var walk_speed: float = float(unit.info.get("Walk Speed", 0.0)) * BattleActor.NEXT_BATTLE_WALK_SPEEDER
		if walk_speed > 0.0:
			maxtime = maxf(maxtime, (target_x - float(unit.position.x)) / walk_speed)
	return maxtime


# 切波入场：玩家 actor 从左屏外走回站位 + 新敌人 actor 从右屏外走到站位。
# 复用 BattleEnterWalk 的入场机制（_entering 冻结 engine，全部就位 _on_actor_enter_done 解冻）。
# 玩家 offset 用负（左屏外），敌人 offset 用正（右屏外），与 BattleEnterWalk.PLAYER/ENEMY_OFFSET 一致。
static func _enter_wave_units(scene, player_actors: Array) -> void:
	scene._entering = true
	scene.is_paused = true
	scene._pending_enter_count = 0
	# 玩家：重绑保留的旧 actor 到新 unit（顺序一致：reset_battle 保序 + actor_list 入场序）+ 从左屏外走回站位。
	var alive_players: Array = scene.engine.foreach_alive_unit(BattleEngine.CAMP_PLAYER)
	var pi: int = 0
	for unit in alive_players:
		if pi >= player_actors.size():
			break
		var actor: BattleActor = player_actors[pi]
		actor.model = unit  # 重绑到新 unit（旧 unit 已被 reset_battle 丢弃）
		scene._actors_by_unit[unit] = actor
		actor.in_scene = true
		# 重复切波：玩家 actor 跨波复用，先断开旧连接再重连（防 enter_walk_finished 多次触发 _on_actor_enter_done）。
		if actor.enter_walk_finished.is_connected(scene._on_actor_enter_done):
			actor.enter_walk_finished.disconnect(scene._on_actor_enter_done)
		var target: Vector2 = Vector2(float(unit.position.x), float(unit.position.y))
		actor.enter_walk_finished.connect(scene._on_actor_enter_done)
		scene._pending_enter_count += 1
		actor.start_enter_walk(target, BattleEnterWalk.PLAYER_OFFSET)
		pi += 1
	# 新敌人：预创建 actor 从右屏外走到站位。
	for unit in scene.engine.foreach_alive_unit(BattleEngine.CAMP_ENEMY):
		var actor: BattleActor = scene._create_actor(unit)
		if actor == null:
			continue
		scene._actors_by_unit[unit] = actor
		actor.in_scene = true
		scene._add_actor(actor)
		var target: Vector2 = Vector2(float(unit.position.x), float(unit.position.y))
		actor.enter_walk_finished.connect(scene._on_actor_enter_done)
		scene._pending_enter_count += 1
		actor.start_enter_walk(target, BattleEnterWalk.ENEMY_OFFSET)
	# 无单位直接解冻
	if scene._pending_enter_count == 0:
		scene._entering = false
		scene.is_paused = false
		scene.engine.running = true
		scene.engine.enabled = true


static func _current_lookup_id(scene) -> int:
	var lookup_id: int = int(scene.engine.battle_lookup_id)
	return lookup_id if lookup_id != 0 else int(scene.engine.stage_info.get(&"Stage ID", 0))


static func _remove_enemy_actors(scene) -> void:
	var kept: Array = []
	for actor in scene.actor_list:
		if actor.model != null and int(actor.model.camp) == BattleEngine.CAMP_PLAYER:
			kept.append(actor)
		else:
			if actor is Node:
				actor.queue_free()
	scene.actor_list = kept
