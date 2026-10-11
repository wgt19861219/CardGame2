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
	scene.set_speed_state(3)
	scene.step(0.033)
	# 源 :767-775 quantize：raw=0.033*3=0.099，num_ticks=round(0.099/0.033)=3 → 推进 3 tick
	assert_gt(eng.ticks, 1, "3x 速度应推进多于 1 tick（quantize 对齐 tick 整数倍）")
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


# 切波投射物回收（2026-09-05 小黑大招箭雨残留）：玩家方投射物飞行中切波，
# _remove_enemy_actors 按 camp==PLAYER 保留其 actor；reset_battle 终结投射物后，
# 切波推进首帧 _advance_actor_list 应销毁投射物 actor（否则永久残留屏幕）。
func test_next_wave_terminates_player_projectile_actors() -> void:
	var eng := _make_engine()
	eng.stage_info = cm.get_raw_table(&"Stage").get("1", {})
	eng.battle_lookup_id = 1
	var p := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_rank": false}, cm, eng, {}, lib)
	eng.add_unit(p)
	var w1: Dictionary = BattleData.from_config(cm, 1, 1).battle_info
	BattleEngineWaves.setup_battle(eng, cm, w1)
	var scene := BattleScene.new()
	scene.setup(eng, cm, w1)
	scene._sync_actors()
	# 构造玩家方飞行中投射物（远距离不命中）：DR 大招箭雨波清瞬间在途的等价物
	var sk := BattleSkill.new({
		"Tile XY Speed": 300.0, "Tile Z Speed": 0.0, "Tile Distance": 0.0, "Tile Gravity": 0.0,
		"Tile OTT Height": 0.0, "Target Type": "target", "Target Camp": -1, "Affected Camp": -1,
		"Max Range": 99999.0, "Min Range": 0.0, "Cost MP": 0.0, "CD": 0.0, "Global CD": 0.0,
	}, p, 1)
	var enemies: Array = eng.alive_units.get(BattleEngine.CAMP_ENEMY, [])
	sk.target = enemies[0]
	var proj := BattleProjectile.new(sk)
	eng.add_projectile(proj)
	ProjectileSync.sync(scene)   # 建投射物 View actor（挂 main_layer 进 actor_list）
	assert_false(bool(proj.terminated), "切波前投射物存活")
	scene._on_next_wave_requested()
	assert_true(bool(proj.terminated), "切波（reset_battle）终结飞行中投射物")
	scene._advance_actor_list(0.033)   # 切波后首帧推进
	var proj_actors_left: int = 0
	for a in scene.actor_list:
		if not (a is BattleActor):
			proj_actors_left += 1
	assert_eq(proj_actors_left, 0, "切波后投射物 actor 全销毁（玩家方也不残留）")
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


# 大血条退役守卫（2026-10-10 用户拍板「放弃血条」）：hpLayer=3 的 Boss 单位不再装配
# BigHpBar（两轮修复观感仍不合格整体移除）。2026-10-11 追：ShieldBoss 常显护盾条
# （源 :1558-1562，auto_hide=false 无盾空条常驻 ui_layer）随 BigHpBar 一并退役，
# Boss 不挂任何血条（头顶 HP/Shield 也不建）。
func test_no_big_blood_panel_for_boss_after_retirement() -> void:
	var eng := _make_engine()
	var boss := _make_unit(1, BattleEngine.CAMP_ENEMY, eng, Vector2(300, 0))
	boss.hp_layer = 3
	eng.add_unit(boss)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	assert_eq(scene.ui_list.size(), 0, "Boss hpLayer=3 → 不再建 BigHpBar（退役）")
	scene.step(0.033)
	var actor: Variant = scene.actor_list[0]
	assert_null(actor.bar_hp, "Boss 头顶不建 HP bar（血条整体退役）")
	assert_null(actor.bar_shield, "Boss 不建 Shield/ShieldBoss bar（退役）")
	assert_true(actor.bar_group.bars.is_empty(), "Boss bar_group 无任何条（退役）")
	var ui_bars: int = 0
	for child in scene.ui_layer.get_children():
		if child is BattleFloatingBar:
			ui_bars += 1
	assert_eq(ui_bars, 0, "ui_layer 无 ShieldBoss 挂载（退役）")
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


