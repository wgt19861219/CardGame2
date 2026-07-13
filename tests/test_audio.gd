extends GutTest
# Step 5.1 AudioManager 单测：音效映射 + 治 pcall 吞错（push_error 显式）。

func test_register_and_get_sfx() -> void:
	var a := AudioManager.new()
	a.register_sfx(&"btn_click", "res://assets/sound/btn.mp3")
	assert_eq(a.get_sfx_path(&"btn_click"), "res://assets/sound/btn.mp3")
	assert_true(a.has_sfx(&"btn_click"))

func test_missing_sfx_errors_not_silent() -> void:
	# 治旧版 pcall 静默吞错：未注册音效应 push_error（不静默返回空）
	var a := AudioManager.new()
	assert_eq(a.get_sfx_path(&"nonexistent"), "", "未注册返回空")
	assert_push_error("音效未注册", "未注册音效应 push_error（治 pcall 吞错）")

func test_hero_sfx_mapping() -> void:
	var a := AudioManager.new()
	a.register_hero_sfx(1, &"attack", "res://assets/sound/Coco_atk.mp3")
	assert_eq(a.get_hero_sfx_path(1, &"attack"), "res://assets/sound/Coco_atk.mp3")

func test_hero_sfx_missing_event_errors() -> void:
	var a := AudioManager.new()
	a.register_hero_sfx(1, &"attack", "res://x.mp3")
	# 英雄有音效但事件缺失
	a.get_hero_sfx_path(1, &"death")
	assert_push_error("英雄音效事件缺失", "缺失事件应 push_error")

func test_bgm_path() -> void:
	var a := AudioManager.new()
	a.set_bgm("res://assets/sound/bgm.mp3")
	assert_eq(a.bgm_path, "res://assets/sound/bgm.mp3")
