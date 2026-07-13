class_name BattleAi
extends RefCounted

## 战斗单位 AI（Logic 层）— 照源 ai.lua（184 行）翻译（Phase 2.5，2026-07-01）。
## 两类同源一文件（源 ed.Ai + ed.AiHealer）：BattleAi 基础 + 内部类 AiHealer 治疗（继承，override update + searchHealTarget）。
## duck-type 协作者（不 import 单位类，避免 class_name 交叉引用）：
##   owner{buff_effects{building,untargetable}, focamp, camp, position, global_cd, skill_list, attack_range,
##     is_out_of_stage(), idle(), walk_towards(dest), cast_skill(skill,target), cast_manual_skill()}；
##   owner.engine{foreach_alive_unit(camp), arena_mode}；
##   skill{is_update, info{Manual}, can_cast_with_target(target)→{ok,reason}, will_cast()}。
## owner 侧行为方法（idle/walk_towards/cast_skill/cast_manual_skill）属 Phase 2.2续单位行为，本轮 duck-type 照源调用。

const HUGE: float = INF  # 源 math.huge（searchTarget 初始最小距离平方）

var owner: Variant = null               # 源 self.owner
var destination: Variant = null         # 源 self.destination（移动目标坐标 Vector2）
var target: Variant = null              # 源 self.target（当前攻击/治疗目标 unit）
var will_cast_manual_skill: bool = true  # 源 self.will_cast_manual_skill
var hero_hooks: Dictionary = {}  # 英雄 hook（源 override 等价）：walkTo（Troll 后排单位近战射程，Phase 2.7）


func _init(p_owner: Variant = null) -> void:
	owner = p_owner


# 源 ed.createAiForUnit / ed.AiCreate（ai.lua:3-5, 15-26）
static func create(p_owner: Variant) -> BattleAi:
	return BattleAi.new(p_owner)


# 源 ed.AiHealerCreate（ai.lua:133-139）— 治疗 AI 工厂（治疗型英雄 lua hook 调）
static func create_healer(p_owner: Variant) -> BattleAi:
	return AiHealer.new(p_owner)


# 源 update（ai.lua:28-67）。building buff 分支：仅 idle（不动）；普通分支：无技能则 walkTo。
# 源两分支前半段（searchTarget→findSkillToCast→Manual/arena 判定）照源内联重复，不抽 helper（复刻铁律：照源结构）。
func update(_dt: float) -> void:
	var res: Array = search_target()
	var found: Variant = res[0] if res.size() > 0 else null
	if bool(owner.buff_effects.get("building", false)):
		if found != null:
			target = found
			var skill: Variant = find_skill_to_cast()
			if skill != null:
				if bool(skill.info.get("Manual", false)) and bool(owner.engine.arena_mode):
					owner.cast_manual_skill()
				else:
					owner.cast_skill(skill, found)
			else:
				owner.idle()
		else:
			owner.idle()
	else:
		if found != null:
			target = found
			var skill: Variant = find_skill_to_cast()
			if skill != null:
				if bool(skill.info.get("Manual", false)) and bool(owner.engine.arena_mode):
					owner.cast_manual_skill()
				else:
					owner.cast_skill(skill, found)
			else:
				walk_to(found)
		elif destination != null:
			walk_to(destination)
		else:
			owner.idle()


# 源 searchTarget（ai.lua:69-88）→ 返回 [target, dist_sq]（双值；skill._select_target 读 res[0]/res[1] 比射程）
func search_target() -> Array:
	var min_dist_sq: float = HUGE
	var found: Variant = null
	var p0: Vector2 = owner.position
	for unit in owner.engine.foreach_alive_unit(int(owner.focamp)):
		if unit == owner:
			continue
		if bool(unit.buff_effects.get("untargetable", false)):
			continue
		var p1: Vector2 = unit.position
		var dx: float = p0.x - p1.x
		var dy: float = p0.y - p1.y
		var dist_sq: float = dx * dx + dy * dy
		if min_dist_sq > dist_sq:
			min_dist_sq = dist_sq
			found = unit
	return [found, min_dist_sq]


