class_name BattleActor
extends Node2D

## 单位 actor（View 包装）— 照源 unit.lua:1518-1567 UnitActorCreate + :1724-1785 update 翻译。
## 从 battle_scene.gd 拆出（控四大原则 ≤400，2026-07-02）。Node2D 容器 + UnitSprite puppet +
## 位置同步 + interp 双缓冲插值（tick 间 lerp）+ FloatingBar 血条 + knockup 弧线 + getRuntimeScale/setActionSpeeder。

const BAR_SCALE: float = 0.6666666666666666          # 源 :1550/1555 setScale(0.666...)
const BAR_HP_Y: float = 114.5                        # 源 :1549 setPosition(0,114.5)
const BAR_SHIELD_Y: float = 110.0                    # 源 :1554 setPosition(0,110)
const BOSS_BAR_POS: Vector2 = Vector2(355.0, 426.0)  # 源 :1559 setPosition(355,426)
const BAR_Z: int = 999                               # 源 :1548/1553 addChild(node, 999)
const MANUALLY_CAST_SCALE: float = 1.35              # 源 :1477 manually_casting 放大
const GRAVITY: float = -1800.0                       # 源 :1722 gravity（knockup 弧线）
const NEXT_BATTLE_WALK_SPEEDER: float = 1.75         # 源 battle_scene.lua:407 ed.next_battle_walk_speeder
const BattleEffect = preload("res://scripts/view/battle/battle_effect.gd")

var model: Variant = null     # BattleUnit（Logic 层单位）
var puppet: Variant = null    # UnitSprite（FCA 动画；源 puppet 不带血条）
var bar_group: Variant = null # BattleFloatingBar.Group（源 :1545）
var bar_hp: Node2D = null     # BattleFloatingBar HP（普通单位头顶）
var bar_shield: Node2D = null # BattleFloatingBar Shield / ShieldBoss
var _ui_layer: Node = null  # Boss ShieldBoss 挂载层（源 :1561 scene.ui_layer）
var _boss_bar_external: bool = false  # bar_shield 在 ui_layer（actor free 需单独清）
var in_scene: bool = false
var _offline: bool = false        # 源 :1662 offline（死亡淡出 / gotoNextBattle 走路）
var _velocity: Vector2 = Vector2.ZERO  # 源 :1741 actor.velocity（gotoNextBattle 走路速度）
var _walk_pos: Vector2 = Vector2.ZERO  # offline 走路累积 Logic 位置（源 self.position velocity 移动）
var _tick: int = -1               # 源 :1727 self.tick（上次同步 tick）
var _has_interp: bool = false     # interp_from 是否就位
var _interp_from: Vector2 = Vector2.ZERO  # 源 :1736 interp_from = previous_position
var _interp_to: Vector2 = Vector2.ZERO    # 源 :1737 interp_to = position
var _interp_alpha: float = 0.0    # 源 :1738 interp_alpha
var _z_speed: Variant = null     # 源 :1537 zSpeed（击飞初速度，null=未击飞）
var _height: float = 0.0         # 源 :1536 actor.height（knockup 渲染高度，独立 model.height）
var _effects: Dictionary = {}    # 源 puppet.effects[name] = effect_node（puppet:addEffect）
var _shader_stack: Array[String] = []  # 源 unit.lua:1636 shader_stack（pushShader/removeShader）
var _cm: Variant = null                 # ConfigManager（use_puppet 查 Puppet 表）


func setup(p_model: Variant, p_cm: Variant, p_ui_layer: Node = null) -> void:
	model = p_model
	_cm = p_cm
	_ui_layer = p_ui_layer
	puppet = UnitSprite.new()
	add_child(puppet)
	puppet.setup(model, p_cm)
	_create_floating_bars()   # 源 :1545-1563
	update_view(0.0)


# 源 actor update（unit.lua:1724-1785）：tick 变化时双缓冲（interp_from=previous_position,
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
		# 源 :1731-1733 getRuntimeScale → node scale（direction*scale, scale）
		var rt_scale: float = _get_runtime_scale()
		scale = Vector2(int(model.direction) * rt_scale, rt_scale)
		# 源 :1746 setActionSpeeder(frozen ? 0 : speeder)
		if puppet != null:
			var spd: float = 0.0 if bool(model.buff_effects.get("frozen", false)) else float(model.speeder)
			puppet.set_speed(spd)
	var logic_pos: Vector2
	if _offline and _velocity != Vector2.ZERO:
		# 源 :1759-1764 interp nil（gotoNextBattle 清）→ velocity 移动（offline 走路到下一关）
		_walk_pos += Vector2(_velocity.x * dt, _velocity.y * dt)
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
	# 源 :1770-1778 knockup 弧线（actor.height 自算每帧，独立 model.height）
	if _z_speed != null:
		_height += float(_z_speed) * dt
		_z_speed = float(_z_speed) + GRAVITY * dt
		if _height < 0.0:
			_z_speed = null
			_height = 0.0
	# 源 height 正=向上（Cocos y 上），Godot y 向下 → 取负让击飞向上
	position = BattleViewCoords.to_view_position(logic_pos.x, logic_pos.y, -_height)
	z_index = -int(float(model.position.y))   # 源 :1781 setZOrder(-position.y)（y 大者靠后）
	if bar_group != null:
		bar_group.update(dt)   # 源 :1782-1784 bar_group:update(dt)


