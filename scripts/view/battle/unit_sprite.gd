class_name UnitSprite
extends Node2D

## 战斗单位精灵（View 层）— FCA 散件动画 + 降级头像。照旧版 CardGameGodot 复用并适配：
## DataTables→ConfigManager 注入；Dictionary→BattleUnit 引用（View→Logic 单向）；删散件
## battle_animator 降级（本项目无该文件，FCA 失败直接降级头像）。
## 动作名照源 unit.lua setAction：Idle/Move/atk/atk2/atk3/ult/Damaged/Death。

const AtlasSprite = preload("res://scripts/ui/atlas_sprite.gd")
const FcaAnimation = preload("res://scripts/ui/fca_animation.gd")

const WALK_VISUAL_SPEED: float = 120.0
const PLAYER_CAMP: int = 1            # = BattleEngine.CAMP_PLAYER（照源玩家阵营）
const DEATH_FALL_ROTATE: float = PI / 2.0
const DEATH_FALL_DROP: float = 30.0
const PORTRAIT_FALLBACK_SIZE: float = 60.0

var _unit: Variant = null             # BattleUnit（duck-type：camp/info/hp/mp/attribs）
var _cm: Variant = null               # ConfigManager（查 Puppet/AnimDuration/AnimAtkFrame）
var _is_player: bool = false
var _is_ranged: bool = false
var _puppet_name: String = ""         # Unit.Puppet（.cha 名，时长/帧表 key）
var _resource: String = ""            # Puppet.Resource（anim_frames 目录名）
var _parts_node: Node2D = null        # 散件根（应用 Scale + 朝向翻转）
var _fallback_portrait: TextureRect = null
var _fca: Node = null
var _using_fca: bool = false
var _base_anim_speed: float = 1.0  # FCA 基础速度（战斗 speeder×2 / 走路 √1.75 / 死亡 1.0）
var _current_speed: float = 1.0    # 档位倍率（broadcast/actor 创建点设，随战斗加速档）
var _dead: bool = false
var _walk_direction: int = 0
var _walk_target_pos: Vector2 = Vector2.ZERO
var _is_walking_to_target: bool = false
var _is_walking_directional: bool = false
var _directional_speed: float = 80.0
var _walk_speed_factor: float = 1.0
var _walk_target_speed: float = WALK_VISUAL_SPEED
var _walk_frozen: bool = false

# 战斗级缓存：同一 plist 只解析一次（battle_scene 跨单位共享）
static var _atlas_cache: Dictionary = {}


func setup(unit: Variant, cm: Variant) -> void:
	_unit = unit
	_cm = cm
	_is_player = int(_unit.camp) == PLAYER_CAMP
	_parts_node = Node2D.new()
	add_child(_parts_node)
	_try_load_fca()
	if _using_fca and _fca:
		_fca.play("Idle")


