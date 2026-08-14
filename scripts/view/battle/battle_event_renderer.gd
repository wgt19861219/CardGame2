class_name BattleEventRenderer
extends RefCounted

## 战斗表现事件分发（View 层）— 阶段三 T4（2026-08-14）。
## battle_scene.step 在 engine.update 后调 render(engine)，同帧 drain 表现事件分发到 actor 渲染。
## Logic 层不再鸭子直调 View；本类是 View 对自家 BattleActor/NpcActor 的适配层
## （on_npc_death 仅 NpcActor 实现等差异用 has_method 软分发——View 调 View，无跨层问题）。
## shader 用 Logic 侧 token 关联 PUSH/REMOVE（actor 维护 token→栈槽映射，跨队列保序）。

static func render(engine: BattleEngine, actors_by_unit: Dictionary) -> void:
	for e in engine.drain_events():
		_dispatch(e, actors_by_unit)


static func _dispatch(e: BattleEvent, actors_by_unit: Dictionary) -> void:
	if e.unit == null:
		return
	var actor: Variant = actors_by_unit.get(e.unit)
	if actor == null:
		return   # 单位未挂 actor（已退场/未入场）→ 静默跳过，等价旧守卫跳过
	match e.type:
		BattleEvent.Type.POPUP:
			actor.spawn_popup(e.text, e.color, e.flag, e.text2)
		BattleEvent.Type.ADD_EFFECT:
			actor.add_effect(e.text, int(e.value))
		BattleEvent.Type.REMOVE_EFFECT:
			actor.remove_effect(e.text)
		BattleEvent.Type.PLAY_EFFECT:
			actor.play_effect(e.text, e.origin, e.scale, e.height, int(e.value))
		BattleEvent.Type.TINT:
			actor.tint(e.rgb.x, e.rgb.y, e.rgb.z)
		BattleEvent.Type.VOICE:
			actor.play_voice(e.text, e.text2)
		BattleEvent.Type.SHADER_PUSH:
			actor.push_shader_keyed(int(e.value), e.text)
		BattleEvent.Type.SHADER_REMOVE:
			actor.remove_shader_keyed(int(e.value))
		BattleEvent.Type.SHAKE:
			actor.start_camera_shake_animation_y(e.value, e.value2, int(e.value3))
		BattleEvent.Type.GOLD_DROP:
			actor.play_gold_drop_effect()
		BattleEvent.Type.LAUNCH:
			actor.launch(e.value)
		BattleEvent.Type.NEW_ACTION:
			if actor.has_method("apply_action_named"):
				actor.apply_action_named(e.text, e.flag)
		BattleEvent.Type.PUPPET:
			actor.use_puppet(e.text, e.flag)
		BattleEvent.Type.NPC_DEATH:
			if actor.has_method("on_npc_death"):
				actor.on_npc_death()
		BattleEvent.Type.ZSPEED:
			if "z_speed" in actor:
				actor.z_speed = e.value
			elif "zSpeed" in actor:
				actor.zSpeed = e.value
