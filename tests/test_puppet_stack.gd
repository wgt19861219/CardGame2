extends GutTest
# Phase 4 puppet 栈测试：push_puppet/remove_puppet/use_puppet + switch_puppet 资源加载。
# MockActor 计数 use_puppet 调用 + MockBuff 计数 on_added_client。

class MockActor:
	extends RefCounted
	var use_puppet_count: int = 0
	var switched_resource: String = ""
	var switched_scale: float = 1.0
	var switched_flip: bool = false
	func use_puppet() -> void:
		use_puppet_count += 1
	func switch_puppet(resource: String, p_scale: float, flip_x: bool) -> void:
		switched_resource = resource; switched_scale = p_scale; switched_flip = flip_x
	func on_start_new_action() -> void: pass

class MockBuff:
	extends RefCounted
	var on_added_client_count: int = 0
	func on_added_client() -> void:
		on_added_client_count += 1


func _make_unit() -> BattleUnit:
	var cm := ConfigManager.new()
	cm.load_all()
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(12345)
	var u := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, 0, {"estimate_rank": true}, cm, eng, {}, null)
	return u


func _puppet_events(u: BattleUnit) -> Array:
	return (u.engine as BattleEngine).events.filter(func(e): return e.type == BattleEvent.Type.PUPPET)


func test_push_puppet_changes_stack() -> void:
	var u := _make_unit()
	var initial_size := u.puppet_stack.size()

	u.push_puppet("Duck")
	assert_eq(u.puppet_stack.size(), initial_size + 1, "push 后栈深度+1")
	assert_eq(String(u.puppet_stack[-1]), "Duck", "栈顶应为 Duck")


func test_push_puppet_returns_id() -> void:
	var u := _make_unit()

	var pid: int = u.push_puppet("Duck")
	assert_eq(pid, u.puppet_stack.size(), "返回的 id 应=栈深度")
	assert_true(pid >= 2, "初始栈含 info.Puppet，push 后 id>=2")


func test_remove_puppet_pops_stack() -> void:
	var u := _make_unit()

	var pid: int = u.push_puppet("Duck")
	assert_eq(String(u.puppet_stack[-1]), "Duck", "push 后栈顶 Duck")
	u.remove_puppet(pid)
	assert_eq(String(u.puppet_stack[-1]), String(u.info.get("Puppet", "")), "remove 后恢复原栈顶")


func test_push_puppet_calls_use_puppet() -> void:
	var u := _make_unit()
	assert_eq(_puppet_events(u).size(), 0, "初始 0 条")
	u.push_puppet("Duck")
	assert_eq(_puppet_events(u).size(), 1, "push 应产 1 条 PUPPET 事件（T4 起 use_puppet 走队列）")


func test_remove_puppet_calls_use_puppet() -> void:
	var u := _make_unit()
	var pid: int = u.push_puppet("Duck")
	(u.engine as BattleEngine).drain_events()  # 重置
	u.remove_puppet(pid)
	assert_eq(_puppet_events(u).size(), 1, "remove 应产 1 条 PUPPET 事件")


func test_switch_puppet_loads_ani() -> void:
	# Duck 有 .ani + 目录，应加载成功
	var sprite := UnitSprite.new()
	add_child(sprite)
	var cm := ConfigManager.new()
	cm.load_all()
	# 建一个最小 unit mock
	var unit := { "camp": 0, "info": {"Puppet": "Coco"} }
	sprite.switch_puppet("Duck", 0.6, false)
	# switch_puppet 后 _using_fca 应 true（Duck .ani 可加载）
	assert_true(sprite._using_fca, "Duck .ani 应加载成功（_using_fca=true）")
	sprite.queue_free()


func test_switch_puppet_loads_abc() -> void:
	# Sheep 只有 .abc，应通过 zip 加载
	var sprite := UnitSprite.new()
	add_child(sprite)
	sprite.switch_puppet("Sheep", 0.9, false)
	assert_true(sprite._using_fca, "Sheep .abc 应加载成功（_using_fca=true）")
	sprite.queue_free()


func test_use_puppet_reruns_buff_on_added_client() -> void:
	# BattleActor.use_puppet 应重跑所有 buff 的 on_added_client
	var actor := BattleActor.new()
	add_child(actor)
	var cm := ConfigManager.new()
	cm.load_all()
	# 建 unit + actor
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(12345)
	var u := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, 0, {"estimate_rank": true}, cm, eng, {}, null)
	actor.setup(u, cm)
	# 加 mock buff
	var buff := MockBuff.new()
	u.buff_list.append(buff)
	assert_eq(buff.on_added_client_count, 0, "初始 0 次")
	# push puppet 触发 use_puppet
	u.push_puppet("Duck")
	BattleEventRenderer.render(u.engine as BattleEngine, {u: actor})   # T4：无 scene step，手动 drain 分发
	assert_true(buff.on_added_client_count >= 1, "use_puppet 应重跑 buff on_added_client")
	actor.queue_free()
