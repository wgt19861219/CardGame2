extends GutTest
# Phase 4 battle_scene 核心骨架冒烟（2026-07-02）。
# 验 BattleScene 装配 + step 主循环：syncActors 创建 actor / actor 位置同步 View 坐标 /
#   速度倍率 quantize（>1x 对齐 tick 整数倍）/ terminated 单位 actor 移除。
# 装配复用 test_battle_smoke 模式（真 BattleEngine + BattleUnit tid=1 Coco + ConfigManager + SkillLibrary）。

var cm: ConfigManager
var lib: SkillLibrary


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()
	lib = SkillLibrary.new(cm)


func after_all() -> void:
	UnitSprite.clear_atlas_cache()


func _make_engine() -> BattleEngine:
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(12345)
	return eng


func _make_unit(tid: int, camp: int, eng: BattleEngine, pos: Vector2) -> BattleUnit:
	var u := BattleUnit.new({"_tid": tid, "_level": 1, "_stars": 1}, camp, {"estimate_rank": true}, cm, eng, {}, lib)
	u.position = pos
	u.previous_position = pos
	return u


func test_scene_creates_actors_for_units() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	var e := _make_unit(1, BattleEngine.CAMP_ENEMY, eng, Vector2(300, 0))
	eng.add_unit(p)
	eng.add_unit(e)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene.step(0.033)
	assert_eq(scene.actor_list.size(), 2, "双方各 1 单位 → 2 actor")
	scene.queue_free()


# 多波切换（照源 nextBattle :463-502）：_on_next_wave_requested 清旧敌人 actor + engine.next_battle 切波。
# stage 1 有 3 波（Battle 表 stage1 wave 1/2/3），wave 1→2 切波验证。
func test_next_wave_switches_and_clears_enemy_actors() -> void:
	var eng := _make_engine()
	eng.stage_info = cm.get_raw_table(&"Stage").get("1", {})
	eng.battle_lookup_id = 1
	var p := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_rank": false}, cm, eng, {}, lib)
	eng.add_unit(p)
	var w1: Dictionary = BattleData.from_config(cm, 1, 1).battle_info
	BattleEngineWaves.setup_battle(eng, cm, w1)
	assert_eq(eng.alive_units.get(BattleEngine.CAMP_ENEMY, []).size(), 2, "wave 1 装配 2 敌人")
	var scene := BattleScene.new()
	scene.setup(eng, cm, w1)
	scene._sync_actors()   # 装配 actor（1 玩家 + 2 敌人）
	assert_eq(scene.actor_list.size(), 3, "wave 1 = 3 actor")
	# 触发切波（源 nextBattle scene 侧）
	scene._on_next_wave_requested()
	assert_eq(eng.wave_id, 2, "切到 wave 2（源 :496 engine.next_battle）")
	assert_gte(scene.actor_list.size(), 2, "切波后有玩家+新入场敌人 actor（_enter_new_enemies 预创建）")
	var has_p: bool = false
	for a in scene.actor_list:
		if int(a.model.camp) == BattleEngine.CAMP_PLAYER:
			has_p = true
	assert_true(has_p, "切波后保留玩家 actor")
	assert_gt(eng.alive_units.get(BattleEngine.CAMP_ENEMY, []).size(), 0, "wave 2 装配新敌人（reset_battle 留玩家+setup_battle）")
	scene.queue_free()


# 信号链路：_on_next_pressed emit → _on_next_wave_requested 触发（setup 自接信号）。
func test_next_pressed_emits_next_wave_requested() -> void:
	var eng := _make_engine()
	eng.stage_info = cm.get_raw_table(&"Stage").get("1", {})
	eng.battle_lookup_id = 1
	var p := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_rank": false}, cm, eng, {}, lib)
	eng.add_unit(p)
	BattleEngineWaves.setup_battle(eng, cm, BattleData.from_config(cm, 1, 1).battle_info)
	var scene := BattleScene.new()
	scene.setup(eng, cm, BattleData.from_config(cm, 1, 1).battle_info)
	add_child(scene)   # _on_next_pressed await get_tree() 需 scene 在树
	scene._on_next_pressed()
	# P1-GUT-4：改信号等待（await emit）替代 yield_for(15.0) 固定时长，消除假阳性 + 加速
	await scene.next_wave_requested
	assert_eq(eng.wave_id, 2, "_on_next_pressed 信号链触发切波")
	scene.queue_free()


func test_actor_position_syncs_to_view() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene.step(0.033)
	assert_eq(scene.actor_list.size(), 1, "单单位 → 1 actor")
	var actor: Variant = scene.actor_list[0]
	var expected: Vector2 = BattleViewCoords.to_view_position(float(p.position.x), float(p.position.y), float(p.height))
	# p 无目标不会移动，position 稳定 (100,0) → view to_godot(100,265)=(180,295)
	assert_eq(actor.position, expected, "actor 位置 = to_view_position(model.position)")
	scene.queue_free()


