class_name BattleWaveAdvancer
extends RefCounted

## 战斗场景波次切换（View helper）— 从 BattleScene 拆出控 ≤400。
## static 方法第一参 scene，照 equip_strengthen_anim.gd 静态拆分范式。
## 主类 _on_next_wave_requested 信号回调委托本类。


# + 刷 wave_mark。玩家 actor/UI 复用（源 :498 reset skipUI=true）；新敌人 actor 由 _sync_actors 下次 tick 装配。
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
	# 玩家 actor 重置 interp（切波后重新接 engine position，避免瞬移）。
	for actor in scene.actor_list:
		if actor is BattleActor and int(actor.model.camp) == BattleEngine.CAMP_PLAYER:
			actor._tick = -1
			actor._has_interp = false
	# 新敌人入场走路（预创建敌方 actor 从右外走到站位，玩家方不动）。
	_enter_new_enemies(scene)


# 新敌人入场：预创建敌方 actor 从右外走到站位（玩家方已在场不动）。
# 冻结 engine（_entering=true），全部就位后 _on_actor_enter_done 解冻恢复 running。
static func _enter_new_enemies(scene) -> void:
	scene._entering = true
	scene.is_paused = true
	scene._pending_enter_count = 0
	for unit in scene.engine.foreach_alive_unit(BattleEngine.CAMP_ENEMY):
		var actor: BattleActor = scene._create_actor(unit)
		if actor == null:
			continue
		unit.actor = actor
		actor.in_scene = true
		scene._add_actor(actor)
		var target: Vector2 = Vector2(float(unit.position.x), float(unit.position.y))
		actor.enter_walk_finished.connect(scene._on_actor_enter_done)
		scene._pending_enter_count += 1
		actor.start_enter_walk(target, 300.0)
	# 无新敌人直接解冻
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