# 查 Unit.Puppet → Puppet.Resource → atlas → FCA；任一缺失降级头像。
func _try_load_fca() -> void:
	_puppet_name = String(_unit.info.get("Puppet", ""))
	var pos_str: String = String(_unit.info.get("Position Type", ""))
	_is_ranged = pos_str.find("REAR") >= 0 or pos_str.find("MIDDLE") >= 0
	if _puppet_name.is_empty():
		_fallback_to_portrait()
		return
	var puppet_cfg: Dictionary = _cm.get_raw_table(&"Puppet").get(_puppet_name, {})
	_resource = String(puppet_cfg.get("Resource", ""))
	if _resource.is_empty():
		_fallback_to_portrait()
		return
	# atlas 加载：先试外部目录（.ani 预解压产物），失败试 .abc/.ani ZIP 直读。
	# plist 前置存在性检查：.abc 单位（Treant 等共 198 场）无预解压目录，
	# 必然失败的 open 只产 WARNING 噪音（回归 2026-08-19 每场 3 条），直跳 zip 路径。
	var plist_path: String = "res://assets/anim_frames/" + _resource + "/sheet.plist"
	var atlas: AtlasSprite = _get_or_load_atlas(plist_path) if FileAccess.file_exists(plist_path) else null
	if atlas == null or not atlas.is_loaded():
		atlas = _get_or_load_atlas_zip("res://assets/anim_frames/" + _resource)
	if atlas == null or not atlas.is_loaded():
		_fallback_to_portrait()
		return
	# 照源 usePuppet :1601-1604 getUnitFlipX = Puppet["ScaleX Inverse"]（资源朝向标记）。
	# direction 由 battle_actor update_view 应用（actor scale.x = direction × scale，源 :1731-1733），
	# puppet 只处理 ScaleX Inverse（不重复翻 camp，否则双重翻转）。
	var scale_x_inv: bool = bool(puppet_cfg.get("ScaleX Inverse", false))
	var puppet_scale: float = float(puppet_cfg.get("Scale", 1.0))
	_parts_node.scale = Vector2(-puppet_scale if scale_x_inv else puppet_scale, puppet_scale)
	_fca = FcaAnimation.new()
	if _fca.load_from_ani(_resource, atlas):
		_parts_node.add_child(_fca)
		_using_fca = true
		_fca.action_finished.connect(_on_fca_action_finished)
		return
	_fca.queue_free()   # FCA 解析失败 → 降级头像
	_fca = null
	_fallback_to_portrait()


func _get_or_load_atlas(plist_path: String) -> AtlasSprite:
	if _atlas_cache.has(plist_path):
		return _atlas_cache[plist_path]
	var atlas := AtlasSprite.new()
	if atlas.load_atlas(plist_path):
		_atlas_cache[plist_path] = atlas
		return atlas
	return null


# ZIP 直读 atlas：.abc 单位（Treant 等）无预解压目录，从 .abc/.ani zip 直读 plist+png。
# 试 .abc 再 .ani（同 FCA 格式，入口名 cha/plist 或 sheet.key/sheet.plist）。
func _get_or_load_atlas_zip(resource_dir: String) -> AtlasSprite:
	for ext in [".abc", ".ani"]:
		var zip_path: String = resource_dir + ext
		if _atlas_cache.has(zip_path):
			return _atlas_cache[zip_path]
		if FileAccess.file_exists(zip_path):
			var atlas := AtlasSprite.new()
			if atlas.load_atlas_from_ani(zip_path):
				_atlas_cache[zip_path] = atlas
				return atlas
	return null


# FCA/puppet 加载失败降级显示。
# camp>0 绿色 ccc3(0,220,0) / camp<=0 红色 ccc3(220,50,50)，setScale(getUnitScale()*0.8)。
# 旧版 CardGameGodot 改用 Portrait 图片降级（不照源），本项目沿用旧版产物；本任务属 CS 审计范围
# 仅触及 TextureRect contentScaleFactor 偏差，源 LabelTTF 不适用 CS 规则 → 本节点保留 + 注释说明，
# Portrait 图片降级 vs LabelTTF 重构待后续按源对齐 task（不在本批 CS 审计内）。
func _fallback_to_portrait() -> void:
	var portrait: String = String(_unit.info.get("Portrait", ""))
	_fallback_portrait = TextureRect.new()
	_fallback_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var has_tex: bool = false
	if not portrait.is_empty():
		var tex: Texture2D = load("res://assets/ui/" + portrait.trim_prefix("UI/")) as Texture2D
		if tex:
			_fallback_portrait.texture = tex
			_fallback_portrait.size = Vector2(80.0, 80.0)
			has_tex = true
	if not has_tex:
		_fallback_portrait.size = Vector2(PORTRAIT_FALLBACK_SIZE, PORTRAIT_FALLBACK_SIZE)
		_fallback_portrait.self_modulate = Color(0.3, 0.3, 0.3)
	_fallback_portrait.position = Vector2(-PORTRAIT_FALLBACK_SIZE / 2.0, -PORTRAIT_FALLBACK_SIZE / 2.0)
	add_child(_fallback_portrait)
	_parts_node.visible = false


# ── 行走系统（_process 驱动；位置由 BattleUnit 算，本类做动画 + 视觉过渡）──

