class_name BattleNpc
extends BattleEntity

## 战斗 NPC（Logic 层）— 照源 npc.lua:1-125（Npc 模型）翻译（Phase 2.6，2026-07-01）。
## NpcActor（:128-240）是 View（puppet/CCNode/setFlipX/onNpcDeath 特效），Phase 4 接。
## NPC = 场景装饰实体（城堡/旗子/背景生物），进 engine.npc_list，die 调 engine.on_npc_die。
## 协作者：engine{ticks,on_npc_die,stage_rect}。setAction 的 AnimDuration 时序查表是 View 层，
## Logic 桩 duration=0（同 _rebuild_phase_list 处理，Logic 核心不依赖 View 时序表）。
## engine 参数为最小适配（源 NpcCreate 用全局 ed.engine，Godot 注入）。

const STATE_IDLE: int = 0
const STATE_DYING: int = 4
const STATE_DEAD: int = 5

var info: Dictionary = {}
var owner: Variant = null
var born_action_name: String = "Idle"
var action_name: Variant = null
var action_loop: bool = false
var action_duration: float = 0.0
var action_elapsed: float = 0.0
var is_flip_x: bool = false
var state: int = STATE_IDLE
var birthtick: int = 0
var dt_action: float = 0.0
var hero_hooks: Dictionary = {}  # 英雄 hook（源 override 等价）：onActionFinished（TitanHead npc 装饰切 Idle2）


func _init(p_info: Dictionary, p_engine: Variant, is_flip_x: bool = false, p_owner: Variant = null) -> void:
	info = p_info
	owner = p_owner
	engine = p_engine
	born_action_name = "Idle"
	action_name = null
	action_loop = false
	action_duration = 0.0
	action_elapsed = 0.0
	self.is_flip_x = is_flip_x
	# puppet_stack（源 :22-24）View 层（Spine 骨骼），Logic 仅持 info.Puppet（Phase 4）
	position = Vector2(float(info.get("Position X", 0.0)), float(info.get("Position Y", 0.0)))
	birthtick = int(p_engine.ticks)
	state = STATE_IDLE


func set_born_action(action_name: String) -> void:
	born_action_name = action_name


func update(dt: float) -> void:
	dt_action = dt
	if action_name != null and not action_loop:
		var elapsed: float = action_elapsed + dt_action
		var duration: float = action_duration
		if duration > 0.0 and elapsed > duration:
			elapsed -= duration
			on_action_finished()
			action_name = null
		action_elapsed = elapsed
	# actor:setFlipX（View）Phase 4
	super.update(dt)


func terminate() -> void:
	super.terminate()


func on_action_finished() -> void:
	var h: Callable = hero_hooks.get("onActionFinished", Callable())
	if h.is_valid():
		h.call(self)


func is_alive() -> bool:
	return state != STATE_DEAD and state != STATE_DYING


func die() -> void:
	if not is_alive():
		return
	set_action("Death", false, true)
	engine.on_npc_die(self)
	state = STATE_DYING
	emit_npc_death()


func set_action(action_name: String, loop: bool, interrupt: bool) -> void:
	action_loop = loop
	if loop and action_name == self.action_name:
		return
	self.action_name = action_name
	action_elapsed = 0.0 if interrupt else maxf(0.0, action_elapsed - action_duration)
	if not loop and action_name != "":
		# action_duration = lookupDataTable("AnimDuration",...)（View 时序表），Logic 桩 0
		action_duration = 0.0
	else:
		action_duration = 0.0
	emit_new_action(action_name, loop)


func set_flip_x(flip: bool) -> void:
	is_flip_x = flip


func get_unit_scale() -> float:
	return 1.0