# 源 setActionSpeeder（unit.lua:1746）— frozen → 动画基础速率 0。
# step 内 engine.update 会 rebuild buff_effects 擦手设 frozen，故 step 后重设 + 强制 tick 块触发验逻辑。
# 2026-09-05 速度分离后：0 落在 _base_anim_speed（fca 实速 = base×mult，0×N=0 再 clamp 下限 0.1）。
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
	assert_eq(actor.puppet._base_anim_speed, 0.0, "frozen → setActionSpeeder(0)（源 :1746，基础速归零）")
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
# 档位持久化（2026-08-31 四轮）后初始档来自 cfg：注入测试专用路径固定初始 1（隔离玩家真实档，
# 多测试共享 user:// 互踩判例——曾致本测试读到取证残留 3/4 档断言错位）。
func test_speed_button_cycles_states() -> void:
	var btn := BattleSpeedButton.new()
	btn.cfg_path = "user://battle_test_cycle.cfg"
	# 显式重置固定路径 cfg（上一轮失败运行会残留中间档位态；旧版 4 连按末态恰为 1
	# 自净掩盖此缺陷，裁 3 档后暴露——固定路径持久化测试必须先重置再读）
	var reset_cfg := ConfigFile.new()
	reset_cfg.set_value("battle", "speed_state", 1)
	reset_cfg.save(btn.cfg_path)
	btn.setup(1)
	assert_eq(btn.get_state(), 1, "初始档 1")
	btn._on_pressed()   # 模拟点击（源 speedBtnHandler）
	assert_eq(btn.get_state(), 2, "点击 → 档 2")
	btn._on_pressed()
	assert_eq(btn.get_state(), 3, "→ 档 3")
	btn._on_pressed()
	assert_eq(btn.get_state(), 1, "档 3 → 1 循环（2026-10-06 用户拍板 4 档裁 3；源 :1048 循环语义不变）")
	btn.queue_free()


# 源 resetUI（:1235-1250）+ speedBtnHandler（:1052-1053）— scene 装配 speedBtn + 点击接 set_speed_state。
# scene 装配走 assembler 读真实 cfg（不可注入）：前置备份+写 1 固定初始档，后置恢复玩家原值。
# 真实档三段式 helper（本文件 scene 装配测试共用）：整档备份 → load 保兄弟键后预置 →
# 测试体 → 整档恢复（原本无档则删除测试产物）。防 CI 抹玩家 user://battle.cfg。
var _cfg_backup: ConfigFile = null
var _cfg_had: bool = false

func _backup_and_prepare_real_cfg(key: String, value: Variant) -> void:
	_cfg_backup = ConfigFile.new()
	_cfg_had = _cfg_backup.load(REAL_BATTLE_CFG) == OK
	var pre := ConfigFile.new()
	pre.load(REAL_BATTLE_CFG)   # 保留兄弟键（auto_combat/speed_state 互不抹）
	pre.set_value("battle", key, value)
	pre.save(REAL_BATTLE_CFG)

func _restore_real_cfg() -> void:
	if _cfg_had:
		_cfg_backup.save(REAL_BATTLE_CFG)
	else:
		DirAccess.open("user://").remove("battle.cfg")

const REAL_BATTLE_CFG: String = "user://battle.cfg"

func test_scene_speed_button_sets_state() -> void:
	_backup_and_prepare_real_cfg("speed_state", 1)
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	assert_not_null(scene.speed_btn, "scene 装配 speed_btn（源 resetUI）")
	scene.speed_btn._on_pressed()   # 1→2
	assert_eq(scene.speed_state, 2, "speed_changed → set_speed_state(2)")
	_restore_real_cfg()
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
# 2026-10-08 auto 偏好持久化后 _on_pressed 写盘：注入测试档隔离玩家真实 user://battle.cfg。
func test_auto_button_toggle() -> void:
	var btn := BattleAutoButton.new()
	btn.cfg_path = "user://battle_test_auto_toggle.cfg"
	btn.setup(false, true)
	assert_eq(btn.is_on(), false, "初始 off")
	btn._on_pressed()
	assert_eq(btn.is_on(), true, "pressed → on（源 :1021 toggle）")
	btn._on_pressed()
	assert_eq(btn.is_on(), false, "再 pressed → off")
	btn.queue_free()


