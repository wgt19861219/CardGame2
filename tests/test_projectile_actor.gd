extends GutTest
# ProjectileActor（View 包装）冒烟测 — 照源 projectile.lua:223-321 ProjectileActor。
# 验位置同步（to_view_position）、旋转（按速度向量倾斜）、朝向（scale.y 翻转）、
# terminated 后由 actor_list 协议销毁。
# 用真 BattleProjectile（Logic 层）+ 真 ConfigManager，actor 入树驱动 update_view。

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


func _make_enemy(eng: BattleEngine, pos: Vector2) -> BattleUnit:
	var u := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_ENEMY, {"estimate_rank": true}, cm, eng, {}, null)
	u.position = pos
	u.previous_position = pos
	u.attribs["ARM"] = 0.0
	u.attribs["DODG"] = 0.0
	u.attribs["PIMU"] = 0.0
	u.info["Collide Radius"] = 20.0
	return u


func _make_proj(caster: BattleUnit, target: BattleUnit) -> BattleProjectile:
	var info := {
		"Tile XY Speed": 1000.0, "Tile Z Speed": 0.0, "Tile Distance": 0.0,
		"Tile Gravity": 0.0, "Tile OTT Height": 0.0,
		"Damage Type": "AD", "Basic Num": 100.0, "Plus Ratio": 0.0, "Plus Attr": "ATK",
		"Target Type": "target", "Target Camp": -1, "Affected Camp": -1,
		"Max Range": 99999.0, "Min Range": 0.0, "Cost MP": 0.0, "CD": 0.0, "Global CD": 0.0,
		"Tile Art": "eff_tile_AV_atk2.cha",  # 资源已迁移（assets/anim_frames/effect/eff_tile_AV_atk2.abc）
	}
	var sk := BattleSkill.new(info, caster, 1)
	sk.target = target
	return BattleProjectile.new(sk)


# 位置同步：actor.position == BattleViewCoords.to_view_position(proj.position, height)（照源 :296）。
func test_position_follows_logic() -> void:
	var eng := _make_engine()
	var attacker := _make_attacker(eng)
	var target := _make_enemy(eng, Vector2(500, 0))  # 远距，飞行中段采样
	eng.add_unit(attacker)
	eng.add_unit(target)
	var proj := _make_proj(attacker, target)
	eng.add_projectile(proj)
	var actor := ProjectileActor.new()
	actor.setup(proj)
	add_child(actor)
	# 推进几 tick 让 proj.position 变化（首 tick birthtick 跳过，第 2 tick 起飞）。
	for i in range(3):
		eng.update(0.033)
	actor.update_view(0.0)
	var expected: Vector2 = BattleViewCoords.to_view_position(proj.position.x, proj.position.y, proj.height)
	assert_eq(actor.position, expected, "actor 位置同步 logic 投射物（含 height 投影）")
	actor.queue_free()


# 旋转：z_speed>0（上抛）+ vx>0（朝右）→ rotation 为负值（抬头，照源 :299-300）。
func test_rotation_follows_velocity() -> void:
	var eng := _make_engine()
	var attacker := _make_attacker(eng)
	var target := _make_enemy(eng, Vector2(500, 0))
	eng.add_unit(attacker)
	eng.add_unit(target)
	var proj := _make_proj(attacker, target)
	proj.z_speed = 300.0  # 模拟上抛（抛物线初段）
	proj.velocity = Vector2(1000.0, 0.0)  # 朝右
	proj.position = Vector2(100, 0)
	var actor := ProjectileActor.new()
	actor.setup(proj)
	add_child(actor)
	actor.update_view(0.0)
	# -atan2(300+0, 1000) ≈ -0.2898 rad（负=抬头）
	assert_true(actor.rotation < 0.0, "z_speed>0 朝右飞行应抬头（rotation<0，实际 %f）" % actor.rotation)
	# 朝向：朝右不翻转
	assert_eq(actor.scale.y, 1.0, "朝右飞行 scale.y=1（不翻转）")
	# 反向：朝左飞行
	proj.velocity = Vector2(-1000.0, 0.0)
	actor.update_view(0.0)
	assert_eq(actor.scale.y, -1.0, "朝左飞行 scale.y=-1（沿 Y 翻转）")
	actor.queue_free()


# actor_list 协议：proj.terminated → _advance_actor_list 销毁 actor（复用单位 actor 同协议）。
func test_terminated_actor_freed() -> void:
	var eng := _make_engine()
	var attacker := _make_attacker(eng)
	var target := _make_enemy(eng, Vector2(100, 0))  # 近距，快速命中终止
	eng.add_unit(attacker)
	eng.add_unit(target)
	var proj := _make_proj(attacker, target)
	eng.add_projectile(proj)
	var actor := ProjectileActor.new()
	actor.setup(proj)
	add_child(actor)
	# 模拟 scene _advance_actor_list 协议：terminated → queue_free
	proj.terminate()
	assert_true(bool(proj.terminated), "投射物已 terminated")
	# 协议判定：model != null and not model.terminated → false → 销毁分支
	var should_free: bool = not (actor.model != null and not bool(actor.model.terminated))
	assert_true(should_free, "terminated 后 actor 应被销毁（协议判定 should_free=true）")
	actor.queue_free()
