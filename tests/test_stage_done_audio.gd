extends GutTest
# 结算音补全（设计 2.4）：第 i 颗星播 one/two/three（源 stagedonelsr.lua:46/50）；
# 掉落弹出 per-item 播 pop_loot（源 soundres.lua:167 pushItem 语义，三-·m-3）。

const AnimatorScript = preload("res://scripts/view/battle/stage_done_animator.gd")


func test_star_sfx_keys_mapping() -> void:
	var keys: Array = AnimatorScript.STAR_SFX_KEYS
	assert_eq(keys.size(), 3, "三档星级音")
	assert_eq(keys[0], "battledown_star_one", "第 0 颗")
	assert_eq(keys[1], "battledown_star_two", "第 1 颗")
	assert_eq(keys[2], "battledown_star_three", "第 2 颗")
	for k in keys:
		assert_true(ResourceLoader.exists("res://assets/sound_menu/" + k + ".mp3"),
			"星级音文件存在: %s" % k)


func test_settlement_keys_registered() -> void:
	var am := AudioManager.new()
	SoundRes.register_all(am)
	assert_true(am.has_sfx(&"battledown_pop_loot"), "pop_loot 已注册")
	assert_true(am.has_sfx(&"common_exp_up"), "exp_up 已注册（Task 1）")


func test_animator_wires_star_and_loot_sfx() -> void:
	# 守卫断言（grep 先例）：星级 bind(i) 每颗星播 + 掉落 per-item 播。
	var src := FileAccess.get_file_as_string("res://scripts/view/battle/stage_done_animator.gd")
	assert_true(src.contains("tween_callback(_play_sfx_star.bind(i))"), "每颗星 bind i 播对应音")
	assert_false(src.contains("_play_sfx_star_one"), "旧 star_one 专用函数已删")
	assert_true(src.contains("tween_callback(_play_sfx_pop_loot)"), "掉落弹出播 pop_loot")
