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

const HUGE: float = INF

var owner: Variant = null
var destination: Variant = null
var target: Variant = null
var will_cast_manual_skill: bool = true
var hero_hooks: Dictionary = {}  # 英雄 hook（源 override 等价）：walkTo（Troll 后排单位近战射程，Phase 2.7）


func _init(p_owner: Variant = null) -> void:
	owner = p_owner


static func create(p_owner: Variant) -> BattleAi:
	return BattleAi.new(p_owner)


static func create_healer(p_owner: Variant) -> BattleAi:
	return AiHealer.new(p_owner)


func update(_dt: float) -> void:
	var res: Array = search_target()
	var found: Variant = res[0] if res.size() > 0 else null
	if bool(owner.buff_effects.get(BattleEffectKeys.BUILDING, false)):
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


func search_target() -> Array:
	var min_dist_sq: float = HUGE
	var found: Variant = null
	var p0: Vector2 = owner.position
	for unit in owner.engine.foreach_alive_unit(int(owner.focamp)):
		if unit == owner:
			continue
		if bool(unit.buff_effects.get(BattleEffectKeys.UNTARGETABLE, false)):
			continue
		var p1: Vector2 = unit.position
		var dx: float = p0.x - p1.x
		var dy: float = p0.y - p1.y
		var dist_sq: float = dx * dx + dy * dy
		if min_dist_sq > dist_sq:
			min_dist_sq = dist_sq
			found = unit
	return [found, min_dist_sq]


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
# 内部类（不带 class_name）规避跨脚本 class_name 交叉引用；外部经 BattleAi.create_healer 工厂构造。
class AiHealer:
	extends BattleAi

	func _init(p_owner: Variant = null) -> void:
		super(p_owner)

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

	func search_heal_target() -> Variant:
		var weakest: Variant = null
		var lowest_hp_percent: float = 1.0
		for unit in owner.engine.foreach_alive_unit(int(owner.camp)):
			var percent: float = float(unit.hp) / float(unit.info.get("Max HP", 1))
			if lowest_hp_percent > percent:
				weakest = unit
				lowest_hp_percent = percent
		return weakest