func test_speed_state_quantize() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	var e := _make_unit(1, BattleEngine.CAMP_ENEMY, eng, Vector2(300, 0))
	eng.add_unit(p)
	eng.add_unit(e)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene.set_speed_state(4)
	scene.step(0.033)
	# 源 :767-775 4x quantize：raw=0.033*4=0.132，num_ticks=round(0.132/0.033)=4 → 推进 4 tick
	assert_gt(eng.ticks, 1, "4x 速度应推进多于 1 tick（quantize 对齐 tick 整数倍）")
	scene.queue_free()


func test_terminated_unit_actor_removed() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	var e := _make_unit(1, BattleEngine.CAMP_ENEMY, eng, Vector2(300, 0))
	eng.add_unit(p)
	eng.add_unit(e)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene.step(0.033)
	assert_eq(scene.actor_list.size(), 2, "step 后 2 actor")
	e.terminate()   # BattleEntity.terminate 设 terminated=true（源 actor_list 推进 :794 判据）
	scene.step(0.033)
	assert_eq(scene.actor_list.size(), 1, "terminated 单位的 actor 应被移除")
	scene.queue_free()


# 源 actor update 双缓冲 interp（unit.lua:1736-1758）：tick 变化设 from=previous_position/to=position，
# 帧间 lerp 平滑。验部分 alpha（0.5）→ 中点。
func test_actor_interp_lerps_between_ticks() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene.step(0.033)   # 1 tick → actor 创建 + update_view(alpha=1, to=position)
	var actor: Variant = scene.actor_list[0]
	# 手设 interp state 模拟 tick 切换（from=80/to=100），防 tick 重设
	actor._tick = int(eng.ticks)
	actor._has_interp = true
	actor._interp_from = Vector2(80.0, 0.0)
	actor._interp_to = Vector2(100.0, 0.0)
	actor._interp_alpha = 0.0
	actor.update_view(0.0165)   # 半 tick（0.0165/0.033=0.5）→ lerp(80,100,0.5)=90
	# view = to_view_position(90, 0, 0) = to_godot(90,265) = (170,295)
	assert_almost_eq(actor.position, BattleViewCoords.to_view_position(90.0, 0.0, 0.0), Vector2(0.5, 0.5), "interp alpha≈0.5 → lerp(80,100)≈90 中点")
	scene.queue_free()


# 源 UnitActorCreate:1545-1563 — actor 集成 FloatingBarGroup（HP + Shield 头顶）。
func test_actor_has_floating_bar_group() -> void:
	var eng := _make_engine()
	# 敌方单位保留头顶血条（玩家方头顶不显示，底部面板已有 HP/MP）。
	var e := _make_unit(1, BattleEngine.CAMP_ENEMY, eng, Vector2(300, 0))
	eng.add_unit(e)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene.step(0.033)
	var actor: Variant = scene.actor_list[0]
	assert_not_null(actor.bar_group, "actor 应有 bar_group（源 :1545）")
	assert_not_null(actor.bar_hp, "敌方普通单位应有头顶 HP bar")
	assert_not_null(actor.bar_shield, "应有 Shield bar")
	assert_eq(actor.bar_hp.position, Vector2(0.0, -114.5), "HP bar y=-114.5（头顶，源 Cocos y=114.5 翻转）")
	assert_eq(actor.bar_shield.position, Vector2(0.0, -110.0), "Shield bar y=-110（头顶）")
	assert_almost_eq(actor.bar_hp.scale.x, 0.6667, 0.001, "HP bar scale 0.666（源 :1550）")
	scene.queue_free()


# 玩家方头顶不创建血条（底部英雄面板已有 HP/MP）。
func test_player_actor_no_head_bar() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene.step(0.033)
	var actor: Variant = scene.actor_list[0]
	assert_null(actor.bar_hp, "玩家方头顶不创建 HP bar（底部面板已有）")
	assert_null(actor.bar_shield, "玩家方头顶不创建 Shield bar")
	scene.queue_free()


# 源 reset :159-162 + addBigBloodPanel :541-546 — Boss 单位（hpLayer!=0）装 BigHpBar 入 ui_list。
func test_add_big_blood_panel_for_boss() -> void:
	var eng := _make_engine()
	var boss := _make_unit(1, BattleEngine.CAMP_ENEMY, eng, Vector2(300, 0))
	boss.hp_layer = 3   # 模拟 Boss 多血段
	eng.add_unit(boss)
	var scene := BattleScene.new()
	scene.setup(eng, cm)   # reset_state 内检测 hpLayer!=0 → add_big_blood_panel
	assert_eq(scene.ui_list.size(), 1, "Boss hpLayer=3 → BigHpBar 入 ui_list")
	var panel: Variant = scene.ui_list[0]
	assert_not_null(panel, "BigHpBar 实例应就位")
	assert_eq(panel.position, Vector2(375.0, 40.0), "Boss 血条固定 HUD 原生坐标(455,120)（原 to_godot(375,440)）")
	scene.queue_free()


