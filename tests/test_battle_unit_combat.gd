extends GutTest
const EmitStub = preload("res://tests/helpers/battle_emit_stub.gd")
# Phase 2.2续-A 伤害闭环（照源 unit.lua:1252 takeDamage 等翻译，2026-07-01）。
# MockUnit/MockSource/MockEngine/MockRng/MockBuff duck-type 契约（照源 unit 协作者）。
# 伤害公式精确数值校验（AD/AP/Holy/防御减伤/暴击/免疫/buff onDamaged/致死/hurt/mp_gain）。

class MockRng:
	extends RefCounted
	var val: float = 1.0  # 默认 1.0：crit_prob>1 不可能 → 稳定不暴击
	func randf() -> float:
		return val

class MockSource:
	extends RefCounted
	var attribs: Dictionary = {"ARMP": 0, "MRI": 0, "CRIT": 0, "MCRIT": 0, "PDM": 1.0}
	var dmg_statistics: float = 0.0

class MockBuff:
	extends RefCounted
	var factor: float = 0.5
	func on_damaged(damage: float, _dt: String) -> float:
		return damage * factor

class MockEngine:
	extends RefCounted
	var rng: Variant = null
	var mp_bonus: float = 1.0
	var on_die_calls: Array = []
	var events: Array = []   # T4：表现事件队列（emit_event 收口）
	func foreach_alive_unit(_camp: int) -> Array:
		return []
	func on_unit_die(u: Variant, killer: Variant) -> void:
		on_die_calls.append([u, killer])
	func emit_event(e: Variant) -> void:
		events.append(e)

class MockUnit extends EmitStub:
	var attribs: Dictionary = {"ARM": 0, "MR": 0, "PIMU": 0, "MIMU": 0, "HP": 1000}
	var buff_list: Array = []
	var buff_effects: Dictionary = {}
	var hp: int = 1000
	var mp: int = 0
	var info: Dictionary = {"MP Gain Rate": 0}
	var level: int = 1
	var camp: int = 1
	var state: int = 0  # BattleUnit.State.IDLE
	var current_skill: Variant = null
	var dmg_statistics: float = 0.0
	var dPSStatisticsRatio: float = 1.0
	var isDeathWithEffect: bool = false
	var manually_casting: bool = false
	var can_cast_manual: bool = false
	var knockup_time: float = -1.0
	var knockup_v: Vector2 = Vector2.ZERO
	var walk_v: Vector2 = Vector2.ZERO
	var action_name: String = ""
	var action_loop: bool = false
	var action_duration: float = 0.0
	var action_elapsed: float = 0.0
	var aura_skill_list: Array = []
	var effect_enemy_aura_skill_list: Array = []
	var name: String = ""        # 源 unit.name（单位代号，音效拼路径 unit.lua:1113/1158）
	func set_hp(v: int) -> int:
		hp = clamp(v, 0, int(attribs.get("HP", 999999)))
		return hp
	func set_mp(v: int) -> int:
		mp = clamp(v, 0, 999999)
		return mp
	func is_alive() -> bool:
		return state != BattleUnit.State.DEAD and state != BattleUnit.State.DYING
	func unfreeze_actor() -> void:
		pass
	func remove_signed_buffer() -> void:
		pass
	func rebuild() -> void:
		pass


# die/cast_manual_skill 音效（T4 起走 BattleEvent.VOICE 事件，断言 engine.events）。


func _make_unit() -> MockUnit:
	var u := MockUnit.new()
	var eng := MockEngine.new()
	eng.rng = MockRng.new()
	u.engine = eng
	return u

func _make_source() -> MockSource:
	return MockSource.new()

# —— takeDamage 公式 ——

# 源 :1297 AD：damage = amount²/(amount+dd*coef) × crit × PDM；defence=0 → dd=0 → damage=amount
func test_take_damage_ad_basic() -> void:
	var u := _make_unit()
	var src := _make_source()
	var lost := BattleUnitCombat.take_damage(u, {"amount": 100, "damage_type": "AD", "source": src})
	assert_eq(lost, 100.0, "AD defence=0：100²/(100+0)=100")
	assert_eq(u.hp, 900, "扣血 1000-100")
	assert_eq(src.dmg_statistics, 100.0, "source.dmg_statistics +=100")

# 源 :1278-1283 AP：dd=defence*12, dc=defence*2.5；defence=0 同 AD
func test_take_damage_ap() -> void:
	var u := _make_unit()
	var src := _make_source()
	var lost := BattleUnitCombat.take_damage(u, {"amount": 100, "damage_type": "AP", "source": src})
	assert_eq(lost, 100.0, "AP defence=0：100")

