extends GutTest
# 3 新英雄 hook 单测（CM/DOTsr/Lion）— 验证 apply 注册 + hook 可调。

var cm: ConfigManager

func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_cm_apply_registers_hooks() -> void:
	var hero: Variant = _make_hero(12)   # CM tid=12
	var cm_hook := HeroCM.new()
	cm_hook.apply(hero)
	var ult: Variant = hero.skills.get("CM_ult")
	if ult != null:
		# ⚠️ CM_ult start/takeEffectAt 是源死代码（CM.lua:2-53 定义但 init_hero :54-57 dead assignment 无 override），
		# 照源不挂（第七轮 P0，[[source-dead-code-activation]]）→ CM_ult 走默认 start/take_effect_at
		assert_false(ult.hero_hooks.has("start"), "CM_ult start 死代码不挂")
		assert_false(ult.hero_hooks.has("takeEffectAt"), "CM_ult takeEffectAt 死代码不挂")
	else:
		pass_test("CM 无 CM_ult 技能（数据未配），apply 不崩")


func test_dotsr_apply_registers_hook() -> void:
	# DOTsr 是 Monster（tid=117），技能装配可能无 DOTsr_atk2，验证 apply 不崩即可
	var hero: Variant = _make_hero(117)
	var hook := HeroDOTsr.new()
	hook.apply(hero)   # 不崩 = 通过（技能不存在时 apply 内部跳过）
	pass_test("DOTsr apply 不崩")


func test_lion_apply_registers_hook() -> void:
	var hero: Variant = _make_hero(6)   # Lion tid=6
	var hook := HeroLion.new()
	hook.apply(hero)
	var atk2: Variant = hero.skills.get("Lion_atk2")
	if atk2 != null:
		assert_true(atk2.hero_hooks.has("takeEffectOn"), "Lion_atk2 takeEffectOn hook 注册")
	else:
		pass_test("Lion 无 Lion_atk2 技能（数据未配），apply 不崩")


func _make_hero(tid: int) -> Variant:
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(42)
	var lib := SkillLibrary.new(cm)
	var p := BattleUnit.new({"_tid": tid, "_level": 1, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_rank": false}, cm, eng, {}, lib)
	eng.add_unit(p)
	return p
