class_name BattleSpeedSync
extends RefCounted

## 战斗切速广播（View helper）— 从 BattleScene 拆出控 ≤400（照 BattleHudAssembler 静态拆分范式）。
## 切速时同步所有 FCA 自驱动画的补偿倍率：actor puppet（人物动作）+ actor buff 特效 +
## 场景特效 effect_list + hero_panel ready 光圈。FcaAnimation 用 _process 真实 delta 自驱，
## 不广播则新档只对新创建动画生效、已存在的仍按旧倍率播 → 切速瞬间新旧动画不同步
## （源 effect/actor/ui 同链被 battle_scene 加速 dt 集中推进，Godot 版自驱须广播补偿，2026-08-19）。


static func broadcast(scene: Variant, state: int) -> void:
	var spd: float = float(scene.SPEED_MULTIPLIERS[state - 1])
	for actor in scene.actor_list:
		# 混装 BattleActor/NpcActor/ProjectileActor：puppet 仅前两者有，ProjectileActor 无此键
		# （点属性即崩；skill_lib 修复后投射物首次出现踩中，Object.get 缺键安全返 null）。
		var puppet: Variant = actor.get("puppet")
		if puppet != null and puppet.has_method("apply_speed_mult"):
			puppet.apply_speed_mult(spd)
		if actor.has_method("apply_speed_to_effects"):
			actor.apply_speed_to_effects(spd)
	for effect in scene.effect_list:
		if effect.has_method("set_speed"):
			effect.set_speed(spd)
	for panel in scene._hero_panels.values():
		if panel != null and panel.has_method("apply_speed"):
			panel.apply_speed(spd)


# 新建 actor 立即带当前档倍率（scene 创建点调用）：开场持久化档 2x-4x 时 broadcast
# 尚未发生，不补则 mult 恒 1（首场战斗动画/走路速度漏倍速）。
static func apply_to_actor(scene: Variant, actor: Variant) -> void:
	var puppet: Variant = actor.get("puppet")
	if puppet != null and puppet.has_method("apply_speed_mult") and scene.has_method("current_speed"):
		puppet.apply_speed_mult(float(scene.call("current_speed")))