# 源 getRuntimeScale（unit.lua:1475-1478）— manually_casting → runtime scale 1.35。
func test_actor_runtime_scale_manually_casting() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	p.manually_casting = true   # 施法中
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene.step(0.033)
	var actor: Variant = scene.actor_list[0]
	assert_almost_eq(actor.scale.y, 1.35, 0.01, "manually_casting → runtime scale 1.35（源 :1477）")
	scene.queue_free()


# 源 setActionSpeeder（unit.lua:1746）— frozen → 动画速率 0。
# step 内 engine.update 会 rebuild buff_effects 擦手设 frozen，故 step 后重设 + 强制 tick 块触发验逻辑。
func test_actor_frozen_zero_action_speeder() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene.step(0.033)
	var actor: Variant = scene.actor_list[0]
	p.buff_effects[BattleEffectKeys.FROZEN] = true   # step 后设（避 rebuild 擦）
	actor._tick = -1   # 强制下个 update_view 触发 tick 块（源 :1746 在 tick 变化块内）
	actor.update_view(0.0)
	assert_eq(actor.puppet._current_speed, 0.0, "frozen → setActionSpeeder(0)（源 :1746）")
	scene.queue_free()


# 源 launch（:1868-1870）+ knockup 弧线（:1770-1778）— launch 设 zSpeed，update_view 算 height 弧线。
func test_actor_knockup_arc() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene.step(0.033)
	var actor: Variant = scene.actor_list[0]
	actor.launch(0.5)   # zSpeed = 0.5 * -GRAVITY * 0.5 = 0.5*1800*0.5 = 450
	assert_almost_eq(float(actor._z_speed), 450.0, 1.0, "launch(0.5) → zSpeed=450（源 :1869）")
	actor.update_view(0.016)   # 弧线推进：_height += 450*0.016 ≈ 7.2
	assert_gt(actor._height, 0.0, "击飞后 height 上升（源 :1772）")
	scene.queue_free()


# 源 knockup（unit.lua:1393-1407）→ actor.launch 链 — BattleUnit.knockup 触发 actor.launch。
func test_unit_knockup_launches_actor() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene.step(0.033)
	var actor: Variant = scene.actor_list[0]
	p.knockup(0.4, Vector2(50.0, 0.0))   # 源 knockup → LAUNCH 事件 → actor.launch(0.4)
	BattleEventRenderer.render(eng, {p: actor})   # T4：drain 分发（生产为 scene.step 内同帧，映射在 scene）
	assert_almost_eq(float(actor._z_speed), 360.0, 1.0, "knockup(0.4) → actor.launch → zSpeed=0.4*1800*0.5=360")
	scene.queue_free()


# 源 getRuntimeScale scaleAction 分支（unit.lua:1464-1474）— startScalingAction → 渐进缩放。
func test_actor_scale_action_grow() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene.step(0.033)
	var actor: Variant = scene.actor_list[0]
	p.start_scaling_action(1.2, 1.0)   # 放大 1.2，1s（源 Boss 大招）
	actor._tick = -1   # 强制 tick 块触发 _get_runtime_scale
	actor.update_view(0.0)
	# scaleActionRunningTime += dt_action；渐进 scale = t/dur*(1.2-1)+1 ∈ [1.0, 1.2]
	assert_between(actor.scale.y, 0.99, 1.21, "scaleAction 渐进 scale ∈ [1.0, 1.2]")
	scene.queue_free()


# 源 speedBtnHandler（:1047-1061）— 点击循环 1→2→3→4→1 + updateSpeedBtnLabel 切贴图/label。
func test_speed_button_cycles_states() -> void:
	var btn := BattleSpeedButton.new()
	btn.setup(1)
	assert_eq(btn.get_state(), 1, "初始档 1")
	btn._on_pressed()   # 模拟点击（源 speedBtnHandler）
	assert_eq(btn.get_state(), 2, "点击 → 档 2")
	btn._on_pressed()
	assert_eq(btn.get_state(), 3, "→ 档 3")
	btn._on_pressed()
	assert_eq(btn.get_state(), 4, "→ 档 4")
	btn._on_pressed()
	assert_eq(btn.get_state(), 1, "档 4 → 1 循环（源 :1048）")
	btn.queue_free()


