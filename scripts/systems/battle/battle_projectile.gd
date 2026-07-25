class_name BattleProjectile
extends BattleEntity

## 战斗投射物（Logic 层）— 照源 projectile.lua:9-220（Projectile 逻辑）翻译（Phase 2.6，2026-07-01）。
## ProjectileActor（:223-320）是 View（精灵/.cha 特效 + setRotation/setScaleY），Phase 4 接。
## 协作者（duck-type）：skill{info,caster,target,take_effect_on(t,src),take_effect_at(pos,src),
##   _target_camp(),launch_point()}；engine{ticks,foreach_alive_unit,stage_rect}。
## 轨迹：ProjectileCreate（launchPoint 定出生点 + 朝目标的 velocity）→ 进 engine.projectile_list
##   → update（base.update 推进 + 抛物高度 + 碰撞检测 → hit/terminate）。
## track（追踪）/jumps（穿透跳跃，类 chain）由 enableTrack/enableJump 开启（源 API，技能 hook 调）。

const MIN_DIST_HUGE: float = INF
const MAX_DIST_HUGE: float = INF
const FIRST_TIME_INIT: float = 1.0
const LAUNCH_DEFAULT_Y: float = 75.0
const COLLIDE_NONE: float = -1.0  # collide_check 无碰撞返回值（源 return false）

var skill: Variant = null
var affect_camp: int = 0
var affect_times: Dictionary = {}
var distance: float = 0.0
var max_distance: float = 0.0
var birthtick: int = 0
var track: bool = false
var track_target: Variant = null
var jumps: int = 0
var source: Variant = null
var find_next_override: Callable = Callable()  # 英雄 hook 覆盖 findNextTaeget（Lich 等自定义跳跃寻目标）
var custom_data: Dictionary = {}  # 运行时自定义（源 Lua 动态加 projectile.XXX；英雄 hook 用，如 Med dmgModifier）
var z_speed: float = 0.0
var hero_hooks: Dictionary = {}  # 英雄 hook（源 override 等价）：update（Phase 2.7续8 TK 3D 追踪）


func _init(p_skill: Variant) -> void:
	var info: Dictionary = p_skill.info
	var caster: Variant = p_skill.caster
	skill = p_skill
	camp = int(caster.camp)
	affect_camp = int(p_skill._affected_camp())
	affect_times = {}
	distance = 0.0
	var tile_dist: float = float(info.get("Tile Distance", 0.0))
	max_distance = MAX_DIST_HUGE if tile_dist == 0.0 else tile_dist
	engine = caster.engine
	birthtick = int(engine.ticks)
	track = false
	jumps = 0
	var launch: Array = p_skill.launch_point()
	position = launch[0]
	height = float(launch[1])
	var xy_speed: float = float(info.get("Tile XY Speed", 0.0))
	var d: Vector2 = p_skill.target.position - position
	if bool(info.get("Aim Target", false)):
		if d == Vector2.ZERO:
			velocity = Vector2(float(caster.direction), 0.0)
		else:
			velocity = d.normalized() * xy_speed
	else:
		d.y = 0.0
		if d == Vector2.ZERO:
			velocity = Vector2(float(caster.direction), 0.0)
		else:
			velocity = d.normalized() * xy_speed
	z_speed = float(info.get("Tile Z Speed", 0.0))
	previous_position = position


func enable_track(p_target: Variant) -> void:
	track = true
	track_target = p_target
	var d: Vector2 = (p_target.position - position).normalized()
	velocity = d * float(skill.info.get("Tile XY Speed", 0.0))


func enable_jump(times: int) -> void:
	jumps = times
	source = skill.target


func update(dt: float) -> void:
	var h: Callable = hero_hooks.get("update", Callable())
	if h.is_valid():
		h.call(self, dt)
	else:
		_update_default(dt)


func _update_default(dt: float) -> void:
	if birthtick == int(engine.ticks):
		return
	var t_target: Variant = track_target
	if t_target != null:
		if not bool(t_target.is_alive()):
			track_target = null
		if bool(t_target.buff_effects.get("untargetable", false)):
			track_target = null
	previous_position = position
	super.update(dt)
	var info: Dictionary = skill.info
	height += z_speed * dt
	z_speed += float(info.get("Tile Gravity", 0.0)) * dt
	distance += float(info.get("Tile XY Speed", 0.0)) * dt
	var h: float = height
	var ott: float = float(info.get("Tile OTT Height", 0.0))
	var aoe: String = str(info.get("AOE Origin", ""))
	if ott == 0.0 or h < ott:
		var first_time: float = FIRST_TIME_INIT
		var first_unit: Variant = null
		var piercing: bool = bool(info.get("Tile Piercing", false))
		for unit in engine.foreach_alive_unit(affect_camp):
			if piercing and affect_times.has(unit):
				continue
			var collide: float = collide_check(unit)
			if collide < 0.0:
				continue
			if piercing:
				hit(unit)
			elif first_time > collide:
				first_time = collide
				first_unit = unit
		if first_unit != null:
			hit(first_unit)
			terminate()
	if not terminated and h <= 0.0 and aoe != "":
		skill.take_effect_at(position)
		terminate()
	if not terminated and (is_out_of_stage() or height < 0.0 or distance > max_distance):
		terminate()


func hit(p_target: Variant) -> void:
	var aoe: String = str(skill.info.get("AOE Origin", ""))
	if aoe != "":
		skill.take_effect_at(p_target.position, self)
	else:
		skill.take_effect_on(p_target, self)
	affect_times[p_target] = int(affect_times.get(p_target, 0)) + 1


func collide_check(unit: Variant) -> float:
	if track_target != null and unit != track_target:
		return COLLIDE_NONE
	if bool(unit.buff_effects.get("untargetable", false)):
		return COLLIDE_NONE
	var radius: float = float(unit.info.get("Collide Radius", 0.0))
	var ux: float = float(unit.position.x)
	var ux0: float = float(unit.previous_position.x)
	var d: float = position.x - ux
	var d0: float = previous_position.x - ux0
	if d > 0.0 and d0 > 0.0:
		d -= radius
		d0 -= radius
	elif d < 0.0 and d0 < 0.0:
		d += radius
		d0 += radius
	var denom: float = d - d0
	if denom == 0.0:
		return COLLIDE_NONE  # 除零保护（源无，Lua NaN 自然 falsy）
	var t: float = -d0 / denom
	if t < 0.0 or t > 1.0:
		return COLLIDE_NONE
	return t


func terminate() -> void:
	jumps -= 1
	if jumps <= 0 or is_out_of_stage():
		super.terminate()
		return
	var target: Variant = find_next_target()
	if target == null:
		super.terminate()
		return
	position = source.position
	var d: Vector2 = target.position - position
	var speed: float = float(skill.info.get("Tile XY Speed", 0.0))
	velocity = d.normalized() * speed
	previous_position = position
	distance = 0.0
	height = 0.0
	z_speed = 0.0
	if track:
		track_target = target
	source = target


func find_next_target() -> Variant:
	if find_next_override.is_valid():
		return find_next_override.call(self)  # 英雄 hook 覆盖（Lich：targetCamp + range 内取最近 source）
	var min_sq: float = MIN_DIST_HUGE
	var ret: Variant = null
	for unit in engine.foreach_alive_unit(int(skill._target_camp())):
		if unit == source:
			continue
		if bool(unit.buff_effects.get("untargetable", false)):
			continue
		if affect_times.has(unit):
			continue
		var dist_sq: float = unit.position.distance_squared_to(position)
		if dist_sq < min_sq:
			ret = unit
			min_sq = dist_sq
	return ret
