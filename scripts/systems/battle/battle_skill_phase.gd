class_name BattleSkillPhase
extends RefCounted

## 技能 phase 时序（Logic 层）：照源 skill.lua phase 推进拆出（rebuildPhaseList / startPhase / onPhaseFinished / gotoEventIdx）。
## 从 BattleSkill 拆分以满足单文件 ≤300 行铁律；静态方法接 skill 实例（读/写 phase_list / current_phase / next_event 等）。
## rebuild_phase_list 查 Puppet/AnimDuration/AnimAtkFrame 表填真实 phase_list（2026-07-05 验证：Coco atk phase_list 含 Time=0.275 Attack 帧，双 Coco 对打 1792 帧分胜负）。
## goto_event_idx 的 idx 为 1-based（对齐源 Lua event_list 索引）；actor setActionElapsed 属 View，桩。

# 投射物发射点缩放系数（照源 skill.lua:651-670 launchPoint）：cha_scale × runtime_scale × unit_scale。
const CHA_SCALE: float = 0.09
const MANUALLY_CAST_SCALE: float = 1.35

# + AnimAtkFrame events 排序 by Time → phase{action_name, duration, event_list}。
# 静态接 skill + puppet；cm 经 caster.cm（ConfigManager，BattleUnit 字段）。


# 投射物发射缩放：骨骼像素坐标→逻辑坐标的三重缩放系数（照源 launchPoint 的 cha_scale * sx * us）。
static func launch_scale(caster: Variant) -> float:
	return CHA_SCALE * _runtime_scale(caster) * _unit_scale(caster)


# 施法者运行时缩放（照源 getRuntimeScale）：scale_action 进行中按进度插值，否则 manually_casting=1.35。
static func _runtime_scale(caster: Variant) -> float:
	if bool(caster.is_scale_action_running):
		var dur: float = float(caster.scale_action_duration)
		if dur > 0.0 and float(caster.scale_action_running_time) > dur:
			return float(caster.scale_action_scale_value)
		if dur > 0.0:
			return float(caster.scale_action_running_time) / dur * (float(caster.scale_action_scale_value) - 1.0) + 1.0
	return MANUALLY_CAST_SCALE if bool(caster.manually_casting) else 1.0


# 施法者单位缩放（照源 getUnitScale）：Puppet 表 Scale × config.size_mod（默认 1）。
static func _unit_scale(caster: Variant) -> float:
	var puppet_name: String = ""
	if caster.puppet_stack.size() > 0:
		puppet_name = String(caster.puppet_stack[-1])
	if puppet_name == "" or caster.cm == null:
		return 1.0
	var cfg: Dictionary = caster.cm.get_raw_table(&"Puppet").get(puppet_name, {})
	return float(cfg.get("Scale", 1.0)) * float(caster.config.get("size_mod", 1.0))
static func rebuild_phase_list(skill: BattleSkill, puppet: String) -> void:
	skill.phase_list = []
	if puppet == "":
		return
	var caster: Variant = skill.caster
	if caster == null or caster.get("cm") == null:
		return
	var cm: Variant = caster.cm
	var raw_actions: Variant = skill.info.get(&"Action(s)", {})
	var anim_names: Array = []
	if raw_actions is Dictionary:
		var idx_keys: Array[int] = []
		for k in raw_actions:
			idx_keys.append(int(k))
		idx_keys.sort()
		for k in idx_keys:
			anim_names.append(raw_actions[str(k)])
	elif raw_actions is Array:
		anim_names = raw_actions
	if anim_names.is_empty():
		return
	var puppet_row: Dictionary = cm.get_raw_table(&"Puppet").get(puppet, {})
	var resource_short: Variant = puppet_row.get(&"Resource", null)
	if resource_short == null:
		return
	var resource_name: String = str(resource_short) + ".cha"
	var anim_dur: Dictionary = cm.get_raw_table(&"AnimDuration").get(resource_name, {})
	var anim_atk: Dictionary = cm.get_raw_table(&"AnimAtkFrame").get(resource_name, {})
	for anim_name in anim_names:
		var an: String = str(anim_name)
		var events: Dictionary = anim_atk.get(an, {})
		if events.is_empty():
			continue
		var duration: float = float(anim_dur.get(an, {}).get(&"Duration", 0.0))
		var event_list: Array = []
		for k in events:
			var ev: Dictionary = events[k]
			ev[&"Type"] = &"Attack"
			event_list.append(ev)
		event_list.sort_custom(func(a, b): return float(a.get(&"Time", 0.0)) < float(b.get(&"Time", 0.0)))
		skill.phase_list.append({
			"action_name": an,
			"duration": duration,
			"event_list": event_list,
		})


static func start_phase(skill: BattleSkill, idx: int) -> void:
	var i: int = idx - 1  # 1-based → 0-based
	if i < 0 or i >= skill.phase_list.size():
		return
	var phase: Dictionary = skill.phase_list[i]
	skill.current_phase_idx = idx
	skill.current_phase = phase
	skill.current_phase_elapsed = 0.0
	skill.next_event_idx = 0
	var evs: Array = phase.get("event_list", [])
	skill.next_event = evs[0] if evs.size() > 0 else {}
	skill.caster.set_action(str(phase.get("action_name", "")), false, true)


static func on_phase_finished(skill: BattleSkill) -> void:
	if skill.current_phase_idx >= skill.phase_list.size():
		skill.finish()
	else:
		skill._start_phase(skill.current_phase_idx + 1)


static func goto_event_idx(skill: BattleSkill, p_idx: int) -> void:
	var evs: Array = skill.current_phase.get("event_list", [])
	if p_idx < 1 or p_idx - 1 >= evs.size():
		return
	skill.next_event_idx = p_idx
	skill.next_event = evs[p_idx] if p_idx < evs.size() else {}
	skill.current_phase_elapsed = float(evs[p_idx - 1].get("Time", 0.0))