# 源 resetUI（:1235-1250）+ speedBtnHandler（:1052-1053）— scene 装配 speedBtn + 点击接 set_speed_state。
func test_scene_speed_button_sets_state() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	assert_not_null(scene.speed_btn, "scene 装配 speed_btn（源 resetUI）")
	scene.speed_btn._on_pressed()   # 1→2
	assert_eq(scene.speed_state, 2, "speed_changed → set_speed_state(2)")
	scene.queue_free()


# 源 returnBtnTapHandler（:395-398）+ createPauseLayer（:206-330）— 点暂停按钮 → 暂停层 + is_paused。
func test_pause_button_creates_layer() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	add_child(scene)   # BattlePauseLayer 进场 tween 需节点在树
	scene._on_return_pressed()   # 模拟点击 return_btn（源 returnBtnTapHandler）
	assert_eq(scene.is_paused, true, "createPauseLayer → is_paused=true（源 :210）")
	assert_not_null(scene.pause_layer, "暂停层创建（源 :219）")
	scene.queue_free()


# 源 resume handler（:296-313）— resume 按钮恢复战斗 + 清暂停层。
func test_pause_resume_clears_layer() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	add_child(scene)
	scene._on_return_pressed()
	scene._on_pause_dismissed()   # 模拟 resume 按钮信号（exit/resume 合一回调，源 resume handler）
	assert_eq(scene.is_paused, false, "resume → is_paused=false（源 :303）")
	assert_null(scene.pause_layer, "resume → 暂停层清除")
	scene.queue_free()


# ===== P1-17：pause_locks 多 reason 字典（源 pauseBattle/resumeBattle :168-175 + any 检查 :777-780）=====

# 源 pauseBattle :168-170 + any :777-780：pause_locks[reason]=true，任一 true → 暂停。
func test_pause_locks_any_check() -> void:
	var scene := BattleScene.new()
	scene.pause_locks["story"] = true
	assert_eq(bool(scene.pause_locks["story"]), true, "pause 设 pause_locks[reason]=true")
	assert_eq(scene.pause_locks.values().has(true), true, "任一锁 true → has(true)（源 :777-780 any）")


# 源 :174 resumeBattle 设 false 非 erase（保留 key，下次 pause 再设 true）。
func test_resume_sets_false_not_erase() -> void:
	var scene := BattleScene.new()
	scene.pause_locks["story"] = true
	scene.pause_locks["story"] = false
	assert_true(scene.pause_locks.has("story"), "resume 设 false 非 erase（保留 key）")
	assert_eq(bool(scene.pause_locks["story"]), false, "resume → pause_locks[reason]=false")
	assert_eq(scene.pause_locks.values().has(true), false, "全解锁 → has(true)=false")


# 源多 reason 互不干扰：pauseButton + story 都锁，解 pauseButton 不影响 story（any 仍 true）。
func test_multi_reason_independent() -> void:
	var scene := BattleScene.new()
	scene.pause_locks["pauseButton"] = true
	scene.pause_locks["story"] = true
	assert_eq(scene.pause_locks.values().has(true), true, "两锁 → has(true)=true")
	scene.pause_locks["pauseButton"] = false
	assert_eq(bool(scene.pause_locks["pauseButton"]), false, "pauseButton 解锁设 false")
	assert_eq(scene.pause_locks.values().has(true), true, "story 仍锁 → has(true) 仍 true（多 reason 互不干扰）")
	scene.pause_locks["story"] = false
	assert_eq(scene.pause_locks.values().has(true), false, "全解 → has(true)=false")


# 源 updateTimer（:1406-1427）— scene 装配 timer + step → text 显 ceil(time_limit) 的 mm:ss。
func test_timer_displays_time_limit() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	var e := _make_unit(1, BattleEngine.CAMP_ENEMY, eng, Vector2(300, 0))
	eng.add_unit(p)
	eng.add_unit(e)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene.step(0.033)
	assert_not_null(scene.timer, "scene 装配 timer（源 :1349）")
	# time_limit 默认 90，1 tick 后 ≈89.97 → ceil=90 → "01:30"
	assert_eq(scene.timer._text.text, "01:30", "timer 显 ceil(time_limit)=01:30（源 :1414）")
	scene.queue_free()


# 源 :1416-1418 — time_limit<20 → mask 显 + 红色预警。
func test_timer_warn_under_20s() -> void:
	var eng := _make_engine()
	eng.time_limit = 15.0   # <20 触发红闪
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	var e := _make_unit(1, BattleEngine.CAMP_ENEMY, eng, Vector2(300, 0))
	eng.add_unit(p)
	eng.add_unit(e)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene.step(0.033)
	assert_eq(scene.timer._mask.visible, true, "time_limit<20 → mask 显红闪（源 :1417）")
	scene.queue_free()


