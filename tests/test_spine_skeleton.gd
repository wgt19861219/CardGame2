extends GutTest
# SpineSkeleton 加载/播放测试（Node2D，需入树 _process）。资源 eff_UI_Main_Shop。

const SPINE_DIR: String = "res://assets/spine/eff_UI_Main_Shop"
const RES_NAME: String = "eff_UI_Main_Shop"


func test_load_skeleton() -> void:
	var sk := SpineSkeleton.new()
	add_child(sk)
	assert_true(sk.load_skeleton(SPINE_DIR, RES_NAME), "load_skeleton 成功")
	assert_true(sk.has_action("Loop"), "has Loop")
	assert_true(sk.has_action("Start"), "has Start")
	assert_false(sk.has_action("Nonexistent"), "无 Nonexistent")
	sk.queue_free()


func test_play_starts_processing() -> void:
	var sk := SpineSkeleton.new()
	add_child(sk)
	sk.load_skeleton(SPINE_DIR, RES_NAME)
	sk.play("Loop", true)
	assert_true(sk.is_playing(), "play Loop 后 is_playing true")
	assert_false(sk.has_action("Nonexistent"), "has_action 守卫")
	sk.queue_free()


func test_play_unknown_action_ignored() -> void:
	var sk := SpineSkeleton.new()
	add_child(sk)
	sk.load_skeleton(SPINE_DIR, RES_NAME)
	sk.play("UnknownAction", true)
	assert_false(sk.is_playing(), "unknown action 不启动 _playing")
	sk.queue_free()
