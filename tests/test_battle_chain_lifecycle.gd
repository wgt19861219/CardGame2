extends GutTest
# 守卫（2026-09-07 宙斯闪电链"释放后不消失"根修）：战斗终态停摆必须终止飞行中链/投射物。
# 根因：victory/exit_stage 置 running=false 后 engine.update 短路，projectile_list 内
# BattleChain 永不 update → 永不 terminated → View _advance_actor_list 永不销毁 ChainActor
#（挂 FCA Loop 无限循环）→ 波清等待/走路与终局拾取结算窗口闪电链持续闪烁（源 ChainEffect
# 靠 content:isTerminated 自灭、不依赖 Logic 停摆，故无此症）。
# 修复：battle_engine._terminate_airborne_projectiles() 于 victory/exit_stage 直接置位。
# 三个场景：正常路径自然终止 / 多波波清帧终止 / 终局胜利帧终止。


var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_engine() -> BattleEngine:
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(777)
	return eng


func _make_unit(tid: int, camp: int, eng: BattleEngine, pos: Vector2) -> BattleUnit:
	var u := BattleUnit.new({"_tid": tid, "_level": 1, "_stars": 1}, camp, {"estimate_rank": true}, cm, eng, {}, null)
	u.position = pos
	u.previous_position = pos
	u.attribs["ARM"] = 0.0
	u.attribs["DODG"] = 0.0
	u.attribs["PIMU"] = 0.0
	return u


# 照源 Zeus_atk2（Skill 42）链参数；手注 phase 触发攻击帧走真实 add_chain 路径
func _make_zeus_chain_skill(caster: BattleUnit, basic_num: float) -> BattleSkill:
	var sk := BattleSkill.new({
		"Damage Type": "AP", "Basic Num": basic_num, "Plus Ratio": 0.0,
		"Max Range": 99999.0, "Target Type": "target", "Target Camp": -1,
		"Affected Camp": 0, "Cost MP": 0.0, "CD": 0.0, "Global CD": 0.0,
		"Track Type": "chain", "Chain Jumps": 3, "Chain Gap": 0.4,
		"Chain Effect": "eff_chain_lightning.cha",
	}, caster, 1)
	sk.phase_list = [{"action_name": "Attack", "duration": 0.5, "event_list": [{"Time": 0.001, "Type": "Attack"}]}]
	return sk


func _count_chain_actors(scene: Node) -> int:
	var cnt: int = 0
	for a in scene.actor_list:
		if a is ChainActor:
			cnt += 1
	return cnt


# 正常路径：敌人血量足够 → 链自然播完（jumps×Gap）terminate + ChainActor 被 queue_free。
func test_normal_battle_chain_terminates_and_actor_freed() -> void:
	var eng := _make_engine()
	var zeus := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	var e1 := _make_unit(1, BattleEngine.CAMP_ENEMY, eng, Vector2(300, 0))
	var e2 := _make_unit(1, BattleEngine.CAMP_ENEMY, eng, Vector2(350, 0))
	var e3 := _make_unit(1, BattleEngine.CAMP_ENEMY, eng, Vector2(400, 0))
	eng.add_unit(zeus)
	eng.add_unit(e1)
	eng.add_unit(e2)
	eng.add_unit(e3)
	var sk := _make_zeus_chain_skill(zeus, 10.0)   # 低伤害：敌人不死，链播完全程
	zeus.skill_list.append(sk)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	add_child_autofree(scene)
	zeus.cast_skill(sk, e1)
	var chain_seen: Variant = null
	var saw_chain := false   # freed 对象的 Variant 判 null 为 false，须显式标记
	var frame: int = 0
	while frame < 600:
		await get_tree().process_frame
		frame += 1
		if not saw_chain:
			for a in scene.actor_list:
				if is_instance_valid(a) and a is ChainActor:
					chain_seen = a
					saw_chain = true
		if saw_chain and not is_instance_valid(chain_seen):
			break   # 已销毁，提前退出
	assert_true(saw_chain, "ChainActor 创建（真实 add_chain→ProjectileSync 路径）")
	assert_false(is_instance_valid(chain_seen), "链自然播完后 ChainActor 被销毁（jumps=3×Gap=0.4 ≈1.2s）")
	assert_eq(_count_chain_actors(scene), 0, "actor_list 无 ChainActor 残留")


# 多波波清：最后一跳电死本波最后敌人 → victory() 波清分支 running=false——停摆帧链必须
# 同步 terminated（修复前：term 恒 false 挂到切波 reset_battle，实测 3.5s+ 闪烁窗口）。
func test_wave_clear_terminates_airborne_chain() -> void:
	var eng := _make_engine()
	eng.stage_info = {"Waves": 2}
	eng.battle_lookup_id = 1
	var zeus := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	var e1 := _make_unit(1, BattleEngine.CAMP_ENEMY, eng, Vector2(300, 0))
	e1.set_hp(20)   # 低血：首跳电死 → 波清落在链跳跃中途（Gap=0.4s 窗口内）
	eng.add_unit(zeus)
	eng.add_unit(e1)
	var sk := _make_zeus_chain_skill(zeus, 500.0)
	zeus.skill_list.append(sk)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	add_child_autofree(scene)
	zeus.cast_skill(sk, e1)
	var frame: int = 0
	while frame < 600:
		await get_tree().process_frame
		frame += 1
		if bool(eng.wave_clear):
			break
	assert_true(bool(eng.wave_clear), "波清触发（链中途电死本波最后敌人）")
	# 波清帧同步断言：停摆瞬间链已终止（修复点）
	var chain_terminated_at_clear: bool = true
	for c in eng.projectile_list:
		if c is BattleChain and not bool(c.terminated):
			chain_terminated_at_clear = false
	assert_true(chain_terminated_at_clear, "波清帧链已 terminated（修复前恒 false）")
	# 波清等待/走路窗口（修复前 ChainActor 在此窗口全程闪烁）
	for i in range(30):
		await get_tree().process_frame
	assert_eq(_count_chain_actors(scene), 0, "波清窗口内 ChainActor 已销毁（修复前挂 3.5s+）")


# 终局胜利：最后一波最后一跳电死 → exit_stage → _finalized 停 _process——胜利帧链必须
# 已 terminated（修复前：View 永不销毁，挂到 change_scene，实测 5s+ 闪烁窗口）。
func test_final_win_terminates_airborne_chain() -> void:
	var eng := _make_engine()
	eng.stage_info = {"Waves": 1}
	eng.battle_lookup_id = 1
	var zeus := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	var e1 := _make_unit(1, BattleEngine.CAMP_ENEMY, eng, Vector2(300, 0))
	e1.set_hp(20)
	eng.add_unit(zeus)
	eng.add_unit(e1)
	var sk := _make_zeus_chain_skill(zeus, 500.0)
	zeus.skill_list.append(sk)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	add_child_autofree(scene)
	zeus.cast_skill(sk, e1)
	var frame: int = 0
	while frame < 600:
		await get_tree().process_frame
		frame += 1
		if eng.last_result != -1:
			break
	assert_ne(eng.last_result, -1, "战斗终局（链中途电死最后一波最后敌人）")
	var chain_terminated_at_end: bool = true
	for c in eng.projectile_list:
		if c is BattleChain and not bool(c.terminated):
			chain_terminated_at_end = false
	assert_true(chain_terminated_at_end, "终局帧链已 terminated（修复前恒 false）")
	for i in range(30):
		await get_tree().process_frame
	assert_eq(_count_chain_actors(scene), 0, "终局窗口内 ChainActor 已销毁（修复前挂到场景切换）")
