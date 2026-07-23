extends GutTest
# AwakeHelper 觉醒养成辅助测试（单机化新增，源 Lua 无觉醒养成激活）。
# 碎片觉醒方案：消耗专属碎片 50 个 → HeroInstance.awake=true。
# 数据：tid=1 (Coco) Can Awake=true / Bg Color=blue / Fragment[1] Fragment ID=124
#       tid=2 (DR)   Can Awake=false（断言 Can Awake 守卫生效）

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# ---- can_awake（基础资格，不含碎片数）----

func test_can_awake_false_when_hero_null() -> void:
	assert_false(AwakeHelper.can_awake(cm, null), "hero=null 拒绝")


func test_can_awake_false_when_already_awake() -> void:
	var hero := HeroInstance.new(1, 1, 1)
	hero.awake = true
	assert_false(AwakeHelper.can_awake(cm, hero), "已觉醒拒绝")


func test_can_awake_false_when_not_awakeable() -> void:
	# tid=2 DR Can Awake=false（Unit.json 字段断言）
	assert_false(cm.get_bool(&"Unit", 2, &"Can Awake"), "前提：tid=2 Can Awake=false")
	var hero := HeroInstance.new(2, 1, 1)
	assert_false(AwakeHelper.can_awake(cm, hero), "Can Awake=false 拒绝")


func test_can_awake_true_when_meets_base_conditions() -> void:
	# tid=1 Coco Can Awake=true
	assert_true(cm.get_bool(&"Unit", 1, &"Can Awake"), "前提：tid=1 Can Awake=true")
	var hero := HeroInstance.new(1, 1, 1)
	assert_true(AwakeHelper.can_awake(cm, hero), "Can Awake=true + 未觉醒 → 可觉醒")


# ---- can_awake_with_count（含碎片数）----

func test_can_awake_with_count_false_when_insufficient() -> void:
	var hero := HeroInstance.new(1, 1, 1)
	assert_false(AwakeHelper.can_awake_with_count(cm, hero, 49), "49<50 拒绝")


func test_can_awake_with_count_true_when_sufficient() -> void:
	var hero := HeroInstance.new(1, 1, 1)
	assert_true(AwakeHelper.can_awake_with_count(cm, hero, 50), "50>=50 通过")


func test_can_awake_with_count_true_when_over_sufficient() -> void:
	var hero := HeroInstance.new(1, 1, 1)
	assert_true(AwakeHelper.can_awake_with_count(cm, hero, 100), "100>=50 通过")


# ---- fragment_id_for_hero ----

func test_fragment_id_for_hero_returns_expected_id() -> void:
	# Fragment[1] Fragment ID=124（test_hero_manager_compose.gd 数据基线）
	assert_eq(AwakeHelper.fragment_id_for_hero(cm, 1), 124, "tid=1 → fragment_id=124")


# ---- awake_hero（执行觉醒）----

func test_awake_hero_success_consumes_fragments_and_sets_awake() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	pd.hero_manager.add_fragment(124, 100)
	var hero: HeroInstance = pd.hero_manager.find_hero_by_tid(1)
	var result: Dictionary = AwakeHelper.awake_hero(pd, hero)
	assert_true(bool(result["ok"]), "觉醒成功")
	assert_true(hero.awake, "hero.awake=true")
	assert_eq(pd.hero_manager.fragment_count(124), 50, "扣 50 碎片（100-50）")


func test_awake_hero_rejects_already_awake() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	pd.hero_manager.add_fragment(124, 100)
	var hero: HeroInstance = pd.hero_manager.find_hero_by_tid(1)
	hero.awake = true
	var result: Dictionary = AwakeHelper.awake_hero(pd, hero)
	assert_false(bool(result.get("ok", false)), "已觉醒拒绝")
	assert_eq(pd.hero_manager.fragment_count(124), 100, "不扣碎片")


func test_awake_hero_rejects_insufficient_fragments() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	pd.hero_manager.add_fragment(124, 30)   # < 50
	var hero: HeroInstance = pd.hero_manager.find_hero_by_tid(1)
	var result: Dictionary = AwakeHelper.awake_hero(pd, hero)
	assert_false(bool(result.get("ok", false)), "碎片不足拒绝")
	assert_false(hero.awake, "awake 未变")
	assert_eq(pd.hero_manager.fragment_count(124), 30, "不扣碎片")


func test_awake_hero_rejects_not_awakeable() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(2)   # tid=2 DR Can Awake=false
	pd.hero_manager.add_fragment(AwakeHelper.fragment_id_for_hero(cm, 2), 100)
	var hero: HeroInstance = pd.hero_manager.find_hero_by_tid(2)
	var result: Dictionary = AwakeHelper.awake_hero(pd, hero)
	assert_false(bool(result.get("ok", false)), "Can Awake=false 拒绝")
	assert_false(hero.awake, "awake 未变")


# ---- 边界：null 安全 ----

func test_awake_hero_rejects_null_player() -> void:
	var hero := HeroInstance.new(1, 1, 1)
	var result: Dictionary = AwakeHelper.awake_hero(null, hero)
	assert_false(bool(result.get("ok", false)), "player=null 拒绝")


func test_awake_hero_rejects_null_hero() -> void:
	var pd := PlayerData.new(cm)
	var result: Dictionary = AwakeHelper.awake_hero(pd, null)
	assert_false(bool(result.get("ok", false)), "hero=null 拒绝")
