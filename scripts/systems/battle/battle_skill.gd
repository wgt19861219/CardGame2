class_name BattleSkill
extends RefCounted

## 战斗技能（Logic 层）：照源 skill.lua（671 行）翻译。
## 技能实例 = SkillCreate(info, caster, level)：持技能信息(info) + 施法者 + 攻击帧时序(phase_list)。
## 目标选择/施法判定委托 BattleSkillTarget（控 ≤250）。

const BattleSkillTarget = preload("res://scripts/systems/battle/battle_skill_target.gd")

const TARGET_CAMP_SELF: int = 0
const TARGET_CAMP_TARGET: int = -1
const HEAL_DENOM: float = 100.0     # start CDR 分母（源 :321）；heal/伤害公式见 BattleSkillEffect
const CD_INTERRUPT_FACTOR: float = 0.5
const MP_SELECTOR_MOD: float = 1000.0
const HUGE: float = INF
const LAUNCH_DEFAULT_Y: float = 75.0

var info: Dictionary = {}
var caster: Variant = null
var level: int = 1
var phase_list: Array = []
var max_range_sq: float = 0.0
var min_range_sq: float = 0.0
var cd_remaining: float = 0.0
var casting: bool = false
var target: Variant = null
var current_phase_idx: int = 0
var current_phase: Dictionary = {}
var current_phase_elapsed: float = 0.0
var next_event_idx: int = 0
var next_event: Dictionary = {}
var attack_counter: int = 0
var can_cast: bool = false
var can_cast_tick: int = -1
var is_update: bool = true
var target_selectors: Dictionary = {}
var hero_hooks: Dictionary = {}  # 英雄 hook（源 override 等价）：源驼峰方法名→Callable wrapper（Phase 2.7）
var custom_data: Dictionary = {}  # 运行时自定义属性包（源 Lua 动态加 skill.XXX；英雄 hook 用，如 Tiny thrownUnit / NEC_ult_effect）

func _init(p_info: Dictionary, p_caster: Variant, p_level: int = 1) -> void:
	info = p_info
	caster = p_caster
	level = p_level
	var max_r: float = float(info.get("Max Range", 0.0))
	max_range_sq = max_r * max_r
	if max_range_sq == 0.0:
		max_range_sq = HUGE
	var min_r: float = float(info.get("Min Range", 0.0))
	min_range_sq = min_r * min_r
	cd_remaining = float(info.get("Init CD", 0.0))
	var puppet: String = ""
	if caster != null and caster.info is Dictionary:
		puppet = str(caster.info.get("Puppet", ""))
	_rebuild_phase_list(puppet)
	var ttype: String = str(info.get("Target Type", ""))
	if ttype == "self":
		info["Target Camp"] = TARGET_CAMP_SELF
	elif ttype == "target":
		info["Target Camp"] = TARGET_CAMP_TARGET
	_build_target_selectors()

func _build_target_selectors() -> void:
	BattleSkillTarget.build_target_selectors(self)

func _rng() -> BattleRng:
	return caster.engine.rng

func display() -> String: return str(info.get("Display Name", info.get("Skill Name", "")))

func _target_selector() -> Callable:
	var h: Callable = hero_hooks.get("targetSelector", Callable())
	return h.call(self) if h.is_valid() else target_selectors.get(str(info.get("Target Type", "")), Callable())

func _affected_camp() -> int:
	return int(caster.focamp) * int(info.get("Affected Camp", 0)) * -1

func _target_camp() -> int:
	return int(caster.focamp) * int(info.get("Target Camp", 0)) * -1

func reset() -> void:
	cd_remaining = float(info.get("Init CD", 0.0))
	casting = false
	target = null
	current_phase_idx = 0
	current_phase = {}
	current_phase_elapsed = 0.0
	next_event_idx = 0
	next_event = {}
	attack_counter = 0

func pause() -> void:
	is_update = false

func resume_update() -> void:
	is_update = true

## 英雄 hook override 点（NEC/Tiny）：hook 内调 _update_default 当 basefunc。
func update(dt_action: float, dt_cd: float) -> void:
	var h: Callable = hero_hooks.get("update", Callable())
	if h.is_valid():
		h.call(self, dt_action, dt_cd)
	else:
		_update_default(dt_action, dt_cd)