func is_walking() -> bool:
	return _is_walking_to_target or _is_walking_directional


# 施法中动作播完不回 Idle：大招动作 2× 速播完后停在末帧等 phase 结束
#（源 update(dt*2) 主导 + setActionElapsed clamp 末帧同款；回 Idle 会出现"施法还没完人已待机"）。
func _on_fca_action_finished(action_name: String) -> void:
	if action_name != "Idle":
		if _unit != null and _unit.get("current_skill") != null:
			var cs: Variant = _unit.current_skill
			if cs != null and bool(cs.get("casting")):
				return   # 施法中：保持末帧
		_fca.play("Idle")


# 速度分离（2026-09-05）：set_speed 设基础速（动画固有速率），apply_speed_mult 设战斗
# 加速档倍率——实际 FCA 速度 = base × mult。切档只动 mult，base 不被覆盖；base 由
# battle_actor update_view 每 tick / 走路启动 / 死亡时刷新。旧口径 set_speed(全量)
# 在切档 broadcast 与 update_view 每 tick 间互相覆盖，是倍速下动画速度断层的根因。
func set_speed(s: float) -> void:
	_base_anim_speed = s
	_apply_anim_speed()


func apply_speed_mult(m: float) -> void:
	_current_speed = m
	_apply_anim_speed()


func _apply_anim_speed() -> void:
	if _using_fca and _fca:
		_fca.set_speed(_base_anim_speed * _current_speed)


# 设 _fca.modulate（不设 self.modulate，避与 play_hit 闪红 Tween 冲突）。
func tint(r: float, g: float, b: float) -> void:
	if _using_fca and _fca:
		_fca.modulate = Color(clampf(r, 0.0, 1.0), clampf(g, 0.0, 1.0), clampf(b, 0.0, 1.0))


# shader modulate（含 alpha，供 push_shader 用——Invisible/Banish 需半透明）。
func set_shader_modulate(c: Color) -> void:
	if _using_fca and _fca:
		_fca.modulate = c


# 源 actor.usePuppet（unit.lua:1569-1634）模型切换 — 销旧 FCA + 加载新资源（.ani 目录或 .abc zip）。
func switch_puppet(resource: String, p_scale: float, flip_x: bool) -> void:
	if _parts_node == null:  # setup 未调时建
		_parts_node = Node2D.new(); add_child(_parts_node)
	if _fca != null and is_instance_valid(_fca): _fca.queue_free()
	_fca = null; _using_fca = false
	if _fallback_portrait != null and is_instance_valid(_fallback_portrait):
		_fallback_portrait.queue_free(); _fallback_portrait = null
	_resource = resource
	_parts_node.scale = Vector2(-p_scale if flip_x else p_scale, p_scale)
	# 尝试 .ani 目录加载，失败再试 .abc/.ani zip
	var atlas: AtlasSprite = _get_or_load_atlas("res://assets/anim_frames/" + resource + "/sheet.plist")
	if atlas == null:
		atlas = AtlasSprite.new()
		var p := "res://assets/anim_frames/" + resource
		if FileAccess.file_exists(p + ".abc"): atlas.load_atlas_from_ani(p + ".abc")
		elif FileAccess.file_exists(p + ".ani"): atlas.load_atlas_from_ani(p + ".ani")
		else: atlas = null
	if atlas == null or not atlas.is_loaded():
		_fallback_to_portrait(); return
	_fca = FcaAnimation.new()
	if _fca.load_from_ani(resource, atlas):
		_parts_node.add_child(_fca); _using_fca = true
		_fca.action_finished.connect(_on_fca_action_finished); _fca.play("Idle")
		_apply_anim_speed()   # 新 FCA _speed 重置为 1，恢复 base×mult
	else:
		_fca.queue_free(); _fca = null; _fallback_to_portrait()


func set_walk_speed_factor(f: float) -> void:
	_walk_speed_factor = f


func freeze_walk() -> void:
	_walk_frozen = true


func unfreeze_walk() -> void:
	_walk_frozen = false


