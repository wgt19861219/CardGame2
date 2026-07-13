extends GutTest
# Phase 4 BigHpBar Boss 多血段测试（2026-07-02）。
# 验 bloodBarInfo 段数 + red/purple/blue 循环（i 从 count 递减）/ 满血 bloodIndex=1 /
#   损血跨段 isMinBlood 标记。照源 hp_bar.lua:137-339。
# MockUnit duck-type hp/attribs.HP/hp_layer/boss_icon_name。

class MockUnit:
	extends RefCounted
	var hp: int = 100
	var attribs: Dictionary = {"HP": 100}
	var hp_layer: int = 3
	var boss_icon_name: String = ""


# 源 getBloodBarRcsAndPercent（:209-228）：hpLayer=3 → 3 段，i 从 3 递减。
# i=3 idx=0 blue（首段/满血段）/ i=2 idx=2 purple / i=1 idx=1 red（末段）。
func test_blood_bar_info_segments() -> void:
	var u := MockUnit.new()
	u.hp_layer = 3
	var bar := BattleBigHpBar.create(u, 600.0)
	add_child(bar)
	assert_eq(bar._blood_bar_info.size(), 3, "hp_layer=3 → 3 段")
	assert_eq(bar._blood_bar_info[0]["name"], "guildraid_hpbar_boss_blue.png", "i=3 idx=0 → blue（首段=满血段）")
	assert_eq(bar._blood_bar_info[1]["name"], "guildraid_hpbar_boss_purple.png", "i=2 idx=2 → purple（中段）")
	assert_eq(bar._blood_bar_info[2]["name"], "guildraid_hpbar_boss_red.png", "i=1 idx=1 → red（末段）")
	assert_almost_eq(float(bar._blood_bar_info[0]["slice"]), 0.3333, 0.01, "slice=1/count=1/3")
	bar.queue_free()


# 源 getBloodBarIndexAndPercent（:229-248）：满血 totalPercent=0 ≤ 第1段 → bloodIndex=1, bloodPercent=1。
func test_full_hp_blood_index_1() -> void:
	var u := MockUnit.new()
	u.hp = 100
	u.hp_layer = 3
	var bar := BattleBigHpBar.create(u, 600.0)
	add_child(bar)
	assert_eq(bar._blood_index, 1, "满血 bloodIndex=1（第1段/满血段）")
	assert_almost_eq(bar._blood_percent, 1.0, 0.01, "满血段内 percent=1")
	bar.queue_free()


# 源 update（:147-160）：损血跨段（bloodIndex 1→2）→ isMinBlood=true, percent=0。
func test_damage_into_next_segment() -> void:
	var u := MockUnit.new()
	u.hp = 100
	u.attribs = {"HP": 100}
	u.hp_layer = 3
	var bar := BattleBigHpBar.create(u, 600.0)
	add_child(bar)
	assert_eq(bar._blood_index, 1, "满血 bloodIndex=1")
	# 损血 40%：hp=60, realBlood=0.6, total=0.4 > 第1段 slice=0.333 → 落第2段（acc=0.667）
	u.hp = 60
	bar.update(0.0)
	assert_true(bar._is_min_blood, "损血进第2段 → isMinBlood=true（源 :151-153）")
	bar.queue_free()


# 源 update（:142-145）：realBloodPercent<=0 → terminated + queue_free。
func test_dead_terminates() -> void:
	var u := MockUnit.new()
	u.hp = 0
	u.attribs = {"HP": 100}
	u.hp_layer = 3
	var bar := BattleBigHpBar.create(u, 600.0)
	add_child(bar)
	bar.update(0.0)
	assert_true(bar.terminated, "hp=0 → terminated=true（源 :144）")
	# queue_free 已调度，不手动 free
