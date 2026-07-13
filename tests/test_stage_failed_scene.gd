extends GutTest
# StageFailedScene 失败结算场景测试（照源 ui/stagefailed.lua，2026-07-03 Phase 4 续）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_scene(param: Dictionary) -> StageFailedScene:
	var scene := StageFailedScene.new()
	add_child(scene)
	scene.setup(param, cm)
	return scene


func test_setup_creates_nodes() -> void:
	var scene := _make_scene({"stage_id": -27, "lose_type": "fail"})
	assert_not_null(scene.get_node_or_null("Bg"), "Bg 节点")
	assert_not_null(scene.get_node_or_null("Shelter"), "Shelter 节点")
	assert_not_null(scene.get_node_or_null("Light"), "Light 节点")
	assert_not_null(scene.get_node_or_null("Title"), "Title 节点")
	assert_not_null(scene.get_node_or_null("Back"), "Back 按钮")
	assert_not_null(scene.get_node_or_null("Menu"), "Menu 按钮")
	scene.queue_free()


func test_title_fail_text() -> void:
	var scene := _make_scene({"stage_id": -27, "lose_type": "fail"})
	var title: Label = scene.get_node("Title")
	assert_eq(title.text, "失败", "lose_type=fail → 失败")
	scene.queue_free()


func test_title_timeout_text() -> void:
	var scene := _make_scene({"stage_id": -27, "lose_type": "timeout"})
	var title: Label = scene.get_node("Title")
	assert_eq(title.text, "超时", "lose_type=timeout → 超时")
	scene.queue_free()


func test_title_default_fail() -> void:
	# 无 lose_type → 默认 fail
	var scene := _make_scene({"stage_id": -27})
	var title: Label = scene.get_node("Title")
	assert_eq(title.text, "失败", "无 lose_type 默认失败")
	scene.queue_free()


func test_light_texture_loaded() -> void:
	# failed_light.png 资源存在 → Light.texture 非空
	var scene := _make_scene({"stage_id": -27, "lose_type": "fail"})
	var light: Sprite2D = scene.get_node("Light")
	assert_not_null(light.texture, "Light texture 加载（failed_light.png）")
	scene.queue_free()


func test_back_button_texture() -> void:
	var scene := _make_scene({"stage_id": -27, "lose_type": "fail"})
	var back: TextureButton = scene.get_node("Back")
	assert_not_null(back.texture_normal, "Back texture_normal（replaybtn.png）")
	assert_true(back.pressed.is_connected(scene._on_back_pressed), "Back pressed 连接")
	scene.queue_free()


func test_menu_button_texture() -> void:
	var scene := _make_scene({"stage_id": -27, "lose_type": "fail"})
	var menu: TextureButton = scene.get_node("Menu")
	assert_not_null(menu.texture_normal, "Menu texture_normal（back2mapbtn.png）")
	assert_true(menu.pressed.is_connected(scene._on_menu_pressed), "Menu pressed 连接")
	scene.queue_free()


func test_shelter_full_rect() -> void:
	var scene := _make_scene({"stage_id": -27, "lose_type": "fail"})
	var shelter: ColorRect = scene.get_node("Shelter")
	# anchors_preset 15（FULL_RECT）后 anchor_right/bottom=1
	assert_eq(shelter.anchor_right, 1.0, "Shelter 全屏 anchor_right=1")
	assert_eq(shelter.anchor_bottom, 1.0, "Shelter 全屏 anchor_bottom=1")
	scene.queue_free()


func test_bg_load_no_crash() -> void:
	# bg 资源加载不崩（-27 Background Pic 可能为空 → texture null 或 Texture2D 都行）
	var scene := _make_scene({"stage_id": -27, "lose_type": "fail"})
	var bg: TextureRect = scene.get_node("Bg")
	assert_not_null(bg, "Bg 节点存在（texture 加载不崩）")
	scene.queue_free()


# P1-16（2026-07-11）：battleStatist 按钮补全（源 stagefailed.lua:345-392 else 分支）。
func test_battle_statist_button() -> void:
	var scene := _make_scene({"stage_id": -27, "lose_type": "fail"})
	assert_not_null(scene.get_node_or_null("BattleStatist"), "BattleStatist 按钮节点")
	var btn: Button = scene.get_node("BattleStatist")
	assert_true(btn.pressed.is_connected(scene._on_battle_statist_pressed), "BattleStatist pressed 连接")
	scene.queue_free()
