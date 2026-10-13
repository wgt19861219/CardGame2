extends GutTest
# loading 场景守卫测试 — 换正确背景图（icecrown）/ 进度条回屏内照源复刻 /
# 启动公告窗（ActivitiesConfig announcement 同源，2026-10-13 用户指示）。

const LOADING_SCENE: PackedScene = preload("res://scenes/main_menu/loading_scene.tscn")
const SCRIPT: GDScript = preload("res://scenes/main_menu/loading_scene.gd")
const BG_RES: String = "res://assets/ui/lich/bg_icecrown.png"


func _make_scene() -> Control:
	var inst := LOADING_SCENE.instantiate() as Control
	add_child(inst)   # _ready 动态建 UI
	return inst


func test_bg_is_icecrown_covered() -> void:
	var s := _make_scene()
	var tex: Texture2D = s._bg.texture
	assert_eq(tex.resource_path, BG_RES, "背景=icecrown 高清图（原 HVGA bg.jpg 512×308 拉伸模糊）")
	assert_eq(s._bg.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED, "COVERED 等比覆盖裁两侧")
	s.queue_free()


func test_bar_inside_screen_and_sourced() -> void:
	var s := _make_scene()
	var rect: Rect2 = s._bar_bg.get_rect()
	assert_between(rect.position.y, 0.0, 480.0 - rect.size.y, "进度条 y 回屏内（旧 y=580 超屏不可见）")
	assert_between(rect.position.x, 0.0, 800.0 - rect.size.x, "进度条 x 屏内")
	assert_almost_eq(rect.get_center().x, 400.0, 0.5, "条中心 x=400（源 ccp(400,100)）")
	assert_almost_eq(rect.get_center().y, 380.0, 0.5, "条中心 y=380（Cocos 100 → 480-100）")
	assert_almost_eq(rect.size.x, 361.8, 0.6, "条宽 241.2×源 scaleX1.5")
	assert_almost_eq(s._bar_fill.position.x, rect.position.x + 22.2, 0.5, "fill 对齐槽区 x=19px 等比点")
	s.queue_free()


func test_fill_region_crops_with_progress() -> void:
	var s := _make_scene()
	var atlas: AtlasTexture = s._bar_fill.texture
	assert_eq(atlas.region.size.x, 0.0, "初始零宽")
	s._progress = 0.5
	s._refresh_bar()
	assert_almost_eq(atlas.region.size.x, 100.0, 0.5, "半程=槽区半宽（CCRectMake 200×0.5）")
	assert_almost_eq(atlas.region.position.x, 19.0, 0.5, "region 起点 x=19 恒定（裁剪不拉伸）")
	assert_almost_eq(s._bar_fill.size.x, 234.2 * 0.5, 0.5, "显示宽同步半宽（volume_bar 范式）")
	assert_eq(s._label.text, "50%", "百分比文字")
	s.queue_free()


func test_announcement_popup_reads_config() -> void:
	var s := _make_scene()
	s._show_announcement()
	var root: Control = s._announce_root
	assert_ne(root, null, "进度满弹公告窗")
	var data: Dictionary = GameData.config.get_raw_table(&"ActivitiesConfig").get("announcement", {})
	var title: String = String((root.get_node("TitleLabel") as Label).text)
	assert_eq(title, String(data.get("title", "")), "标题来自 ActivitiesConfig announcement")
	var scroll: ScrollContainer = root.get_node("BodyScroll") as ScrollContainer
	assert_true(scroll.clip_contents, "正文区裁切（2026-10-13 用户指示：滚动不出底板）")
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "禁横向滚动，只上下滚")
	var body: String = String((scroll.get_node("BodyLabel") as Label).text)
	assert_eq(body, "%s\n\n%s" % [String(data.get("desc", "")), String(data.get("rules", ""))],
			"正文=desc+rules（与主城活动公告同源）")
	var enter: Button = root.get_node("EnterBtn") as Button
	assert_true(enter.pressed.is_connected(s._on_enter_pressed), "进入按钮已接线切主城")
	var frame: Rect2 = (root.get_node("Frame") as Control).get_rect()
	assert_gt(enter.position.y, frame.position.y + frame.size.y,
			"进入按钮在弹窗外面下方（2026-10-13 用户修正，不压弹窗底板）")
	assert_almost_eq(enter.position.x + enter.size.x * 0.5, frame.get_center().x, 1.0,
			"按钮水平居中于弹窗")
	assert_between(enter.position.y + enter.size.y, 0.0, 480.0, "按钮在屏内")
	s.queue_free()


func test_announcement_fallback_on_empty_table() -> void:
	var cm: ConfigManager = ConfigManager.new()
	cm.load_all()
	cm._tables[&"ActivitiesConfig"] = {}   # 清空公告表 → 兜底默认文案
	var data: Dictionary = cm.get_raw_table(&"ActivitiesConfig").get("announcement", {})
	assert_eq(String(data.get("desc", SCRIPT.DEFAULT_DESC)), SCRIPT.DEFAULT_DESC,
			"空表走默认文案兜底（不弹窗卡死、不空白）")