# 2026-09-06 贴图升级守卫 — autocombat_on/off.png 入库（源 Content/res 直录），撤文本降级。
# 2026-10-08 auto 偏好持久化后 _on_pressed 写盘：注入测试档隔离玩家真实档。
func test_auto_button_texture_states() -> void:
	var btn := BattleAutoButton.new()
	btn.cfg_path = "user://battle_test_auto_tex.cfg"
	btn.setup(false, true)
	assert_not_null(btn._button.texture_normal, "off 态贴图 autocombat_off.png 已加载（撤文本降级）")
	var off_tex: Texture2D = btn._button.texture_normal
	btn._on_pressed()
	assert_not_null(btn._button.texture_normal, "on 态贴图 autocombat_on.png")
	assert_ne(btn._button.texture_normal, off_tex, "on/off 两态贴图不同（源 CCMenuItemToggle setSelectedIndex）")
	btn.queue_free()


# 2026-09-06 位置守卫 — 源 ccp(734,60) MenuItem 中心锚 → Godot 左上角须减显示半尺寸
# （三轮订正：显示=纹理像素÷CS=82.73×46.83，同倍速换算），与倍速按钮(735,120)同竖线
# 左右对齐 + 垂直间距 60（上下紧邻）。挂树等一帧后 TextureButton size 适配纹理实测
# （离树未布局恒 0×0），显示尺寸 = size × scale。
func test_auto_button_position_aligns_speed_button() -> void:
	var auto_btn := BattleAutoButton.new()
	auto_btn.setup(false, true)
	var speed_btn := BattleSpeedButton.new()
	speed_btn.cfg_path = "user://battle_test_align.cfg"   # 隔离玩家真实档（只读也注入，防污染判例）
	speed_btn.setup(1)
	add_child_autofree(auto_btn)
	add_child_autofree(speed_btn)
	await get_tree().process_frame
	assert_almost_eq(auto_btn._button.scale.x, 1.0 / 1.28125, 0.001, "auto ÷CS 缩放（Director 全局 CS 判例三轮订正）")
	assert_almost_eq(speed_btn._btn.scale.x, 1.0 / 1.28125, 0.001, "speed ÷CS 缩放")
	var auto_disp: Vector2 = auto_btn._button.size * auto_btn._button.scale
	var speed_disp: Vector2 = speed_btn._btn.size * speed_btn._btn.scale
	assert_almost_eq(auto_disp.x, 82.73, 0.5, "auto 显示宽 106px÷CS=82.73 点")
	assert_almost_eq(auto_disp.y, 46.83, 0.5, "auto 显示高 60px÷CS=46.83 点")
	assert_almost_eq(speed_disp.x, 81.95, 0.5, "speed 显示宽 105px÷CS=81.95 点")
	var ac: Vector2 = auto_btn.position + auto_disp * 0.5
	var sc: Vector2 = speed_btn.position + speed_disp * 0.5
	assert_almost_eq(ac.x, sc.x - 1.0, 0.5, "中心 x 差 1 = 源 ccp 735/734 同竖线（左右对齐）")
	assert_eq(ac.y - sc.y, 60.0, "垂直中心间距 60 = 源 120−60（上下紧邻一按钮高）")


