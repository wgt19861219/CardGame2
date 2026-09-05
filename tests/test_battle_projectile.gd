extends GutTest
# Phase 2.6 BattleProjectile（照源 projectile.lua:9-220 翻译，2026-07-01）。
# 验 ProjectileCreate 飞行命中终止 + 穿透多目标 + collideCheck X 轴碰撞 t 计算。
# affect_camp：focamp=-camp（player camp=1→focamp=-1）× Affected Camp(-1) × -1 = -1（enemy），避开施法者。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_engine() -> BattleEngine:
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(777)
	return eng


func _make_attacker(eng: BattleEngine) -> BattleUnit:
	var u := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_rank": true}, cm, eng, {}, null)
	u.position = Vector2(0, 0)
	u.previous_position = u.position
	u.attribs["ARM"] = 0.0
	u.attribs["DODG"] = 0.0
	u.attribs["PIMU"] = 0.0
	return u


func _make_enemy(eng: BattleEngine, pos: Vector2, name_suffix: String) -> BattleUnit:
	var u := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_ENEMY, {"estimate_rank": true}, cm, eng, {}, null)
	u.position = pos
	u.previous_position = pos
	u.attribs["ARM"] = 0.0
	u.attribs["DODG"] = 0.0
	u.attribs["PIMU"] = 0.0
	u.info["Collide Radius"] = 20.0  # 源 collideCheck 读 unit.info["Collide Radius"]
	u.name = name_suffix
	return u


func _make_proj_skill(caster: BattleUnit, piercing: bool) -> BattleSkill:
	var info := {
		"Tile XY Speed": 1000.0, "Tile Z Speed": 0.0, "Tile Distance": 0.0,
		"Tile Gravity": 0.0, "Tile OTT Height": 0.0,
		"Damage Type": "AD", "Basic Num": 100.0, "Plus Ratio": 0.0, "Plus Attr": "ATK",
		"Target Type": "target", "Target Camp": -1, "Affected Camp": -1,
		"Max Range": 99999.0, "Min Range": 0.0, "Cost MP": 0.0, "CD": 0.0, "Global CD": 0.0,
	}
	if piercing:
		info["Tile Piercing"] = true
	return BattleSkill.new(info, caster, 1)


# 源 ProjectileCreate（:9-56）+ update（:74-128）：飞行 → collide → hit → terminate
func test_projectile_flies_and_hits_target() -> void:
	var eng := _make_engine()
	var attacker := _make_attacker(eng)
	var target := _make_enemy(eng, Vector2(200, 0), "t")
	eng.add_unit(attacker)
	eng.add_unit(target)
	var sk := _make_proj_skill(attacker, false)
	sk.target = target
	var proj := BattleProjectile.new(sk)
	eng.add_projectile(proj)
	var hp_before := int(target.hp)
	for i in range(20):
		if proj.terminated:
			break
		eng.update(0.033)
	assert_true(int(target.hp) < hp_before, "投射物命中 target（hp %d → %d）" % [hp_before, int(target.hp)])
	assert_true(proj.terminated, "命中后 terminate")


# 源 update（:103-114）Tile Piercing：穿透命中多目标不立即终止（直到出界）
func test_projectile_piercing_hits_multiple() -> void:
	var eng := _make_engine()
	var attacker := _make_attacker(eng)
	var e1 := _make_enemy(eng, Vector2(150, 0), "e1")
	var e2 := _make_enemy(eng, Vector2(250, 0), "e2")
	var e3 := _make_enemy(eng, Vector2(350, 0), "e3")
	eng.add_unit(attacker)
	eng.add_unit(e1)
	eng.add_unit(e2)
	eng.add_unit(e3)
	var sk := _make_proj_skill(attacker, true)
	sk.target = e1
	var proj := BattleProjectile.new(sk)
	eng.add_projectile(proj)
	for i in range(40):
		if proj.terminated:
			break
		eng.update(0.033)
	assert_true(proj.affect_times.size() >= 2, "穿透命中 >=2 目标（实际 %d）" % proj.affect_times.size())
	assert_true(proj.terminated, "穿透飞出界 terminate")


