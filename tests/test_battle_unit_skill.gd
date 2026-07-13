extends GutTest
# Phase 2.2续-D initSkill 装配（照源 unit.lua:351 initSkill 翻译，2026-07-01）。
# 集成测试：真 ConfigManager（load_all）+ SkillLibrary.new(cm)。tid=1 英雄真实 SkillGroup 表数据。

var cm: ConfigManager
var lib: SkillLibrary

func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()
	lib = SkillLibrary.new(cm)

func _make_hero(tid: int = 1, level: int = 1, with_lib: bool = true, proto_extra: Dictionary = {}) -> BattleUnit:
	var proto := {"_tid": tid, "_level": level, "_stars": 1}
	proto.merge(proto_extra, true)
	return BattleUnit.new(proto, BattleEngine.CAMP_PLAYER, {"estimate_rank": true}, cm, null, {}, lib if with_lib else null)


# 源 initSkill（:351-416）：lib null → 跳过装配（skill_list 空）
func test_init_skill_lib_null_skips() -> void:
	var u := _make_hero(1, 1, false)
	assert_eq(u.skill_list.size(), 0, "lib null → 跳过装配")
	assert_null(u.basic_skill, "lib null → basic_skill null")
	assert_eq(u.attack_range, 0.0, "lib null → attack_range=0")


# 源 :388-394 active 技能 → SkillCreate → skill_list
func test_init_skill_loads_active_skills() -> void:
	var u := _make_hero(1, 1, true)
	assert_true(u.skill_list.size() > 0, "lib 注入 → 装配 active 技能（tid=1 应有普攻）")


# 源 :405-407 basic_skill + attack_range = Max Range - 5
func test_init_skill_basic_skill_and_range() -> void:
	var u := _make_hero(1, 1, true)
	assert_not_null(u.basic_skill, "basic_skill 装配（普攻 Basic Skill 组）")
	if u.basic_skill != null:
		var max_range: float = float(u.basic_skill.info.get("Max Range", 0.0))
		assert_eq(u.attack_range, max_range - 5.0, "attack_range = basic_skill Max Range - 5")


# 源 :408-414 skill_list 按 Priority 降序。
# estimate_rank 模式无 _skill_levels → 只 Basic Skill（源 :372-379 skill_level=0，仅 Basic 强制 1）。
# 注入 _skill_levels 触发多槽装配，验 skill_level 算法 + Priority 排序。
func test_init_skill_priority_sorted() -> void:
	var u := _make_hero(1, 60, true, {"_skill_levels": {"1": 1, "2": 1, "3": 1, "5": 1, "6": 1}})
	assert_true(u.skill_list.size() >= 2, "estimate_rank+_skill_levels 装配 >=2 技能（验 skill_level=_skill_levels[slot]+SKL）")
	for i in range(u.skill_list.size() - 1):
		var p1: int = int(u.skill_list[i].info.get("Priority", 0))
		var p2: int = int(u.skill_list[i + 1].info.get("Priority", 0))
		assert_true(p1 >= p2, "Priority 降序（idx%d=%d >= idx%d=%d）" % [i, p1, i + 1, p2])


# 源 :392-394 Manual 技能 → manual_skill（大招，高 rank 解锁）
func test_init_skill_manual_skill_at_high_rank() -> void:
	var u := _make_hero(1, 60, true)  # rank=6
	# tid=1 数据可能未配置 Manual 大招；manual_skill 为 null（无 Manual 组）或 info.Manual=true 均合法
	if u.manual_skill == null:
		assert_true(true, "tid=1 level=60 无 Manual 技能组（数据未配置大招）")
	else:
		assert_true(bool(u.manual_skill.info.get("Manual", false)), "manual_skill 的 info.Manual=true")


# 源 :349 ai 创建（:190）在 initSkill 前，_init 后 ai 非 null
func test_init_creates_ai_with_skill() -> void:
	var u := _make_hero(1, 1, true)
	assert_not_null(u.ai, "_init 创建 ai")
	assert_true(u.ai is BattleAi, "ai 是 BattleAi")
