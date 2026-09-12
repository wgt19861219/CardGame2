extends GutTest

# ExerciseDegreePanel 资源副本难度弹窗守卫测试（2026-09-12 修走错组件）。
# 照源 exercise.lua degreeWindow.create(:692-770) + createDegree(:449-560)：
# ①content 静态树几何（frame 705x300 中心(400,220) / 4 槽 ox=97 dx=170 oy=140 /
#   vit 行 y=45 / title y=95——frame 局部左下原点直译 y'=300-y，口径同
#   dungeon_degree_popup 批 3 定稿）
# ②panel fill（get_stages 数据 / 解锁灰化 / 次数行）
# ③Logic 计次（check_enter_act_group：组键共享 DailyLimit / 用尽拒绝 / 跨组隔离）
# ④路由分流守卫（main_scene exp 系走 degree、em/equip 走 dungeon_map）

const CONTENT_PATH: String = "res://scenes/ui/exercise_degree_content.tscn"
const PANEL_PATH: String = "res://scripts/ui/exercise_degree_panel.gd"
# 难度按钮显示尺寸 = act_select_bg 221x195px ÷ CS(1.28125) = 172.49x152.20。
const BTN_W: float = 172.49
const BTN_H: float = 152.20

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_player(level: int = 100) -> PlayerData:
	var pd := PlayerData.new(cm)
	pd.team_level = level
	return pd


# ── ① content 静态树（源 :705-720 frame / createDegree 槽位）──

func test_content_static_tree() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	var layer: Control = inst.get_node("%PanelLayer") as Control
	assert_almost_eq(layer.offset_left, 47.5, 0.1, "frame 左 = to_godot(400,220).x - 705/2")
	assert_almost_eq(layer.offset_top, 110.0, 0.1, "frame 顶 = 480 - (220 + 300/2)")
	assert_almost_eq(layer.size.x, 705.0, 0.1, "frame 宽照源 scaleSize 705")
	assert_almost_eq(layer.size.y, 300.0, 0.1, "frame 高照源 scaleSize 300")
	var title: Label = inst.get_node("%Title") as Label
	assert_eq(title.text, "选择难度", "标题静态文案（源 EXERCISE.PLEASE_SELECT_DIFFICULTY_LEVEL）")
	assert_eq(title.theme_type_variation, &"ExerciseTitleLabel", "标题复用 ExerciseTitleLabel")

func test_content_slot_positions() -> void:
	# 源 createDegree(:481-560) ox=97 dx=170 oy=140（frame 局部左下原点）→ Godot 局部
	# 中心 (97+170*(i-1), 300-140=160)。
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	for i in range(1, 5):
		var btn: TextureButton = inst.get_node("%Slot" + str(i)) as TextureButton
		assert_not_null(btn.texture_normal, "槽 %d 贴图接线" % i)
		assert_almost_eq((btn.offset_left + btn.offset_right) / 2.0, 97.0 + 170.0 * (i - 1), 0.5,
			"槽 %d 中心 x 照源 ox=97 dx=170" % i)
		assert_almost_eq((btn.offset_top + btn.offset_bottom) / 2.0, 160.0, 0.5,
			"槽 %d 中心 y 照源 oy=140 → 局部 160" % i)
		assert_almost_eq(btn.size.x, BTN_W, 0.5, "槽 %d 宽 = act_select_bg 221px÷CS" % i)
		assert_almost_eq(btn.size.y, BTN_H, 0.5, "槽 %d 高 = act_select_bg 195px÷CS" % i)
		var title: Label = inst.get_node("%Slot" + str(i) + "Title") as Label
		assert_almost_eq((title.offset_top + title.offset_bottom) / 2.0, 205.0, 0.5,
			"槽 %d 标题 y 照源 oy-45=95 → 局部 205" % i)

func test_content_vit_row_positions() -> void:
	# 源 vit 行 y=45 → 局部 255；vit_bg act_comment_bg 182x44px÷CS=142.05x34.34。
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	for i in range(1, 5):
		var vit_bg: TextureRect = inst.get_node("PanelLayer/Slot%dVitBg" % i) as TextureRect
		assert_almost_eq((vit_bg.offset_top + vit_bg.offset_bottom) / 2.0, 255.0, 0.5,
			"槽 %d 体力行 y 照源 ly=45 → 局部 255" % i)
		assert_almost_eq(vit_bg.size.x, 142.05, 0.5, "vit_bg 宽 = act_comment_bg 182px÷CS")
		var vit_num: Label = inst.get_node("%Slot" + str(i) + "VitNum") as Label
		var num_cx: float = (vit_num.offset_left + vit_num.offset_right) / 2.0
		var slot_cx: float = 97.0 + 170.0 * (i - 1)
		assert_true(num_cx < slot_cx, "槽 %d 数字在中心左侧（源 anchor(1,0.5) x-5）" % i)

func test_content_decoration_mouse_filter() -> void:
	# 装饰节点（icon/vit 行）禁吞点击红线。
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	for i in range(1, 5):
		var icon: TextureRect = inst.get_node("%Slot" + str(i) + "Icon") as TextureRect
		assert_eq(icon.mouse_filter, Control.MOUSE_FILTER_IGNORE, "槽 %d icon 不吞点击" % i)


# ── ② panel fill ──

