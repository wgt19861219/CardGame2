extends GutTest
# Phase 2.5 ai（照源 ai.lua 184 翻译，2026-07-01）。
# MockSkill/MockUnit/MockEngine duck-type 契约（照源 ai 协作者：owner/engine/skill）。
# owner 侧行为方法（idle/walk_towards/cast_skill/cast_manual_skill）属 Phase 2.2续，此处 MockUnit 桩记录调用。

class MockSkill:
	extends RefCounted
	var is_update: bool = true
	var info: Dictionary = {}
	var ok_result: bool = true
	var will_cast_result: bool = true
	func can_cast_with_target(_t: Variant) -> Dictionary:
		return {"ok": ok_result, "reason": ""}
	func will_cast() -> bool:
		return will_cast_result

class MockUnit:
	extends RefCounted
	var buff_effects: Dictionary = {}
	var focamp: int = -1   # owner 默认玩家方（camp=1 → focamp=-1）
	var camp: int = 1
	var position: Vector2 = Vector2.ZERO
	var global_cd: float = 0.0
	var skill_list: Array = []
	var attack_range: float = 100.0
	var hp: float = 1000.0
	var info: Dictionary = {"Max HP": 1000}
	var engine: Variant = null
	var idle_count: int = 0
	var walk_calls: Array = []
	var cast_skill_calls: Array = []
	var cast_manual_count: int = 0
	func idle() -> void:
		idle_count += 1
	func walk_towards(dest: Vector2) -> void:
		walk_calls.append(dest)
	func cast_skill(skill: Variant, t: Variant) -> void:
		cast_skill_calls.append([skill, t])
	func cast_manual_skill() -> void:
		cast_manual_count += 1
	func is_out_of_stage() -> bool:
		return false

class MockEngine:
	extends RefCounted
	var arena_mode: bool = false
	var units_by_camp: Dictionary = {}  # camp(int) -> Array[unit]
	func foreach_alive_unit(camp: int) -> Array:
		return units_by_camp.get(camp, []).duplicate()


func _make_owner() -> MockUnit:
	var o := MockUnit.new()
	o.engine = MockEngine.new()
	return o

func _make_skill(info_overrides: Dictionary = {}) -> MockSkill:
	var s := MockSkill.new()
	s.info.merge(info_overrides, true)
	return s

func _make_enemy(x: float) -> MockUnit:
	var u := MockUnit.new()
	u.position = Vector2(x, 0)
	return u

# —— search_target ——

# 源 searchTarget（ai.lua:69-88）：取距离平方最小
func test_search_target_nearest() -> void:
	var o := _make_owner()
	o.position = Vector2(0, 0)
	o.engine.units_by_camp[-1] = [_make_enemy(50), _make_enemy(300)]
	var res := BattleAi.new(o).search_target()
	assert_eq(float(res[1]), 2500.0, "dist_sq=50²=2500 取最近")

# 源：跳过 untargetable
func test_search_target_skip_untargetable() -> void:
	var o := _make_owner()
	var close := _make_enemy(10)
	close.buff_effects[BattleEffectKeys.UNTARGETABLE] = true
	var far := _make_enemy(200)
	o.engine.units_by_camp[-1] = [close, far]
	var res := BattleAi.new(o).search_target()
	assert_eq(res[0], far, "跳过 untargetable")

# 源：unit ~= owner（跳过自身）
func test_search_target_skip_self() -> void:
	var o := _make_owner()
	o.engine.units_by_camp[-1] = [o]  # owner 误入敌方列表
	var res := BattleAi.new(o).search_target()
	assert_eq(res[0], null, "跳过自身")

# 源：空列表 → [null, INF]
func test_search_target_empty() -> void:
	var o := _make_owner()
	o.engine.units_by_camp[-1] = []
	var res := BattleAi.new(o).search_target()
	assert_eq(res[0], null, "无目标")
	assert_eq(float(res[1]), INF, "dist_sq=INF")

