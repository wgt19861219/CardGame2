extends GutTest
# StageFailedScene 失败结算场景测试（照源 ui/stagefailed.lua，2026-07-03 Phase 4 续）。
# 2026-07-18 重构：chrome 静态化进 stage_failed_content.tscn（content 挂 scene 自身）。
# 节点访问：scene._content.get_node(...)（坑 6 测试扫描深度，.tscn 多一层 content）。

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
	assert_not_null(scene._content.get_node_or_null("Bg"), "Bg 节点")
	assert_not_null(scene._content.get_node_or_null("Shelter"), "Shelter 节点")
	assert_not_null(scene._content.get_node_or_null("Light"), "Light 节点")
	assert_not_null(scene._content.get_node_or_null("Title"), "Title 节点")
	assert_not_null(scene._content.get_node_or_null("Back"), "Back 按钮")
	assert_not_null(scene._content.get_node_or_null("Menu"), "Menu 按钮")
	scene.queue_free()


func test_title_fail_text() -> void:
	var scene := _make_scene({"stage_id": -27, "lose_type": "fail"})
	var title: Label = scene._content.get_node("Title")
	assert_eq(title.text, "失败", "lose_type=fail → 失败")
	scene.queue_free()


func test_title_timeout_text() -> void:
	var scene := _make_scene({"stage_id": -27, "lose_type": "timeout"})
	var title: Label = scene._content.get_node("Title")
	assert_eq(title.text, "超时", "lose_type=timeout → 超时")
	scene.queue_free()


func test_title_default_fail() -> void:
	# 无 lose_type → 默认 fail
	var scene := _make_scene({"stage_id": -27})
	var title: Label = scene._content.get_node("Title")
	assert_eq(title.text, "失败", "无 lose_type 默认失败")
	scene.queue_free()


func test_light_texture_loaded() -> void:
	# failed_light.png 资源存在 → Light.texture 非空
	var scene := _make_scene({"stage_id": -27, "lose_type": "fail"})
	var light: Sprite2D = scene._content.get_node("Light")
	assert_not_null(light.texture, "Light texture 加载（failed_light.png）")
	scene.queue_free()


func test_back_button_texture() -> void:
	var scene := _make_scene({"stage_id": -27, "lose_type": "fail"})
	var back: TextureButton = scene._content.get_node("Back")
	assert_not_null(back.texture_normal, "Back texture_normal（replaybtn.png）")
	assert_true(back.pressed.is_connected(scene._on_back_pressed), "Back pressed 连接")
	scene.queue_free()


func test_menu_button_texture() -> void:
	var scene := _make_scene({"stage_id": -27, "lose_type": "fail"})
	var menu: TextureButton = scene._content.get_node("Menu")
	assert_not_null(menu.texture_normal, "Menu texture_normal（back2mapbtn.png）")
	assert_true(menu.pressed.is_connected(scene._on_menu_pressed), "Menu pressed 连接")
	scene.queue_free()


func test_shelter_full_rect() -> void:
	var scene := _make_scene({"stage_id": -27, "lose_type": "fail"})
	var shelter: ColorRect = scene._content.get_node("Shelter")
	# anchors_preset 15（FULL_RECT）后 anchor_right/bottom=1
	assert_eq(shelter.anchor_right, 1.0, "Shelter 全屏 anchor_right=1")
	assert_eq(shelter.anchor_bottom, 1.0, "Shelter 全屏 anchor_bottom=1")
	scene.queue_free()


func test_bg_load_no_crash() -> void:
	# bg 资源加载不崩（-27 Background Pic 可能为空 → texture null 或 Texture2D 都行）
	var scene := _make_scene({"stage_id": -27, "lose_type": "fail"})
	var bg: TextureRect = scene._content.get_node("Bg")
	assert_not_null(bg, "Bg 节点存在（texture 加载不崩）")
	scene.queue_free()


# P1-16（2026-07-11）：battleStatist 按钮补全（源 stagefailed.lua:345-392 else 分支）。
func test_battle_statist_button() -> void:
	var scene := _make_scene({"stage_id": -27, "lose_type": "fail"})
	assert_not_null(scene._content.get_node_or_null("BattleStatist"), "BattleStatist 按钮节点")
	var btn: Button = scene._content.get_node("BattleStatist")
	assert_true(btn.pressed.is_connected(scene._on_battle_statist_pressed), "BattleStatist pressed 连接")
	scene.queue_free()


# 批 G（2026-08-28）P0-1/P0-2 守卫：battleStatist 按钮源直译 rect + count Label 挂按钮内。
# 源 stagefailed.lua:345-392 左中锚 ccp(500,335) scaleSize 70×50 → Godot offset (500,120)~(570,170)；
# battleCount 挂按钮内 ccp(35,26)（旧实现挂 _content 全局 (677,186) 飘位）。
func test_battle_statist_rect_and_count_inside() -> void:
	var scene := _make_scene({"stage_id": -27, "lose_type": "fail"})
	var btn: Button = scene._content.get_node("BattleStatist")
	assert_almost_eq(btn.offset_left, 500.0, 0.1, "按钮左缘 x=500（源直译，旧 505.83 系 960 系数残留）")
	assert_almost_eq(btn.offset_top, 120.0, 0.1, "按钮上缘 y=120（源 335 翻转-25）")
	assert_almost_eq(btn.size.x, 70.0, 0.1, "按钮宽 70（scaleSize 点数不÷CS，旧 58.33=70/1.2 实锤）")
	assert_almost_eq(btn.size.y, 50.0, 0.1, "按钮高 50")
	var count: Label = btn.get_child(0) as Label
	assert_not_null(count, "count Label 挂按钮内（apply_with_label 内建）")
	assert_eq(count.text, StageSettlementCommon.statist_label_text(cm), "count 文案=数据")
	assert_eq(count.position, Vector2.ZERO, "count 铺满按钮（源 ccp(35,26) 中心≈按钮中心）")
	scene.queue_free()


# 批 G P0-2 守卫：Light ÷CS + prompt 源直译位（源 createPrompt ccp(205,165)/(445,165) → Godot y=315）。
func test_light_scale_and_prompt_positions() -> void:
	var scene := _make_scene({"stage_id": -27, "lose_type": "fail"})
	var light: Sprite2D = scene._content.get_node("Light")
	assert_almost_eq(light.scale.x, 1.0 / 1.28125, 0.001, "Light ÷CS")
	assert_eq(scene.PROMPT_POS[0], Vector2(205.0, 315.0), "prompt1 源直译（旧 246,420 贴屏底）")
	assert_eq(scene.PROMPT_POS[1], Vector2(445.0, 315.0), "prompt2 源直译（旧 534,420）")
	scene.queue_free()