func test_panel_fill_unlock_and_lock() -> void:
	# team_level=30：难度 1（Unlock 10）解锁、难度 2（Unlock 30）解锁、难度 3/4（50/70）锁定。
	var pd := _make_player(30)
	var panel := ExerciseDegreePanel.new("exerciseDegree", {})
	panel.setup_panel("exp", pd, pd.stage_manager)
	add_child_autofree(panel)
	assert_eq(panel._slot_titles[0].text, "难度 I", "解锁槽标题")
	assert_eq(panel._slot_titles[2].text, "Lv 50", "锁定槽标题显示解锁等级（源 lock 图缺失的文字替代）")
	assert_eq(panel._slot_btns[0].modulate, Color(1, 1, 1, 1), "解锁槽不灰化")
	assert_ne(panel._slot_btns[2].modulate, Color(1, 1, 1, 1), "锁定槽灰化（源 setSpriteGray）")
	# vit fill：exp 组四难度 Vitality Cost 均 6（Stage 表实测）。
	assert_eq((panel._content.get_node("%Slot1VitNum") as Label).text, "6", "槽 1 体力照 Stage 表")
	# 次数行：ActStageGroup 20001 DailyLimit=2。
	assert_eq((panel._content.get_node("%TimesNumber") as Label).text, "2", "剩余次数照 DailyLimit")

func test_panel_fill_times_exhausted() -> void:
	# 用满 DailyLimit（20001 组 2 次）→ 次数用尽文案。
	var pd := _make_player(100)
	pd.stage_manager.act_times[20001] = 2
	var panel := ExerciseDegreePanel.new("exerciseDegree", {})
	panel.setup_panel("exp", pd, pd.stage_manager)
	add_child_autofree(panel)
	assert_eq((panel._content.get_node("%TimesTitle") as Label).text, "今日次数已用完",
		"次数用尽换文案（源 :344-352）")

func test_panel_no_static_construction() -> void:
	# 两件套红线：panel 零静态 .new()（ExerciseManager/StageDetailPanel/BattleRng 属
	# 动态查询与跳转白名单）。
	var text: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_eq(text.count(".new("),
		text.count("ExerciseManager.new(") + text.count("StageDetailPanel.new(") + text.count("BattleRng.new("),
		"静态节点零 .new(，仅查询/跳转白名单")


# ── ③ Logic 计次（StageDungeonLogic.check_enter_act_group）──

func test_act_group_counts_and_rejects() -> void:
	# 20001 组 DailyLimit=2：两次放行并计次，第三次拒绝。
	var mgr := StageManager.new(cm)
	assert_eq(StageDungeonLogic.check_enter_act_group(mgr, 20001, cm), "", "第 1 次放行")
	assert_eq(StageDungeonLogic.check_enter_act_group(mgr, 21001, cm), "", "第 2 次放行（难度 2 同组共享）")
	assert_eq(int(mgr.act_times.get(20001, 0)), 2, "组键 20001 计 2 次（四难度同键）")
	assert_eq(StageDungeonLogic.check_enter_act_group(mgr, 23001, cm), "no_attempts", "第 3 次拒绝")

func test_act_group_isolated_between_groups() -> void:
	# 20001 组（Limit 2）用满不影响 20003 组（Limit 5）。
	var mgr := StageManager.new(cm)
	mgr.act_times[20001] = 2
	assert_eq(StageDungeonLogic.check_enter_act_group(mgr, 20003, cm), "", "跨组互不影响")

func test_assemble_stage_battle_counts_act_group() -> void:
	# 端到端：assemble 进战斗即计次（View 战斗走本入口）。
	var pd := _make_player(100)
	var tids: Array[int] = [1]
	var rng := BattleRng.new(7)
	var r1: Dictionary = pd.stage_manager.assemble_stage_battle(20001, pd, tids, rng)
	assert_true(bool(r1.get("ok", false)), "首次装配成功")
	assert_eq(int(pd.stage_manager.act_times.get(20001, 0)), 1, "装配计次 1")
	pd.stage_manager.act_times[20001] = 2   # 直接用满（避免跑两次完整战斗）
	var r2: Dictionary = pd.stage_manager.assemble_stage_battle(20001, pd, tids, rng)
	assert_false(bool(r2.get("ok", false)), "组次数用尽装配拒绝")
	assert_eq(str(r2.get("error", "")), "no_attempts", "拒绝错误码")


# ── ④ 路由直连守卫（2026-09-12 二轮：占位弹窗退役，主城建筑照源直连 dungeon 地图）──

func test_main_scene_routes_direct() -> void:
	# 主城 defence（时光之穴建筑）/exercise（英雄试炼建筑）直连 dungeon 地图
	# （照源 main.lua:1330/:1448 → exercise.create 终版直转 dungeon_map），无中间弹窗。
	var text: String = FileAccess.get_file_as_string("res://scenes/main_menu/main_scene.gd")
	assert_true(text.contains("\"defence\":") and text.contains("open_dungeon_groups(self, \"em\", [50005, 50006, 50007])"),
		"defence（时光之穴）应直连 em 地图 50005-7")
	assert_true(text.contains("\"exercise\":") and text.contains("open_dungeon_groups(self, \"equip\", [50001, 50002, 50003, 50004])"),
		"exercise（英雄试炼）应直连 equip 地图 50001-4")
	assert_false(text.contains("MainSceneEntryRouter.open_exercise_panel"), "占位聚合弹窗应退役（无 router 调用）")
	var router: String = FileAccess.get_file_as_string("res://scripts/ui/main_scene_entry_router.gd")
	assert_false(router.contains("static func open_exercise_panel"), "router 不应再有占位弹窗入口")
	assert_true(router.contains("static func open_exercise_degree"), "资源试炼弹窗入口 helper 保留")
