extends GutTest
# Step 4.1 UI 框架单测：SceneManager 锁/排队 + Toast 队列。
# SceneManager.change_scene() 同步返回 bool（异步解锁内化），测试直接断言返回值，无需 await。

const SceneManagerScript = preload("res://scripts/autoload/scene_manager.gd")
const ToastScript = preload("res://scripts/autoload/toast.gd")

func test_scene_manager_locks_during_change() -> void:
	var sm := SceneManagerScript.new()
	assert_true(sm.change_scene("res://scenes/main.tscn"), "首次切换受理")
	assert_true(sm.is_locked(), "切换中应锁住")
	assert_false(sm.change_scene("res://scenes/other.tscn"), "锁住时排队不立即受理")

func test_scene_manager_pending_consumed_on_unlock() -> void:
	var sm := SceneManagerScript.new()
	sm.change_scene("res://a.tscn")
	sm.change_scene("res://b.tscn")  # 排队
	sm.on_scene_loaded()  # 解锁 + 消费排队
	assert_true(sm.is_locked(), "消费排队请求后又锁住")
	assert_eq(sm.current_scene_path(), "res://b.tscn", "当前切到排队的 b")

func test_toast_queue() -> void:
	var toast := ToastScript.new()
	toast.show_message("hello")
	toast.show_message("world")
	assert_eq(toast.pending_count(), 2)
	assert_eq(toast.consume(), "hello")
	assert_eq(toast.consume(), "world")
	assert_eq(toast.consume(), "", "空队列返回空")
