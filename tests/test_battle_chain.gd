extends GutTest
# Phase 2.6 BattleChain（照源 chain.lua:1-84 翻译，2026-07-01）。
# 验 ChainCreate 首跳（target 受伤）+ update 跳跃（多目标受伤 / jumps_remaining 递减 / 终止）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_engine() -> BattleEngine:
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(777)
	return eng


func _make_enemy(eng: BattleEngine, pos: Vector2, name_suffix: String) -> BattleUnit:
	var u := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_ENEMY, {"estimate_rank": true}, cm, eng, {}, null)
	u.position = pos
	u.previous_position = pos
	u.attribs["ARM"] = 0.0
	u.attribs["DODG"] = 0.0
	u.attribs["PIMU"] = 0.0
	u.name = name_suffix
	return u


# Chain 技能 info（AD，Chain Jumps=3，无 Buff ID；Track Type 由 _create_chain 路径不走，直接测 chain）
func _make_chain_skill(caster: BattleUnit) -> BattleSkill:
	return BattleSkill.new({
		"Chain Jumps": 3,
		"Chain Gap": 0.1,
		"Max Range": 99999.0,
		"Min Range": 0.0,
		"Damage Type": "AD",
		"Basic Num": 100.0,
		"Plus Ratio": 0.0,
		"Target Type": "target",
		"Target Camp": -1,
		"Affected Camp": 0,
		"Cost MP": 0.0,
		"CD": 0.0,
		"Global CD": 0.0,
	}, caster, 1)


# 源 ChainCreate（:10-22）+ jump（:26-37）：构造即首跳 takeEffectOn(target)
func test_chain_create_first_jump_hits_target() -> void:
	var eng := _make_engine()
	var attacker := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_rank": true}, cm, eng, {}, null)
	attacker.position = Vector2(0, 0)
	attacker.previous_position = attacker.position
	var e1 := _make_enemy(eng, Vector2(200, 0), "e1")
	eng.add_unit(attacker)
	eng.add_unit(e1)
	var hp_before := int(e1.hp)
	var sk := _make_chain_skill(attacker)
	sk.target = e1
	var chain := BattleChain.new(sk)
	assert_eq(chain.jumps_remaining, 2, "首跳后 jumps_remaining 3→2")
	assert_true(int(e1.hp) < hp_before, "首跳 takeEffectOn 命中 e1（hp %d → %d）" % [hp_before, int(e1.hp)])


# 源 update（:40-54）+ findNextTaeget（:60-83）：jump_timer 到点 → 跳下一目标 → 多目标受伤
func test_chain_update_jumps_to_next_targets() -> void:
	var eng := _make_engine()
	var attacker := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_rank": true}, cm, eng, {}, null)
	attacker.position = Vector2(0, 0)
	attacker.previous_position = attacker.position
	var e1 := _make_enemy(eng, Vector2(200, 0), "e1")
	var e2 := _make_enemy(eng, Vector2(250, 0), "e2")
	var e3 := _make_enemy(eng, Vector2(300, 0), "e3")
	eng.add_unit(attacker)
	eng.add_unit(e1)
	eng.add_unit(e2)
	eng.add_unit(e3)
	var sk := _make_chain_skill(attacker)
	sk.target = e1
	var chain := BattleChain.new(sk)
	eng.add_chain(chain)
	assert_eq(eng.projectile_list.size(), 1, "chain 进 projectile_list")
	for i in range(30):
		eng.update(0.033)
		if chain.terminated:
			break
	var hit_count: int = 0
	for e in [e1, e2, e3]:
		if int(e.hp) < int(e.attribs.get("HP", 0)):
			hit_count += 1
	assert_true(hit_count >= 2, "chain 跳跃命中 >=2 个目标（实际 %d）" % hit_count)
	assert_true(chain.terminated, "chain 跳跃完毕终止")


# ── View 层守卫：ChainActor 拉伸须乘法保留 FCA 基准缩放（2026-09-06 宙斯连锁闪电全屏回归）──
# dbdd6ee 起 update_view 覆盖式赋值 content_node.scale，冲掉 FCA root 的 0.09 基准——
# 散件 transform 的 1/0.09 因子失去配对 → 净放大 ~11×（链条横铺全屏"技能动画错乱"）。
# 修复照 play_effect_on_scene 同款乘法范式（dbdd6ee 在该处已立的判例）保留基准。
class StubUnit:
	extends RefCounted
	var position: Vector2
	func _init(p: Vector2) -> void:
		position = p

class StubSkillInfo:
	extends RefCounted
	var info: Dictionary
	func _init(i: Dictionary) -> void:
		info = i

class StubChain:
	extends RefCounted
	var skill: StubSkillInfo
	var source: StubUnit
	var target: StubUnit
	func _init(s: StubSkillInfo, src: StubUnit, tgt: StubUnit) -> void:
		skill = s; source = src; target = tgt


func test_chain_actor_stretch_multiplies_fca_base_scale() -> void:
	var src := StubUnit.new(Vector2(100.0, 200.0))
	var tgt := StubUnit.new(Vector2(400.0, 200.0))
	var chain := StubChain.new(StubSkillInfo.new({"Chain Effect": "eff_chain_lightning.cha"}), src, tgt)
	var actor := ChainActor.new()
	add_child_autofree(actor)
	actor.setup(chain)
	assert_eq(actor.get_child_count(), 1, "content 节点挂载（真资源加载成功）")
	var n: Node2D = actor.get_child(0)
	var base: float = FcaAnimation.BATTLE_SCALE
	assert_almost_eq(n.scale.y, base * 3.0, 0.001,
		"y = 基准(0.09)×3 乘法保留（覆盖式=3.0 即 ~11× 放大回归）")
	var view_a: Vector2 = BattleViewCoords.to_view_position(100.0, 200.0, 12.0)
	var view_b: Vector2 = BattleViewCoords.to_view_position(400.0, 200.0, 48.0)
	var dist: float = view_a.distance_to(view_b)
	assert_almost_eq(n.scale.x, base * dist / 100.0, 0.001,
		"x = 基准(0.09)×dist/100（覆盖式=dist/100 即 ~11× 放大回归）")
	# external positioning（照源 chain.lua:104 setExternalPositioning）：散件 transform=IDENTITY
	# （纹理原尺寸居中）——若应用 cha 仿射则 ×1/0.09 失控放大+tx/ty 移出屏（全屏错乱回归）
	for c in n.get_children():
		if (c as CanvasItem).visible:
			assert_almost_eq((c as Node2D).transform.x.x, 1.0, 0.0001,
				"external 模式散件线性=IDENTITY（应用仿射=11× 放大回归）")
			assert_almost_eq((c as Node2D).transform.origin.x, 0.0, 0.0001,
				"external 模式散件 origin=0（丢弃骨架 tx/ty）")