# 源 auto_btn pressed → scene.auto_combat。
# 2026-10-08 auto 偏好持久化 + 取消通关门槛后装配恒读真实 cfg（assembler 内 new 不可注入）：
# 前置备份+写固定 off，后置恢复玩家原值（照 test_scene_speed_button_sets_state 判例）。
func test_scene_auto_button_toggles_combat() -> void:
	_backup_and_prepare_real_cfg("auto_combat", false)
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	assert_eq(scene.auto_combat, false, "初始 auto_combat=档 off（单机化默认，源 :118 localMode）")
	assert_not_null(scene.auto_btn, "scene 装配 auto_btn（源 resetUI :1252）")
	scene.auto_btn._on_pressed()
	assert_eq(scene.auto_combat, true, "auto_btn pressed → auto_combat=true（源 :1021）")
	_restore_real_cfg()
	scene.queue_free()


# 2026-10-08 取消通关门槛（源 :1224-1226 pve stars<3 隐藏 → 用户指示全模式恒显示）：
# 无上下文装配也显示，不再按星数 gating。
func test_scene_auto_button_always_visible() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	assert_eq(scene.auto_btn.visible, true, "无通关门槛 → auto_btn 恒显示")
	scene.queue_free()


# 星数门槛 stub mgr（源 ed.player:getStageStar → 本项目 stage_manager.stage_stars 鸭子类型）。
class StarMgrStub extends RefCounted:
	var stars := 0
	func stage_stars(_sid: int) -> int:
		return stars


# 装配读档 off → 引擎同步 off（2026-10-08 取消门槛后不再依赖 stars=3 上下文）。
# 真实 cfg 不可注入（assembler 内 new）：走 _backup_and_prepare/_restore 三段式（2026-10-09 修互抹）。
func test_scene_auto_button_reads_persisted_off() -> void:
	_backup_and_prepare_real_cfg("auto_combat", false)
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var mgr := StarMgrStub.new()
	mgr.stars = 0
	var scene := BattleScene.new()
	scene._battle_context = {"mode": "stage", "stage_id": 1, "mgr": mgr}
	scene.setup(eng, cm)
	assert_eq(scene.auto_btn.visible, true, "低星（0 星）→ auto_btn 仍显示（门槛已取消）")
	assert_eq(scene.auto_combat, false, "档 off → auto_combat=false（读档同步）")
	_restore_real_cfg()
	scene.queue_free()


# 2026-10-08 auto 偏好持久化正向链路 — 装配读档 on → 引擎同步 on（跨战斗记忆，无门槛）。
# 真实 cfg 不可注入（assembler 内 new）：走 _backup_and_prepare/_restore 三段式（2026-10-09 修互抹）。
func test_scene_auto_button_reads_persisted_on() -> void:
	_backup_and_prepare_real_cfg("auto_combat", true)
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	assert_eq(scene.auto_combat, true, "档 on → 新战斗 auto_combat=true（跨战斗记忆）")
	assert_eq(scene.auto_btn.is_on(), true, "按钮初始态显示 on（读档）")
	_restore_real_cfg()
	scene.queue_free()


# 门槛不回归守卫（2026-10-08 用户指示取消）：源 :1224 pve stars<3 隐藏已废弃，
# 显式低星 mgr（stars=2）上下文也必须显示。
func test_scene_auto_button_visible_below_3_stars() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var mgr := StarMgrStub.new()
	mgr.stars = 2
	var scene := BattleScene.new()
	scene._battle_context = {"mode": "stage", "stage_id": 1, "mgr": mgr}
	scene.setup(eng, cm)
	assert_eq(scene.auto_btn.visible, true, "pve stars=2 < 3 → auto_btn 仍显示（门槛已取消）")
	scene.queue_free()


