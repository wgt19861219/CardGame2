extends GutTest
# Phase 4 特效接入测试：BattleEffect 包装 FcaAnimation 加载 .abc + play_effect_on_scene/add_effect 真播放。
# 验：.abc 加载成功 / 资源缺失降级不崩 / .cha 后缀剥离 / scene 挂载 / actor 挂载。

const BattleEffect = preload("res://scripts/view/battle/battle_effect.gd")


func test_effect_loads_abc() -> void:
	# eff_launch_spike.abc 是 Lion 地刺特效（hero_lion.gd:27 调用），资源确认存在
	var eff := BattleEffect.create("effect/eff_launch_spike")
	assert_not_null(eff, "eff_launch_spike.abc 加载应成功")
	if eff == null:
		return
	eff.play()
	assert_false(eff.is_terminated(), "播放中不应 terminated")
	eff.get_node().queue_free()


func test_effect_invalid_resource_fallback() -> void:
	var eff := BattleEffect.create("effect/nonexistent_effect_xyz")
	assert_null(eff, "不存在的资源应返回 null（降级由调用方处理）")


func test_effect_cha_suffix_stripped() -> void:
	# 带 .cha 后缀应与无后缀等价（照源 string.gsub 剥除）
	var eff1 := BattleEffect.create("effect/eff_launch_spike")
	var eff2 := BattleEffect.create("effect/eff_launch_spike.cha")
	assert_not_null(eff1, "无后缀加载应成功")
	assert_not_null(eff2, ".cha 后缀应剥离后等价加载")
	if eff1:
		eff1.get_node().queue_free()
	if eff2:
		eff2.get_node().queue_free()


func test_effect_no_prefix_falls_back_to_effect_dir() -> void:
	# 数据表原始值无 effect/ 前缀（如 "eff_tile_AV_atk2.cha"），资源全在 effect/ 子目录。
	# create 应自动回退 effect/ 前缀加载（修投射物/命中特效全降级 bug）。
	var eff := BattleEffect.create("eff_tile_AV_atk2.cha")
	assert_not_null(eff, "无 effect/ 前缀应回退到 effect/ 子目录加载成功")
	if eff:
		eff.get_node().queue_free()


func test_play_effect_on_scene_creates_fca() -> void:
	var scene := BattleScene.new()
	scene.setup(null, null)  # 建 4 层节点（_create_layers + reset_state）
	scene.play_effect_on_scene("effect/eff_launch_spike", Vector2(100, 200), 1.0, 0.0, 1)
	assert_eq(scene.effect_list.size(), 1, "effect_list 应含 1 个特效")
	var eff: Variant = scene.effect_list[0]
	assert_true(eff is BattleEffect, "应为 BattleEffect（非 FallbackEffect）")
	scene.queue_free()


func test_play_effect_on_scene_invalid_falls_back() -> void:
	var scene := BattleScene.new()
	scene.setup(null, null)
	scene.play_effect_on_scene("effect/nonexistent_xyz", Vector2(0, 0), 1.0, 0.0, 1)
	assert_eq(scene.effect_list.size(), 1, "降级也进 effect_list")
	var eff: Variant = scene.effect_list[0]
	assert_false(eff is BattleEffect, "不存在的资源应降级非 BattleEffect")
	scene.queue_free()


func test_add_effect_attaches_to_actor() -> void:
	var actor := BattleActor.new()
	add_child(actor)  # 需入树（降级 create_timer 需要 SceneTree）
	actor.add_effect("effect/eff_launch_spike", 1)
	assert_true(actor.get_child_count() >= 1, "add_effect 应挂载子节点")
	actor.remove_effect("effect/eff_launch_spike")
	actor.queue_free()


func test_add_effect_invalid_falls_back() -> void:
	var actor := BattleActor.new()
	add_child(actor)
	actor.add_effect("effect/nonexistent_xyz", 0)
	assert_true(actor.get_child_count() >= 1, "降级也应挂载占位 Node2D")
	actor.remove_effect("effect/nonexistent_xyz")
	actor.queue_free()


func test_effect_start_to_loop_switch() -> void:
	# eff_buff_Axe_atk2.abc 实测 actions=['Start','Loop']（327 .abc 全量统计：'Start'=304 / 'Loop'=130 / 无 'Play'）。
	# 照源 LegendAnimationEffect：play() 默认 "Start"，Start 播完切 Loop 循环。
	# 原代码默认 "Play" 永走 fallback 首个 action，Loop 循环主体丢失——本测试守护切换。
	var eff := BattleEffect.create("effect/eff_buff_Axe_atk2")
	assert_not_null(eff, "eff_buff_Axe_atk2.abc 加载应成功")
	if eff == null:
		return
	eff.play()  # 默认 action="Start"
	assert_false(eff.is_terminated(), "Start 播放中不应 terminated")
	var fca: Variant = eff.get("_fca")
	assert_true(fca != null and is_instance_valid(fca), "fca 应有效")
	if fca != null and is_instance_valid(fca):
		# fca._next_action=="Loop" = Start→Loop 自动切换就绪（fca_animation.gd:308-311 Start 播完自动切）
		assert_eq(str(fca.get("_next_action")), "Loop", "Start→Loop 切换就绪")
	eff.get_node().queue_free()


