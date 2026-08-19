class_name BattleEffect
extends RefCounted

## FCA 特效包装（View 层）— 复刻源 effect.lua EffectCreate + resource_manager.lua createFcaNode。
## 把 FcaAnimation 包装为 effect_list 兼容对象（update/is_terminated 协议）。
## .abc 资源加载失败时降级为空 Node2D（照源 createFcaNode stub 兜底）。

const AtlasSprite = preload("res://scripts/ui/atlas_sprite.gd")
const FcaAnimation = preload("res://scripts/ui/fca_animation.gd")

var _fca: FcaAnimation = null
var _node: Node2D = null
var _terminated: bool = false
var _loop: bool = false


## 静态工厂（照源 createFcaNode + EffectCreate .cha 分支）。
## effect_name 可能带 .cha 后缀（源 string.gsub 剥除）或 effect/ 子目录前缀；返回 BattleEffect 或 null。
## 路径回退：数据表原始值（如 "eff_tile_X.cha"）无子目录前缀，但资源全在
## assets/anim_frames/effect/ 下，故原路径查不到时自动补 effect/ 前缀重试。
static func create(effect_name: String) -> BattleEffect:
	var name := effect_name.substr(0, effect_name.length() - 4) if effect_name.ends_with(".cha") else effect_name
	# 注意：.abc/.ani 是 zip 非 Godot 资源，用 FileAccess.file_exists 而非 ResourceLoader.exists
	var atlas := AtlasSprite.new()
	var atlas_ok := false
	var zip_path := "res://assets/anim_frames/" + name + ".abc"
	var ani_path := "res://assets/anim_frames/" + name + ".ani"
	# 原路径查不到时回退 effect/ 子目录（生产数据表值无前缀，资源全在 effect/ 下）。
	if not (FileAccess.file_exists(zip_path) or FileAccess.file_exists(ani_path)):
		zip_path = "res://assets/anim_frames/effect/" + name + ".abc"
		ani_path = "res://assets/anim_frames/effect/" + name + ".ani"
	if FileAccess.file_exists(zip_path):
		atlas_ok = atlas.load_atlas_from_ani(zip_path)
	elif FileAccess.file_exists(ani_path):
		atlas_ok = atlas.load_atlas_from_ani(ani_path)
	if not atlas_ok:
		return null  # 降级：调用方建空 Node2D（照源 CCNode stub 兜底）

	var fca := FcaAnimation.new()
	if not fca.load_from_ani(name, atlas):
		return null

	var eff := BattleEffect.new()
	eff._fca = fca
	eff._node = fca  # FcaAnimation extends Node2D，直接作为场景节点
	return eff


# 战斗加速同步：FcaAnimation _process 用真实 delta 自驱，特效须由外部补偿倍率
# （源 effect:update(dt) 与 actor 同链被加速 dt 集中推进；Godot 版自驱漏倍率 →
# 2x 下人物动作 2x 播而特效 1x 播，技能动画与人物动画不同步，2026-08-19 修）。
func set_speed(s: float) -> void:
	if _fca != null:
		_fca.set_speed(s)


func play(action: String = "Start", loop: bool = false) -> void:
	_loop = loop
	if _fca == null:
		return
	# Start/Loop 切换在 C++ 内部，不经 effect.lua:30/48）：enter → setStartAction（默认 "Start"）；
	# onAnimFinished → 有 Loop 切 Loop 循环，否则 terminate。
	# ⚠️ 原默认 "Play" 系误用 effect.lua 路径 B（XML）的 effect_group.start or "Play"——
	# 实测 327 .abc：'Start'=304 / 'Loop'=130 / 无 'Play'，原代码永走 fallback 首个 action。
	var start_action := action
	if not _fca.has_action(start_action):
		if _fca.get_action_names().size() > 0:
			start_action = _fca.get_action_names()[0]  # 兜底首个（无 Start 的单次/角色特效）
		else:
			return
	# Start→Loop 自动切换：先 play(Start) 再 set_next_action(Loop)——fca.play :207 会清 _next_action，
	# 故 set 必须在 play 后（照 unit_sprite.gd:260-261 范式）；切时 loop=true 无限循环，靠外部 remove_effect 终止
	if start_action != "Loop" and _fca.has_action("Loop"):
		_fca.play(start_action, false)
		_fca.set_next_action("Loop")
	else:
		_fca.play(start_action, loop)  # 无 Loop 配对：loop 参数控制单 action 循环
	if not _fca.action_finished.is_connected(_on_action_finished):
		_fca.action_finished.connect(_on_action_finished)


# Loop 无限循环靠外部 remove_effect 终止；其余 action 播完 terminate。
func _on_action_finished(action_name: String) -> void:
	if action_name == "Start" and _fca != null and _fca.has_action("Loop"):
		return
	_terminated = true


## effect_list 协议：推进（FcaAnimation _process 自驱动，这里仅占位）。
func update(_dt: float) -> void:
	pass


## effect_list 协议：是否终止（照源 isTerminated）。
func is_terminated() -> bool:
	if _terminated:
		return true
	if _fca != null and _fca.is_finished():
		return true
	return false


func get_node() -> Node2D:
	return _node


# RefCounted 析构时 free 持有的 _node（FcaAnimation 挂场景层，RefCounted 不级联 free → orphan/CanvasItem leak 根因）。
# effect_list 移除 effect → 引用归零 → PREDELETE → free _node（1339 CanvasItem leaked 修复）。
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _node != null and is_instance_valid(_node):
		_node.queue_free()


## 降级占位特效（资源缺失时用，照源 createFcaNode CCNode stub 兜底）。
class FallbackEffect:
	var _node: Node2D; var _life: float
	func _init(node: Node2D, life: float) -> void: _node = node; _life = life
	func update(dt: float) -> void:
		_life -= dt
		if _life <= 0.0 and is_instance_valid(_node): _node.queue_free()
	func is_terminated() -> bool: return _life <= 0.0
	func get_node() -> Node2D: return _node
	# RefCounted 析构 free _node（update 内 _life<=0 已 free 时 is_instance_valid 守卫跳过）。
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and _node != null and is_instance_valid(_node):
			_node.queue_free()
