extends GutTest
# 战斗掉落宝箱接线守卫（2026-08-31）：LOOT_DROP 事件链（emit → renderer → director → BattleLootView）。
# 根因：源 onUnitDie → scene:showMonsterLoots 的 View 副作用在 Phase 2.6 剥离成桩后入口缺失，
# 宝箱组件/数据/基础设施齐备却零引用（战斗无掉落显示，结算有 — ctx.loots 独立通路）。
# 守卫：die 触发（源码 grep 断言）/ 事件入队 / renderer 分发 / 槽位过滤（(wave=1,monster=1) 照源 makebits）/ 胜利自动收集。

const COMBAT_PATH: String = "res://scripts/systems/battle/battle_unit_combat.gd"
const SCENE_PATH: String = "res://scripts/view/battle/battle_scene.gd"

var cm: ConfigManager
var lib: SkillLibrary


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()
	lib = SkillLibrary.new(cm)


func _make_engine() -> BattleEngine:
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(12345)
	return eng


func _make_unit(tid: int, camp: int, eng: BattleEngine, pos: Vector2) -> BattleUnit:
	var u := BattleUnit.new({"_tid": tid, "_level": 1, "_stars": 1}, camp, {"estimate_rank": true}, cm, eng, {}, lib)
	u.position = pos
	u.previous_position = pos
	return u


func _make_scene_with_loots(loots: Array) -> BattleScene:
	var eng := _make_engine()
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene._battle_context = {"mode": "stage", "loots": loots}
	add_child(scene)
	# 空 engine 无玩家单位会立即判负触发 _finalize_battle（ctx 缺 mgr/stage_id 崩）；
	# 本套件只测 director/renderer 函数，禁 _process 手动驱动。
	scene.set_process(false)
	return scene


# die 流程发射 LOOT_DROP（battle_unit_combat.gd 紧邻 emit_gold_drop；grep 断言防误删，照 builder 退役守卫先例）。
func test_die_source_emits_loot_drop() -> void:
	var src: String = FileAccess.get_file_as_string(COMBAT_PATH)
	assert_true(src.contains("u.emit_loot_drop()"), "die 流程应含 u.emit_loot_drop()（源 onUnitDie :1038 showMonsterLoots）")


# 实体 emit_loot_drop → engine 事件队列（headless 消费者断言，照 T4 events 范式）。
func test_entity_emit_loot_drop_enqueues_event() -> void:
	var eng := _make_engine()
	var monster := _make_unit(1, BattleEngine.CAMP_ENEMY, eng, Vector2(300, 0))
	monster.monster_idx = 1
	monster.emit_loot_drop()
	var events: Array[BattleEvent] = eng.drain_events()
	assert_eq(events.size(), 1, "一条 LOOT_DROP 事件")
	assert_eq(events[0].type, BattleEvent.Type.LOOT_DROP, "type == LOOT_DROP")


# 槽位语义：源 local_server.lua:397 makebits(3,1,3,1,10,id) = 全部 (wave=1, monster=1)，
# 第一波第一个怪死亡弹出全部宝箱；同怪再死不重复；他怪/英雄不弹。
func test_director_spawns_chests_for_first_monster_only() -> void:
	var loots: Array = [
		{"id": 390, "type": ""},
		{"id": 201, "type": "equip"},
		{"id": 201, "type": "equip"},
	]
	var scene := _make_scene_with_loots(loots)
	var monster := _make_unit(1, BattleEngine.CAMP_ENEMY, scene.engine, Vector2(300, 0))
	monster.monster_idx = 1
	BattleLootDirector.show_monster_loots(scene, monster)
	assert_eq(scene.ui_list.size(), 3, "第一怪死亡弹出全部 3 宝箱（槽位全 (1,1)）")
	BattleLootDirector.show_monster_loots(scene, monster)
	assert_eq(scene.ui_list.size(), 3, "同怪再死不重复弹出（spawned 标记）")
	var other := _make_unit(2, BattleEngine.CAMP_ENEMY, scene.engine, Vector2(320, 0))
	other.monster_idx = 2
	BattleLootDirector.show_monster_loots(scene, other)
	assert_eq(scene.ui_list.size(), 3, "monster_idx=2 无槽位不弹")
	var hero := _make_unit(1, BattleEngine.CAMP_PLAYER, scene.engine, Vector2(100, 0))
	BattleLootDirector.show_monster_loots(scene, hero)
	assert_eq(scene.ui_list.size(), 3, "英雄死亡不弹（camp 过滤，源 camp==emCampEnemy）")
	scene.queue_free()


