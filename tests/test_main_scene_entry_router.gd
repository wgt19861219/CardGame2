extends GutTest
## MainSceneEntryRouter 入口路由 helper 单测（全 static，仿 midas_renderer 测试范式）。
## 验证 open_xxx 建 panel + 挂到 scene（mock Node 作 scene，断言 add_child/show_window 调用）。


func test_open_avatar_builds_panel() -> void:
	var scene := Node.new()
	add_child(scene)
	MainSceneEntryRouter.open_avatar(scene)
	assert_true(scene.get_child_count() > 0, "open_avatar 建了 panel")
	scene.free()


func test_open_midas_builds_panel() -> void:
	var scene := Node.new()
	add_child(scene)
	MainSceneEntryRouter.open_midas(scene)
	assert_true(scene.get_child_count() > 0, "open_midas 建了 panel")
	scene.free()


func test_open_equip_strengthen_empty_team_toasts() -> void:
	# 2026-09-08 四轮对齐源：入口不看 team（选英雄窗列全部英雄），仅英雄库空才 Toast 拦截；
	# team 空 + 英雄库有 → 建面板（未选英雄空态，nohead 占位 +「请选择英雄」）。
	var scene := Node.new()
	add_child(scene)
	var saved_team: Array = GameData.player.team.duplicate()
	GameData.player.team.clear()
	MainSceneEntryRouter.open_equip_strengthen(scene)
	assert_eq(scene.get_child_count(), 1, "team 空但英雄库有 → 建面板（源 selectwindow 列全部英雄）")
	GameData.player.team = saved_team
	scene.free()


func test_open_dungeon_groups_data_conversion() -> void:
	var scene := Node.new()
	add_child(scene)
	MainSceneEntryRouter.open_dungeon_groups(scene, "em", [50005, 50006])
	assert_true(scene.get_child_count() > 0, "open_dungeon_groups 建了 panel")
	scene.free()


func test_open_excavate_search_when_empty() -> void:
	var scene := Node.new()
	add_child(scene)
	MainSceneEntryRouter.open_excavate(scene)
	assert_true(scene.get_child_count() > 0, "open_excavate 建了 panel")
	scene.free()


func test_open_exercise_degree_builds_panel() -> void:
	# 2026-09-12 二轮：ExercisePanel 占位弹窗退役，路由改主城建筑直连 dungeon 地图
	# （照源 exercise.create 终版直转）；资源试炼弹窗入口 helper 保留（组件可用）。
	var scene := Node.new()
	add_child(scene)
	MainSceneEntryRouter.open_exercise_degree(scene, "exp")
	assert_true(scene.get_child_count() > 0, "ExerciseDegreePanel 挂到 scene")
	scene.free()
