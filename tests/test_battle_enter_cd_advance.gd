extends GutTest

## 守卫：入场冻结期间技能 CD 照源持续衰减（2026-09-15 小技能不触发根修，方案 A）。
## 源行为：切波 nextBattle（reset CD 回 Init CD）后 running=true 持续 tick，入场走路+2.5s 过场
## 期间 CD 继续衰减（battle_engine.lua:127 resetBattle running=true）；本项目入场走 View 动画
## 冻结 engine（battle_scene._process _entering 分支不 step），补 BattleUnitUpdate.tick_skill_cd_only
## 在该分支推进 CD（只推 CD/global_cd，不推 AI/伤害/施法帧）。
## 波清后走向屏外（_walking_to_next）不推——源此阶段 victory() running=false 暂停，CD 同样停。

var cm: ConfigManager

func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_engine() -> BattleEngine:
	var eng := BattleEngine.new()
	eng.stage_info = {}
	return eng


func _make_unit(eng: BattleEngine) -> BattleUnit:
	var u := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_rank": true}, cm, eng, {}, null)
	u.position = Vector2(0, 0)
	u.previous_position = u.position
	return u


func _make_cd_skill(caster: BattleUnit) -> BattleSkill:
	return BattleSkill.new({
		"Skill Group ID": 99, "Skill Name": "probe_cd",
		"Max Range": 99999.0, "Min Range": 0.0, "Cost MP": 0.0,
		"CD": 12.0, "Init CD": 6.0, "Global CD": 0.0,
		"Target Type": "target", "Target Camp": -1,
		"Damage Type": "AD",
	}, caster, 1)


# ── Logic 层：tick_skill_cd_only ──

# CD 与 global_cd 按真实时长衰减（无 HAST 时 dt_cd=dt）
func test_tick_advances_skill_cd_and_global_cd() -> void:
	var eng := _make_engine()
	var u := _make_unit(eng)
	var sk := _make_cd_skill(u)
	u.skill_list = [sk]
	u.global_cd = 0.5
	BattleUnitUpdate.tick_skill_cd_only(u, 1.0)
	assert_between(float(sk.cd_remaining), 4.9, 5.1, "CD 6→≈5（1 秒窗口）")
	assert_between(float(u.global_cd), -0.6, -0.4, "global_cd 同步衰减")


# 死亡单位不推（主 update 对死亡单位同样不进 CD 段）
func test_tick_skips_dead_unit() -> void:
	var eng := _make_engine()
	var u := _make_unit(eng)
	var sk := _make_cd_skill(u)
	u.skill_list = [sk]
	u.state = BattleUnit.State.DEAD
	BattleUnitUpdate.tick_skill_cd_only(u, 1.0)
	assert_between(float(sk.cd_remaining), 5.9, 6.1, "死亡单位 CD 不动")


# HAST 缩放与主 update 同公式（hast=100 → dt_cd=2×dt）
func test_tick_respects_hast_scaling() -> void:
	var eng := _make_engine()
	var u := _make_unit(eng)
	var sk := _make_cd_skill(u)
	u.skill_list = [sk]
	u.attribs["HAST"] = 100.0
	BattleUnitUpdate.tick_skill_cd_only(u, 1.0)
	assert_between(float(sk.cd_remaining), 3.9, 4.1, "HAST=100 时 1 秒窗口衰减 2")


# casting 中技能不推施法帧（dt_action=0），仅非 casting 技能减 CD
func test_tick_does_not_advance_casting_phase() -> void:
	var eng := _make_engine()
	var u := _make_unit(eng)
	var casting_sk := _make_cd_skill(u)
	casting_sk.casting = true
	casting_sk.current_phase = {"event_list": []}
	casting_sk.current_phase_elapsed = 0.0
	casting_sk.next_event = {}
	u.current_skill = casting_sk
	var idle_sk := _make_cd_skill(u)
	idle_sk.cd_remaining = 6.0
	u.skill_list = [casting_sk, idle_sk]
	BattleUnitUpdate.tick_skill_cd_only(u, 1.0)
	assert_between(float(casting_sk.current_phase_elapsed), -0.01, 0.01, "casting 技能施法帧不推进")
	assert_between(float(idle_sk.cd_remaining), 4.9, 5.1, "非 casting 技能 CD 正常衰减")