func _update_default(dt_action: float, dt_cd: float) -> void:
	if casting and self == caster.current_skill:
		current_phase_elapsed += dt_action
		var evs: Array = current_phase.get("event_list", [])
		while not next_event.is_empty() and current_phase_elapsed > float(next_event.get("Time", HUGE)):
			if str(next_event.get("Type", "")) == "Attack":
				_on_attack_frame()
			next_event_idx += 1
			next_event = evs[next_event_idx] if next_event_idx < evs.size() else {}
	else:
		cd_remaining -= dt_cd

func can_cast_with_target(p_target: Variant) -> Dictionary:
	var h: Callable = hero_hooks.get("canCastWithTarget", Callable())
	if h.is_valid():
		return h.call(self, p_target)
	return _can_cast_with_target_default(p_target)

func _can_cast_with_target_default(p_target: Variant) -> Dictionary:
	return BattleSkillTarget.can_cast_with_target(self, p_target)

func will_cast() -> bool:
	var h: Callable = hero_hooks.get("willCast", Callable())
	return h.call(self) if h.is_valid() else true

func _will_cast_default() -> bool:
	return true

func can_trigger() -> bool:
	var h: Callable = hero_hooks.get("canTrigger", Callable())
	return bool(h.call(self)) if h.is_valid() else false

func start(p_target: Variant) -> void:
	var h: Callable = hero_hooks.get("start", Callable())
	if h.is_valid():
		h.call(self, p_target)  # hook 内调 _start_default 当 basefunc
	else:
		_start_default(p_target)

func _start_default(p_target: Variant) -> void:
	target = p_target
	_select_target(p_target)
	cd_remaining = float(info.get("CD", 0.0))
	casting = true
	attack_counter = 0
	_start_phase(1)
	is_update = true
	caster.global_cd = float(info.get("Global CD", 0.0))
	var cdr: float = float(caster.attribs.get("CDR", 0.0)) / HEAL_DENOM
	caster.set_mp(float(caster.mp) - float(info.get("Cost MP", 0.0)) * (1.0 - cdr))
	var launch_eff: String = String(info.get("Launch Effect", ""))
	if launch_eff != "":
		caster.emit_add_effect(launch_eff, -1)

func _select_target(default_t: Variant) -> Variant:
	var h: Callable = hero_hooks.get("selectTarget", Callable())
	if h.is_valid():
		target = h.call(self, default_t)
		return target
	return _select_target_default(default_t)

func _select_target_default(default_t: Variant) -> Variant:
	return BattleSkillTarget.select_target_default(self, default_t)

func finish() -> void:
	var h: Callable = hero_hooks.get("finish", Callable())
	if h.is_valid():
		h.call(self)  # hook 内调 _finish_default 当 basefunc
	else:
		_finish_default()

func _finish_default() -> void:
	if bool(caster.manually_casting):
		caster.engine.unfreeze()
		caster.manually_casting = false
	casting = false
	caster.current_skill = null
	caster.idle()

func interrupt() -> void:
	var h: Callable = hero_hooks.get("interrupt", Callable())
	if h.is_valid():
		h.call(self)
	else:
		_interrupt_default()

func _interrupt_default() -> void:
	if attack_counter == 0:
		cd_remaining = float(info.get("CD", 0.0)) * CD_INTERRUPT_FACTOR
		caster.global_cd = float(info.get("Global CD", 0.0)) * CD_INTERRUPT_FACTOR
	finish()

func _start_phase(idx: int) -> void:
	var h: Callable = hero_hooks.get("startPhase", Callable())
	BattleSkillPhase.start_phase(self, idx) if not h.is_valid() else h.call(self, idx)

func _on_phase_finished() -> void:
	var h: Callable = hero_hooks.get("onPhaseFinished", Callable())
	h.call(self) if h.is_valid() else BattleSkillPhase.on_phase_finished(self)

func _on_attack_frame() -> void:
	var h: Callable = hero_hooks.get("onAttackFrame", Callable())
	if h.is_valid():
		h.call(self)  # hook 内调 _on_attack_frame_default 当 basefunc
	else:
		_on_attack_frame_default()

