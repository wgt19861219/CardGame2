class_name BattleChain
extends BattleEntity

## 战斗链式技能（Logic 层）— 照源 chain.lua:1-84（Chain 逻辑）翻译（Phase 2.6，2026-07-01）。
## ChainEffect（chain.lua:87-157）是 View（LegendAminationEffect 特效），Phase 4 接。
## 协作者（duck-type）：skill{info,caster,target,take_effect_on(target,src),_target_camp(),
##   min_range_sq,max_range_sq,engine}。跳跃：ChainCreate→jump（首跳 takeEffectOn）
##   →update（jump_timer 到点 → findNextTarget → jump / terminate）。
## chain 不移动（不调 base.update），仅 jump_timer 推进 + 跳跃结算；进 engine.projectile_list（源 addChain）。

const JUMP_GAP_SQ: int = 6400
const MIN_TIMES_HUGE: int = 100000
const MIN_DIST_HUGE: float = INF
const CHAIN_EFFECT_HEIGHT: float = 48.0

var skill: Variant = null
var source: Variant = null
var target: Variant = null
var jumps_remaining: int = 0
var jump_timer: float = 0.0
var affect_times: Dictionary = {}


func _init(p_skill: Variant) -> void:
	var info: Dictionary = p_skill.info
	skill = p_skill
	source = p_skill.caster
	target = p_skill.target
	jumps_remaining = int(info.get("Chain Jumps", 0))
	jump_timer = 0.0
	affect_times = {}
	engine = p_skill.caster.engine
	jump()


func jump() -> void:
	jumps_remaining -= 1
	jump_timer += float(skill.info.get("Chain Gap", 0.0))
	affect_times[target] = int(affect_times.get(target, 0)) + 1
	skill.take_effect_on(target, source)
	# Chain 连线特效由 View 层 ChainActor 渲染（照源 chain.lua ChainEffect，含距离拉伸+旋转）。
	# ChainActor 通过 ProjectileSync 发现本 chain（actor==null）后挂载，跟随 source/target 变化。
	# 此处不主动调 play_effect（旧实现是无拉伸直线，被 ChainActor 取代）。


func update(dt: float) -> void:
	jump_timer -= dt
	if jump_timer <= 0.0:
		if jumps_remaining > 0:
			source = target
			target = find_next_target()
			if target != null:
				jump()
				return
		terminate()


func find_next_target() -> Variant:
	var min_times: int = MIN_TIMES_HUGE
	var min_dist: float = MIN_DIST_HUGE
	var ret: Variant = null
	for unit in engine.foreach_alive_unit(int(skill._target_camp())):
		if unit == source:
			continue
		if bool(unit.buff_effects.get("untargetable", false)):
			continue
		var times: int = int(affect_times.get(unit, 0))
		if times > min_times:
			continue
		var dist_sq: float = absf(unit.position.distance_squared_to(source.position) - float(JUMP_GAP_SQ))
		if dist_sq > min_dist:
			continue
		if dist_sq > float(skill.min_range_sq) and dist_sq < float(skill.max_range_sq):
			ret = unit
			min_times = times
			min_dist = dist_sq
	return ret
