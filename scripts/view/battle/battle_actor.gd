class_name BattleActor
extends Node2D

## 单位 actor（View 包装）— 照源 unit.lua:1518-1567 UnitActorCreate + :1724-1785 update 翻译。
## 从 battle_scene.gd 拆出（控四大原则 ≤400，2026-07-02）。Node2D 容器 + UnitSprite puppet +
## 位置同步 + interp 双缓冲插值（tick 间 lerp）+ FloatingBar 血条 + knockup 弧线 + getRuntimeScale/setActionSpeeder。
##
## 入场走路（start_enter_walk）：战斗开场单位从场外走到站位（_offline 离线自驱），
## 到位发 enter_walk_finished 信号，BattleScene 计数归零后解冻 engine。

const BAR_SCALE: float = 0.6666666666666666
const BAR_HP_Y: float = -114.5   # 源 Cocos y=114.5（向上），Godot 左上原点翻转为负（头顶）
const BAR_SHIELD_Y: float = -110.0
const BOSS_BAR_POS: Vector2 = Vector2(435.0, 134.0)  # 原 to_godot(355,426)=(355+80,560-426)，Boss 护盾条 HUD 原生坐标
const BAR_Z: int = 999
const MANUALLY_CAST_SCALE: float = 1.35
const GRAVITY: float = -1800.0
const NEXT_BATTLE_WALK_SPEEDER: float = 1.75
const ENTER_WALK_SPEEDER: float = 1.75   # 入场走路加速（复用切波系数）
const ENTER_ARRIVE_THRESHOLD: float = 5.0  # 入场到位判定阈值（logic 单位）
# 切波走路出屏目标 x（view 屏宽 960，OFFSET_X=80 → logic x>880 出屏）。
# 取 1050（view 1130，出屏 170px）确保角色（宽约 130px）完全藏在屏外，停在 900（view 980）会半露右边缘。
const WAVE_WALK_OFFSCREEN_X: float = 1050.0

# 入场走路完成（BattleScene 计数归零后解冻 engine）。
signal enter_walk_finished
const BattleEffect = preload("res://scripts/view/battle/battle_effect.gd")

var model: Variant = null     # BattleUnit（Logic 层单位）
var puppet: Variant = null    # UnitSprite（FCA 动画；源 puppet 不带血条）
var bar_group: Variant = null # BattleFloatingBar.Group（源 :1545）
var bar_hp: Node2D = null     # BattleFloatingBar HP（普通单位头顶）
var bar_shield: Node2D = null # BattleFloatingBar Shield / ShieldBoss
var _ui_layer: Node = null  # Boss ShieldBoss 挂载层（源 :1561 scene.ui_layer）
var _boss_bar_external: bool = false  # bar_shield 在 ui_layer（actor free 需单独清）
var in_scene: bool = false
var _offline: bool = false
var _velocity: Vector2 = Vector2.ZERO
var _walk_pos: Vector2 = Vector2.ZERO  # offline 走路累积 Logic 位置（源 self.position velocity 移动）
var _tick: int = -1
var _has_interp: bool = false     # interp_from 是否就位
var _interp_from: Vector2 = Vector2.ZERO
var _interp_to: Vector2 = Vector2.ZERO
var _interp_alpha: float = 0.0
var _z_speed: Variant = null
var _height: float = 0.0
var _effects: Dictionary = {}
var _shader_stack: Array[String] = []
var _shader_keys: Dictionary = {}      # T4：Logic token → push_shader 返回槽位（keyed 变体用）
var _cm: Variant = null                 # ConfigManager（use_puppet 查 Puppet 表）
var _enter_target: Variant = null       # 入场目标 logic 坐标（Vector2）或 null（非入场态）
var _hold_offline: bool = false         # 到位后保持离线静止（goto_next_battle 走屏外等切波，不接 engine interp）
var _enter_arrive_dir: int = 0          # 入场到位锁定的朝向（±1），interp 首帧用它防 engine direction 瞬变致翻转


func setup(p_model: Variant, p_cm: Variant, p_ui_layer: Node = null) -> void:
	model = p_model
	_cm = p_cm
	_ui_layer = p_ui_layer
	puppet = UnitSprite.new()
	add_child(puppet)
	puppet.setup(model, p_cm)
	_create_floating_bars()
	update_view(0.0)