# 出击阵容排列方向（源 addHeroPanel battle_scene.lua:521-529）：x=width*(N/2-idx+3)+10，
# 先加入（idx 小）x 大排最右、后加入往左——配合两侧同款 sortHeroList（普攻射程升序，
# 近战前排先入 unit_list）即「前排最右」。HBox 默认 add_child 先加在左恰相反
# （2026-10-08 用户 MuMu 实测反馈反了，修=add_hero_panel 后入插最左）。
# 守卫：先加入者的面板 index 大于后加入者（更靠右）。tid 1=Coco 前排/2=DR 后排
#（Unit.json Position Type），add_unit 顺序即 unit_list 顺序（重排在 stage_manager 侧）。
func test_hero_panels_first_unit_rightmost() -> void:
	var eng := _make_engine()
	var p1 := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	var p2 := _make_unit(2, BattleEngine.CAMP_PLAYER, eng, Vector2(200, 0))
	eng.add_unit(p1)
	eng.add_unit(p2)
	var scene := BattleScene.new()
	# heroes_panel 复用 hud.bottom_left（_ready 进树才赋值），须先 add_child 再 setup
	# 装配循环才挂得上面板（camera_shake 测试同款入树先例）。
	add_child_autofree(scene)
	scene.setup(eng, cm)
	assert_eq(scene.heroes_panel.get_child_count(), 2, "两英雄各装配一块面板")
	var idx_first: int = scene.heroes_panel.get_children().find(scene._hero_panels[p1])
	var idx_second: int = scene.heroes_panel.get_children().find(scene._hero_panels[p2])
	assert_gt(idx_first, idx_second, "先加入（前排）在最右：child index 大于后加入者")
	scene.queue_free()


# 非 pve 分支照旧显示（门槛取消前后行为一致，全模式恒显示）。
func test_scene_auto_button_visible_in_non_stage_modes() -> void:
	for m in ["pvp", "excavate"]:
		var eng := _make_engine()
		var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
		eng.add_unit(p)
		var scene := BattleScene.new()
		scene._battle_context = {"mode": m}
		scene.setup(eng, cm)
		assert_eq(scene.auto_btn.visible, true, "mode=%s 非 pve → auto_btn 显示（源非 pve 无门槛）" % m)
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


# 源 nextBtnTapHandler :418-428：start_player_walk 算 maxtime（玩家 actor 走到出屏目标）。
# 2026-09-05 方法自 battle_scene 下沉至 BattleWaveAdvancer（LINT005 行数）。
func test_start_player_walk_maxtime() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100.0, 0.0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene.step(0.033)
	p.info["Walk Speed"] = 200.0
	var maxtime: float = BattleWaveAdvancer.start_player_walk(scene)
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
# 2026-09-06 三轮订正：MenuItemImage 显示=纹理像素÷CS（源 hello.lua:311 Director 全局
# setContentScaleFactor(615/480)=1.28125，引擎 Texture2D::getContentSize 返回点尺寸），
# 08-28"MenuItemImage 不÷CS"判例推翻——hourglass/加速钮/auto 钮三处同步÷CS。
# 计时器：源 battle_scene.lua:1341-1387 bg Scale9 106×44 anchor(0,0.5)@(610,440)→
# Godot 显示区 (610,18)-(716,62)；hourglass 显示 40×80 像素÷CS=31.2×62.4 中心 (697,43)。
# 加速钮：显示 105×60 像素÷CS=81.95×46.83 中心 (735,120)→Godot 左上 (694.02,336.59)。
# auto 钮：显示 106×60÷CS=82.73×46.83 中心 (734,60)→左上 (692.63,396.59)。
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
	assert_almost_eq(hg.scale.x, 0.7805, 0.001, "hourglass ÷CS 显示 31.2×62.4（MenuItemImage 一样÷CS，三轮订正）")
	# 加速钮：中心 (735,360) 显示 81.95×46.83 → 左上 (694.02,336.59)
	assert_almost_eq(scene.speed_btn.position.x, 694.02, 0.5, "speed btn 左上 x=694.02（中心 735−105/CS/2）")
	assert_almost_eq(scene.speed_btn.position.y, 336.59, 0.5, "speed btn 左上 y=336.59（中心 360−60/CS/2）")
	assert_almost_eq(scene.speed_btn._btn.scale.x, 1.0 / 1.28125, 0.001, "speed btn scale=1/CS（三轮订正）")
	# auto 钮：中心 (734,420) 显示 82.73×46.83 → 左上 (692.63,396.59)（默认隐藏，几何不受 visible 影响）
	assert_almost_eq(scene.auto_btn.position.x, 692.63, 0.5, "auto btn 左上 x=692.63（中心 734−106/CS/2）")
	assert_almost_eq(scene.auto_btn.position.y, 396.59, 0.5, "auto btn 左上 y=396.59（中心 420−60/CS/2）")
	assert_almost_eq(scene.auto_btn._button.scale.x, 1.0 / 1.28125, 0.001, "auto btn scale=1/CS（三轮订正）")
	# 暂停钮：÷CS 54.6×53.9 中心 (757,40) → 左上 (729.7,13.1)
	assert_almost_eq(scene.return_btn.position.x, 729.7, 0.1, "return btn 左上 x=729.7（÷CS 源直译）")
	assert_almost_eq(scene.return_btn.position.y, 13.1, 0.1, "return btn 左上 y=13.1")
	assert_almost_eq(scene.return_btn.scale.x, 1.0 / 1.28125, 0.001, "return btn scale=1/CS（createButtonWithMask÷CS）")
	scene.queue_free()


