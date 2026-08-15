extends GutTest
# exercise_panel 试炼入口选择面板测试。
# 两件套范式守卫（批 1 Task 1，2026-08-15）：完整静态树进 exercise_content.tscn
# （框架照源 degreeWindow 直译），panel 只 connect + fill，零静态 .new()。

const ENTRY_TEXTS: Array = ["英雄副本", "装备副本", "经验试炼", "金币试炼", "智力试炼", "敏捷试炼", "力量试炼"]


func test_panel_assembles() -> void:
	var panel := ExercisePanel.new()
	add_child(panel)
	# 两件套（2026-08-15）：chrome 静态化进 exercise_content.tscn；content 顶层
	# Bg/CloseBtn/PanelLayer 3 个；EntryGrid（PanelLayer 下）内 7 个静态入口按钮。
	var content: Node = panel.get_node_or_null("ExerciseContent")
	assert_not_null(content, "content（ExerciseContent）应存在")
	assert_eq(content.get_child_count(), 3, "content 应有 3 个顶层子节点（Bg/CloseBtn/PanelLayer）")
	var grid: Node = content.get_node_or_null("%EntryGrid")
	assert_not_null(grid, "EntryGrid 应存在")
	assert_eq(grid.get_child_count(), ExercisePanel.ENTRY_KEYS.size(), "EntryGrid 应有 7 个静态入口按钮")
	panel.queue_free()


func test_content_static_tree() -> void:
	# 框架层照源 degreeWindow.create(exercise.lua:694-786) 直译：
	# 蒙层 ccc4(0,0,0,150) / frame main_vit_tips 705x300 中心(400,220) / close 中心(750,350)。
	var scene: PackedScene = load("res://scenes/ui/exercise_content.tscn")
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	var layer: Control = inst.get_node("%PanelLayer") as Control
	assert_not_null(layer, "PanelLayer（源 frame 等价）常驻 tscn")
	assert_almost_eq(layer.offset_left, 127.5, 0.1, "frame 左 = to_godot(400,220).x - 705/2")
	assert_almost_eq(layer.offset_top, 190.0, 0.1, "frame 顶 = 560 - (220 + 300/2)")
	assert_almost_eq(layer.size.x, 705.0, 0.1, "frame 宽照源 scaleSize 705")
	assert_almost_eq(layer.size.y, 300.0, 0.1, "frame 高照源 scaleSize 300")
	var frame: NinePatchRect = layer.get_node("Frame") as NinePatchRect
	assert_not_null(frame, "Frame（main_vit_tips 九宫格底）常驻 tscn")
	assert_not_null(frame.texture, "Frame 贴图已接线")
	var bg: ColorRect = inst.get_node("Bg") as ColorRect
	assert_almost_eq(bg.color.a, 150.0 / 255.0, 0.01, "蒙层 alpha 照源 ccc4(0,0,0,150)")
	var close: TextureButton = inst.get_node("%CloseBtn") as TextureButton
	assert_not_null(close, "关闭按钮常驻 tscn")
	assert_almost_eq((close.offset_left + close.offset_right) / 2.0, 830.0, 0.5,
		"close 中心 x 照源 to_godot(750,350).x")
	assert_almost_eq((close.offset_top + close.offset_bottom) / 2.0, 210.0, 0.5,
		"close 中心 y 照源 to_godot(750,350).y")


func test_content_title_variation() -> void:
	# 标题照源 title（exercise.lua:764-776）：fontinfo ui_normal_button(17 号+暗红阴
	# 影(63,5,0)) + config color ccc3(231,206,19)，走 theme variation 而非节点 override。
	# 注：variation 数值断言走 theme 资源表项——节点级 get_theme_font_size 不解析
	# variation（GUT 环境实测 ShopTitleLabel 同样回落 Label 默认 16，项目惯例只断言名字）。
	var scene: PackedScene = load("res://scenes/ui/exercise_content.tscn")
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	var title: Label = inst.get_node("%Title") as Label
	assert_not_null(title, "标题常驻 tscn")
	assert_eq(title.theme_type_variation, &"ExerciseTitleLabel", "标题走 ExerciseTitleLabel variation")
	var theme: Theme = load("res://resources/themes/default_theme.tres") as Theme
	assert_eq(theme.get_theme_item(Theme.DATA_TYPE_FONT_SIZE, "font_size", "ExerciseTitleLabel"), 17,
		"标题字号 17 照源 ui_normal_button")
	assert_eq((theme.get_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "ExerciseTitleLabel") as Color),
		Color(0.906, 0.808, 0.075), "标题金色照源 ccc3(231,206,19)")


