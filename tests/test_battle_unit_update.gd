extends GutTest
# Phase 2.2续-C update tick 主驱动（照源 unit.lua:878 update/1022 onActionFinished 翻译，2026-07-01）。
# MockUnit/MockSkill/MockBuff/MockAi/MockEngine duck-type，覆盖 update 各段 + on_action_finished 分支。

class MockSkill:
	extends RefCounted
	var info: Dictionary = {}
	var target: Variant = null  # update direction 段访问 current_skill.target
	var updated: int = 0
	var phase_finished: int = 0
	func update(_a: float, _b: float) -> void:
		updated += 1
	func _on_phase_finished() -> void:
		phase_finished += 1
	func can_cast_with_target(_t: Variant) -> Dictionary:
		return {"ok": true, "reason": ""}

class MockBuff:
	extends RefCounted
	var updated: int = 0
	func update(_dt: float) -> void:
		updated += 1

class MockAi:
	extends RefCounted
	var updated: int = 0
	var target: Variant = null
	func update(_dt: float) -> void:
		updated += 1

class MockEngine:
	extends RefCounted
	var stage_rect: Dictionary = {"minX": 0.0, "maxX": 800.0, "minY": -120.0, "maxY": 120.0}
	var freeze_level: int = 0
	var mp_bonus: float = 1.0
	var alive_by_camp: Dictionary = {}
	func foreach_alive_unit(camp: int) -> Array:
		return alive_by_camp.get(camp, []).duplicate()

class MockUnit:
	extends RefCounted
	var attribs: Dictionary = {"MSPD": 0.0, "HAST": 0.0, "MPR": 0.0, "HPR": 0.0, "HP": 1000.0}
	var buff_effects: Dictionary = {}
	var buff_list: Array = []
	var skill_list: Array = []
	var hp: int = 1000
	var mp: int = 0
	var info: Dictionary = {}
	var camp: int = 1
	var state: int = 0
	var current_skill: Variant = null
	var manually_casting: bool = false
	var engine: Variant = null
	var ai: Variant = null
	var manual_skill: Variant = null
	var config: Dictionary = {}
	var position: Vector2 = Vector2.ZERO
	var previous_position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var walk_v: Vector2 = Vector2.ZERO
	var knockup_time: float = -1.0
	var knockup_v: Vector2 = Vector2.ZERO
	var direction: int = 1
	var radius: float = 20.0
	var action_name: String = ""
	var action_loop: bool = false
	var action_duration: float = 0.0
	var action_elapsed: float = 0.0
	var speeder: float = 1.0
	var dt_action: float = 0.0
	var hp_low: bool = false
	var hasCorpse: bool = false
	var push: bool = false
	var global_cd: float = 0.0
	var idle_count: int = 0
	func is_alive() -> bool:
		return state != BattleUnit.State.DEAD and state != BattleUnit.State.DYING
	func set_hp(v: int) -> int:
		hp = clamp(v, 0, int(attribs.get("HP", 999999)))
		return hp
	func set_mp(v: int) -> int:
		mp = clamp(v, 0, 999999)
		return mp
	func set_action(p_name: String, p_loop: bool = false, _interrupt: bool = false) -> void:
		action_name = p_name
		action_loop = p_loop
	func idle() -> void:
		idle_count += 1
		state = BattleUnit.State.IDLE
	# 源 update:892 调 self:onActionFinished()（单位方法，BattleUnit 走 hero_hooks 分发；MockUnit 无 hook 直接转发静态）
	func on_action_finished() -> void:
		BattleUnitUpdate.on_action_finished(self)


func _make_unit() -> MockUnit:
	var u := MockUnit.new()
	u.engine = MockEngine.new()
	u.engine.alive_by_camp = {BattleEngine.CAMP_PLAYER: [], BattleEngine.CAMP_ENEMY: []}
	return u

# —— speeder（源 :879-887）——

# 源 :884 MSPD>=0：(MSPD+100)/100
func test_speeder_mspd_positive() -> void:
	var u := _make_unit()
	u.attribs["MSPD"] = 50.0
	BattleUnitUpdate.update(u, 0.033)
	assert_eq(u.speeder, 1.5, "MSPD=50 → (50+100)/100=1.5")

# 源 :884 MSPD<0：100/(100-MSPD)
func test_speeder_mspd_negative() -> void:
	var u := _make_unit()
	u.attribs["MSPD"] = -50.0
	BattleUnitUpdate.update(u, 0.033)
	assert_almost_eq(u.speeder, 0.6667, 0.001, "MSPD=-50 → 100/150≈0.667")