# 源 collideCheck（:142-166）：X 轴一维碰撞 t∈[0,1] 或无碰撞
func test_collide_check_x_axis() -> void:
	var eng := _make_engine()
	var attacker := _make_attacker(eng)
	var target := _make_enemy(eng, Vector2(200, 0), "t")
	eng.add_unit(attacker)
	eng.add_unit(target)
	var sk := _make_proj_skill(attacker, false)
	sk.target = target
	var proj := BattleProjectile.new(sk)
	proj.position = Vector2(210, 0)  # 跨过 target(200)：d=10,d0=-10 → t=0.5
	proj.previous_position = Vector2(190, 0)
	var t := proj.collide_check(target)
	assert_true(t >= 0.0 and t <= 1.0, "跨过 target 碰撞 t∈[0,1]（实际 %f）" % t)
	proj.position = Vector2(50, 0)  # 远离
	proj.previous_position = Vector2(40, 0)
	assert_eq(proj.collide_check(target), BattleProjectile.COLLIDE_NONE, "远离无碰撞 → -1")


# 切波回收（2026-09-05 小黑大招箭雨残留根因）：reset_battle 置空 projectile_list 前必须终结投射物。
# 投射物脱离列表后不再 update，terminated 恒 false → View _advance_actor_list 永不销毁 actor
# （玩家方投射物被 _remove_enemy_actors 按 camp==PLAYER 保留，冻结切波期间箭停在空中永久残留）。
func test_reset_battle_terminates_flying_projectiles() -> void:
	var eng := _make_engine()
	var attacker := _make_attacker(eng)
	var target := _make_enemy(eng, Vector2(2000, 0), "far")   # 远目标：飞行中不命中
	eng.add_unit(attacker)
	eng.add_unit(target)
	var sk := _make_proj_skill(attacker, false)
	sk.target = target
	var proj := BattleProjectile.new(sk)
	eng.add_projectile(proj)
	assert_false(bool(proj.terminated), "构造后投射物存活")
	eng.reset_battle()
	assert_true(bool(proj.terminated), "切波重置终结飞行中投射物（View actor 随之销毁）")
	assert_eq(eng.projectile_list.size(), 0, "列表清空")


# 冻结投射物变色（2026-09-05 投射物残留回归二轮）：engine.freeze() 遍历 projectile_list
# 对飞行中投射物 emit_tint（battle_entity.gd freeze/unfreeze），事件经 _dispatch 调
# ProjectileActor.tint——曾漏译炸 Nonexistent function 'tint' → step 从 render 行中断
# （当帧 ProjectileSync.sync/_advance_actor_list 全跳）+ 编辑器 Debugger Break 挂死游戏，
# 即用户"投射物切波后还在"复现根因（probe 实锤）。守卫：freeze→分发→变色/复白全链不炸。
func test_freeze_projectile_tint_dispatch_no_crash() -> void:
	var eng := _make_engine()
	var attacker := _make_attacker(eng)
	var target := _make_enemy(eng, Vector2(2000, 0), "far")
	eng.add_unit(attacker)
	eng.add_unit(target)
	var sk := _make_proj_skill(attacker, false)
	sk.target = target
	var proj := BattleProjectile.new(sk)
	eng.add_projectile(proj)
	var actor := ProjectileActor.new()
	actor.setup(proj)
	# freeze → emit TINT → 手动模拟 _dispatch 分发（renderer 直调等价，炸点即 tint 缺方法）
	eng.freeze()
	BattleEventRenderer.render(eng, {proj: actor})
	assert_eq(actor.modulate, Color(0.4, 0.4, 0.4), "冻结 tint=FREEZE_TINT(0.4) 变暗蓝灰")
	# unfreeze → 复白（UNFREEZE_TINT=2.5 clamp 到 1.0=WHITE）
	eng.unfreeze()
	BattleEventRenderer.render(eng, {proj: actor})
	assert_eq(actor.modulate, Color.WHITE, "解冻 tint=2.5 clamp 到 1.0 复白")
	actor.queue_free()