# 源 resetUI（:1198-1206）+ showNextButton（:1392-1404）— nextBtn 初始不可见，show 后可见。
func test_next_button_show_hide() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	add_child(scene)   # show_button 摆动 tween 需在树
	assert_eq(scene.next_btn.is_button_visible(), false, "next_btn 初始不可见（源 :1203）")
	scene.show_next_button()
	assert_eq(scene.next_btn.is_button_visible(), true, "show_next_button → 可见（源 :1398）")
	scene.queue_free()


# 源 nextBtnTapHandler（:408-444）— next_btn pressed → battle_supply + next_wave_requested + hide。
func test_next_button_pressed_emits() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	add_child(scene)
	scene.show_next_button()
	var emitted: Array = [false]
	scene.next_wave_requested.connect(func() -> void: emitted[0] = true)
	scene.next_btn._on_pressed()   # 模拟点击 → _on_next_pressed async 走路 maxtime 后 emit
	# P1-GUT-4：改信号等待替代 yield_for(15.0)，消除时序假阳性 + CI 加速
	await scene.next_wave_requested
	assert_eq(emitted[0], true, "next_btn pressed → next_wave_requested 信号")
	assert_eq(scene.next_btn.is_button_visible(), false, "pressed → hide（源 :416-417）")
	scene.queue_free()


# 源 addGold :998 formatNumWithComma — gold marker 显千分位。
func test_resource_marker_gold_formats_comma() -> void:
	var m := BattleResourceMarker.new()
	m.setup(BattleResourceMarker.Kind.GOLD, Vector2.ZERO)
	m.set_value(1234)
	assert_eq(m._text.text, "1,234", "gold set_value 千分位（源 formatNumWithComma）")
	m.queue_free()


func test_resource_marker_loot_plain_value() -> void:
	var m := BattleResourceMarker.new()
	m.setup(BattleResourceMarker.Kind.LOOT, Vector2.ZERO)
	m.set_value(5)
	assert_eq(m._text.text, "5", "loot set_value 原值（源 :966 str value）")
	m.queue_free()


# 源 resetUI :1289-1339 — battle_info 非空装 wave_mark + goldmarker + lootmarker。
func test_scene_markers_with_battle_info() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm, {"Wave ID": 2})
	add_child(scene)
	assert_not_null(scene.wave_mark, "battle_info 非空 → 装 wave_mark（源 :1292）")
	assert_not_null(scene.gold_marker, "装 gold_marker（源 :1310）")
	assert_not_null(scene.loot_marker, "装 loot_marker（源 :1326）")
	scene.queue_free()


# 向后兼容：不传 battle_info → 不装 marker（现有测试不受影响）。
func test_scene_no_markers_without_battle_info() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)   # 不传 battle_info
	assert_null(scene.wave_mark, "无 battle_info → 不装 wave_mark")
	assert_null(scene.gold_marker, "不装 gold_marker")
	assert_null(scene.loot_marker, "不装 loot_marker")
	scene.queue_free()


# 源 resetUI :1296 createNumbers(wave_mark, wave_id.."/3") → Label "2/3"。
func test_wave_mark_shows_wave_id() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm, {"Wave ID": 2})
	add_child(scene)
	var lbl: Label = scene.wave_mark.get_child(0)
	assert_eq(lbl.text, "2/3", "wave_mark 显 'WaveID/3'（源 :1296）")
	scene.queue_free()


# 源 addGold :990-1014 — engine.gold_count 累加 + marker 同步。
func test_add_gold_accumulates() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm, {"Wave ID": 1})
	add_child(scene)
	scene.add_gold(100)
	scene.add_gold(50)
	assert_eq(eng.gold_count, 150, "add_gold 累加 engine.gold_count（源 :993）")
	assert_eq(scene.gold_marker.get_value(), 150, "marker 显累加值")
	scene.queue_free()


# 源 addLootMarker :957-988 — engine.loot_count 累加。
func test_add_loot_marker_accumulates() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm, {"Wave ID": 1})
	add_child(scene)
	scene.add_loot_marker(3)
	assert_eq(eng.loot_count, 3, "add_loot_marker 累加 engine.loot_count（源 :961）")
	scene.queue_free()


# 源 loot.lua flyToMarkerAndCleanup 末尾 ed.scene:addLootMarker(1) — loot_view 拾取接通 scene。
func test_loot_view_fly_calls_add_loot_marker() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm, {"Wave ID": 1})
	add_child(scene)
	var monster := _make_unit(1, BattleEngine.CAMP_ENEMY, eng, Vector2(300, 0))
	var loot: BattleLootView = BattleLootView.create(null, "gold", monster, 1, 100, scene.ui_layer)
	loot.set_scene(scene)
	loot.on_tapped()   # fly tween 0.3s 末尾 scene.add_loot_marker(1)
	await loot.flew_to_marker   # P2-GUT-2：信号等待替代 yield_for 固定时长
	assert_eq(eng.loot_count, 1, "loot 拾取 → scene.add_loot_marker(1)（源 loot.lua fly 末尾）")
	scene.queue_free()