# interp_to=position, alpha=0）+ 帧间 lerp 平滑（Logic 每 tick 跳进，View 帧间插值）+ y 排序 z_index。
func update_view(dt: float) -> void:
	if model == null:
		return
	var eng: Variant = model.engine
	if not _offline and eng != null and _tick != int(eng.ticks):
		_tick = int(eng.ticks)
		_has_interp = true
		_interp_from = Vector2(float(model.previous_position.x), float(model.previous_position.y))
		_interp_to = Vector2(float(model.position.x), float(model.position.y))
		_interp_alpha = 0.0
		var rt_scale: float = _get_runtime_scale()
		# 入场到位锁定：到位后 interp 首帧用锁定朝向（防 engine 解冻首 tick direction 瞬变致翻转），
		# 只锁第一帧（_enter_arrive_dir 清零），之后交给 model.direction 正常接管。
		var dir_for_scale: int = _enter_arrive_dir if _enter_arrive_dir != 0 else int(model.direction)
		_enter_arrive_dir = 0
		scale = Vector2(dir_for_scale * rt_scale, rt_scale)
		if puppet != null:
			var spd: float = 0.0 if bool(model.buff_effects.get(BattleEffectKeys.FROZEN, false)) else float(model.speeder)
			puppet.set_speed(spd)
	var logic_pos: Vector2
	if _offline:
		# 离线态：velocity!=ZERO 时走路（设朝向 + 移动 _walk_pos）；velocity==ZERO 时静止（如 goto_next_battle
		# 到位后等切波，保持屏外不动，不被 interp 拉回站位）。
		if _velocity != Vector2.ZERO:
			# 离线走路时设朝向（velocity 方向 = 朝向，玩家朝右 +scale.x / 敌方朝左 -scale.x）。
			var abs_s: float = absf(scale.x) if scale.x != 0.0 else 1.0
			var sign_x: float = 1.0 if _velocity.x > 0.0 else -1.0
			scale = Vector2(sign_x * abs_s, abs_s)
			_walk_pos += Vector2(_velocity.x * dt, _velocity.y * dt)
			# 入场到位判定：_walk_pos 接近 _enter_target 时发信号。
			if _enter_target != null:
				var tgt: Vector2 = Vector2(_enter_target)
				if _walk_pos.distance_to(tgt) < ENTER_ARRIVE_THRESHOLD:
					_walk_pos = tgt
					_enter_target = null
					_velocity = Vector2.ZERO
					if _hold_offline:
						# goto_next_battle 到位：保持离线静止在屏外等切波（不 emit、不切 interp，防被拉回站位）。
						_hold_offline = false
					else:
						# start_enter_walk 到位：清离线态重接 engine interp + emit（_on_actor_enter_done 解冻）。
						# 锁定到位朝向：engine 解冻首 tick 的 direction 会瞬变（实测 +1 持续 3 帧再回 -1），
						# 直接映射到 actor scale = 整体翻转 3 帧 = 猛抖。记录到位朝向，interp 首帧用它防翻转。
						_enter_arrive_dir = 1 if scale.x > 0.0 else -1
						_offline = false
						_tick = -1
						_has_interp = false
						if puppet != null and puppet.has_method("play_action"):
							puppet.play_action("Idle", true)
						enter_walk_finished.emit()
		position = BattleViewCoords.to_view_position(_walk_pos.x, _walk_pos.y, 0.0)
		z_index = -int(_walk_pos.y)
		if bar_group != null:
			bar_group.update(dt)
		return
	if _has_interp:
		_interp_alpha = minf(_interp_alpha + dt / BattleEngine.TICK_INTERVAL, 1.0)
		logic_pos = _interp_from.lerp(_interp_to, _interp_alpha)
	else:
		logic_pos = Vector2(float(model.position.x), float(model.position.y))
	if _z_speed != null:
		_height += float(_z_speed) * dt
		_z_speed = float(_z_speed) + GRAVITY * dt
		if _height < 0.0:
			_z_speed = null
			_height = 0.0
	position = BattleViewCoords.to_view_position(logic_pos.x, logic_pos.y, -_height)
	z_index = -int(float(model.position.y))
	if bar_group != null:
		bar_group.update(dt)


