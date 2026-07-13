class_name BattleProjectile
extends BattleEntity

## 战斗投射物（Logic 层）— 照源 projectile.lua:9-220（Projectile 逻辑）翻译（Phase 2.6，2026-07-01）。
## ProjectileActor（:223-320）是 View（精灵/.cha 特效 + setRotation/setScaleY），Phase 4 接。
## 协作者（duck-type）：skill{info,caster,target,take_effect_on(t,src),take_effect_at(pos,src),
##   _target_camp(),launch_point()}；engine{ticks,foreach_alive_unit,stage_rect}。
## 轨迹：ProjectileCreate（launchPoint 定出生点 + 朝目标的 velocity）→ 进 engine.projectile_list
##   → update（base.update 推进 + 抛物高度 + 碰撞检测 → hit/terminate）。
## track（追踪）/jumps（穿透跳跃，类 chain）由 enableTrack/enableJump 开启（源 API，技能 hook 调）。

const MIN_DIST_HUGE: float = INF  # 源 math.huge（findNext 距离初始）
const MAX_DIST_HUGE: float = INF  # 源 :19 math.huge（Tile Distance=0 → 无限射程）
const FIRST_TIME_INIT: float = 1.0  # 源 :100 firstTime=1（取最小 collide t）
const LAUNCH_DEFAULT_Y: float = 75.0  # 源 :654 event={X=0,Y=75}（无 Attack 事件时骨骼 Y 偏移）
const COLLIDE_NONE: float = -1.0  # collide_check 无碰撞返回值（源 return false）

var skill: Variant = null
var affect_camp: int = 0  # 源 :16 skill:affectedCamp()
var affect_times: Dictionary = {}  # 源 :17 单位→已命中次数（穿透不重复）
var distance: float = 0.0  # 源 :18 已飞行距离（超 max_distance 终止）
var max_distance: float = 0.0  # 源 :19 Tile Distance（0→INF）
var birthtick: int = 0  # 源 :20 ed.engine.ticks（出生同 tick 跳过 update）
var track: bool = false  # 源 :21 enableTrack 开启
var track_target: Variant = null  # 源 enableTrack 设
var jumps: int = 0  # 源 :22 enableJump 设（>0 时命中后跳下一目标，类 chain）
var source: Variant = null  # 源 enableJump/terminate 上一跳目标（下跳起点）
var find_next_override: Callable = Callable()  # 英雄 hook 覆盖 findNextTaeget（Lich 等自定义跳跃寻目标）
var custom_data: Dictionary = {}  # 运行时自定义（源 Lua 动态加 projectile.XXX；英雄 hook 用，如 Med dmgModifier）
var z_speed: float = 0.0  # 源 :49 Tile Z Speed（抛物高度速度）
var hero_hooks: Dictionary = {}  # 英雄 hook（源 override 等价）：update（Phase 2.7续8 TK 3D 追踪）


# 源 ProjectileCreate（projectile.lua:9-56）
func _init(p_skill: Variant) -> void:
	var info: Dictionary = p_skill.info
	var caster: Variant = p_skill.caster
	skill = p_skill
	camp = int(caster.camp)
	affect_camp = int(p_skill._affected_camp())
	affect_times = {}
	distance = 0.0
	var tile_dist: float = float(info.get("Tile Distance", 0.0))
	max_distance = MAX_DIST_HUGE if tile_dist == 0.0 else tile_dist  # 源 :19 0→math.huge
	engine = caster.engine
	birthtick = int(engine.ticks)
	track = false
	jumps = 0
	var launch: Array = p_skill.launch_point()  # 源 :23 skill:launchPoint() → pos,h
	position = launch[0]
	height = float(launch[1])
	var xy_speed: float = float(info.get("Tile XY Speed", 0.0))
	var d: Vector2 = p_skill.target.position - position  # 源 edpSub(target.pos, self.pos)
	if bool(info.get("Aim Target", false)):
		if d == Vector2.ZERO:  # 源 d[1]==0 and d[2]==0
			velocity = Vector2(float(caster.direction), 0.0)
		else:
			velocity = d.normalized() * xy_speed  # 源 edpMult(edpNormalize(d), v[1])
	else:
		d.y = 0.0  # 源 :39 非 Aim Target 只看 X 方向
		if d == Vector2.ZERO:
			velocity = Vector2(float(caster.direction), 0.0)
		else:
			velocity = d.normalized() * xy_speed
	z_speed = float(info.get("Tile Z Speed", 0.0))
	previous_position = position  # 源 :51-54


# 源 enableTrack（:60-65）：追踪目标，每帧重算 velocity 朝向 track_target
func enable_track(p_target: Variant) -> void:
	track = true
	track_target = p_target
	var d: Vector2 = (p_target.position - position).normalized()  # 源 edpNormalize(edpSub(...))
	velocity = d * float(skill.info.get("Tile XY Speed", 0.0))


# 源 enableJump（:68-71）：开启命中后跳跃（times 次），source 初始为技能目标
func enable_jump(times: int) -> void:
	jumps = times
	source = skill.target


# 源 update（:74-128）：英雄 hook override 点（TK 3D 追踪）。hook 内调 _update_default 当 basefunc。
func update(dt: float) -> void:
	var h: Callable = hero_hooks.get("update", Callable())
	if h.is_valid():
		h.call(self, dt)
	else:
		_update_default(dt)