# 源 autoCombatHandler :1021 — auto_btn toggle on/off。
func test_auto_button_toggle() -> void:
	var btn := BattleAutoButton.new()
	btn.setup(false, true)
	assert_eq(btn.is_on(), false, "初始 off")
	btn._on_pressed()
	assert_eq(btn.is_on(), true, "pressed → on（源 :1021 toggle）")
	btn._on_pressed()
	assert_eq(btn.is_on(), false, "再 pressed → off")
	btn.queue_free()


# 源 auto_btn pressed → scene.auto_combat。
func test_scene_auto_button_toggles_combat() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	assert_eq(scene.auto_combat, false, "初始 auto_combat=false（单机化默认，源 :118 localMode）")
	assert_not_null(scene.auto_btn, "scene 装配 auto_btn（源 resetUI :1252）")
	scene.auto_btn._on_pressed()
	assert_eq(scene.auto_combat, true, "auto_btn pressed → auto_combat=true（源 :1021）")
	scene.queue_free()


# 源 :1224-1226 pve stars<3 → auto_btn 隐藏（单机默认隐藏）。
func test_scene_auto_button_default_hidden() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	assert_eq(scene.auto_btn.visible, false, "pve stars<3 → auto_btn 默认隐藏（源 :1225）")
	scene.queue_free()


# 源 startCameraShakeAnimationY :1440 — scene 加 Camera2D + start 创建震动 tween。
func test_camera_shake_y_creates_tween() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	add_child(scene)
	assert_not_null(scene._camera, "scene 装配 Camera2D（源 CCDirector 相机）")
	scene.start_camera_shake_animation_y(10.0, 0.3, 6)   # 源 startCameraShakeAnimationY
	assert_not_null(scene._shake_tween_y, "start → 创建震动 tween（源 :1440）")
	scene.queue_free()


# 源 stopCameraShakeAnimationX :1461 — stop 清 tween + 还原 offset。
func test_camera_shake_stop_restores() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	add_child(scene)
	scene.start_camera_shake_animation_x(10.0, 0.3, 6)
	scene.stop_camera_shake_animation_x()
	assert_null(scene._shake_tween_x, "stop → tween 清除（源 :1462）")
	assert_eq(scene._camera.offset.x, 0.0, "stop → offset.x 还原 0")
	scene.queue_free()


# 源 gotoNextBattle（unit.lua:1873-1890）：puppet Move + velocity + scale(1,1) + offline + 清 interp。
func test_actor_goto_next_battle_state() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100.0, 0.0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene.step(0.033)
	var actor: Variant = scene.actor_list[0]
	actor.goto_next_battle(200.0)   # Walk Speed = 200
	assert_eq(actor._offline, true, "goto_next_battle → offline=true（源 :1885）")
	assert_eq(actor.scale, Vector2.ONE, "scale(1,1) 朝右走去翻转（源 :1883-1884）")
	assert_eq(actor._has_interp, false, "清 interp（源 :1887-1889）")
	assert_almost_eq(float(actor._velocity.x), 200.0 * 1.75, 1.0, "velocity.x = WalkSpeed×1.75（源 :1880）")
	assert_eq(actor._velocity.y, 0.0, "velocity.y = 0（源 :1881）")
	scene.queue_free()


# 源 update :1759-1764 interp nil（offline）→ velocity 移动（pos += v*dt）。
func test_actor_offline_velocity_moves_position() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100.0, 0.0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene.step(0.033)
	var actor: Variant = scene.actor_list[0]
	actor.goto_next_battle(200.0)   # velocity.x = 350
	var x_before: float = actor.position.x
	actor.update_view(0.1)   # 0.1s → position.x += 350*0.1 = 35（Logic→View x 正交）
	assert_gt(actor.position.x, x_before, "offline velocity 移动 position.x 增加（源 :1762）")
	scene.queue_free()


# 源 nextBtnTapHandler :418-428：_start_player_walk_to_next_battle 算 maxtime（玩家 actor 走到出屏目标）。
func test_start_player_walk_maxtime() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100.0, 0.0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene.step(0.033)
	p.info["Walk Speed"] = 200.0
	var maxtime: float = scene._start_player_walk_to_next_battle()
	# 目标 = WAVE_WALK_OFFSCREEN_X(1050)，distance = 1050-100 = 950, walk_speed = 200*1.75 = 350
	# maxtime = 950/350 ≈ 2.714（出屏目标，view 1130 出屏 170px 角色完全藏住）
	assert_almost_eq(maxtime, 950.0 / 350.0, 0.01, "maxtime = distance/(WalkSpeed×1.75)（出屏目标 :424）")
	var actor: Variant = scene.actor_list[0]
	assert_eq(actor._offline, true, "_start_player_walk 触发 actor.goto_next_battle（源 :421）")
	scene.queue_free()