# 源 findSkillToCast（ai.lua:90-107）— 英雄 hook override 点（Marine atk2 限定 arena/right side）。hook 内调 _find_skill_to_cast_default 当 basefunc。
func find_skill_to_cast() -> Variant:
	var h: Callable = hero_hooks.get("findSkillToCast", Callable())
	return h.call(self) if h.is_valid() else _find_skill_to_cast_default()

# global_cd>0 跳过；遍历 skill_list，is_update 且（手动可施 or 非手动）+ canCast+willCast
func _find_skill_to_cast_default() -> Variant:
	if float(owner.global_cd) > 0.0:
		return null
	var list: Array = owner.skill_list
	for i in range(list.size()):
		var skill: Variant = list[i]
		var is_manual: bool = bool(skill.info.get("Manual", false))
		if bool(skill.is_update) and (will_cast_manual_skill or not is_manual):
			var r: Dictionary = skill.can_cast_with_target(target)
			if bool(r.get("ok", false)) and bool(skill.will_cast()):
				return skill
	return null


# 源 walkTo（ai.lua:109-121）：英雄 hook override 点（Troll 后排单位近战射程）。hook 内调 _walk_to_default 当 basefunc。
func walk_to(dest: Variant) -> void:
	var h: Callable = hero_hooks.get("walkTo", Callable())
	if h.is_valid():
		h.call(self, dest)
	else:
		_walk_to_default(dest)

func _walk_to_default(dest: Variant) -> void:
	var dest_pos: Vector2
	if dest is Vector2:
		dest_pos = dest
	else:
		dest_pos = dest.position
	var ar: float = float(owner.attack_range)
	var dsq: float = _dist_sq(dest_pos, owner.position)
	# 源 if not (dsq <= attack_range^2) or isOutOfStage() then 空（落 walk_towards）else idle return
	if not (dsq <= ar * ar) or bool(owner.is_out_of_stage()):
		pass
	else:
		owner.idle()
		return
	owner.walk_towards(dest_pos)


func _dist_sq(a: Vector2, b: Vector2) -> float:
	var dx: float = a.x - b.x
	var dy: float = a.y - b.y
	return dx * dx + dy * dy


# ─────────────────────────────────────────────────────────────
# 源 ed.AiHealer（ai.lua:125-184）：治疗 AI，继承 ed.Ai，override update + 加 searchHealTarget。
# 内部类（不带 class_name）规避跨脚本 class_name 交叉引用；外部经 BattleAi.create_healer 工厂构造。
class AiHealer:
	extends BattleAi

	func _init(p_owner: Variant = null) -> void:
		super(p_owner)

	# 源 AiHealer update（ai.lua:141-169）：优先治疗最低血量友军，其次攻击，否则走向/待机。
	func update(_dt: float) -> void:
		var heal_target: Variant = search_heal_target()
		if heal_target != null:
			target = heal_target
			var skill: Variant = find_skill_to_cast()
			if skill != null:
				owner.cast_skill(skill, heal_target)
				return
		var atk_res: Array = search_target()
		var attack_target: Variant = atk_res[0] if atk_res.size() > 0 else null
		if attack_target != null:
			target = attack_target
			var skill: Variant = find_skill_to_cast()
			if skill != null:
				owner.cast_skill(skill, attack_target)
				return
		if heal_target != null:
			target = heal_target
			walk_to(heal_target)
		elif attack_target != null:
			target = attack_target
			walk_to(attack_target)
		else:
			owner.idle()

	# 源 searchHealTarget（ai.lua:172-183）：遍历同营存活，取 hp/Max HP 比例最低（最虚弱）。
	func search_heal_target() -> Variant:
		var weakest: Variant = null
		var lowest_hp_percent: float = 1.0
		for unit in owner.engine.foreach_alive_unit(int(owner.camp)):
			var percent: float = float(unit.hp) / float(unit.info.get("Max HP", 1))
			if lowest_hp_percent > percent:
				weakest = unit
				lowest_hp_percent = percent
		return weakest
