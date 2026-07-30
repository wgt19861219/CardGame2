extends GutTest

## StageDetailBuilder 单测 — 照源 stagedetail.lua 坐标转换 + resInfo + .tscn fill + stars 亮暗 + LSTR 化。
## 重构（2026-07-17）：build→setup_content（.tscn instantiate + fill），to_godot 改两 float 参数。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_to_godot_conversion() -> void:
	# cocos(400,205) → Godot(480,355)（offset 80,80 + y 翻转 560-cy）
	assert_eq(StageDetailBuilder.to_godot(400.0, 205.0), Vector2(480.0, 355.0))
	assert_eq(StageDetailBuilder.to_godot(0.0, 0.0), Vector2(80.0, 560.0))
	assert_eq(StageDetailBuilder.to_godot(800.0, 480.0), Vector2(880.0, 80.0))


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


func _instantiate_content() -> Control:
	var content: Control = preload("res://scenes/ui/stage_detail_content.tscn").instantiate() as Control
	add_child(content)
	return content


func test_setup_content_returns_ui_dict() -> void:
	var content: Control = _instantiate_content()
	var info: Dictionary = {"title": "测试", "detail": "", "power": 10, "count_limit": 3, "count": 1, "star": 2, "stage_type": "normal"}
	var ui: Dictionary = StageDetailBuilder.setup_content(content, info, StageDetailBuilder.get_res_info("normal"), cm)
	assert_true(ui.has("frame2"), "应有 frame2")
	assert_true(ui.has("frame3"), "应有 frame3")
	assert_false(ui.has("title"), "不应有 title（节点已删，关卡名改由父面板章节标题栏显示）")
	assert_true(ui.has("go_button"), "应有 go_button")
	assert_true(ui.has("reset"), "应有 reset")
	assert_true(ui.has("count_number"), "应有 count_number")
	assert_true(ui.has("go_button_shade"), "应有 go_button_shade")
	assert_gt(content.get_child_count(), 0, "content 含静态子节点")
	content.queue_free()


func test_setup_content_buttons_are_texturebutton() -> void:
	var content: Control = _instantiate_content()
	var ui: Dictionary = StageDetailBuilder.setup_content(content, {"stage_type": "normal"}, StageDetailBuilder.get_res_info("normal"), cm)
	assert_true(ui["go_button"] is TextureButton, "go_button 应为 TextureButton")
	assert_true(ui["reset"] is TextureButton, "reset 应为 TextureButton")
	content.queue_free()


func test_setup_content_go_button_shade_hidden_by_default() -> void:
	var content: Control = _instantiate_content()
	var ui: Dictionary = StageDetailBuilder.setup_content(content, {"stage_type": "normal"}, StageDetailBuilder.get_res_info("normal"), cm)
	var gs: TextureRect = ui["go_button_shade"]
	assert_false(gs.visible, "go_button_shade 默认隐藏（源 :1881 visible=false）")
	content.queue_free()


# 照源 LSTR 化（源 :1686 PHYSICAL_EXERTION / :1834 ENEMY_LINEUP / :1848 MAY_BE_OBTAINED / :1807 PURCHASE）。
func test_setup_content_uses_lstr_for_section_labels() -> void:
	var content: Control = _instantiate_content()
	var ui: Dictionary = StageDetailBuilder.setup_content(content, {"stage_type": "normal"}, StageDetailBuilder.get_res_info("normal"), cm)
	assert_eq((ui["power_title"] as Label).text, "体力消耗", "power_title LSTR STAGEDETAIL.PHYSICAL_EXERTION")
	assert_eq((ui["enemy_title"] as Label).text, "敌方阵容", "enemy_title LSTR STAGEDETAIL.ENEMY_LINEUP")
	assert_eq((ui["award_title"] as Label).text, "可能获得", "award_title LSTR STAGEDETAIL.MAY_BE_OBTAINED")
	assert_eq((ui["reset_label"] as Label).text, "购买", "reset_label LSTR EQUIPINFO.PURCHASE")
	content.queue_free()


# 源 :1730 T(LSTR("EXERCISE.REMAINING_TIMES_FOR_TODAY_"), count) — key="今日剩余次数:" + 数字拼接。
func test_setup_content_count_title_lstr_concat_left() -> void:
	var content: Control = _instantiate_content()
	var info: Dictionary = {"stage_type": "normal", "count_limit": 5, "count": 2}
	var ui: Dictionary = StageDetailBuilder.setup_content(content, info, StageDetailBuilder.get_res_info("normal"), cm)
	assert_eq((ui["count_title"] as Label).text, "今日剩余次数:3", "count_title = LSTR + left(5-2=3)")
	content.queue_free()


func test_setup_content_fills_title_and_detail_text() -> void:
	var content: Control = _instantiate_content()
	var info: Dictionary = {"title": "第一章", "detail": "关卡描述", "stage_type": "normal"}
	var ui: Dictionary = StageDetailBuilder.setup_content(content, info, StageDetailBuilder.get_res_info("normal"), cm)
	# Title 节点已删（关卡名改由父面板关卡选择的章节标题栏显示），ui dict 不再含 title 项。
	assert_false(ui.has("title"), "ui dict 不应含 title（节点已删）")
	assert_eq((ui["detail"] as Label).text, "关卡描述", "detail 文本")
	assert_true((ui["detail"] as Label).visible, "detail 非空 → visible")
	content.queue_free()


func test_create_stars_three_with_texture() -> void:
	var parent := Node.new()
	add_child(parent)
	StageDetailBuilder.create_stars(parent, 2, 55)
	assert_eq(parent.get_child_count(), 3, "应建 3 颗星（2 亮 1 暗）")
	var s0: Sprite2D = parent.get_child(0) as Sprite2D
	assert_ne(s0.texture, null, "亮星应加载 detail_star 纹理")
	assert_almost_eq(s0.scale.x, 0.8, 0.01, "星 scale 0.8（源 :1229）")
	parent.queue_free()
