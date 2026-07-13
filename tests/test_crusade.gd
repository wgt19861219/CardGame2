extends GutTest
# Step 3.5 远征单测：15层推进 + HP/MP跨战斗 + 分组reset + 领奖。

func test_fight_win_advances_and_saves_hp() -> void:
	var c := CrusadeManager.new()
	var hp: Dictionary = {1: 0.5, 2: 0.8}
	var mp: Dictionary = {1: 0.3}
	c.fight(true, hp, mp)
	assert_eq(c.cur_stage, 2, "胜推进到层 2")
	assert_eq(c.hero_hp(1), 0.5, "HP 跨战斗保存")

func test_fight_defeat_no_advance() -> void:
	var c := CrusadeManager.new()
	c.fight(false, {1: 0.1}, {})
	assert_eq(c.cur_stage, 1, "败不推进")

func test_reset_clears_to_full_hp() -> void:
	var c := CrusadeManager.new()
	c.fight(true, {1: 0.3}, {})
	c.reset()
	assert_eq(c.cur_stage, 1, "重置回到层 1")
	assert_eq(c.reset_times, 1, "reset_times+1")
	assert_eq(c.hero_hp(1), 1.0, "重置后满血")

func test_reset_clears_progress() -> void:
	var c := CrusadeManager.new()
	c.fight(true, {1: 0.5}, {})
	assert_true(c.is_stage_cleared(1))
	c.reset()
	assert_false(c.is_stage_cleared(1), "重置清进度")

func test_draw_reward_requires_clear() -> void:
	var c := CrusadeManager.new()
	assert_false(c.draw_reward(1), "未通关不可领")
	c.fight(true, {}, {})
	assert_true(c.draw_reward(1), "通关可领")
	assert_false(c.draw_reward(1), "重复不可领")

func test_max_stage_no_overflow() -> void:
	var c := CrusadeManager.new()
	c.cur_stage = 15
	c.fight(true, {}, {})
	assert_eq(c.cur_stage, 15, "15 层通关不再推进")
	assert_true(c.is_stage_cleared(15))

func test_hero_hp_default_full() -> void:
	var c := CrusadeManager.new()
	assert_eq(c.hero_hp(999), 1.0, "未参战英雄默认满血")


# 源 :2620-2621 仅 stageId>=cur_stage 才推进 cur_stage=stageId+1（防重打旧关跳关）。
func test_fight_replay_old_stage_no_advance() -> void:
	var c := CrusadeManager.new()
	c.cur_stage = 3  # 已推进到层 3（层 1/2 已过）
	# 重打旧关 stage=1（<cur_stage=3）：胜利也不推进 cur_stage（源 :2620 stageId>=cur_stage 才推进）
	c.fight(true, {1: 0.5}, {}, 1)
	assert_eq(c.cur_stage, 3, "重打旧关(stage<cur_stage)不推进（源 :2620 防跳关）")
	assert_true(c.is_stage_cleared(1), "旧关胜利仍标 cleared")


func test_fight_high_stage_advances_to_next() -> void:
	var c := CrusadeManager.new()
	c.cur_stage = 2
	# 打高于当前的层 stage=5（>=cur_stage=2）：推进到 stage+1=6（源 :2621 cur_stage=stageId+1）
	c.fight(true, {1: 0.5}, {}, 5)
	assert_eq(c.cur_stage, 6, "stage>cur_stage 推进到 stage+1（源 :2621）")
