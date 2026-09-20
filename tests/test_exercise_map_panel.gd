extends GutTest

# ExerciseMapPanel 旧版试炼地图守卫测试（2026-09-19 经典样式复活；四轮收敛源
# pristine 形态：无背景色块/无名牌/cavern 入口裁剪）。
# ①content 静态树几何（MapLayer 裁剪区/入口点击区 rect 照源 exerciseres center
#   配置/装饰层 mf=2/四轮红线：无 MapBg·无名牌·无 cavern 节点）
# ②panel fill（em/equip 双模式：标题/组显隐/角色 fca 生成数/资源本点击流转）
# ③弹窗组件可用性（DungeonMatrixPopup/ExerciseCavernPopup 组件保留待挂载，
#   直接构造守卫——ExerciseDegreePanel「待入口挂载」同款先例）
# ④双分支互切守卫（源码级：两面板互有对方 open 调用 + 主城/快跳路由走经典地图）

const CONTENT_PATH: String = "res://scenes/ui/exercise_map_content.tscn"
const PANEL_PATH: String = "res://scripts/ui/exercise_map_panel.gd"
const MATRIX_PANEL_PATH: String = "res://scripts/ui/dungeon_matrix_popup.gd"
const CAVERN_PANEL_PATH: String = "res://scripts/ui/exercise_cavern_popup.gd"
const DMAP_PANEL_PATH: String = "res://scripts/ui/dungeon_map_panel.gd"
const MAIN_SCENE_PATH: String = "res://scenes/main_menu/main_scene.gd"
const ROUTER_PATH: String = "res://scripts/ui/main_scene_entry_router.gd"

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_player(level: int = 95) -> PlayerData:
	var pd := PlayerData.new(cm)
	pd.team_level = level
	return pd


func _make_panel(p_mode: String, level: int = 95) -> ExerciseMapPanel:
	var pd := _make_player(level)
	var panel := ExerciseMapPanel.new("exerciseMap", {})
	panel.setup_panel(pd, pd.stage_manager, BattleRng.new(7), p_mode)
	add_child_autofree(panel)
	return panel


# ── ① content 静态树（四轮红线：源 pristine 形态）──

func test_content_static_tree() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	var map_layer: Control = inst.get_node("%MapLayer") as Control
	assert_true(map_layer.clip_contents, "MapLayer 裁剪照源 clipRect (44,20,712,370)")
	assert_almost_eq(map_layer.offset_left, 44.0, 0.1, "裁剪区 x=44 照源")
	assert_almost_eq(map_layer.offset_top, 90.0, 0.1, "裁剪区 y=480-20-370=90 照源")
	assert_almost_eq(map_layer.size.x, 712.0, 0.1, "裁剪区宽 712 照源")
	assert_almost_eq(map_layer.size.y, 370.0, 0.1, "裁剪区高 370 照源")
	# 装饰层 mf=2 不吞点击
	for deco in ["TitleShadow", "Frame", "TitleBg"]:
		var node: Control = inst.get_node(deco) as Control
		assert_eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s 装饰不吞点击" % deco)
	# em 组入口点击区 rect：源 exp center(212,210) r85 → 局部 (83,95)-(253,265)
	var exp_btn: Control = inst.get_node("%ExpBtn") as Control
	assert_almost_eq(exp_btn.offset_left, 83.0, 0.1, "exp 入口局部 x=127-44 照源触摸区")
	assert_almost_eq(exp_btn.offset_top, 95.0, 0.1, "exp 入口局部 y=185-90 照源触摸区")
	assert_almost_eq(exp_btn.size.x, 170.0, 0.1, "exp 入口宽 = 2x85 照源半径")


func test_content_pristine_form_no_plates() -> void:
	# 四轮红线：源 pristine 形态——无背景色块（MapBg）、无名牌（Plate/入口 Label）、
	# 无 cavern 入口节点；互切按钮（SwitchStyleBtn）是唯一保留名牌样式的功能件
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	assert_eq(inst.get_node_or_null("%MapBg"), null, "四轮去背景色块：无 MapBg 节点")
	for uname in ["%ExpBtn", "%MoneyBtn", "%IntBtn", "%AgiBtn", "%StrBtn"]:
		var btn := inst.get_node(uname) as Control
		for child in btn.get_children():
			assert_false(String(child.name).contains("Plate") or String(child.name).ends_with("Label"),
				"资源本入口不得带名牌子节点: %s/%s" % [uname, child.name])
	for uname in ["%EmCavernBtn", "%EquipCavernBtn", "%Dg1Btn"]:
		assert_eq(inst.get_node_or_null(uname), null, "cavern/dg 入口不得回潮: %s" % uname)


# ── ② panel fill 双模式 ──

func test_fill_em_mode() -> void:
	var panel := _make_panel("em")
	assert_eq((panel._content.get_node("%TitleLabel") as Label).text, "时光之穴", "em 页标题")
	assert_true((panel._content.get_node("%EmGroup") as Control).visible, "em 组显示")
	assert_false((panel._content.get_node("%EquipGroup") as Control).visible, "equip 组隐藏")
	assert_eq((panel._content.get_node("%FcaLayer") as Control).get_child_count(), 3,
		"em 页角色数 = exp(NagaPriest+NagaArcher)+money(Tank)")


