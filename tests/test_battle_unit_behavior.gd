extends GutTest
# Phase 2.2续-B 行为方法（照源 unit.lua:1039 idle/1053 walkTowards/1075 summon/1085 castSkill 翻译，2026-07-01）。
# 真实 BattleUnit（cm.load_all）测实例转发 + ai 创建；cast_skill 用 MockSkill（start 桩）。

var cm: ConfigManager

func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()

func _make_hero(tid: int = 1, level: int = 1) -> BattleUnit:
	return BattleUnit.new({"_tid": tid, "_level": level, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_rank": true}, cm)

class MockSkill:
	extends RefCounted
	var started: Array = []
	func start(t: Variant) -> void:
		started.append(t)


# 源 UnitCreate:190 createAiForUnit → _init 创建 ai
func test_init_creates_ai() -> void:
	var u := _make_hero()
	assert_not_null(u.ai, "_init 创建 ai")
	assert_true(u.ai is BattleAi, "ai 是 BattleAi 实例")

# 源 idle（:1039-1050）：非 IDLE → IDLE + walk_v=0 + Idle 动作
func test_idle() -> void:
	var u := _make_hero()
	u.state = BattleUnit.State.ATTACK
	u.walk_v = Vector2(100, 0)
	u.idle()
	assert_eq(u.state, BattleUnit.State.IDLE, "→ IDLE")
	assert_eq(u.walk_v, Vector2.ZERO, "walk_v 清零")
	assert_eq(u.action_name, "Idle", "动作 Idle（push=false）")

# 源 :1043-1045 已 IDLE 早返（不重置动作）
func test_idle_already_idle() -> void:
	var u := _make_hero()
	u.state = BattleUnit.State.IDLE
	u.action_name = "Old"
	u.idle()
	assert_eq(u.action_name, "Old", "已 IDLE 不重置动作")

# 源 idle（:1048）：push=true → "Move" 动作
func test_idle_push_uses_move() -> void:
	var u := _make_hero()
	u.state = BattleUnit.State.ATTACK
	u.push = true
	u.idle()
	assert_eq(u.action_name, "Move", "push=true → Move 动作")

# 源 walkTowards（:1053-1073）：WALK 状态 + walk_v 朝目标
func test_walk_towards() -> void:
	var u := _make_hero()
	u.position = Vector2(0, 0)
	u.info["Walk Speed"] = 100.0
	u.walk_towards(Vector2(100, 0))
	assert_eq(u.state, BattleUnit.State.WALK, "→ WALK")
	assert_eq(u.action_name, "Move", "动作 Move")
	# dir=(100,0), scaled=(100×100, 0)=(10000,0), normalized=(1,0) ×100 = (100,0)
	assert_eq(u.walk_v, Vector2(100, 0), "walk_v 朝 +x")

# 源 :1063-1064 dest==position → walk_v=0
func test_walk_towards_zero_vector() -> void:
	var u := _make_hero()
	u.position = Vector2(50, 50)
	u.info["Walk Speed"] = 100.0
	u.walk_towards(Vector2(50, 50))
	assert_eq(u.walk_v, Vector2.ZERO, "零向量 → walk_v=0")

# 源 summon（:1075-1083）：BIRTH + 出生动作
func test_summon_default_action() -> void:
	var u := _make_hero()
	u.summon()
	assert_eq(u.state, BattleUnit.State.BIRTH, "→ BIRTH")
	assert_eq(u.action_name, "Birth", "默认 Birth 动作")

# 源 summon（:1078-1081）：自定义 bornActionName
func test_summon_custom_action() -> void:
	var u := _make_hero()
	u.summon("Appear")
	assert_eq(u.action_name, "Appear", "自定义出生动作")

# 源 castSkill（:1085-1094）：ATTACK + skill.start(target) + current_skill
func test_cast_skill() -> void:
	var u := _make_hero()
	var s := MockSkill.new()
	var target := _make_hero()
	u.cast_skill(s, target)
	assert_eq(u.state, BattleUnit.State.ATTACK, "→ ATTACK")
	assert_eq(u.current_skill, s, "current_skill=skill")
	assert_eq(u.walk_v, Vector2.ZERO, "walk_v 清零")
	assert_eq(s.started.size(), 1, "skill.start 被调")
	assert_eq(s.started[0], target, "start(target)")

# 源 setAction 实例转发（补续A：skill._start_phase 调 caster.set_action）
func test_set_action_instance() -> void:
	var u := _make_hero()
	u.set_action("Idle", true, false)
	assert_eq(u.action_name, "Idle", "set_action 实例转发 BattleUnitCombat")