# 源 getRuntimeScale（unit.lua:1463-1479）：scaleAction 分支（:1464-1474）+ manually_casting（:1475-1478）。
func _get_runtime_scale() -> float:
	# 源 :1464-1474 scaleAction（技能缩放动画，Boss 大招）
	if bool(model.is_scale_action_running):
		model.scale_action_running_time += float(model.dt_action)   # 源 :1466
		if model.scale_action_running_time > model.scale_action_duration:
			return float(model.scale_action_scale_value)   # 源 :1468 超时→终值
		return model.scale_action_running_time / model.scale_action_duration * (model.scale_action_scale_value - 1.0) + 1.0   # 源 :1471 渐变
	# 源 :1475-1478 manually_casting
	return MANUALLY_CAST_SCALE if bool(model.manually_casting) else 1.0


# 源 ed.PopupCreate(str, color, actor, crit, style)（popup.lua）的 View 桥——Logic 层（combat/buff/
# skill/engine/heroes）鸭子调此方法（复用 launch 同模式 u.get("actor").spawn_popup(...)），不 import
# BattlePopup（三层分离铁律）。color 色键透传给 BattlePopup 映射 RGB。_ui_layer 由 setup 装配（Boss
# ShieldBar 复用同引用）。model = BattleUnit（Logic position，BattlePopup 内部 toViewPosition）。
# 源 ed.PopupCreate(str, color, actor, crit, style)（popup.lua）的 View 桥——Logic 层（combat/buff/
# skill/engine/heroes）鸭子调此方法（复用 launch 同模式 u.get("actor").spawn_popup(...)），不 import
# BattlePopup（三层分离铁律）。color 色键透传给 BattlePopup 映射 RGB。_ui_layer 由 setup 装配（Boss
# ShieldBar 复用同引用）。model = BattleUnit（Logic position，BattlePopup 内部 toViewPosition）。
func spawn_popup(text: String, color: String, crit: bool = false, style: String = "damage") -> void:
	if _ui_layer == null or model == null:
		return
	BattlePopup.create(text, model, crit, style, color, _ui_layer)


# 源 unit.lua:1113/1158 ed.playEffect("sound/<NAME>_ULT|_DEATH.mp3") 的 View 桥——
# combat die / behavior cast_manual_skill 鸭子调 u.actor.play_voice(name, suffix)，转发
# AudioPlayer.play_sfx_by_path（三层分离：Logic 不直接碰 Audio；照 spawn_popup 同模式）。
# name 传入时已 to_upper（源 :1111/1156 string.upper(self.name) 在 Logic 完成）。
func play_voice(unit_name: String, suffix: String) -> void:
	if model == null or unit_name == "":
		return
	AudioPlayer.play_sfx_by_path("sound/" + unit_name + suffix + ".mp3")


# 源 npc.lua:177-186 onStartNewAction → puppet:setAction(action_name)+setLoop。
# 目标分发：Death/Damaged/atk*/ult → puppet.play_*（含目标自加视觉反馈）；
# Move/Idle/"" → 现有 walk 系统处理（不重复，walk_to_position/start_walk 已驱动 Move/Idle FCA）；
# 其他（Birth/Idle2 等特殊英雄动作）→ puppet.play_action 通用 FCA play。
func on_start_new_action() -> void:
	if puppet == null or model == null:
		return
	var action: String = String(model.action_name)
	match action:
		"Death":
			puppet.play_death()
		"Damaged":
			puppet.play_hit()
		"atk", "atk2", "atk3":
			puppet.play_attack(Vector2.ZERO)
		"ult":
			puppet.play_ult(Vector2.ZERO)
		"Move", "Idle", "":
			pass
		_:
			puppet.play_action(action, bool(model.action_loop))


# 源 puppet:addEffect（unit.lua:1792-1800）：挂载 .cha FCA 特效到 puppet（随角色移动）。
# hero hook 鸭子调 caster.actor.add_effect(name, zorder) / target.actor.add_effect(name, zorder)。
func add_effect(effect_name: String, zorder: int = 0) -> void:
	if effect_name == "":
		return
	remove_effect(effect_name)   # 源 :345 先清同名旧 effect

	# 照源 EffectCreate .cha 分支：尝试加载 FCA 特效
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


# 源 puppet:removeEffect：移除同名特效节点。
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