# 回归（2026-09-04 倍速下移动动画不播）：首 tick 新单位的 NEW_ACTION 事件曾因
# BattleEventRenderer.render 先于 _sync_actors 执行（单位尚无 actor）被静默丢弃，
# Logic 侧 set_action 的 loop+同名守卫不重发 → 开局走向敌人全程滑行无 Move 动画
# （1x/2x/4x 全丢，高速下观感更明显）。step 顺序改 sync 前置后修复。
func test_first_tick_move_action_reaches_puppet() -> void:
	var eng := _make_engine()
	eng.stage_info = cm.get_raw_table(&"Stage").get("1", {})
	eng.battle_lookup_id = 1
	var p := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_rank": false}, cm, eng, {}, lib)
	eng.add_unit(p)
	var w1: Dictionary = BattleData.from_config(cm, 1, 1).battle_info
	BattleEngineWaves.setup_battle(eng, cm, w1)
	var scene := BattleScene.new()
	scene.setup(eng, cm, w1)
	# engine.next_tick 初始 0：首帧 step 即首 tick——AI 决策走向对手 + NEW_ACTION 事件分发
	# 与 actor 首次创建同帧竞争，事件先于 actor 创建即被丢。
	scene.step(0.033)
	var checked: int = 0
	for a in scene.actor_list:
		var u: Variant = a.model
		if u == null or String(u.action_name) != "Move":
			continue
		var fca: Variant = a.puppet.get("_fca")
		assert_not_null(fca, "Move 单位应有 FCA 傀儡（tid=1 资源正常加载）")
		if fca == null:
			continue
		assert_eq(String(fca.get_current_action()), "Move",
			"首 tick 的 Move 事件应送达 puppet（移动期间播移动动画，不滑行）")
		checked += 1
	assert_gt(checked, 0, "开局双方走向对手，应有 Move 状态单位被检查")
	scene.queue_free()


# 回归（2026-09-05 倍速下出屏走路速度断层 + 动画档位倍率缺失）：
# 探针实证 4x 下战斗内移动 3.96px/帧 vs 离线走路（出屏/入场）1.45px/帧——离线走路的
# 位置速度/动画速度/编排 timer 全部不随倍速档。修复口径：UnitSprite 速度分离
# base（speeder×2 / 走路 √1.75）× mult（档位倍率），切档/创建点只动 mult。
func test_offline_walk_speed_follows_speed_state() -> void:
	var eng := _make_engine()
	var p := _make_unit(1, BattleEngine.CAMP_PLAYER, eng, Vector2(100, 0))
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene.step(0.033)
	var actor: Variant = scene.actor_list[0]
	# 3x（最高档）：freeze 分支（切波走路）位置速度应为 1x 的 3 倍
	scene.set_speed_state(3)
	scene._walking_to_next = true
	actor.goto_next_battle(100.0, 1050.0)
	actor.update_view(0.0)   # 同步 position 到重置后的 _walk_pos（goto 不立即定位）
	var x0_4x: float = actor.position.x
	scene._process(0.0167)
	scene._process(0.0167)
	var dx_4x: float = actor.position.x - x0_4x
	# 1x 对照
	scene.set_speed_state(1)
	actor.goto_next_battle(100.0, 1050.0)
	actor.update_view(0.0)
	var x0_1x: float = actor.position.x
	scene._process(0.0167)
	scene._process(0.0167)
	var dx_1x: float = actor.position.x - x0_1x
	assert_almost_eq(dx_4x, dx_1x * 3.0, 0.5, "3x 离线走路位移应为 1x 的 3 倍（档位贯穿 freeze 分支）")
	scene.queue_free()