func test_effect_single_action_no_loop_terminates() -> void:
	# eff_battle_drop_money.abc 实测 actions=['Start']（无 Loop 配对）：照源 onAnimFinished 无 loop_anim → terminate。
	# play() 默认 "Start"，无 Loop → 不切，loop 参数控制（默认 false 单次播完 terminate）。
	var eff := BattleEffect.create("effect/eff_battle_drop_money")
	assert_not_null(eff, "eff_battle_drop_money.abc 加载应成功")
	if eff == null:
		return
	eff.play()
	assert_false(eff.is_terminated(), "播放中不应 terminated")
	var fca: Variant = eff.get("_fca")
	if fca != null and is_instance_valid(fca):
		# 无 Loop 配对 → _next_action 不应被设为 Loop
		assert_ne(str(fca.get("_next_action")), "Loop", "无 Loop 配对应设 Start→Loop 切换")
	eff.get_node().queue_free()


# ── 战斗加速同步（2026-08-19）：FCA _process 真实 delta 自驱，特效须 set_speed 补偿倍率 ──
# 源 effect:update(dt) 与 actor 同链被加速 dt 集中推进；Godot 版漏补偿 → 2x 下人物动作
# 2x 播而特效 1x 播（技能动画与人物动画不同步根因）。

func test_effect_set_speed_forwards_to_fca() -> void:
	var eff := BattleEffect.create("effect/eff_launch_spike")
	if eff == null:
		fail_test("eff_launch_spike 加载失败，测试环境异常")
		return
	assert_eq(eff.get("_fca").get("_speed"), 1.0, "默认速度 1x")
	eff.set_speed(2.0)
	assert_eq(eff.get("_fca").get("_speed"), 2.0, "set_speed 应转发到 fca._speed")
	eff.get_node().queue_free()


func test_play_effect_on_scene_applies_speed() -> void:
	var scene := BattleScene.new()
	scene.setup(null, null)
	scene.set_speed_state(2)
	assert_eq(scene.current_speed(), 2.0, "current_speed 读接口应返回倍率")
	scene.play_effect_on_scene("effect/eff_launch_spike", Vector2(0, 0), 1.0, 0.0, 0)
	var eff: Variant = scene.effect_list[0]
	assert_true(eff is BattleEffect, "应创建 BattleEffect")
	if eff is BattleEffect:
		assert_eq(eff.get("_fca").get("_speed"), 2.0, "场景特效创建时应带当前倍率")
	scene.queue_free()


func test_speed_change_updates_existing_effects() -> void:
	var scene := BattleScene.new()
	scene.setup(null, null)
	scene.play_effect_on_scene("effect/eff_launch_spike", Vector2(0, 0), 1.0, 0.0, 0)
	scene._on_speed_changed(3)
	var eff: Variant = scene.effect_list[0]
	assert_true(eff is BattleEffect, "真资源应创建 BattleEffect（非降级）")
	if eff is BattleEffect:
		assert_eq(eff.get("_fca").get("_speed"), 3.0, "切速应同步已存在的场景特效")
	scene.queue_free()


func test_add_effect_applies_scene_speed() -> void:
	var scene := BattleScene.new()
	scene.setup(null, null)
	scene.set_speed_state(2)
	var actor := BattleActor.new()
	scene.main_layer.add_child(actor)   # 入 scene 树（add_effect 向上找 current_speed）
	actor.add_effect("effect/eff_launch_spike", 1)
	var eff: Variant = actor.get("_effects").get("effect/eff_launch_spike", null)
	assert_not_null(eff, "add_effect 应登记 _effects")
	if eff != null and eff is BattleEffect:
		assert_eq(eff.get("_fca").get("_speed"), 2.0, "actor buff 特效创建时应带 scene 倍率")
	actor.apply_speed_to_effects(3.0)
	if eff != null and eff is BattleEffect:
		assert_eq(eff.get("_fca").get("_speed"), 3.0, "apply_speed_to_effects 应切速同步")
	actor.remove_effect("effect/eff_launch_spike")
	scene.queue_free()