func _on_attack_frame_default() -> void:
	if bool(caster.manually_casting):
		caster.engine.unfreeze()
		caster.manually_casting = false
	attack_counter += 1
	BattleSkillEffect.emit_attack_voice(caster, attack_counter)
	if str(info.get("Target Type", "")) == "random" or target == null or not bool(target.is_alive()):
		_select_target(null)
	if target == null:
		return
	var ttype: String = str(info.get("Track Type", ""))
	if ttype == "projectile":
		caster.engine.add_projectile(_create_projectile())  # Phase 2.6 子模块
	elif ttype == "chain":
		caster.engine.add_chain(BattleChain.new(self))
	elif ttype == "":
		BattleSkillEffect.take_effect_at(self, target.position)
	caster.set_mp(float(caster.mp) + float(info.get("Gain MP", 0.0)) * float(caster.engine.mp_bonus))
	var fwd: float = float(info.get("Move Forward", 0.0))
	if fwd != 0.0:
		caster.position = Vector2(caster.position.x + fwd * float(caster.direction), caster.position.y)

func _create_projectile() -> Variant:
	var h: Callable = hero_hooks.get("createProjectile", Callable())
	return h.call(self) if h.is_valid() else _create_projectile_default()

func _create_projectile_default() -> Variant: return BattleProjectile.new(self)

func create_chain() -> BattleChain: return BattleChain.new(self)

func create_buff(target: Variant) -> Variant:
	var h: Callable = hero_hooks.get("createBuff", Callable())
	return h.call(self, target) if h.is_valid() else _create_buff_default(target)

func _create_buff_default(target: Variant) -> Variant:
	return BattleBuff.new(info.get("buff_info", {}), target, caster)


func take_effect_on(p_target: Variant, src: Variant = null) -> Array:
	var h: Callable = hero_hooks.get("takeEffectOn", Callable())
	return h.call(self, p_target, src) if h.is_valid() else BattleSkillEffect.take_effect_on(self, p_target, src)

func take_effect_at(p_location: Vector2, src: Variant = null) -> void:
	var h: Callable = hero_hooks.get("takeEffectAt", Callable())
	if h.is_valid():
		h.call(self, p_location, src)  # hook 内调 BattleSkillEffect.take_effect_at 当 basefunc（无递归）
	else:
		BattleSkillEffect.take_effect_at(self, p_location, src)


func get_damage(p_target: Variant, p_power: float, dt: String, field: String, src: Variant, crit_mod: float) -> float:
	var h: Callable = hero_hooks.get("getDamage", Callable())
	return float(h.call(self, p_target, p_power, dt, field, src, crit_mod)) if h.is_valid() else BattleSkillEffect.get_damage(p_target, p_power, dt, field, src, crit_mod)


# crit_mod = info CRIT%/100（默认 100→1.0）；英雄 hook（Luna 衰减 / SF / Med / WD / TA / KOTL）解构 basefunc 双值后返 Array。
func power(src: Variant, target: Variant = null) -> Array:
	var h: Callable = hero_hooks.get("power", Callable())
	return h.call(self, src, target) if h.is_valid() else BattleSkillEffect.power(self, src, target)

func launch_point() -> Array:
	var h: Callable = hero_hooks.get("launchPoint", Callable())
	return h.call(self) if h.is_valid() else _launch_point_default()

func _launch_point_default() -> Array:
	# 照源 skill.lua:651-670 launchPoint：骨骼挂点坐标（event.X/Y 动画像素）需经三重缩放
	# 才是逻辑坐标：cha_scale(0.09) × runtime_scale(manually_casting 1.35/scale_action) × unit_scale(Puppet.Scale)。
	var e: Dictionary = next_event if (not next_event.is_empty() and str(next_event.get("Type", "")) == "Attack") else {"X": 0.0, "Y": LAUNCH_DEFAULT_Y}
	var s: float = BattleSkillPhase.launch_scale(caster)
	return [Vector2(caster.position.x + float(e.get("X", 0.0)) * s, caster.position.y), float(e.get("Y", LAUNCH_DEFAULT_Y)) * s]

func trigger() -> void:
	var h: Callable = hero_hooks.get("trigger", Callable())
	if h.is_valid():
		h.call(self)

func goto_event_idx(p_idx: int) -> void:
	BattleSkillPhase.goto_event_idx(self, p_idx)

func _rebuild_phase_list(_puppet: String) -> void:
	BattleSkillPhase.rebuild_phase_list(self, _puppet)