# 战斗内动画速度 = base(speeder×2) × 档位倍率：3x 下 spd=6（base 2 × mult 3），
# 切档 broadcast 只改 mult（base 不被覆盖——此前 set_speed(N) 全量覆盖回 2 是断层根因）。
func test_combat_anim_speed_is_base_times_state_mult() -> void:
	var eng := _make_engine()
	eng.stage_info = cm.get_raw_table(&"Stage").get("1", {})
	eng.battle_lookup_id = 1
	var p := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_rank": false}, cm, eng, {}, lib)
	p.info["Walk Speed"] = 1000.0
	eng.add_unit(p)
	var w1: Dictionary = BattleData.from_config(cm, 1, 1).battle_info
	BattleEngineWaves.setup_battle(eng, cm, w1)
	var scene := BattleScene.new()
	scene.setup(eng, cm, w1)
	scene.set_speed_state(3)
	scene.step(0.033)
	var fca: Variant = null
	for a in scene.actor_list:
		if a.model != null and String(a.model.action_name) == "Move":
			fca = a.puppet.get("_fca")
			break
	assert_not_null(fca, "应有 Move 单位")
	if fca != null:
		assert_almost_eq(float(fca.get("_speed")), 6.0, 0.01, "3x 战斗内动画速度 = base 2×speeder × mult 3（speeder=1 时 6.0）")
		scene._on_speed_changed(2)
		assert_almost_eq(float(fca.get("_speed")), 4.0, 0.01, "切 2x 后 = base 2 × mult 2 = 4.0（mult 不覆盖 base）")
	scene.queue_free()


# 手动下一波按钮路径：走路期间必须置 _walking_to_next 冻结 engine
# （否则 step 继续跑：波清状态 tick 空转 + effect/timer 用放大 dt 乱推进）。
func test_next_pressed_freezes_engine_during_walk() -> void:
	var eng := _make_engine()
	eng.stage_info = cm.get_raw_table(&"Stage").get("1", {})
	eng.battle_lookup_id = 1
	var p := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_rank": false}, cm, eng, {}, lib)
	p.info["Walk Speed"] = 1000.0
	eng.add_unit(p)
	var scene := BattleScene.new()
	scene.setup(eng, cm, BattleData.from_config(cm, 1, 1).battle_info)
	scene._sync_actors()
	scene.set_speed_state(3)
	add_child(scene)
	scene._on_next_pressed()
	# 同步段立即置位（协程 fire-and-forget，同步段在首个 await 前执行完毕；
	# 不可等帧断言——headless 全速下 maxtime/N timer 可能早于帧回调到期）
	assert_true(scene._walking_to_next, "手动下一波走路期间应置 _walking_to_next（冻结 engine）")
	await scene.next_wave_requested
	assert_false(scene._walking_to_next, "切波请求发出后应复位")
	scene.queue_free()


# ─────────────────────────────────────────────────────────────────
# auto 代点波次入场缓冲（2026-10-11，群反馈 #12）。
# 源 auto 代点（hero_panel.lua:127-131，本项目 update 同构翻译）无入场门——满能量
# 进下一波 0.5s 即代点大招（JUGG_ult 无敌斩 MaxRange=800 全场跳脸），玩家实测
# 「满能量进入下一波的时候，进场就释放了」。受控偏离=切波后 AUTO_CAST_WAVE_GRACE_TICKS
# 引擎 tick 内不代点；单测直驱 _within_wave_grace（update 接线为单点 if 门）。
class FakeGraceEng:
	var ticks: int = 0
	var wave_id: int = 1