# 源 :881 manually_casting → MSPD=0 → speeder=1
func test_speeder_manually_casting() -> void:
	var u := _make_unit()
	u.attribs["MSPD"] = 50.0
	u.manually_casting = true
	BattleUnitUpdate.update(u, 0.033)
	assert_eq(u.speeder, 1.0, "manually_casting → speeder=1")

# —— action 推进（源 :888-896）——

# 源 :891-894 非 loop 动作超 duration → onActionFinished
func test_action_advance_triggers_on_finished() -> void:
	var u := _make_unit()
	u.action_name = "Atk"
	u.action_loop = false
	u.action_duration = 0.5
	u.action_elapsed = 0.49
	u.state = BattleUnit.State.ATTACK
	u.current_skill = MockSkill.new()
	BattleUnitUpdate.update(u, 0.033)
	# elapsed=0.523>0.5 → onActionFinished(ATTACK) → current_skill._on_phase_finished
	assert_eq(int(u.current_skill.phase_finished), 1, "超 duration → onActionFinished ATTACK → onPhaseFinished")

# 源 :897-899 isAlive false 早返（不 regen）
func test_not_alive_returns_early() -> void:
	var u := _make_unit()
	u.state = BattleUnit.State.DEAD
	u.attribs["MPR"] = 100.0
	var mp_before: int = u.mp
	BattleUnitUpdate.update(u, 0.033)
	assert_eq(u.mp, mp_before, "DEAD 早返 → 不 regen mp")

# —— 移动（源 :900-941）——

# 源 :940 position += v*dt_action
func test_movement_position() -> void:
	var u := _make_unit()
	u.position = Vector2(100, 0)
	u.walk_v = Vector2(100, 0)
	u.state = BattleUnit.State.WALK
	BattleUnitUpdate.update(u, 0.1)
	# speeder=1(MSPD=0), dt_action=0.1, vel.x=100 → position.x=100+100*0.1=110
	assert_eq(u.position.x, 110.0, "position.x += walk_v.x*dt_action")

# 源 :923-925 walk_v.x 与 direction 反向 → 翻转
func test_direction_flip() -> void:
	var u := _make_unit()
	u.direction = 1
	u.walk_v = Vector2(-100, 0)  # 朝左，与 direction=1 反向
	u.state = BattleUnit.State.WALK
	BattleUnitUpdate.update(u, 0.033)
	assert_eq(u.direction, -1, "walk_v 朝反方向 → direction 翻转")

# 源 :927-931 knockup_time 递减，到 0 → knockup_v 清零
func test_knockup_decrement_and_clear() -> void:
	var u := _make_unit()
	u.knockup_time = 0.05
	u.knockup_v = Vector2(10, 20)
	BattleUnitUpdate.update(u, 0.1)
	# 0.05-0.1=-0.05<=0 → knockup_v=ZERO
	assert_eq(u.knockup_v, Vector2.ZERO, "knockup_time 到 0 → knockup_v 清零")

# 源 :934-936 position.x>maxX-50 且 vel.x>0 → vel.x=0（不超边界）
func test_stage_boundary_clamp() -> void:
	var u := _make_unit()
	u.position = Vector2(760, 0)  # >800-50=750
	u.walk_v = Vector2(100, 0)  # vel.x>0
	u.state = BattleUnit.State.WALK
	BattleUnitUpdate.update(u, 0.1)
	assert_eq(u.position.x, 760.0, "边界 + 朝外 → 不移动（vel.x 置 0）")

# —— skill cd（源 :942-950）——

# 源 :945 global_cd -= dt_cd（dt_cd=dt×HAST 系数）
func test_global_cd_decrement() -> void:
	var u := _make_unit()
	u.global_cd = 1.0
	u.attribs["HAST"] = 0.0  # dt_cd=0.033×1
	BattleUnitUpdate.update(u, 0.033)
	assert_almost_eq(u.global_cd, 0.967, 0.001, "global_cd -= dt×(100/100)=0.033")

# 源 :947-949 skill_list.update(dt_action, dt_cd)
func test_skill_list_update() -> void:
	var u := _make_unit()
	var s := MockSkill.new()
	u.skill_list = [s]
	BattleUnitUpdate.update(u, 0.033)
	assert_eq(s.updated, 1, "skill.update 被调")

# —— AI 调度（源 :955-964）——