# 源 update 默认体（:74-128）：出生同 tick 跳过 + track 目标校验 + base.update 推进 + 抛物高度 + 碰撞检测
func _update_default(dt: float) -> void:
	if birthtick == int(engine.ticks):
		return  # 源 :75-77 出生同 tick 不 update
	var t_target: Variant = track_target
	if t_target != null:
		if not bool(t_target.is_alive()):
			track_target = null
		if bool(t_target.buff_effects.get("untargetable", false)):
			track_target = null
	previous_position = position  # 源 :87-90
	super.update(dt)  # 源 :91 base.update（Entity 推进 position += velocity*dt）
	var info: Dictionary = skill.info
	height += z_speed * dt  # 源 :93
	z_speed += float(info.get("Tile Gravity", 0.0)) * dt  # 源 :94
	distance += float(info.get("Tile XY Speed", 0.0)) * dt  # 源 :95
	var h: float = height
	var ott: float = float(info.get("Tile OTT Height", 0.0))
	var aoe: String = str(info.get("AOE Origin", ""))
	if ott == 0.0 or h < ott:  # 源 :99 未过 OTT 高度才碰撞检测
		var first_time: float = FIRST_TIME_INIT
		var first_unit: Variant = null
		var piercing: bool = bool(info.get("Tile Piercing", false))
		for unit in engine.foreach_alive_unit(affect_camp):
			if piercing and affect_times.has(unit):
				continue  # 源 :104 穿透且已命中过 → 跳过
			var collide: float = collide_check(unit)
			if collide < 0.0:
				continue  # 源 :107 无碰撞
			if piercing:
				hit(unit)  # 源 :109 穿透直接命中（不终止）
			elif first_time > collide:
				first_time = collide  # 源 :111 非穿透取最近碰撞
				first_unit = unit
		if first_unit != null:
			hit(first_unit)
			terminate()  # 源 :118 非穿透命中即终止
	if not terminated and h <= 0.0 and aoe != "":  # 源 :121 落地 + AOE
		skill.take_effect_at(position)
		terminate()
	if not terminated and (is_out_of_stage() or height < 0.0 or distance > max_distance):
		terminate()  # 源 :125 出界/落地/超距


# 源 hit（:131-139）：AOE→takeEffectAt(target.pos,self) / 单体→takeEffectOn(target,self) + affect_times++
func hit(p_target: Variant) -> void:
	var aoe: String = str(skill.info.get("AOE Origin", ""))
	if aoe != "":
		skill.take_effect_at(p_target.position, self)  # 源 :134 带 source（projectile）
	else:
		skill.take_effect_on(p_target, self)  # 源 :136 带 source
	affect_times[p_target] = int(affect_times.get(p_target, 0)) + 1  # 源 :138


# 源 collideCheck（:142-166）：X 轴一维碰撞（考虑单位 Collide Radius），返回碰撞插值 t∈[0,1] 或无碰撞
func collide_check(unit: Variant) -> float:
	if track_target != null and unit != track_target:
		return COLLIDE_NONE  # 源 :143 追踪模式只碰 track_target
	if bool(unit.buff_effects.get("untargetable", false)):
		return COLLIDE_NONE  # 源 :146
	var radius: float = float(unit.info.get("Collide Radius", 0.0))
	var ux: float = float(unit.position.x)
	var ux0: float = float(unit.previous_position.x)
	var d: float = position.x - ux  # 源 :152
	var d0: float = previous_position.x - ux0  # 源 :153
	if d > 0.0 and d0 > 0.0:
		d -= radius  # 源 :155
		d0 -= radius
	elif d < 0.0 and d0 < 0.0:
		d += radius  # 源 :158
		d0 += radius
	var denom: float = d - d0
	if denom == 0.0:
		return COLLIDE_NONE  # 除零保护（源无，Lua NaN 自然 falsy）
	var t: float = -d0 / denom  # 源 :161
	if t < 0.0 or t > 1.0:
		return COLLIDE_NONE  # 源 :162
	return t


# 源 terminate（:169-200）：jumps-- → 还有跳跃次数且未出界 → findNext 跳下一目标；否则真终止
func terminate() -> void:
	jumps -= 1  # 源 :171
	if jumps <= 0 or is_out_of_stage():
		super.terminate()  # 源 :173 basefunc(self)（terminated=true）
		return
	var target: Variant = find_next_target()  # 源 :176
	if target == null:
		super.terminate()  # 源 :197 无下一目标 → 终止
		return
	position = source.position  # 源 :178-181 跳到 source 位置
	var d: Vector2 = target.position - position
	var speed: float = float(skill.info.get("Tile XY Speed", 0.0))
	velocity = d.normalized() * speed  # 源 :184
	previous_position = position  # 源 :185-188
	distance = 0.0
	height = 0.0
	z_speed = 0.0
	if track:
		track_target = target  # 源 :193
	source = target  # 源 :195


# 源 findNextTaeget（:203-219）：affect_camp 内距离最近 + 未命中过 + 非当前 source
func find_next_target() -> Variant:
	if find_next_override.is_valid():
		return find_next_override.call(self)  # 英雄 hook 覆盖（Lich：targetCamp + range 内取最近 source）
	var min_sq: float = MIN_DIST_HUGE
	var ret: Variant = null
	for unit in engine.foreach_alive_unit(int(skill._target_camp())):
		if unit == source:
			continue  # 源 :207
		if bool(unit.buff_effects.get("untargetable", false)):
			continue  # 源 :208
		if affect_times.has(unit):
			continue  # 源 :209 已命中过 → 跳过
		var dist_sq: float = unit.position.distance_squared_to(position)  # 源 :211 edpDistanceSQ
		if dist_sq < min_sq:
			ret = unit
			min_sq = dist_sq
	return ret