# 源 :1284-1289 Holy：defence/crit/immunity/dd/dc 全 0
func test_take_damage_holy() -> void:
	var u := _make_unit()
	var src := _make_source()
	var lost := BattleUnitCombat.take_damage(u, {"amount": 100, "damage_type": "Holy", "source": src})
	assert_eq(lost, 100.0, "Holy 无防御 → 100")

# 源 :1276 AD 防御减伤：defence=ARM-ARMP=100，dd=100*8=800；damage=100²/(100+800)≈11.11
func test_take_damage_defence_reduction() -> void:
	var u := _make_unit()
	u.attribs["ARM"] = 100
	var src := _make_source()
	var lost := BattleUnitCombat.take_damage(u, {"amount": 100, "damage_type": "AD", "source": src})
	assert_almost_eq(lost, 11.1111, 0.01, "defence=100→dd=800：100²/900≈11.11")

# 源 :1293-1295 暴击：crit_prob=CRIT/(100+dc)*crit_mod=100/100=1.0 > rand(0.5) → ×2
func test_take_damage_crit() -> void:
	var u := _make_unit()
	var src := _make_source()
	src.attribs["CRIT"] = 100
	u.engine.rng.val = 0.5  # crit_prob=1.0 > 0.5 → 暴击
	var lost := BattleUnitCombat.take_damage(u, {"amount": 100, "damage_type": "AD", "source": src})
	assert_eq(lost, 200.0, "暴击 ×2：100*2=200")

# 源 :1299 immunity>=100 完全免疫 → return 0
func test_take_damage_immune() -> void:
	var u := _make_unit()
	u.attribs["PIMU"] = 100
	var src := _make_source()
	var lost := BattleUnitCombat.take_damage(u, {"amount": 100, "damage_type": "AD", "source": src})
	assert_eq(lost, 0.0, "PIMU>=100 免疫 → 0")
	assert_eq(u.hp, 1000, "hp 不变")

# 源 :1316-1318 buff onDamaged 链
func test_take_damage_buff_on_damaged() -> void:
	var u := _make_unit()
	u.buff_list = [MockBuff.new()]  # factor=0.5 半减
	var src := _make_source()
	var lost := BattleUnitCombat.take_damage(u, {"amount": 100, "damage_type": "AD", "source": src})
	assert_eq(lost, 50.0, "buff 半减：100→50")

# 源 :1333-1335 hp==0 → die
func test_take_damage_die() -> void:
	var u := _make_unit()
	u.hp = 50
	u.attribs["HP"] = 1000
	var src := _make_source()
	BattleUnitCombat.take_damage(u, {"amount": 100, "damage_type": "AD", "source": src})
	assert_eq(u.state, BattleUnit.State.DYING, "致死 → DYING")
	assert_eq(u.hp, 0, "hp=0")
	assert_eq(u.engine.on_die_calls.size(), 1, "engine.on_unit_die 被调")

# 源 :1338-1348 lost > HP*0.08 且非 Birth/不可打断/不受控 → hurt
func test_take_damage_hurt() -> void:
	var u := _make_unit()
	u.hp = 1000
	u.attribs["HP"] = 1000
	var src := _make_source()
	BattleUnitCombat.take_damage(u, {"amount": 100, "damage_type": "AD", "source": src})
	# lost=100 > 1000*0.08=80 → hurt
	assert_eq(u.state, BattleUnit.State.HURT, "lost>阈值 → HURT")
	assert_eq(u.action_name, "Damaged", "hurt 动作")

# 源 :1339 lost <= HP*0.08 → 不打断
func test_take_damage_no_hurt_small_loss() -> void:
	var u := _make_unit()
	u.hp = 1000
	u.attribs["HP"] = 1000
	var src := _make_source()
	BattleUnitCombat.take_damage(u, {"amount": 10, "damage_type": "AD", "source": src})
	# lost=10 <= 80 → 不 hurt
	assert_eq(u.state, BattleUnit.State.IDLE, "小损不打断")

# 源 :1350-1351 mp_gain = lost * MP Gain Rate / HP * mp_bonus
func test_take_damage_mp_gain() -> void:
	var u := _make_unit()
	u.hp = 1000
	u.attribs["HP"] = 1000
	u.info = {"MP Gain Rate": 100}
	u.mp = 0
	var src := _make_source()
	BattleUnitCombat.take_damage(u, {"amount": 100, "damage_type": "AD", "source": src})
	# mp_gain = 100 * 100 / 1000 = 10
	assert_eq(u.mp, 10, "mp_gain=lost*rate/HP=10")

# 源 :1353-1355 field=mp → setMP(mp-lost)
func test_take_damage_mp_field() -> void:
	var u := _make_unit()
	u.mp = 200
	var src := _make_source()
	BattleUnitCombat.take_damage(u, {"amount": 50, "damage_type": "AD", "field": "mp", "source": src})
	assert_eq(u.mp, 150, "mp field：mp-lost=200-50")

