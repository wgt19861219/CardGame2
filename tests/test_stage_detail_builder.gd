extends GutTest

## StageDetailBuilder 单测 — 照源 stagedetail.lua 坐标转换 + resInfo + 节点装配 + stars 亮暗。


func test_to_godot_conversion() -> void:
	# cocos(400,205) → Godot(480,355)（offset 80,80 + y 翻转 560-cy）
	assert_eq(StageDetailBuilder.to_godot(Vector2(400.0, 205.0)), Vector2(480.0, 355.0))
	assert_eq(StageDetailBuilder.to_godot(Vector2(0.0, 0.0)), Vector2(80.0, 560.0))
	assert_eq(StageDetailBuilder.to_godot(Vector2(800.0, 480.0)), Vector2(880.0, 80.0))


func test_get_res_info_normal() -> void:
	var ri: Dictionary = StageDetailBuilder.get_res_info("normal")
	assert_eq(String(ri["frame"]), "res://assets/ui/alpha/HVGA/stage-map-frame.png")
	assert_eq(String(ri["title_bg"]), "res://assets/ui/alpha/HVGA/Normal_title_bg.png")
	assert_eq(int(ri["star_gap"]), 55)
	assert_eq(Vector2(ri["go_btn_pos"]), Vector2(698.0, 80.0))
	assert_eq(Vector2(ri["frame_pos"]), Vector2(400.0, 205.0))


func test_get_res_info_elite() -> void:
	var ri: Dictionary = StageDetailBuilder.get_res_info("elite")
	assert_eq(String(ri["frame"]), "res://assets/ui/alpha/HVGA/stage-map-elite-frame.png")
	assert_eq(String(ri["title_bg"]), "res://assets/ui/alpha/HVGA/Elite_title_bg.png")
	assert_eq(int(ri["star_gap"]), 50)
	assert_eq(Vector2(ri["frame_pos"]), Vector2(400.0, 207.0))


func test_get_res_info_raid() -> void:
	var ri: Dictionary = StageDetailBuilder.get_res_info("raid")
	assert_eq(String(ri["frame"]), "res://assets/ui/alpha/HVGA/stage_map_guild_frame.png")


func test_get_res_info_dungeon() -> void:
	var ri: Dictionary = StageDetailBuilder.get_res_info("dungeon")
	assert_eq(String(ri["frame"]), "res://assets/ui/alpha/HVGA/stage-map-elite-frame.png")


func test_build_creates_nodes() -> void:
	var parent := Node.new()
	add_child(parent)
	var info: Dictionary = {"title": "测试", "detail": "", "power": 10, "count_limit": 3, "count": 1, "star": 2, "stage_type": "normal"}
	var ui: Dictionary = StageDetailBuilder.build(parent, info, StageDetailBuilder.get_res_info("normal"))
	assert_true(ui.has("frame2"), "应有 frame2")
	assert_true(ui.has("frame3"), "应有 frame3")
	assert_true(ui.has("title"), "应有 title")
	assert_true(ui.has("go_button"), "应有 go_button")
	assert_true(ui.has("reset"), "应有 reset")
	assert_true(ui.has("count_number"), "应有 count_number")
	assert_true(ui.has("go_button_shade"), "应有 go_button_shade")
	assert_true(parent.get_child_count() > 0, "父应装配子节点")
	parent.queue_free()


func test_build_buttons_are_texturebutton() -> void:
	var parent := Node.new()
	add_child(parent)
	var ui: Dictionary = StageDetailBuilder.build(parent, {"stage_type": "normal"}, StageDetailBuilder.get_res_info("normal"))
	assert_true(ui["go_button"] is TextureButton, "go_button 应为 TextureButton")
	assert_true(ui["reset"] is TextureButton, "reset 应为 TextureButton")
	parent.queue_free()


func test_build_go_button_shade_hidden_by_default() -> void:
	var parent := Node.new()
	add_child(parent)
	var ui: Dictionary = StageDetailBuilder.build(parent, {"stage_type": "normal"}, StageDetailBuilder.get_res_info("normal"))
	var gs: Sprite2D = ui["go_button_shade"]
	assert_false(gs.visible, "go_button_shade 默认隐藏（源 :1881 visible=false）")
	parent.queue_free()


func test_create_stars_three_with_texture() -> void:
	var parent := Node.new()
	add_child(parent)
	StageDetailBuilder.create_stars(parent, 2, 55)
	assert_eq(parent.get_child_count(), 3, "应建 3 颗星（2 亮 1 暗）")
	var s0: Sprite2D = parent.get_child(0) as Sprite2D
	assert_ne(s0.texture, null, "亮星应加载 detail_star 纹理")
	assert_almost_eq(s0.scale.x, 0.8, 0.01, "星 scale 0.8（源 :1229）")
	parent.queue_free()