func _process(delta: float) -> void:
	if _dead or _walk_frozen:
		return
	if _is_walking_to_target:
		var dist: float = position.distance_to(_walk_target_pos)
		if dist < 2.0:
			position = _walk_target_pos
			_is_walking_to_target = false
			if _using_fca and _fca:
				_fca.play("Idle")
			return
		var dir: Vector2 = (_walk_target_pos - position).normalized()
		position += dir * minf(_walk_target_speed * _current_speed * delta, dist)
		return
	if _is_walking_directional and _walk_direction != 0:
		position.x += _walk_direction * _directional_speed * _current_speed * _walk_speed_factor * delta


func walk_to_position(target_pos: Vector2, _duration: float, speed: float = -1.0) -> void:
	if _dead:
		return
	_is_walking_directional = false
	if _using_fca and _fca:
		_fca.play("Move")
	_walk_direction = 0
	_walk_target_pos = target_pos
	_walk_target_speed = speed if speed > 0.0 else WALK_VISUAL_SPEED
	_is_walking_to_target = true


func start_walk(direction: int, speed: float) -> void:
	if _dead:
		return
	_is_walking_to_target = false
	if _using_fca and _fca:
		_fca.play("Move")
	_walk_direction = direction
	_directional_speed = speed * _walk_speed_factor
	_is_walking_directional = true


func play_walk_anim_only() -> void:
	if _using_fca and _fca:
		_fca.play("Move")


func stop_walk(final_pos: Vector2) -> void:
	_walk_direction = 0
	_is_walking_directional = false
	_is_walking_to_target = false
	position = final_pos
	if _using_fca and _fca and _fca.get_current_action() == "Move":
		_fca.play("Idle")


# ── 动作接口（FCA 驱动；行走中受击/闪避用 Tween 视觉反馈不中断移动）──

func _stop_walk_immediately() -> void:
	_is_walking_to_target = false
	_is_walking_directional = false
	_walk_direction = 0


func _is_in_attack_action() -> bool:
	var cur: String = _fca.get_current_action() if _fca else ""
	return cur == "atk" or cur == "ult"


func play_attack(_target_pos: Vector2) -> void:
	if _dead or not _using_fca:
		return
	_stop_walk_immediately()
	if not _is_in_attack_action():
		_fca.play("atk", false)
		_fca.set_next_action("Idle")


func play_ult(_target_pos: Vector2) -> void:
	if _dead or not _using_fca:
		return
	_stop_walk_immediately()
	# 只防 ult 重复触发；atk 播放中必须打断切 ult（源 setAction 无条件切换——
	# 旧守卫挡掉 atk 中的 ult 致"技能已放动画不播"不同步，2026-08-18 修）。
	if _fca.get_current_action() != "ult":
		_fca.play("ult", false)
		_fca.set_next_action("Idle")


func play_hit() -> void:
	if _dead or not _using_fca:
		return
	var cur: String = _fca.get_current_action()
	if cur == "Move":
		# 行走中受击：闪红 + 缩放脉冲（受击单位引擎中仍在移动，视觉同步）
		var t := create_tween()
		t.tween_property(self, "modulate", Color.RED, 0.05)
		t.tween_property(self, "modulate", Color.WHITE, 0.15)
		var t2 := create_tween()
		t2.tween_property(self, "scale", Vector2(0.95, 1.05), 0.05)
		t2.tween_property(self, "scale", Vector2.ONE, 0.1)
	elif not _is_in_attack_action():
		_fca.play("Damaged", false)
		_fca.set_next_action("Idle")


func play_dodge() -> void:
	if _dead or not _using_fca:
		return
	var cur: String = _fca.get_current_action()
	if cur == "Move":
		var t := create_tween()
		t.tween_property(self, "modulate", Color(1, 1, 1, 0.5), 0.1)
		t.tween_property(self, "modulate", Color.WHITE, 0.15)
	elif cur == "Idle" or cur == "Damaged":
		_fca.play("Damaged", false)
		_fca.set_next_action("Idle")


