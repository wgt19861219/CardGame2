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