func _get_runtime_scale() -> float:
	if bool(model.is_scale_action_running):
		# 计时由 Logic 推进（T4-B6，battle_unit_update），View 只读（治反写）
		if float(model.scale_action_running_time) > float(model.scale_action_duration):
			return float(model.scale_action_scale_value)
		return float(model.scale_action_running_time) / float(model.scale_action_duration) * (float(model.scale_action_scale_value) - 1.0) + 1.0
	return MANUALLY_CAST_SCALE if bool(model.manually_casting) else 1.0


# skill/engine/heroes）鸭子调此方法（复用 launch 同模式 u.get("actor").spawn_popup(...)），不 import
# BattlePopup（三层分离铁律）。color 色键透传给 BattlePopup 映射 RGB。_ui_layer 由 setup 装配（Boss
# ShieldBar 复用同引用）。model = BattleUnit（Logic position，BattlePopup 内部 toViewPosition）。
# skill/engine/heroes）鸭子调此方法（复用 launch 同模式 u.get("actor").spawn_popup(...)），不 import
# BattlePopup（三层分离铁律）。color 色键透传给 BattlePopup 映射 RGB。_ui_layer 由 setup 装配（Boss
# ShieldBar 复用同引用）。model = BattleUnit（Logic position，BattlePopup 内部 toViewPosition）。
func spawn_popup(text: String, color: String, crit: bool = false, style: String = "damage") -> void:
	if _ui_layer == null or model == null:
		return
	BattlePopup.create(text, model, crit, style, color, _ui_layer)


# combat die / behavior cast_manual_skill 鸭子调 u.actor.play_voice(name, suffix)，转发
# AudioPlayer.play_sfx_by_path（三层分离：Logic 不直接碰 Audio；照 spawn_popup 同模式）。
# name 传入时已 to_upper（源 :1111/1156 string.upper(self.name) 在 Logic 完成）。
func play_voice(unit_name: String, suffix: String) -> void:
	if model == null or unit_name == "":
		return
	AudioPlayer.play_sfx_by_path("sound/" + unit_name + suffix + ".mp3")


# 目标分发：Death/Damaged/atk*/ult → puppet.play_*（含目标自加视觉反馈）；
# Move/Idle/"" → 现有 walk 系统处理（不重复，walk_to_position/start_walk 已驱动 Move/Idle FCA）；
# 其他（Birth/Idle2 等特殊英雄动作）→ puppet.play_action 通用 FCA play。
func on_start_new_action() -> void:
	if puppet == null or model == null:
		return
	apply_action_named(String(model.action_name), bool(model.action_loop))


## T4 事件分发入口：动作来自事件快照（非 drain 时 model 现值——die 移除傀儡后置 Death 的时序下，
## PUPPET 恢复必须用发射时动作，否则 play_death 双触发重复连信号）。
func apply_action_named(action: String, loop: bool) -> void:
	match action:
		"Death":
			puppet.play_death()
		"Damaged":
			puppet.play_hit()
		"atk", "atk2", "atk3":
			puppet.play_attack(Vector2.ZERO)
		"ult":
			puppet.play_ult(Vector2.ZERO)
		"Move":
			puppet.play_action("Move", true)
		"Idle", "":
			puppet.play_action("Idle", true)
		_:
			puppet.play_action(action, loop)


# hero hook 鸭子调 caster.actor.add_effect(name, zorder) / target.actor.add_effect(name, zorder)。
func add_effect(effect_name: String, zorder: int = 0) -> void:
	if effect_name == "":
		return
	remove_effect(effect_name)

	var battle_effect := BattleEffect.create(effect_name)
	if battle_effect != null:
		battle_effect.play()
		var node: Node2D = battle_effect.get_node()
		node.name = effect_name
		add_child(node)
		node.z_index = zorder
		_effects[effect_name] = battle_effect
	else:
		# 降级：空 Node2D + 1s 占位（资源缺失，照源 createFcaNode stub 兜底）
		var node := Node2D.new()
		node.name = effect_name
		add_child(node)
		node.z_index = zorder
		_effects[effect_name] = node
		get_tree().create_timer(1.0).timeout.connect(remove_effect.bind(effect_name))