func test_content_entry_buttons_static() -> void:
	# 7 入口按钮静态进 tscn：文字照聚合层语义，样式走 ExerciseEntryButton variation。
	var scene: PackedScene = load("res://scenes/ui/exercise_content.tscn")
	var inst: Control = scene.instantiate() as Control
	add_child_autofree(inst)
	var grid: GridContainer = inst.get_node("%EntryGrid") as GridContainer
	assert_eq(grid.get_child_count(), 7, "7 入口按钮静态进 tscn")
	for i in grid.get_child_count():
		var btn := grid.get_child(i) as Button
		assert_eq(btn.text, String(ENTRY_TEXTS[i]), "按钮 %d 文字照入口语义" % i)
		assert_eq(btn.theme_type_variation, &"ExerciseEntryButton", "入口按钮 %d 走 variation" % i)


func test_panel_no_static_construction() -> void:
	# 两件套红线：panel 零静态 .new()（仅动态立绘 AtlasSprite/FcaAnimation 白名单）。
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/exercise_panel.gd")
	assert_eq(text.count(".new()"), text.count("AtlasSprite.new()") + text.count("FcaAnimation.new()"),
		"静态节点零 .new()，仅动态立绘白名单")


func test_entry_keys_complete() -> void:
	# 7 个入口
	assert_eq(ExercisePanel.ENTRY_KEYS.size(), 7, "应有 7 个入口")
	var keys: Array = []
	for e in ExercisePanel.ENTRY_KEYS:
		keys.append(e.key)
	assert_true(keys.has("em"), "应有 em（英雄副本）")
	assert_true(keys.has("equip"), "应有 equip（装备副本）")
	assert_true(keys.has("str"), "应有 str（力量试炼）")
	assert_true(keys.has("agi"), "应有 agi（敏捷试炼）")
	assert_true(keys.has("int"), "应有 int（智力试炼）")
	assert_true(keys.has("exp"), "应有 exp（经验试炼）")
	assert_true(keys.has("money"), "应有 money（金币试炼）")


var _cb_key: String = ""
var _cb_groups: Array = []

func test_entry_callback() -> void:
	var panel := ExercisePanel.new()
	add_child(panel)
	_cb_key = ""; _cb_groups = []
	panel.set_entry_callback(_on_test_callback)
	panel._on_entry_pressed(ExercisePanel.ENTRY_KEYS[0])
	assert_eq(_cb_key, "em", "回调应收到 key=em")
	assert_eq(_cb_groups.size(), 3, "em 应有 3 个 group")
	panel.queue_free()

func _on_test_callback(key: String, groups: Array) -> void:
	_cb_key = key; _cb_groups = groups


func test_entry_button_signal_fill() -> void:
	# fill 链路端到端：静态按钮 pressed → panel bind 分发 → 回调收到 (key, groups)。
	var panel := ExercisePanel.new()
	add_child(panel)
	_cb_key = ""; _cb_groups = []
	panel.set_entry_callback(_on_test_callback)
	var content: Control = panel.get_node("ExerciseContent") as Control
	(content.get_node("%EmBtn") as BaseButton).pressed.emit()
	assert_eq(_cb_key, "em", "EmBtn pressed 应回调 key=em")
	assert_eq(_cb_groups, [50005, 50006, 50007], "EmBtn 应携带英雄副本 groups")
	panel.queue_free()


func test_em_groups() -> void:
	var entry: Dictionary = ExercisePanel.ENTRY_KEYS[0]
	assert_eq(entry.groups, [50005, 50006, 50007], "em 应映射英雄副本 50005-7")


func test_equip_groups() -> void:
	var entry: Dictionary = ExercisePanel.ENTRY_KEYS[1]
	assert_eq(entry.groups, [50001, 50002, 50003, 50004], "equip 应映射装备副本 50001-4")


func test_resource_trial_groups() -> void:
	# str=20005, agi=20004, int=20003, exp=20001, money=20002
	var by_key: Dictionary = {}
	for e in ExercisePanel.ENTRY_KEYS:
		by_key[e.key] = e
	assert_eq(by_key.str.groups, [20005], "str→20005")
	assert_eq(by_key.agi.groups, [20004], "agi→20004")
	assert_eq(by_key.int.groups, [20003], "int→20003")
	assert_eq(by_key.exp.groups, [20001], "exp→20001")
	assert_eq(by_key.money.groups, [20002], "money→20002")