func test_fill_equip_mode() -> void:
	var panel := _make_panel("equip")
	assert_eq((panel._content.get_node("%TitleLabel") as Label).text, "英雄试炼", "equip 页标题")
	assert_false((panel._content.get_node("%EmGroup") as Control).visible, "em 组隐藏")
	assert_true((panel._content.get_node("%EquipGroup") as Control).visible, "equip 组显示")
	assert_eq((panel._content.get_node("%FcaLayer") as Control).get_child_count(), 5,
		"equip 页角色数 = int(1)+agi(1)+str(3)")


func test_resource_entry_opens_degree_panel() -> void:
	var panel := _make_panel("em")
	var before: int = panel.get_child_count()
	(panel._content.get_node("%ExpBtn") as BaseButton).pressed.emit()
	assert_gt(panel.get_child_count(), before, "点 exp 入口弹 ExerciseDegreePanel")


# ── ③ 弹窗组件可用性（保留待挂载先例守卫）──

func test_matrix_popup_component_usable() -> void:
	# DungeonMatrixPopup 组件保留待挂载（四轮 cavern 入口裁剪）——直接构造守卫
	var mgr := ExerciseManager.new()
	mgr.setup(cm)
	var bosses: Array = mgr.get_dungeon_bosses(50005)
	var popup := DungeonMatrixPopup.new("dungeonMatrix", {})
	popup.setup_popup(bosses, 95, cm)
	add_child_autofree(popup)
	var rows: Array = popup._rows
	assert_eq(rows.size(), 3, "50005 组 3 boss 行")
	assert_eq((rows[0] as Control).get_node("%NameLabel").text, "教官拉苏维奥斯",
		"首行名 lstr（DUNGEON.BOSS_INSTRUCTOR_RAZUVIUS）")
	assert_eq(((rows[0] as Control).get_node("%Cell1/Txt") as Label).modulate,
		DungeonMatrixPopup.DIFF_COLORS[0], "Normal 分色照源 (100,200,100)")


func test_matrix_popup_lock_gray() -> void:
	# 50001 系 UnlockLevel 60，低级(50)整格灰化（源 setSpriteGray）
	var mgr := ExerciseManager.new()
	mgr.setup(cm)
	var bosses: Array = mgr.get_dungeon_bosses(50001)
	var popup := DungeonMatrixPopup.new("dungeonMatrix", {})
	popup.setup_popup(bosses, 50, cm)
	add_child_autofree(popup)
	var cell: Control = (popup._rows[0] as Control).get_node("%Cell1")
	assert_eq(cell.modulate, DungeonMatrixPopup.GRAY_MODULATE, "低等级整格灰化")
	assert_true((cell.get_node("Btn") as Button).disabled, "锁定格 disabled")


func test_cavern_popup_component_usable() -> void:
	# ExerciseCavernPopup 组件保留待挂载——直接构造守卫（3 英雄本中文按钮）
	var pd := _make_player()
	var popup := ExerciseCavernPopup.new("exerciseCavern", {})
	popup.setup_panel(pd)
	add_child_autofree(popup)
	assert_eq((popup._content.get_node("%Dg5Label") as Label).text, "纳克萨玛斯",
		"dg5 名走 Group Name lstr 中文")
	assert_eq((popup._content.get_node("%Dg7Label") as Label).text, "安其拉废墟", "dg7 名 lstr 中文")


# ── ④ 双分支互切与路由守卫（源码级）──

func test_switch_routes_guard() -> void:
	var map_src: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_true(map_src.contains("open_dungeon_groups"), "经典地图面板持有切远征路由")
	assert_true(map_src.contains("SwitchStyleBtn"), "经典地图接线互切按钮")
	assert_false(map_src.contains("CavernPopup"), "四轮 cavern 入口裁剪：panel 不再引用子窗组件")
	var dmap_src: String = FileAccess.get_file_as_string(DMAP_PANEL_PATH)
	assert_true(dmap_src.contains("open_exercise_map"), "远征地图面板持有切经典路由")
	assert_true(dmap_src.contains("ClassicStyleBtn"), "远征地图接线互切按钮")
	var scene_src: String = FileAccess.get_file_as_string(MAIN_SCENE_PATH)
	assert_eq(scene_src.count("open_exercise_map"), 4,
		"主城 defence/exercise + FarmChapter 快跳共 4 处走经典地图")


func test_no_runtime_style_override() -> void:
	# 零运行时样式 override 守卫（add_theme_*_override 禁令，参照 test_exercise_degree 同款红线）
	for path in [PANEL_PATH, MATRIX_PANEL_PATH, CAVERN_PANEL_PATH]:
		var src: String = FileAccess.get_file_as_string(path)
		assert_false(src.contains("add_theme_stylebox_override"), "%s 禁运行时样式套用" % path)


func test_router_helper_guard() -> void:
	var router_src: String = FileAccess.get_file_as_string(ROUTER_PATH)
	assert_true(router_src.contains("static func open_exercise_map"), "router 持有经典地图入口 helper")
	assert_false(router_src.contains("待入口挂载设计拍板"), "资源本入口已挂载（旧拍板注释退役）")