func remove_effect(effect_name: String) -> void:
	if _effects.has(effect_name):
		var stored: Variant = _effects[effect_name]
		_effects.erase(effect_name)
		# BattleEffect（FCA）或 Node2D（降级占位）两种形态
		var node: Node2D = null
		if stored is BattleEffect:
			node = stored.get_node()
		elif stored is Node2D:
			node = stored
		if node != null and is_instance_valid(node):
			node.queue_free()


func tint(r: float, g: float, b: float) -> void:
	if puppet != null and puppet.has_method("tint"):
		puppet.tint(r, g, b)


const SHADER_COLORS: Dictionary = {
	"FrozenShader": Color(0.6, 0.7, 1.0), "StoneShader": Color(0.5, 0.5, 0.5),
	"PoisonShader": Color(0.5, 1.0, 0.5), "BanishShader": Color(1.0, 0.5, 0.5, 0.5),
	"InvisibleShader": Color(1.0, 1.0, 1.0, 0.3), "IceShader": Color(0.5, 0.8, 1.0),
}

func push_shader(shader_name: String) -> int:
	_shader_stack.append(shader_name)
	_apply_top_shader()
	return _shader_stack.size()

## T4 事件化配套：Logic 侧 token 关联（跨事件队列 PUSH/REMOVE 保序），token→栈槽映射由 View 维护。
func push_shader_keyed(token: int, shader_name: String) -> void:
	_shader_keys[token] = push_shader(shader_name)

func remove_shader_keyed(token: int) -> void:
	if _shader_keys.has(token):
		remove_shader(int(_shader_keys[token]))
		_shader_keys.erase(token)

func remove_shader(shader_id: int) -> void:
	if shader_id > _shader_stack.size() or shader_id < 1:
		return
	_shader_stack[shader_id - 1] = ""
	while _shader_stack.size() > 0 and _shader_stack[-1] == "":
		_shader_stack.pop_back()
	_apply_top_shader()

func _apply_top_shader() -> void:
	if puppet == null:
		return
	if _shader_stack.size() == 0:
		puppet.tint(1.0, 1.0, 1.0)  # useDefaultShader 等价（恢复 _fca.modulate=WHITE）
	else:
		var top: String = _shader_stack[-1]
		var c: Color = SHADER_COLORS.get(top, Color.WHITE)
		# shader 需含 alpha（Invisible/Banish 半透明），直接设 _fca.modulate（通过 puppet.set_shader_modulate）
		if puppet.has_method("set_shader_modulate"):
			puppet.set_shader_modulate(c)
		else:
			puppet.tint(c.r, c.g, c.b)


func use_puppet(p_action: String = "", p_loop: bool = false) -> void:
	if model == null or puppet == null:
		return
	var stack: Array = model.puppet_stack
	if stack.size() == 0:
		return
	var puppet_name: String = String(stack[-1])
	if puppet_name == "":
		return
	# 查 Puppet 表取 Resource/Scale/ScaleX Inverse
	var cfg: Dictionary = {}
	if _cm != null:
		cfg = _cm.get_raw_table(&"Puppet").get(puppet_name, {})
	var resource: String = String(cfg.get("Resource", puppet_name))
	var p_scale: float = float(cfg.get("Scale", 1.0))
	var flip_x: bool = bool(cfg.get("ScaleX Inverse", false))
	# 清 shader 栈（旧 puppet 销毁，shader 随之丢失）
	_shader_stack.clear()
	# 切模型
	puppet.switch_puppet(resource, p_scale, flip_x)
	# 恢复 action（照源 :1627-1629 setAction + setLoop）；事件路径用发射时快照（T4），直调默认现值
	if p_action != "":
		apply_action_named(p_action, p_loop)
	else:
		on_start_new_action()
	# 重跑所有 buff 的 onAddedClient（照源 :1632，在新 puppet 上重建 effect/shader）
	for buff in model.buff_list:
		if buff.has_method("on_added_client"):
			buff.on_added_client()