# —— find_skill_to_cast ——

# 源 findSkillToCast（ai.lua:91-92）：global_cd > 0 → nil
func test_find_skill_global_cd() -> void:
	var o := _make_owner()
	o.global_cd = 1.0
	o.skill_list = [_make_skill()]
	assert_eq(BattleAi.new(o).find_skill_to_cast(), null, "global_cd>0 → null")

# 源：is_update=false 跳过
func test_find_skill_not_update() -> void:
	var o := _make_owner()
	var s := _make_skill()
	s.is_update = false
	o.skill_list = [s]
	assert_eq(BattleAi.new(o).find_skill_to_cast(), null, "is_update=false 跳过")

# 源（ai.lua:97）：Manual 且 will_cast_manual_skill=false 跳过
func test_find_skill_manual_blocked() -> void:
	var o := _make_owner()
	o.skill_list = [_make_skill({"Manual": true})]
	var ai := BattleAi.new(o)
	ai.will_cast_manual_skill = false
	assert_eq(ai.find_skill_to_cast(), null, "Manual + 不施手动 → 跳过")

# 源（ai.lua:98-100）：canCast + willCast → 返回 skill
func test_find_skill_can_cast_ok() -> void:
	var o := _make_owner()
	var s := _make_skill()
	o.skill_list = [s]
	var ai := BattleAi.new(o)
	ai.target = _make_enemy(50)  # target 是 AI 状态（源 self.target），非 owner 字段
	assert_eq(ai.find_skill_to_cast(), s, "可施法 → 返回 skill")

# 源（ai.lua:99）：canCast 通过但 willCast=false → 不选
func test_find_skill_will_cast_false() -> void:
	var o := _make_owner()
	var s := _make_skill()
	s.will_cast_result = false
	o.skill_list = [s]
	var ai := BattleAi.new(o)
	ai.target = _make_enemy(50)
	assert_eq(ai.find_skill_to_cast(), null, "willCast=false → 不选")

# —— update 基础 AI ——

# 源 update（ai.lua:43-45,63-64）：无目标 → idle
func test_update_no_target_idle() -> void:
	var o := _make_owner()
	o.engine.units_by_camp[-1] = []
	BattleAi.new(o).update(0.033)
	assert_eq(o.idle_count, 1, "无目标 → idle")

# 源（ai.lua:47-56）：有目标 + 可施法 → castSkill
func test_update_cast() -> void:
	var o := _make_owner()
	o.engine.units_by_camp[-1] = [_make_enemy(50)]
	o.skill_list = [_make_skill()]
	BattleAi.new(o).update(0.033)
	assert_eq(o.cast_skill_calls.size(), 1, "可施法 → cast_skill")

# 源（ai.lua:57-58）：有目标 + 无可施技能（非 building）→ walkTo
func test_update_walk_when_no_skill() -> void:
	var o := _make_owner()
	o.engine.units_by_camp[-1] = [_make_enemy(500)]  # 出 attack_range
	o.skill_list = []
	BattleAi.new(o).update(0.033)
	assert_eq(o.walk_calls.size(), 1, "有目标无技能 → walk_towards")

# 源（ai.lua:40-42）：building + 有目标 + 无技能 → idle（非 walk）
func test_update_building_idle() -> void:
	var o := _make_owner()
	o.buff_effects[BattleEffectKeys.BUILDING] = true
	o.engine.units_by_camp[-1] = [_make_enemy(500)]
	o.skill_list = []
	BattleAi.new(o).update(0.033)
	assert_eq(o.idle_count, 1, "building → idle")
	assert_eq(o.walk_calls.size(), 0, "building 不 walk")