# 源 unit.lua:1918-1921 tint（actor:tint → puppet:tint）。
func tint(r: float, g: float, b: float) -> void:
	if puppet != null and puppet.has_method("tint"):
		puppet.tint(r, g, b)


# 源 unit.lua:1636-1644 pushShader — shader 名映射 modulate 近似色（降级，非真 Godot shader）。
const SHADER_COLORS: Dictionary = {
	"FrozenShader": Color(0.6, 0.7, 1.0), "StoneShader": Color(0.5, 0.5, 0.5),
	"PoisonShader": Color(0.5, 1.0, 0.5), "BanishShader": Color(1.0, 0.5, 0.5, 0.5),
	"InvisibleShader": Color(1.0, 1.0, 1.0, 0.3), "IceShader": Color(0.5, 0.8, 1.0),
}

func push_shader(shader_name: String) -> int:
	_shader_stack.append(shader_name)
	_apply_top_shader()
	return _shader_stack.size()  # 源返回栈深度作 ID

# 源 unit.lua:1647-1659 removeShader — 栈打洞 + 尾部清理 + 回退栈顶 or 默认。
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


# 源 actor.usePuppet（unit.lua:1569-1634）— 栈顶模型切换 + 清 shader 栈 + 重跑 buff onAddedClient。
func use_puppet() -> void:
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
	# 恢复当前 action（照源 :1627-1629 setAction + setLoop）
	on_start_new_action()
	# 重跑所有 buff 的 onAddedClient（照源 :1632，在新 puppet 上重建 effect/shader）
	for buff in model.buff_list:
		if buff.has_method("on_added_client"):
			buff.on_added_client()


# 源 ed.scene:playEffectOnScene（battle_scene.lua:889）的 View 桥——hero hook 鸭子调
# u.actor.play_effect(...)，转发到 BattleScene.play_effect_on_scene（三层分离：Logic 不 import scene）。
func play_effect(effect_name: String, origin: Vector2, scale: float = 1.0, height: float = 0.0, zorder: int = 0) -> void:
	var scene := get_parent()
	while scene != null and not scene.has_method("play_effect_on_scene"):
		scene = scene.get_parent()
	if scene != null and scene.has_method("play_effect_on_scene"):
		scene.play_effect_on_scene(effect_name, origin, scale, height, zorder)


# 源 unit.lua:1674 playGoldDropEffect — monster 死亡掉金币飘字 + addGold。
# combat die 鸭子调 u.actor.play_gold_drop_effect()（需 model.config.money>0，源 self.model.money）。
var _gold_drop_played: bool = false
func play_gold_drop_effect() -> void:
	if model == null or _gold_drop_played:
		return
	var money: int = int(model.config.get("money", 0))
	if money <= 0:
		return
	_gold_drop_played = true
	# 源 :1685-1690 延迟 0.2s → playEffect + popup + addGold
	var pos: Vector2 = model.position
	var scene := get_parent()
	while scene != null and not scene.has_method("add_gold"):
		scene = scene.get_parent()
	if scene == null:
		return
	await _delay_call(scene, 0.2, _do_gold_drop.bind(money, pos))


# 源 :1687-1690：playEffect("eff_battle_drop_money") + popup("+N","gold") + addGold(money)
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


# 源 launch（:1868-1870）：击飞启动，zSpeed = time * -gravity * 0.5（向上初速度）。
func launch(time: float) -> void:
	_z_speed = time * -GRAVITY * 0.5


# 源 gotoNextBattle（unit.lua:1873-1890）：玩家走路到下一关（nextBtnTapHandler 调）。
# puppet Move + speeder^0.5 + velocity = Walk Speed × 1.75 + scale(1,1) 朝右 + offline + 清 interp。
func goto_next_battle(walk_speed: float) -> void:
	if puppet != null:
		if puppet.has_method("play_walk_anim_only"):
			puppet.play_walk_anim_only()   # 源 :1875-1876 setAction(Move) + loop
		if puppet.has_method("set_speed"):
			puppet.set_speed(sqrt(NEXT_BATTLE_WALK_SPEEDER))   # 源 :1878 speeder^0.5
	_velocity = Vector2(walk_speed * NEXT_BATTLE_WALK_SPEEDER, 0.0)   # 源 :1879-1882
	_walk_pos = Vector2(float(model.position.x), float(model.position.y))
	scale = Vector2.ONE   # 源 :1883-1884 setScale(1,1)（朝右走，去 direction 翻转）
	_offline = true
	_has_interp = false   # 源 :1887-1889 清 interp（用 velocity 移动）
	_z_speed = null
	_height = 0.0


# 源 UnitActorCreate:1545-1563 — bar_group + HP/Shield（普通）或 ShieldBoss（Boss 挂 ui_layer）。
func _create_floating_bars() -> void:
	bar_group = BattleFloatingBar.create_group()
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
		bar_shield.position = BattleViewCoords.to_godot(BOSS_BAR_POS.x, BOSS_BAR_POS.y)
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