# u.actor.play_effect(...)，转发到 BattleScene.play_effect_on_scene（三层分离：Logic 不 import scene）。
func play_effect(effect_name: String, origin: Vector2, scale: float = 1.0, height: float = 0.0, zorder: int = 0) -> void:
	var scene := get_parent()
	while scene != null and not scene.has_method("play_effect_on_scene"):
		scene = scene.get_parent()
	if scene != null and scene.has_method("play_effect_on_scene"):
		scene.play_effect_on_scene(effect_name, origin, scale, height, zorder)


# u.actor.start_camera_shake_animation_y(...)，转发到 BattleScene（三层分离：Logic 不 import scene）。
# scene==null（纯 Logic 测试 / headless 无场景）自动跳过，等价源 ed.run_with_scene 守卫。
func start_camera_shake_animation_y(max_height: float, shake_time: float, shake_num: int) -> void:
	var scene := get_parent()
	while scene != null and not scene.has_method("start_camera_shake_animation_y"):
		scene = scene.get_parent()
	if scene != null and scene.has_method("start_camera_shake_animation_y"):
		scene.start_camera_shake_animation_y(max_height, shake_time, shake_num)


# combat die 鸭子调 u.actor.play_gold_drop_effect()（需 model.config.money>0，源 self.model.money）。
var _gold_drop_played: bool = false
func play_gold_drop_effect() -> void:
	if model == null or _gold_drop_played:
		return
	var money: int = int(model.config.get("money", 0))
	if money <= 0:
		return
	_gold_drop_played = true
	var pos: Vector2 = model.position
	var scene := get_parent()
	while scene != null and not scene.has_method("add_gold"):
		scene = scene.get_parent()
	if scene == null:
		return
	await _delay_call(scene, 0.2, _do_gold_drop.bind(money, pos))


func _do_gold_drop(money: int, pos: Vector2) -> void:
	play_effect("effect/eff_battle_drop_money", pos, 1.0, 0.0, 1)
	spawn_popup("+" + str(money), "golden", false, "gold")
	var scene := get_parent()
	while scene != null and not scene.has_method("add_gold"):
		scene = scene.get_parent()
	if scene != null:
		scene.add_gold(money)


# 延迟回调辅助（scene 在树里才 await）
func _delay_call(scene: Node, delay: float, cb: Callable) -> void:
	if scene != null and scene.is_inside_tree():
		await scene.get_tree().create_timer(delay).timeout
	cb.call()


func launch(time: float) -> void:
	_z_speed = time * -GRAVITY * 0.5


# 战斗入场走路：actor 从场外起点走到 target_logic_pos，到位发 enter_walk_finished。
# from_offset 为相对站位的场外偏移（玩家负=左外，敌方正=右外）；velocity 方向自动朝向 target。
# 复用 _offline 离线自驱机制（同 goto_next_battle），setup 的初始 update_view 须跳过（_enter_pending）。
func start_enter_walk(target_logic_pos: Vector2, from_offset: float) -> void:
	var start_pos := Vector2(target_logic_pos.x + from_offset, target_logic_pos.y)
	_walk_pos = start_pos
	_enter_target = target_logic_pos
	var base_speed: float = float(model.info.get("Walk Speed", 0.0)) if model != null else 0.0
	if base_speed <= 0.0:
		base_speed = 100.0   # 兜底（Walk Speed 缺失）
	# 方向：offset<0（玩家从左外）→ +x 走向 target；offset>0（敌方从右外）→ -x。
	var dir_x: float = -1.0 if from_offset > 0.0 else 1.0
	_velocity = Vector2(dir_x * base_speed * ENTER_WALK_SPEEDER, 0.0)
	# 立即设朝向（按 velocity 方向），消除首帧错误朝向（敌方 setup 时 direction 可能还是默认 +1，
	# 首帧渲染会朝右，第 2 帧 _offline 分支才纠正 → 起步闪一下）。
	var abs_s: float = absf(scale.x) if scale.x != 0.0 else 1.0
	scale = Vector2(dir_x * abs_s, abs_s)
	if puppet != null:
		if puppet.has_method("play_walk_anim_only"):
			puppet.play_walk_anim_only()
		if puppet.has_method("set_speed"):
			puppet.set_speed(sqrt(ENTER_WALK_SPEEDER))
	_offline = true
	_has_interp = false
	_hold_offline = false  # 入场到位后正常 emit + 重接 engine interp（非 goto_next_battle 的屏外静止）
	_z_speed = null
	_height = 0.0
	# 立即定位到场外起点（不等下一帧 update_view）。
	position = BattleViewCoords.to_view_position(_walk_pos.x, _walk_pos.y, 0.0)