# 源 :1325 source == self → 不计统计
func test_take_damage_self_source_no_stat() -> void:
	var u := _make_unit()
	u.dmg_statistics = 0.0
	# source 设为 u 自身（自伤），不计 dmg_statistics
	BattleUnitCombat.take_damage(u, {"amount": 10, "damage_type": "Holy", "source": u})
	assert_eq(u.dmg_statistics, 0.0, "source==self 不加统计")

# —— die（直接）——

# 源 die（:1148-1209）
func test_die() -> void:
	var u := _make_unit()
	u.hp = 100
	var src := _make_source()
	BattleUnitCombat.die(u, src)
	assert_eq(u.state, BattleUnit.State.DYING, "die → DYING")
	assert_eq(u.hp, 0, "hp=0")
	assert_eq(u.mp, 0, "mp=0")
	assert_eq(u.engine.on_die_calls.size(), 1, "on_unit_die")

# 源 die :1155-1159 死亡音效（T4 起 VOICE 事件）：name 非空 → engine.events 产 VOICE。
func test_die_plays_death_voice() -> void:
	var u := _make_unit()
	u.hp = 100
	u.name = "AM"
	BattleUnitCombat.die(u, null)
	var voices: Array = u.engine.events.filter(func(e): return e.type == BattleEvent.Type.VOICE)
	assert_eq(voices.size(), 1, "die 产 1 条 VOICE 事件")
	assert_eq(voices[0].text, "AM", "name 大写透传")
	assert_eq(voices[0].text2, "_DEATH", "suffix _DEATH")

# 源 die :1156 name 空 → 音效跳过（heroName=nil 不播，源 if heroName then）。
func test_die_no_voice_when_name_empty() -> void:
	var u := _make_unit()
	u.hp = 100
	BattleUnitCombat.die(u, null)
	var voices: Array = u.engine.events.filter(func(e): return e.type == BattleEvent.Type.VOICE)
	assert_eq(voices.size(), 0, "name 空 不产 VOICE 事件")

# —— takeHeal ——

# 源 takeHeal（:1217-1242）hp 分支
func test_take_heal_hp() -> void:
	var u := _make_unit()
	u.hp = 500
	u.attribs["HP"] = 1000
	BattleUnitCombat.take_heal(u, 100, "hp", null)
	assert_eq(u.hp, 600, "hp+100")

# 源 :1226-1227 mp 分支
func test_take_heal_mp() -> void:
	var u := _make_unit()
	u.mp = 50
	BattleUnitCombat.take_heal(u, 100, "mp", null)
	assert_eq(u.mp, 150, "mp+100")

# 源 :1228-1229 unheal → 不加血
func test_take_heal_unheal() -> void:
	var u := _make_unit()
	u.hp = 500
	u.buff_effects[BattleEffectKeys.UNHEAL] = true
	BattleUnitCombat.take_heal(u, 100, "hp", null)
	assert_eq(u.hp, 500, "unheal 不加血")

# 源 :1222-1224 source.PDM 缩放
func test_take_heal_source_pdm() -> void:
	var u := _make_unit()
	u.hp = 500
	u.attribs["HP"] = 1000
	var src := MockSource.new()
	src.attribs["PDM"] = 0.5
	BattleUnitCombat.take_heal(u, 100, "hp", src)
	assert_eq(u.hp, 550, "amount*source.PDM=100*0.5=50")

# —— knockup ——

# 源 knockup（:1393-1407）
func test_knockup() -> void:
	var u := _make_unit()
	BattleUnitCombat.knockup(u, 1.0, Vector2(100, 0))
	assert_eq(u.knockup_time, 1.0, "knockup_time")
	assert_eq(u.knockup_v, Vector2(100, 0), "knockup_v=dist/time")

# 源 :1394 stable 免击退
func test_knockup_stable() -> void:
	var u := _make_unit()
	u.buff_effects[BattleEffectKeys.STABLE] = true
	BattleUnitCombat.knockup(u, 1.0, Vector2(100, 0))
	assert_eq(u.knockup_time, -1.0, "stable 免击退（time 不变）")

# —— set_action ——

# 源 setAction（:816-817）loop 同名不重置
func test_set_action_loop_same_skip() -> void:
	var u := _make_unit()
	u.action_name = "Idle"
	u.action_elapsed = 5.0
	BattleUnitCombat.set_action(u, "Idle", true, false)
	assert_eq(u.action_elapsed, 5.0, "同名 loop 不重置 elapsed")

# 源 :819-821 新动作 + interrupt → elapsed=0
func test_set_action_new_interrupt() -> void:
	var u := _make_unit()
	u.action_elapsed = 5.0
	BattleUnitCombat.set_action(u, "Death", false, true)
	assert_eq(u.action_name, "Death", "action_name")
	assert_eq(u.action_elapsed, 0.0, "interrupt → elapsed=0")
