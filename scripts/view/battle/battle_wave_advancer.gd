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
