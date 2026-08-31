extends RefCounted

## 测试 mock 用的 BattleEvent 发射桩（阶段三 T4）。
## Logic 现以 u.emit_* 鸭子调表现事件；unit 型 mock extends 本类即满足契约。
## 事件同时进本地 events 缓冲（无 engine 也可断言）并转发 engine.emit_event（若有）。

var engine: Variant = null
var events: Array = []

func emit_event(e: BattleEvent) -> void:
	events.append(e)
	if engine != null and engine.has_method("emit_event"):
		engine.emit_event(e)

func emit_popup(text: String, color: String, crit: bool = false, style: String = "damage") -> void:
	emit_event(BattleEvent.popup(self, text, color, crit, style))

func emit_add_effect(effect_name: String, zorder: int = 0) -> void:
	emit_event(BattleEvent.add_effect(self, effect_name, zorder))

func emit_remove_effect(effect_name: String) -> void:
	emit_event(BattleEvent.remove_effect(self, effect_name))

func emit_play_effect(effect_name: String, at: Vector2, p_scale: float = 1.0, p_height: float = 0.0, zorder: int = 0) -> void:
	emit_event(BattleEvent.play_effect(self, effect_name, at, p_scale, p_height, zorder))

func emit_tint(p_r: float, p_g: float, p_b: float) -> void:
	emit_event(BattleEvent.tint(self, Vector3(p_r, p_g, p_b)))

func emit_voice(unit_name: String, suffix: String) -> void:
	emit_event(BattleEvent.voice(self, unit_name, suffix))

func emit_shader_push(token: int, shader_name: String) -> void:
	emit_event(BattleEvent.shader_push(self, token, shader_name))

func emit_shader_remove(token: int) -> void:
	emit_event(BattleEvent.shader_remove(self, token))

func emit_shake(max_height: float, shake_time: float, shake_num: int) -> void:
	emit_event(BattleEvent.shake(self, max_height, shake_time, shake_num))

func emit_gold_drop() -> void:
	emit_event(BattleEvent.gold_drop(self))

func emit_loot_drop() -> void:
	emit_event(BattleEvent.loot_drop(self))

func emit_launch(time: float) -> void:
	emit_event(BattleEvent.launch(self, time))

func emit_new_action(action: String = "", loop: bool = false) -> void:
	emit_event(BattleEvent.new_action(self, action, loop))

func emit_puppet(action: String = "", loop: bool = false) -> void:
	emit_event(BattleEvent.puppet(self, action, loop))

func emit_npc_death() -> void:
	emit_event(BattleEvent.npc_death(self))

func emit_zspeed(v: float) -> void:
	emit_event(BattleEvent.zspeed(self, v))