# 源 :956/962 IDLE 态 + 非 disableAI + 未冻结 → ai.update
func test_ai_dispatched_when_idle() -> void:
	var u := _make_unit()
	u.state = BattleUnit.State.IDLE
	u.ai = MockAi.new()
	BattleUnitUpdate.update(u, 0.033)
	assert_eq(int(u.ai.updated), 1, "IDLE → ai.update 调用")

# 源 :960 disableAI → 不调度
func test_ai_blocked_by_disable_ai() -> void:
	var u := _make_unit()
	u.state = BattleUnit.State.IDLE
	u.buff_effects[BattleEffectKeys.DISABLE_AI] = true
	u.ai = MockAi.new()
	BattleUnitUpdate.update(u, 0.033)
	assert_eq(int(u.ai.updated), 0, "disableAI → ai 不更新")

# 源 :961 engine.freeze_level!=0 → 不调度
func test_ai_blocked_by_freeze() -> void:
	var u := _make_unit()
	u.state = BattleUnit.State.IDLE
	u.engine.freeze_level = 1
	u.ai = MockAi.new()
	BattleUnitUpdate.update(u, 0.033)
	assert_eq(int(u.ai.updated), 0, "freeze_level=1 → ai 不更新")

# —— buff update + regen（源 :999-1009）——

# 源 :999-1001 buff_list.update
func test_buff_update() -> void:
	var u := _make_unit()
	var b := MockBuff.new()
	u.buff_list = [b]
	BattleUnitUpdate.update(u, 0.033)
	assert_eq(b.updated, 1, "buff.update 被调")

# 源 :1003 MPR 回蓝
func test_regen_mpr() -> void:
	var u := _make_unit()
	u.attribs["MPR"] = 10.0
	u.mp = 50
	BattleUnitUpdate.update(u, 1.0)
	assert_eq(u.mp, 60, "mp += MPR*dt*mp_bonus=10*1*1")

# 源 :1005-1007 HPR 回血
func test_regen_hpr() -> void:
	var u := _make_unit()
	u.attribs["HPR"] = 5.0
	u.hp = 100
	BattleUnitUpdate.update(u, 1.0)
	assert_eq(u.hp, 105, "hp += HPR*dt=5")

# 源 :1004 noHPR → 不回血
func test_no_hpr_blocks_regen() -> void:
	var u := _make_unit()
	u.attribs["HPR"] = 5.0
	u.buff_effects[BattleEffectKeys.NO_HPR] = true
	u.hp = 100
	BattleUnitUpdate.update(u, 1.0)
	assert_eq(u.hp, 100, "noHPR → 不回血")

# —— hp 保护 + hp_low（源 :1010-1013）——

# 源 :1010-1012 hp==0 且存活 → hp=1
func test_hp_zero_protection() -> void:
	var u := _make_unit()
	u.hp = 0
	u.attribs["HP"] = 1000.0
	BattleUnitUpdate.update(u, 0.033)
	assert_eq(u.hp, 1, "hp==0 存活 → 保 1")

# 源 :1013 hp/HP<0.2 → hp_low
func test_hp_low_flag() -> void:
	var u := _make_unit()
	u.hp = 100
	u.attribs["HP"] = 1000.0
	BattleUnitUpdate.update(u, 0.033)
	assert_true(u.hp_low, "hp/HP=0.1<0.2 → hp_low")

# —— onActionFinished（源 :1022-1037）——

# 源 :1025-1030 DYING → DEAD + hasCorpse
func test_on_action_finished_dying_to_dead() -> void:
	var u := _make_unit()
	u.state = BattleUnit.State.DYING
	BattleUnitUpdate.on_action_finished(u)
	assert_eq(u.state, BattleUnit.State.DEAD, "DYING → DEAD")
	assert_true(u.hasCorpse, "非召唤物 → hasCorpse")

# 源 :1031-1032 ATTACK → current_skill.onPhaseFinished
func test_on_action_finished_attack() -> void:
	var u := _make_unit()
	u.state = BattleUnit.State.ATTACK
	var s := MockSkill.new()
	u.current_skill = s
	BattleUnitUpdate.on_action_finished(u)
	assert_eq(s.phase_finished, 1, "ATTACK → onPhaseFinished")

# 源 :1033-1034 else → idle
func test_on_action_finished_else_idle() -> void:
	var u := _make_unit()
	u.state = BattleUnit.State.WALK
	BattleUnitUpdate.on_action_finished(u)
	assert_eq(u.idle_count, 1, "非 DEAD/DYING/ATTACK → idle")
