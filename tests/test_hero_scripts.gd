extends GutTest
# 阶段三 T2（2026-08-14）：BattleHeroScripts 直 load 装配守卫（取代 BattleHeroRegistry 人工映射）。
# 数据表驱动完整性：Unit 表全部 Script 字段断言按约定可 load——缺文件即红，治"漏登记静默失效"
# （迁移期实锤：Lion/DOTsr 文件在而 registry 漏登记，hook 长期哑）。
# 另守卫 proto_awake 迁移语义 + apply 装配冒烟。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_all_unit_table_scripts_loadable() -> void:
	var unit_table: Dictionary = cm.get_raw_table(&"Unit")
	var checked: int = 0
	for id in unit_table:
		var row: Dictionary = unit_table[id]
		var script_path := String(row.get("Script", ""))
		if script_path == "":
			continue
		assert_true(BattleHeroScripts.can_load(script_path), "Unit 表 Script 无法按约定 load：%s（Unit id=%s）" % [script_path, id])
		checked += 1
	assert_gt(checked, 0, "Unit 表应存在 Script 引用（对账有效性质）")


# 迁移期漏登记实锤的回归守卫：这两个此前在 registry 缺失，直 load 后应可加载
func test_lion_and_dotsr_now_loadable() -> void:
	assert_true(BattleHeroScripts.can_load("battle/heroes/Lion"), "Lion 可加载（原 registry 漏登记）")
	assert_true(BattleHeroScripts.can_load("battle/heroes/DOTsr"), "DOTsr 可加载（原 registry 漏登记）")
	assert_false(BattleHeroScripts.can_load("battle/heroes/NoSuchHero"), "不存在的能力应返回 false")


func test_proto_awake_reads_awake_field() -> void:
	assert_false(BattleHeroScripts.proto_awake({}), "proto 无 _awake 键 → false（不觉醒）")
	assert_false(BattleHeroScripts.proto_awake({"_awake": false}), "proto._awake=false → false")
	assert_true(BattleHeroScripts.proto_awake({"_awake": true}), "proto._awake=true → 觉醒激活")


# apply 装配冒烟：AV 直 load 后 hook 注册成功（等价旧 registry 分发行为，mock 范式对齐 test_hero_av）
class MockSkill:
	extends RefCounted
	var hero_hooks: Dictionary = {}


class MockHero:
	extends RefCounted
	var skills: Dictionary = {}


func test_apply_registers_hero_hooks() -> void:
	var hero := MockHero.new()
	hero.skills["AV_ult"] = MockSkill.new()
	hero.skills["AV_atk3"] = MockSkill.new()
	hero.skills["AV_atk2"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/AV", hero)
	assert_true(hero.skills["AV_atk2"].hero_hooks.has("createProjectile"), "AV_atk2 createProjectile hook 应注册")
	assert_true(hero.skills["AV_ult"].hero_hooks.has("start"), "AV_ult start hook 应注册")


# 空 script_path 直接跳过（battle_unit 调用约定）
func test_apply_empty_path_noop() -> void:
	var hero := MockHero.new()
	BattleHeroScripts.apply("", hero)
	assert_eq(hero.skills.size(), 0, "空路径不应装配任何 hook")