# 源 reset :101-111 — battle_info["Background Pic"] → 背景图。Godot 侧挂独立 CanvasLayer
# （layer=-1，TextureRect full_rect + KEEP_ASPECT_COVERED），不受 Camera2D 偏移且不遮挡 actor。
func test_create_background_from_battle_info() -> void:
	var eng := _make_engine()
	eng.stage_info = cm.get_raw_table(&"Stage").get("1", {})
	eng.battle_lookup_id = 1
	var p := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_rank": false}, cm, eng, {}, lib)
	eng.add_unit(p)
	var w1: Dictionary = BattleData.from_config(cm, 1, 1).battle_info
	var scene := BattleScene.new()
	scene.setup(eng, cm, w1)
	add_child(scene)
	var bg_pic: String = String(w1.get("Background Pic", ""))
	if bg_pic.is_empty():
		gut.p("Battle 表 stage1 wave1 无 Background Pic 字段，跳过")
	else:
		var bg_layer: CanvasLayer = scene.get_node_or_null("BackgroundLayer") as CanvasLayer
		assert_not_null(bg_layer, "背景独立 CanvasLayer（layer=-1，渲染在 actor 之下）")
		if bg_layer != null:
			assert_eq(bg_layer.layer, -1, "CanvasLayer layer=-1（在世界画布之下）")
			var bg: TextureRect = bg_layer.get_child(0) as TextureRect
			assert_not_null(bg, "背景 TextureRect（源 :104 createSprite）")
			if bg != null:
				assert_not_null(bg.texture, "背景 texture 加载")
				assert_eq(bg.anchors_preset, Control.PRESET_FULL_RECT, "全屏 anchor")
				assert_eq(bg.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED, "cover 模式铺满")
	scene.queue_free()



# 入场走路状态机：_start_enter_walk 冻结 engine（is_paused）+ _entering=true；全部就位后解冻。
func test_enter_walk_freezes_then_unfreezes_engine() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	var e := _make_unit(1, BattleEngine.CAMP_ENEMY, eng, Vector2(300, 0))
	eng.add_unit(p)
	eng.add_unit(e)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	add_child(scene)
	scene._start_enter_walk()   # 测试默认关入场，手动触发
	assert_true(scene.is_paused, "入场期间 engine 冻结（is_paused=true）")
	assert_true(scene._entering, "_entering=true")
	assert_eq(scene._pending_enter_count, 2, "2 个单位待入场")
	# 模拟全部就位
	scene._actors_by_unit[p].enter_walk_finished.emit()
	assert_true(scene._entering, "1 个就位，仍入场中")
	scene._actors_by_unit[e].enter_walk_finished.emit()
	assert_false(scene._entering, "全部就位，_entering=false")
	assert_false(scene.is_paused, "全部就位，engine 解冻")
	scene.queue_free()


# start_enter_walk：actor 起步在场外（offset）、_offline=true、velocity 朝向 target。
func test_start_enter_walk_sets_offline_and_velocity() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	add_child(scene)
	scene._start_enter_walk()   # 测试默认关入场，手动触发
	var actor: BattleActor = scene._actors_by_unit.get(p) as BattleActor
	assert_not_null(actor, "玩家 actor 已预创建（T4-B7：查 scene 映射）")
	# 玩家 offset=-300 → 起步 x=100-300=-200（场外左），velocity +x 朝 target。
	assert_lt(float(actor._walk_pos.x), 100.0, "玩家起步在场外（x<站位）")
	assert_true(actor._offline, "_offline=true（离线自驱）")
	assert_gt(float(actor._velocity.x), 0.0, "玩家 velocity +x（走向右）")
	# 敌方 offset=+300 → velocity -x
	var e := _make_unit(2, BattleEngine.CAMP_ENEMY, eng, Vector2(500, 0))
	eng.add_unit(e)
	var e_actor := BattleActor.new()
	e_actor.setup(e, cm)
	e_actor.start_enter_walk(Vector2(500, 0), 300.0)
	assert_lt(float(e_actor._velocity.x), 0.0, "敌方 velocity -x（走向左）")
	assert_gt(float(e_actor._walk_pos.x), 500.0, "敌方起步在场外（x>站位）")
	e_actor.queue_free()
	scene.queue_free()


