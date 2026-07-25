class_name BattleEnergyBallManager
extends RefCounted

## Kael 能量球管理（Logic 层）— 照源 energyball.lua:1-194 翻译（Phase 2.6，2026-07-01）。
## 纯 Logic：3 槽位球管理（addEnergyBall/consumeEnergyBall/update CD 递减/canCastSkill 球组合匹配）。
## ballBar（addBall/playCompose）View 留 Phase 4。依赖 unit{is_alive,skill_condition}（Kael hook 填）。
## makebits 位编码（源 :170/:179）用位运算实现，canCastSkill 内 m/t 同编码自洽。

const STATUS_EMPTY: int = 0
const STATUS_BORN: int = 1
const STATUS_AVAILABLE: int = 2
const SLOT_CD: float = 0.0
const BALL_CD: float = 0.0
const SKILL_CAST_CD: float = 0.0
const EPSILON: float = 0.0001
const BITS_PER_FIELD: int = 2
const SLOT_COUNT: int = 3
const SKILL_CAST_READY: int = 2
const LIGHTNING_SHIFT: int = BITS_PER_FIELD * 2  # lightning 字段位偏移（第 3 字段）
const LIGHTNING_IDX: int = 2      # cond 数组 lightning 索引（源 Lua [3] → Godot [2]）


class Slot:
	var ball_type: String = ""
	var ball_status: int = 0
	var ball_cd_time: float = 0.0
	var cd_time: float = 0.0
	var occupied: bool = false
	var my_slot_idx: int = 0

	func _init(i: int) -> void:
		my_slot_idx = i

	func reset() -> void:
		ball_type = ""
		ball_status = 0  # STATUS_EMPTY（内部类避免外部 const 限定）
		ball_cd_time = 0.0
		occupied = false


var slots: Array = []
var unit: Variant = null
var skill_cast_cd_time: float = 0.0
var skill_cast_status: int = 0


func _init(p_unit: Variant) -> void:
	unit = p_unit
	skill_cast_cd_time = 0.0
	skill_cast_status = 0
	slots = []
	for i in range(1, SLOT_COUNT + 1):
		slots.append(Slot.new(i))


func _get_empty_slot(check_occupied: bool) -> Array:
	for s: Slot in slots:
		if check_occupied:
			if s.ball_type == "" and s.cd_time <= EPSILON and skill_cast_cd_time <= EPSILON and not s.occupied:
				return [s, s.my_slot_idx]
		elif s.ball_type == "" and s.cd_time <= EPSILON and skill_cast_cd_time <= EPSILON:
			return [s, s.my_slot_idx]
	return [null, 0]


func is_slots_full() -> bool:
	for s: Slot in slots:
		if s.ball_type == "":
			return false
	return true


func is_slots_available() -> bool:
	for s: Slot in slots:
		if s.ball_type == "" or s.ball_status != STATUS_AVAILABLE:
			return false
	return true


func add_energy_ball(ball_type: String, my_slot_idx: int = 0) -> void:
	if not bool(unit.is_alive()) or skill_cast_cd_time > EPSILON:
		return
	var s: Variant = null
	if my_slot_idx < 1:
		s = _get_empty_slot(false)[0]
	else:
		s = slots[my_slot_idx - 1]
	if s == null:
		return
	s.ball_type = ball_type
	s.ball_status = STATUS_BORN
	s.ball_cd_time = BALL_CD
	s.cd_time = SLOT_CD
	# ballBar:addBall（View）Phase 4


func consume_energy_ball() -> void:
	if not bool(unit.is_alive()):
		return
	if not is_slots_available():
		return
	for s: Slot in slots:
		s.reset()
	skill_cast_cd_time = SKILL_CAST_CD
	skill_cast_status = 1
	# ballBar:playCompose（View）Phase 4


func update(dt: float) -> void:
	for s: Slot in slots:
		if s.cd_time >= EPSILON:
			s.cd_time -= dt
		if s.ball_status == STATUS_BORN:
			s.ball_cd_time -= dt
			if s.ball_cd_time <= EPSILON:
				s.ball_status = STATUS_AVAILABLE
	if skill_cast_cd_time > EPSILON:
		skill_cast_cd_time -= dt
		if skill_cast_cd_time <= EPSILON:
			skill_cast_status = SKILL_CAST_READY


func _get_available_balls() -> int:
	var counts: Dictionary = {}
	for s: Slot in slots:
		if s.ball_type != "" or s.ball_status == STATUS_AVAILABLE:
			counts[s.ball_type] = int(counts.get(s.ball_type, 0)) + 1
	return _pack_balls(int(counts.get("ice", 0)), int(counts.get("fire", 0)), int(counts.get("lightning", 0)))


static func _pack_balls(ice: int, fire: int, lightning: int) -> int:
	return ice | (fire << BITS_PER_FIELD) | (lightning << LIGHTNING_SHIFT)


func can_cast_skill(skill: Variant) -> bool:
	var cond: Variant = unit.skill_condition.get(skill.info.get("Skill Group ID"))
	if cond == null:
		return true
	var m: int = _pack_balls(int(cond[0]), int(cond[1]), int(cond[LIGHTNING_IDX]))
	var t: int = _get_available_balls()
	if is_slots_available() and m == t:
		return true
	return false


func clear() -> void:
	for s: Slot in slots:
		s.reset()
