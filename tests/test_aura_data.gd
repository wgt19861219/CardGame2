extends GutTest
# AuraData 光环数据（Step 1.1 阶段3 通用机制）：buff + radius + target_camp 构造。
# 照源：owner 周围 radius 内的 target_camp 单位受 buff 影响（友军增益/敌军减益）。


# 源 _init：存 buff + radius + target_camp（自定义值）
func test_init_stores_fields() -> void:
	var a := AuraData.new(null, 120.0, AuraData.TargetCamp.ENEMY)
	assert_eq(a.buff, null, "buff 引用（null 占位）")
	assert_eq(a.radius, 120.0, "radius=120")
	assert_eq(a.target_camp, AuraData.TargetCamp.ENEMY, "target_camp=ENEMY")


# 源 _init 默认值（无参）：buff=null / radius=0 / camp=ALLY
func test_init_defaults() -> void:
	var a := AuraData.new()
	assert_eq(a.buff, null, "默认 buff=null")
	assert_eq(a.radius, 0.0, "默认 radius=0")
	assert_eq(a.target_camp, AuraData.TargetCamp.ALLY, "默认 camp=ALLY")


# TargetCamp 枚举值（ALLY/ENEMY 可区分）
func test_target_camp_enum_distinct() -> void:
	assert_ne(AuraData.TargetCamp.ALLY, AuraData.TargetCamp.ENEMY, "ALLY ≠ ENEMY")
