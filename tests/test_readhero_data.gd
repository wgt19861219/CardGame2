extends GutTest
# Phase 5.1 readhero_data 数据查询测试（2026-07-02）。
# 验 ReadheroData：get_hero_init_stars（Unit 表 Initial Stars）/ get_growth（+STR/+AGI/+INT+star）。
# tid=1 Coco：+STR1=3.3 / +AGI1=1.3 / +INT1=2.2 / Initial Stars=1。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 源 :44-48 — Unit 表 "Initial Stars"。
func test_get_hero_init_stars() -> void:
	assert_eq(ReadheroData.get_hero_init_stars(1, cm), 1, "tid=1 Coco Initial Stars=1")


# 源 :116-143 — Unit 表 "+STR"+star 等 growth 字段。
func test_get_growth() -> void:
	var g: Dictionary = ReadheroData.get_growth(1, 1, cm)
	assert_almost_eq(float(g["STR"]), 3.3, 0.01, "tid=1 star=1 +STR1=3.3（源 :140）")
	assert_almost_eq(float(g["AGI"]), 1.3, 0.01, "+AGI1=1.3")
	assert_almost_eq(float(g["INT"]), 2.2, 0.01, "+INT1=2.2")


# 源 :129-131 star<=0 → 空。
func test_get_growth_star_zero() -> void:
	var g: Dictionary = ReadheroData.get_growth(1, 0, cm)
	assert_eq(g.size(), 0, "star<=0 → 空 growth（源 :129）")