func test_auto_grace_blocks_right_after_wave_change() -> void:
	var panel := BattleHeroPanel.new()
	add_child_autofree(panel)
	var eng := FakeGraceEng.new()
	eng.ticks = 100
	eng.wave_id = 2   # panel 初值 _last_wave_id=-1 → 首次判波即建立缓冲
	assert_true(panel._within_wave_grace(eng), "切波瞬间（tick 100）落在缓冲期内 → 不代点")
	eng.ticks = 100 + BattleHeroPanel.AUTO_CAST_WAVE_GRACE_TICKS - 1
	assert_true(panel._within_wave_grace(eng), "缓冲末 tick（截止-1）仍拦，边界含头")


func test_auto_grace_expires_after_grace_ticks() -> void:
	var panel := BattleHeroPanel.new()
	add_child_autofree(panel)
	var eng := FakeGraceEng.new()
	eng.ticks = 100
	eng.wave_id = 2
	panel._within_wave_grace(eng)   # 建立缓冲
	eng.ticks = 100 + BattleHeroPanel.AUTO_CAST_WAVE_GRACE_TICKS
	assert_false(panel._within_wave_grace(eng), "达到缓冲截止 tick → 恢复代点（边界不含尾）")


func test_auto_grace_restarts_on_next_wave_change() -> void:
	var panel := BattleHeroPanel.new()
	add_child_autofree(panel)
	var eng := FakeGraceEng.new()
	eng.ticks = 100
	eng.wave_id = 2
	panel._within_wave_grace(eng)   # 波 2 缓冲建立
	eng.ticks = 100 + BattleHeroPanel.AUTO_CAST_WAVE_GRACE_TICKS
	assert_false(panel._within_wave_grace(eng), "波 2 缓冲过期")
	eng.ticks += 10
	eng.wave_id = 3                  # 波 2→3 再切波
	assert_true(panel._within_wave_grace(eng), "再切波 → 缓冲按新波重计")


# 红阶英雄战斗内头像框（2026-10-11 用户反馈「红色品阶英雄进入战斗后框还是橙色的」根修）：
# 战斗 rank 被 RANK_MAX=12 clamp（源 unit.lua:137 同款，属性表 12 档口径），框是纯视觉
# 不应跟 clamp 走——battle_hero_panel 取框改用 proto._rank（存档进阶 rank），红阶 18-23
# → readhero_icon 红款 hero_icon_frame_13。守卫：_rank 23 英雄的面板框贴图=frame_13 非
# frame_11（rank 12 clamp 档金橙）。
func test_red_rank_hero_panel_uses_red_frame() -> void:
	var eng := _make_engine()
	# 真实玩家英雄语义（estimate_rank=false 走 proto._rank；_make_unit 的 estimate 分支不读 _rank）
	var p := BattleUnit.new({"_tid": 1, "_level": 80, "_stars": 5, "_rank": 23}, BattleEngine.CAMP_PLAYER, {"estimate_rank": false}, cm, eng, {}, lib)
	p.position = Vector2(100, 0)
	p.previous_position = p.position
	eng.add_unit(p)
	var scene := BattleScene.new()
	add_child_autofree(scene)
	scene.setup(eng, cm)
	assert_eq(int(p.rank), 12, "战斗内 rank 仍被 RANK_MAX=12 clamp（属性口径不动）")
	var panel: Variant = scene._hero_panels.get(p) if scene._hero_panels != null else null
	assert_not_null(panel, "红阶英雄装配了头像面板")
	var tex: Texture2D = panel.frame_btn.texture_normal
	assert_not_null(tex, "框贴图已加载")
	var path: String = str(tex.resource_path)
	assert_true(path.ends_with("hero_icon_frame_13.png"), "红阶(rank 23)战斗框=红款 frame_13，实际 %s" % path)
	scene.queue_free()