func play_death() -> void:
	_dead = true
	_stop_walk_immediately()
	if not _using_fca:
		_play_fall_down()
		return
	set_speed(1.0)   # 死亡动画基础速 1×（档位倍率仍生效，源死亡动画随 dt 加速）
	if _fca.action_finished.is_connected(_on_fca_action_finished):
		_fca.action_finished.disconnect(_on_fca_action_finished)
	if _fca.has_action("Death"):
		_fca.play("Death", false)
		_fca.action_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)
	else:
		_fca.stop()
		_play_fall_down()


# 直接 FCA play。BattleActor.on_start_new_action 的 default 分支用。
func play_action(action_name: String, loop: bool) -> void:
	if _dead or not _using_fca or not _fca:
		return
	if _fca.has_action(action_name):
		_fca.play(action_name, loop)


func _on_death_anim_finished(_action_name: String) -> void:
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(_on_death_fade_done)


func _on_death_fade_done() -> void:
	visible = false


func _play_fall_down() -> void:
	var fall_dir: float = -1.0 if _is_player else 1.0
	var t := create_tween()
	t.set_speed_scale(_current_speed)
	t.set_parallel(true)
	t.tween_property(_parts_node, "rotation", fall_dir * DEATH_FALL_ROTATE, 0.4).set_ease(Tween.EASE_IN)
	t.tween_property(_parts_node, "position:y", DEATH_FALL_DROP, 0.4).set_ease(Tween.EASE_IN)
	t.set_parallel(false)
	t.tween_property(self, "modulate:a", 0.0, 0.6).set_delay(0.3)
	t.tween_callback(_on_death_fade_done)


# ── 动作时长 / 攻击帧查询（源 AnimDuration/AnimAtkFrame 表，供 Phase 4 battle_scene 调度）──

func get_attack_duration() -> float:
	return _duration("atk", 0.3)


func get_ult_duration() -> float:
	return _duration("ult", 1.0)


func get_attack_launch_time() -> float:
	return _launch_time("atk", get_attack_duration() * 0.4)


func get_ult_launch_time() -> float:
	return _launch_time("ult", get_ult_duration() * 0.4)


func is_ranged() -> bool:
	return _is_ranged


func _duration(action: String, fallback: float) -> float:
	var d: float = _lookup_anim_duration(action)
	if d > 0.0:
		return d
	if _using_fca and _fca:
		d = _fca.get_action_duration(action)
		if d > 0.0:
			return d
	return fallback


func _launch_time(action: String, fallback: float) -> float:
	var t: float = _lookup_atk_frame_time(action)
	if t > 0.0:
		return t
	if _using_fca and _fca:
		t = _fca.get_attack_frame_time(action)
		if t > 0.0:
			return t
	return fallback


# AnimDuration[puppet_name][action].Duration
func _lookup_anim_duration(action: String) -> float:
	if _puppet_name.is_empty() or _cm == null:
		return 0.0
	return float(_cm.get_raw_table(&"AnimDuration").get(_puppet_name, {}).get(action, {}).get("Duration", 0.0))


# AnimAtkFrame[puppet_name][action][time_key].Time（取首个帧事件时间）
func _lookup_atk_frame_time(action: String) -> float:
	if _puppet_name.is_empty() or _cm == null:
		return 0.0
	var row: Dictionary = _cm.get_raw_table(&"AnimAtkFrame").get(_puppet_name, {}).get(action, {})
	for time_key in row:
		var t: float = float(time_key)
		if t > 0.0:
			return t
	return 0.0


# ── 静态缓存清理（battle_scene 进出战时调）──
# 注：prewarm_unit 已删（2026-07-26 A2）—— 零调用的死代码，建 N 个 Sprite2D 后立即 free 纯浪费。
# 预热需求由首次 _try_load_fca/switch_puppet 自然填充 _cache + _atlas_cache 满足。


static func clear_atlas_cache() -> void:
	for key in _atlas_cache:
		_atlas_cache[key].unload()
	_atlas_cache.clear()
	FcaAnimation.clear_cache()
