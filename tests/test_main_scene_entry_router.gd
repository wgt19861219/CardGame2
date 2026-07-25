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
	var scene := Node.new()
	add_child(scene)
	var saved_team: Array = GameData.player.team.duplicate()
	GameData.player.team.clear()
	MainSceneEntryRouter.open_equip_strengthen(scene)
	assert_eq(scene.get_child_count(), 0, "空阵容不建 panel")
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


func test_open_exercise_panel_with_callback() -> void:
	var scene := Node.new()
	add_child(scene)
	var cb_called: Array[bool] = [false]
	var cb: Callable = func(_m: String, _g: Array) -> void: cb_called[0] = true
	MainSceneEntryRouter.open_exercise_panel(scene, cb)
	assert_true(scene.get_child_count() > 0, "ExercisePanel 挂到 scene")
	scene.free()