# .abc 单位（Treant，Unit 101）ZIP 直读：无预解压目录，从 Treant.abc 加载 FCA 成功。
func test_abc_unit_loads_fca_from_zip() -> void:
	var eng := _make_engine()
	var u := BattleUnit.new({"_tid": 101, "_level": 1, "_stars": 1}, BattleEngine.CAMP_ENEMY, {"estimate_rank": false}, cm, eng, {}, lib)
	eng.add_unit(u)
	assert_eq(String(u.info.get("Puppet", "")), "Treant.cha", "Unit 101 Puppet=Treant.cha")
	assert_false(FileAccess.file_exists("res://assets/anim_frames/Treant/sheet.plist"), "Treant 无预解压目录（.abc 单位）")
	assert_true(FileAccess.file_exists("res://assets/anim_frames/Treant.abc"), "Treant.abc zip 存在")
	var sprite := UnitSprite.new()
	sprite.setup(u, cm)
	assert_true(sprite._using_fca, "Treant(.abc) ZIP 直读 FCA 成功（非降级头像）")
	sprite.queue_free()


# 2026-08-18 用户复验收官验收实跑反馈：点速度按钮报
# Invalid access 'puppet' on ProjectileActor——actor_list 混装（BattleActor/NpcActor 有 puppet，
# ProjectileActor 无此键），skill_lib 修复后技能投射物首次真实出现踩中。
func test_speed_changed_with_projectile_actor_mixed() -> void:
	var scene := BattleScene.new()
	add_child_autofree(scene)
	# 模拟 ProjectileSync 混装：裸 Node2D（无 puppet 键）+ 带 puppet 的单位 actor
	var fake_projectile := Node2D.new()
	scene.actor_list.append(fake_projectile)
	var eng := _make_engine()
	var u := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	var actor := BattleActor.new()
	actor.setup(u, cm)
	scene.actor_list.append(actor)
	scene._on_speed_changed(2)   # 修复前：对 Node2D 点 .puppet 即崩
	assert_eq(scene.speed_state, 2, "速度档已切换")
	fake_projectile.queue_free()


# 2026-08-28 战斗域批次几何守卫：HUD 源直译坐标防回退（越屏/偏位根修）。
# 计时器：源 battle_scene.lua:1341-1387 bg Scale9 106×44 anchor(0,0.5)@(610,440)→
# Godot 显示区 (610,18)-(716,62)；hourglass MenuItemImage 原尺寸 40×80 中心 (677,437)→(697,43)。
# 加速钮：源 :1236-1241 MenuItemImage 原尺寸 105×60 中心 (735,120)→Godot 左上 (682.5,330)。
# 暂停钮：源 :1189-1191 createButtonWithMask（createSprite÷CS）中心 (757,440)→
# 左上 (729.7,13.1)+scale 1/1.28125。
func test_hud_geometry_source_translated() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	var e := _make_unit(1, BattleEngine.CAMP_ENEMY, eng, Vector2(300, 0))
	eng.add_unit(p)
	eng.add_unit(e)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene.step(0.033)
	# 计时器 bg：显示 106×44 at (610,18)（Sprite2D centered (663,40)+scale）
	var t: BattleTimer = scene.timer
	var bg := t.get_node("BattleTimerContent/Bg") as Sprite2D
	assert_almost_eq(bg.position.x, 663.0, 0.5, "timer bg 中心 x=663（显示区 610-716 源直译）")
	assert_almost_eq(bg.position.y, 40.0, 0.5, "timer bg 中心 y=40（显示区 18-62 源直译）")
	var bg_w: float = bg.texture.get_width() * bg.scale.x
	assert_almost_eq(bg_w, 106.0, 0.5, "timer bg 显示宽 106（源 Scale9 setContentSize）")
	var hg := t.get_node("BattleTimerContent/Hourglass") as Sprite2D
	assert_almost_eq(hg.position.x, 697.0, 0.5, "hourglass 中心 x=697（源 677+半宽 20）")
	assert_almost_eq(hg.scale.x, 1.0, 0.01, "hourglass 原尺寸显示（MenuItemImage 不÷CS）")
	# 加速钮：中心 (735,360) 原尺寸 105×60 → 左上 (682.5,330)
	assert_almost_eq(scene.speed_btn.position.x, 682.5, 0.5, "speed btn 左上 x=682.5（中心 735−105/2）")
	assert_almost_eq(scene.speed_btn.position.y, 330.0, 0.5, "speed btn 左上 y=330（中心 360−60/2）")
	# 暂停钮：÷CS 54.6×53.9 中心 (757,40) → 左上 (729.7,13.1)
	assert_almost_eq(scene.return_btn.position.x, 729.7, 0.1, "return btn 左上 x=729.7（÷CS 源直译）")
	assert_almost_eq(scene.return_btn.position.y, 13.1, 0.1, "return btn 左上 y=13.1")
	assert_almost_eq(scene.return_btn.scale.x, 1.0 / 1.28125, 0.001, "return btn scale=1/CS（createButtonWithMask÷CS）")
	scene.queue_free()