# 切波走路：玩家走到屏外（target_x）等 advance_wave 切波。puppet Move + velocity 朝右 + offline。
# 到位后 _hold_offline 保持离线静止在屏外（不接 interp，防被拉回站位闪现），等 start_enter_walk 接管。
# target_x：屏外右目标 x；到位停止（双保险：到位判定 + await maxtime 任一先到）。
func goto_next_battle(walk_speed: float, target_x: float = -1.0) -> void:
	if puppet != null:
		if puppet.has_method("play_walk_anim_only"):
			puppet.play_walk_anim_only()
		if puppet.has_method("set_speed"):
			puppet.set_speed(sqrt(NEXT_BATTLE_WALK_SPEEDER))
	_velocity = Vector2(walk_speed * NEXT_BATTLE_WALK_SPEEDER, 0.0)
	_walk_pos = Vector2(float(model.position.x), float(model.position.y))
	if target_x > 0.0:
		# _enter_target 是 logic 坐标；_walk_pos 到达 target_x 即停（update_view _offline 分支判定）。
		_enter_target = Vector2(target_x, float(model.position.y))
		_hold_offline = true  # 到位后保持屏外静止等切波（不 emit、不切 interp）
	scale = Vector2.ONE
	_offline = true
	_has_interp = false
	_z_speed = null
	_height = 0.0


# 切波后重置离线态让 actor 重新接 engine interp（源 syncActors 波次 reparent 分支 :570-579）。
# 当前切波改走 start_enter_walk（玩家也走入场），本方法暂无调用者，保留供未来需要时复用。
func reset_after_wave_walk() -> void:
	_offline = false
	_velocity = Vector2.ZERO
	_enter_target = null
	_walk_pos = Vector2.ZERO
	_tick = -1
	_has_interp = false
	_z_speed = null
	_height = 0.0


func _create_floating_bars() -> void:
	bar_group = BattleFloatingBar.create_group()
	# 玩家方头顶不显示血条（底部英雄面板已有 HP/MP）；敌方保留头顶血条看血量。
	if int(model.camp) == BattleEngine.CAMP_PLAYER:
		return
	if int(model.hp_layer) == 0:
		# 普通单位：头顶 HP + Shield，挂 actor node（源 :1547-1556）
		bar_hp = BattleFloatingBar.create(model, "HP")
		add_child(bar_hp)
		bar_hp.z_index = BAR_Z
		bar_hp.position = Vector2(0.0, BAR_HP_Y)
		bar_hp.scale = Vector2(BAR_SCALE, BAR_SCALE)
		bar_group.add_bar("HP", bar_hp)
		bar_shield = BattleFloatingBar.create(model, "Shield")
		add_child(bar_shield)
		bar_shield.z_index = BAR_Z
		bar_shield.position = Vector2(0.0, BAR_SHIELD_Y)
		bar_shield.scale = Vector2(BAR_SCALE, BAR_SCALE)
		bar_group.add_bar("Shield", bar_shield)
	else:
		# Boss：ShieldBoss 挂 ui_layer 固定位置（源 :1558-1562）
		bar_shield = BattleFloatingBar.create(model, "ShieldBoss")
		bar_shield.position = BOSS_BAR_POS
		bar_shield.scale.x = -1.0
		if _ui_layer != null:
			_ui_layer.add_child(bar_shield)
			_boss_bar_external = true
		else:
			add_child(bar_shield)
		bar_group.add_bar("ShieldBoss", bar_shield)


# Boss ShieldBoss 挂 ui_layer，actor free 时需单独清（普通 bars 随 actor 自动 free）。
func _exit_tree() -> void:
	if _boss_bar_external and bar_shield != null and _ui_layer != null:
		if bar_shield.get_parent() == _ui_layer:
			_ui_layer.remove_child(bar_shield)
		bar_shield.queue_free()