# 源（ai.lua:35-36）：Manual + arena_mode → castManualSkill
func test_update_manual_arena() -> void:
	var o := _make_owner()
	o.engine.arena_mode = true
	o.engine.units_by_camp[-1] = [_make_enemy(50)]
	o.skill_list = [_make_skill({"Manual": true})]
	BattleAi.new(o).update(0.033)
	assert_eq(o.cast_manual_count, 1, "Manual + arena → cast_manual_skill")
	assert_eq(o.cast_skill_calls.size(), 0, "不走 cast_skill")

# 源（ai.lua:60-61）：无目标 + destination → walkTo(destination)
func test_update_destination() -> void:
	var o := _make_owner()
	o.engine.units_by_camp[-1] = []
	var ai := BattleAi.new(o)
	ai.destination = Vector2(200, 0)  # destination 是 AI 状态（源 self.destination），非 owner 字段
	ai.update(0.033)
	assert_eq(o.walk_calls.size(), 1, "destination → walk_towards")
	assert_eq(o.walk_calls[0], Vector2(200, 0), "走向 destination")

# —— walk_to ——

# 源 walkTo（ai.lua:115-118）：在 attack_range 内 → idle 返回
func test_walk_to_in_range_idle() -> void:
	var o := _make_owner()
	o.attack_range = 100.0
	BattleAi.new(o).walk_to(Vector2(50, 0))  # dsq=2500 < 10000
	assert_eq(o.idle_count, 1, "范围内 → idle")
	assert_eq(o.walk_calls.size(), 0, "不 walk")

# 源 walkTo（ai.lua:120）：出范围 → walkTowards
func test_walk_to_out_range_walk() -> void:
	var o := _make_owner()
	o.attack_range = 100.0
	BattleAi.new(o).walk_to(Vector2(500, 0))
	assert_eq(o.walk_calls.size(), 1, "范围外 → walk_towards")

# 源 walkTo（ai.lua:110-112）：dest 为 unit → 取其 position
func test_walk_to_unit_position() -> void:
	var o := _make_owner()
	o.attack_range = 100.0
	BattleAi.new(o).walk_to(_make_enemy(500))
	assert_eq(o.walk_calls.size(), 1, "unit → 取 position walk")
	assert_eq(o.walk_calls[0], Vector2(500, 0), "dest=unit.position")

# —— AiHealer ——

# 源 AiHealerCreate 工厂（ai.lua:133-139）
func test_create_healer_type() -> void:
	var ai := BattleAi.create_healer(_make_owner())
	assert_not_null(ai, "工厂返回实例")
	assert_true(ai is BattleAi, "AiHealer is BattleAi")

# 源 AiHealer update（ai.lua:142-149）：优先治疗最低血量友军
func test_healer_heal_priority() -> void:
	var o := _make_owner()
	var ally_low := MockUnit.new()
	ally_low.hp = 100
	ally_low.info = {"Max HP": 1000}
	ally_low.position = Vector2(50, 0)
	var ally_full := MockUnit.new()
	ally_full.hp = 1000
	ally_full.info = {"Max HP": 1000}
	ally_full.position = Vector2(60, 0)
	o.engine.units_by_camp[1] = [ally_low, ally_full]  # 同营
	o.skill_list = [_make_skill()]
	BattleAi.create_healer(o).update(0.033)
	assert_eq(o.cast_skill_calls.size(), 1, "治疗优先 → cast_skill")
	assert_eq(o.cast_skill_calls[0][1], ally_low, "治疗最低血量友军")

# 源 searchHealTarget（ai.lua:172-183）：满血友军不优先（percent=1 不 < lowest=1）
func test_healer_no_weak_target() -> void:
	var o := _make_owner()
	var ally_full := MockUnit.new()
	ally_full.hp = 1000
	ally_full.info = {"Max HP": 1000}
	o.engine.units_by_camp[1] = [ally_full]
	o.skill_list = [_make_skill()]
	BattleAi.create_healer(o).update(0.033)
	assert_eq(o.cast_skill_calls.size(), 0, "无虚弱友军 → 不治疗施法")