# renderer 分发：LOOT_DROP 事件 → scene 弹宝箱（不依赖死亡单位 actor）。
func test_renderer_dispatches_loot_drop_to_scene() -> void:
	var scene := _make_scene_with_loots([{"id": 390, "type": ""}])
	var monster := _make_unit(1, BattleEngine.CAMP_ENEMY, scene.engine, Vector2(300, 0))
	monster.monster_idx = 1
	scene.engine.emit_event(BattleEvent.loot_drop(monster))
	BattleEventRenderer.render(scene.engine, {}, scene)
	assert_eq(scene.ui_list.size(), 1, "LOOT_DROP 事件 → 宝箱入 ui_list")
	scene.queue_free()


# 无 loots 的 battle_context（pvp/excavate）→ 空槽位不弹（等价源 player.loots 为空）。
func test_empty_context_spawns_nothing() -> void:
	var eng := _make_engine()
	var scene := BattleScene.new()
	scene.setup(eng, cm)
	scene._battle_context = {"mode": "pvp"}
	add_child(scene)
	scene.set_process(false)
	var monster := _make_unit(1, BattleEngine.CAMP_ENEMY, eng, Vector2(300, 0))
	monster.monster_idx = 1
	BattleLootDirector.show_monster_loots(scene, monster)
	assert_eq(scene.ui_list.size(), 0, "pvp 无 loots 键 → 不弹宝箱")
	scene.queue_free()


# 波清即吸宝箱（源 battle_scene.lua:442 autoCollectLoots 随 nextwaveAction 并行）。
# 波次切换走 _on_wave_clear 自动流程（next_btn 不显示，_on_next_pressed 系不可达遗留），
# 收集职责必须挂 _on_wave_clear，grep 断言防回退到不可达路径。
func test_wave_clear_collects_chests() -> void:
	var src: String = FileAccess.get_file_as_string(SCENE_PATH)
	var start: int = src.find("func _on_wave_clear()")
	assert_true(start > 0, "_on_wave_clear 存在")
	var body: String = src.substr(start, src.find("\nfunc ", start + 10) - start)
	assert_true(body.contains("_auto_collect_loots()"), "波清流程应吸宝箱（源 :442，用户验收项）")
	var start2: int = src.find("func _on_next_pressed()")
	var body2: String = src.substr(start2, src.find("\nfunc ", start2 + 10) - start2)
	assert_false(body2.contains("_auto_collect_loots()"), "按钮路径不重复负责收集（职责单一在波清）")


# 胜利结算前自动收集（源 battle_engine.lua:1530 result==0 autoCollectLoots）：宝箱全收 + marker 计数。
func test_collect_before_finalize_collects_all_chests() -> void:
	var scene := _make_scene_with_loots([{"id": 390, "type": ""}, {"id": 201, "type": "equip"}])
	var monster := _make_unit(1, BattleEngine.CAMP_ENEMY, scene.engine, Vector2(300, 0))
	monster.monster_idx = 1
	BattleLootDirector.show_monster_loots(scene, monster)
	scene.engine.last_result = BattleEngine.RESULT_WIN
	await BattleLootDirector.collect_before_finalize(scene)
	var collected: int = 0
	for ui in scene.ui_list:
		if not is_instance_valid(ui):
			collected += 1   # 飞抵 marker 已 queue_free（视为已收集）
		elif ui.has_method("is_terminated") and bool(ui.is_terminated()):
			collected += 1
	assert_eq(collected, 2, "胜利时 2 宝箱全部自动收集")
	assert_eq(scene.engine.loot_count, 2, "飞抵 marker 计数 ×2（add_loot_marker(1)/箱）")
	scene.queue_free()