# ── View 层：battle_scene._process 分支行为 ──

func _assemble_rank7_stage1() -> Dictionary:
	var lib := SkillLibrary.new(cm)
	var player := PlayerData.new(cm)
	player.vitality = 100
	for tid: int in [1, 2, 3, 4, 5]:
		player.hero_manager.add_hero(tid)
	for inst_id in player.hero_manager.heroes.keys():
		var h: HeroInstance = player.hero_manager.heroes[inst_id]
		h.rank = 7
		h.level = 70
		h.skill_levels = [70, 70, 70, 70]
	var mgr := StageManager.new(cm)
	mgr.skill_lib = lib
	return mgr.assemble_stage_battle(1, player, [1, 2, 3, 4, 5], BattleRng.new(12345))


func _find_first_minor_skill(eng: BattleEngine) -> BattleSkill:
	for u in eng.unit_list:
		if int(u.camp) == BattleEngine.CAMP_PLAYER:
			for s in u.skill_list:
				var n := String(s.info.get("Skill Name", ""))
				if n.ends_with("_atk2") or n.ends_with("_atk3"):
					return s
	return null


# 入场冻结（_entering）期间 _process 推进技能 CD（贴源：源此阶段引擎持续 tick）
func test_scene_entering_process_advances_skill_cd() -> void:
	var asm := _assemble_rank7_stage1()
	assert_true(bool(asm.get("ok", false)), "装配应成功")
	var eng: BattleEngine = asm["engine"]
	var scene := BattleScene.new()
	add_child(scene)
	scene.process_mode = Node.PROCESS_MODE_DISABLED   # 阻止引擎真实帧自动 _process 污染测量（仅手动调用）
	scene.setup(eng, cm, asm["battle_info"])
	var minor := _find_first_minor_skill(eng)
	assert_not_null(minor, "应装配到小技能（rank7 英雄）")
	scene.set_speed_state(1)   # 速度档持久化（user:// ConfigFile）可能读到实机存的 4x，固定 1x 使断言确定
	scene._entering = true
	var before := float(minor.cd_remaining)
	scene._process(1.0)
	assert_between(float(minor.cd_remaining), before - 1.1, before - 0.9, "入场冻结 1s 小技能 CD 衰减 ≈1")
	# 波清后走向屏外（_walking_to_next）不推——源 victory() running=false 暂停语义
	scene._entering = false
	scene._walking_to_next = true
	var before2 := float(minor.cd_remaining)
	scene._process(1.0)
	assert_between(float(minor.cd_remaining), before2 - 0.01, before2 + 0.01, "切波走路阶段 CD 不动（照源暂停）")
	scene.queue_free()


# ── 端到端：3 波战斗带入场窗口，小技能至少施放一次 ──

func test_three_wave_battle_casts_minor_skill_with_enter_window() -> void:
	var asm := _assemble_rank7_stage1()
	assert_true(bool(asm.get("ok", false)), "装配应成功")
	var eng: BattleEngine = asm["engine"]
	const ENTER_WINDOW := 2.5   # 入场走路+过场窗口（源 EnterBattleStage Timer 2.5s 量级）
	var cast_count := 0
	var prev_casting: Dictionary = {}
	var ticks := 0
	while ticks < 3000 and not eng.stage_ended:
		if not eng.running:
			if eng.wave_clear:
				BattleEngineWaves.next_battle(eng, cm)
				eng.wave_clear = false
				eng.running = true
				for u in eng.unit_list:
					BattleUnitUpdate.tick_skill_cd_only(u, ENTER_WINDOW)
				continue
			break
		eng.update(BattleEngine.TICK_INTERVAL)
		ticks += 1
		for u in eng.unit_list:
			if int(u.camp) != BattleEngine.CAMP_PLAYER or not u.is_alive():
				continue
			for s in u.skill_list:
				var n := String(s.info.get("Skill Name", ""))
				if not (n.ends_with("_atk2") or n.ends_with("_atk3")):
					continue
				var key := "%s/%s" % [str(u.info.get("ID", "?")), n]
				var now := bool(s.casting)
				if now and not bool(prev_casting.get(key, false)):
					cast_count += 1
				prev_casting[key] = now
	assert_gt(cast_count, 0, "带入场窗口的 3 波战斗小技能应至少施放 1 次（实测 %d）" % cast_count)
