extends GutTest
# Crusade UI 守卫测试（2026-07-02 初建；2026-07-17 .tscn 重构；2026-08-16 批 3 Task 7
# 两件套改造重写：格子照源散点（HBox 均排退役）+ fog 归源（scale=4 等比）+ 美术层/
# 规则页静态进 tscn + builder/rule_renderer 退役）。用例 18→28 不缩水（第二轮验收
# +2：两态贴图归源 + hint box 分支）。

const BUILDER_PATH: String = "res://scripts/ui/crusade_panel_builder.gd"
const RENDERER_PATH: String = "res://scripts/ui/crusade_rule_renderer.gd"
const PANEL_PATH: String = "res://scripts/ui/crusade_panel.gd"
# 源 crusadeconfig.lua fog：640×127px Prescaled=false 口径 ÷CS×4.0 = 1998.05×396.49
# （ratio 5.039 = 源等比；旧 230×90 ratio 2.56 是 A 类纵横比债）。
const CS: float = 1.28125
const FOG_SIZE: Vector2 = Vector2(640.0 / CS * 4.0, 127.0 / CS * 4.0)

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_panel(root: Node, seed_val: int = 12345) -> CrusadePanel:
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var panel := CrusadePanel.new("crusade", {})
	panel.setup_panel(pd, BattleRng.new(seed_val))
	panel.show_window(root)
	return panel


func test_panel_assembles() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	assert_eq(panel.container.get_child_count(), 1, "container 仅挂 content（.tscn 根）")
	var content: Node = panel.container.get_child(0)
	# content 19 直接子（源 z 序直译：Scroll → Light1/2 → Frame → TitleBg → Title →
	# BottomFrame → RuleBtn/ResetBtn/LefttimeLabel/ShopBtn/DragonIcon → CloseBtn →
	# EnemyPreviewHost/StartBtn/ResultLabel（项目适配）→ HintAnchor → RuleLayer）。
	assert_eq(content.get_child_count(), 19, "content 19 直接子（静态层 + 项目适配层）")
	assert_eq(panel.fog_rects.size(), 4, "4 fog（tscn 静态，instantiate 后收集）")
	assert_eq(panel.stage_buttons.size(), CrusadeData.MAX_STAGE, "15 stage 按钮")
	assert_eq(panel.box_rects.size(), CrusadeData.MAX_STAGE, "15 box 按钮（源 :311）")
	for i in range(panel.box_rects.size()):
		assert_true(panel.box_rects[i] is TextureButton, "box 是 TextureButton 可点（源 :311）")
	panel.remove_window()
	root.queue_free()


# 静态美术层（批 3 Task 7）：bg 三段/frame/light×2/title_bg/title/reset_bg 全静态进
# tscn（原 CrusadePanelBuilder procedural 退役）；fog 四张照源归位（scale=4 等比 +
# 叠层挂滚动内容随格滚动）。
func test_static_art_layers_present() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	var content: Control = panel.container.get_child(0) as Control
	for node_name in ["Light1", "Light2", "Frame", "TitleBg", "Title"]:
		var tr: TextureRect = content.get_node("%" + node_name) as TextureRect
		assert_not_null(tr, "%s 静态美术层存在" % node_name)
		if tr != null:
			assert_not_null(tr.texture, "%s 纹理非空" % node_name)
			assert_eq(tr.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s mouse_filter=IGNORE" % node_name)
	# BottomFrame 是 NinePatchRect（源 Scale9Sprite cap 直译）。
	var bottom_frame: NinePatchRect = content.get_node("%BottomFrame") as NinePatchRect
	assert_not_null(bottom_frame.texture, "BottomFrame 纹理非空（75×75px cap L20/T37/R37/B20）")
	assert_eq(bottom_frame.mouse_filter, Control.MOUSE_FILTER_IGNORE, "BottomFrame mouse_filter=IGNORE")
	# bg 三段 + fog 四张挂 ScrollContent（= 源 dragContainer，随滚动）。
	var scroll_content: Control = content.get_node("%ScrollContent") as Control
	var tex_count: int = 0
	for c in scroll_content.get_children():
		if c is TextureRect:
			tex_count += 1
	assert_eq(tex_count, 7, "ScrollContent 内 7 TextureRect（Bg1-3 + Fog4/3/2/1，静态）")
	panel.remove_window()
	root.queue_free()


# fog 归源守卫（批 3 Task 7 核心）：四张同 rect 叠放（源 pos 全 (25,210)）+ 尺寸
# 1998.05×396.49（640×127÷CS×4 等比，ratio≈5.04）+ 声明序 fog4 底 fog1 顶（源 z 序）。
func test_fog_source_ratio_and_stacking() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	var content: Control = panel.container.get_child(0) as Control
	var scroll_content: Control = content.get_node("%ScrollContent") as Control
	for i in range(1, 5):
		var fog: TextureRect = scroll_content.get_node("%Fog" + str(i)) as TextureRect
		assert_not_null(fog, "Fog%d 挂 ScrollContent（源 dragContainer 直属）" % i)
		if fog == null:
			continue
		assert_almost_eq(fog.size.x, FOG_SIZE.x, 0.5, "Fog%d 宽 =640/CS×4（源 scale=4.0 等比）" % i)
		assert_almost_eq(fog.size.y, FOG_SIZE.y, 0.5, "Fog%d 高 =127/CS×4（ratio 5.04 归源）" % i)
		assert_almost_eq(fog.position.x, 25.0, 0.01, "Fog%d x=25（源 anchor(0,0.5) pos(25,·)）" % i)
		assert_almost_eq(fog.position.y, 4.63, 0.01, "Fog%d y=4.63（源 y=210 中心线映射）" % i)
	# 源声明序 fog4→fog1（后声明 z 上）：fog1 绘制序在 fog4 之上（迷雾分层消散）。
	var fog4: Node = scroll_content.get_node("%Fog4")
	var fog1: Node = scroll_content.get_node("%Fog1")
	assert_gt(fog1.get_index(), fog4.get_index(), "Fog1 绘制序高于 Fog4（源 z 序 fog4 底 fog1 顶）")
	panel.remove_window()
	root.queue_free()


# 源 crusade.lua:628-650 clipNode：bgframe 803.12×441.75 中心 (400,210) 内缩
# L18/R28/T18/B18 → cocos 视口 (16.44,7.12)-(773.56,412.88) → Godot 直译。
func test_scroll_clip_rect_matches_source() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	var content: Control = panel.container.get_child(0) as Control
	var scroll: ScrollContainer = content.get_node("%Scroll") as ScrollContainer
	var r: Rect2 = scroll.get_rect()
	assert_almost_eq(r.position.x, 16.44, 0.01, "clip 视口 x=16.44+80（源 insetL 18）")
	assert_almost_eq(r.position.y, 67.12, 0.01, "clip 视口 y=560-412.88（源 insetT 18）")
	assert_almost_eq(r.size.x, 757.12, 0.01, "clip 视口宽 =803.12-18-28（源 clipW）")
	assert_almost_eq(r.size.y, 405.76, 0.01, "clip 视口高 =441.75-18-18（源 clipH）")
	assert_eq(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "纵向禁滚（源仅横向拖拽）")
	panel.remove_window()
	root.queue_free()


# 源 laftMap/rightMap/rightMap2 空容器中心 (25,12)/(752,12)/(1477,12)（dragContainer 局部）
# → ScrollContent 原点 (x, 412.88-12=400.88)；格子/宝箱 fill 挂 Map 内散点布置。
func test_map_origins() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	var scroll_content: Control = (panel.container.get_child(0) as Control).get_node("%ScrollContent") as Control
	var expects := [Vector2(25.0, 400.88), Vector2(752.0, 400.88), Vector2(1477.0, 400.88)]
	for i in range(3):
		var map_node: Control = scroll_content.get_node("%" + ["LaftMap", "RightMap", "RightMap2"][i]) as Control
		assert_almost_eq(map_node.position.x, expects[i].x, 0.01, "Map%d x 原点" % (i + 1))
		assert_almost_eq(map_node.position.y, expects[i].y, 0.01, "Map%d y 原点（源 y=12 映射）" % (i + 1))
	panel.remove_window()
	root.queue_free()


# 格子照源散点（源 crusadeconfig battle1-15 中心锚 + 各图尺寸各异 px/CS）：
# battle1 (135,260) 239×213px、battle10 (584,145) 207×216px、battle11 (30,265) 207×169px。
func test_stage_buttons_scatter_positions() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	var b1: TextureButton = panel.stage_buttons[0]
	var b10: TextureButton = panel.stage_buttons[9]
	var b11: TextureButton = panel.stage_buttons[10]
	assert_almost_eq(b1.size.x, 239.0 / CS, 0.5, "battle1 宽 =239px/CS（逐图实测）")
	assert_almost_eq(b1.size.y, 213.0 / CS, 0.5, "battle1 高 =213px/CS")
	assert_almost_eq(b10.size.x, 207.0 / CS, 0.5, "battle10 宽 =207px/CS")
	assert_almost_eq(b11.size.y, 169.0 / CS, 0.5, "battle11 高 =169px/CS")
	# battle1 左上 = LaftMap 局部 (135-93.22, -260-83.12)（position 相对直接父 Map，
	# Map 原点在 ScrollContent (25,400.88)，cocos y 上正→Godot 负）。
	assert_almost_eq(b1.position.x, 135.0 - 239.0 / CS / 2.0, 0.5, "battle1 局部 x（源 laftMap 局部 135）")
	assert_almost_eq(b1.position.y, -260.0 - 213.0 / CS / 2.0, 0.5, "battle1 局部 y（源局部 260）")
	# battle11 挂 RightMap2（源 parent=rightMap2，段 3）。
	var rm2: Node = b11.get_parent()
	assert_eq(rm2.name, "RightMap2", "battle11 挂 RightMap2（源 parent）")
	panel.remove_window()
	root.queue_free()


# 宝箱照源（box 中心锚 scale=0.8，box5 silver/box15 gold 各档贴图）。
func test_box_positions_and_sizes() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	var box1: TextureButton = panel.box_rects[0]
	var box5: TextureButton = panel.box_rects[4]
	var box15: TextureButton = panel.box_rects[14]
	# bronze_closed 89×84px ÷CS×0.8；silver/gold_closed 90×84px。
	assert_almost_eq(box1.size.x, 89.0 / CS * 0.8, 0.5, "box1 宽 =89px/CS×0.8（bronze）")
	assert_almost_eq(box5.size.x, 90.0 / CS * 0.8, 0.5, "box5 宽 =90px/CS×0.8（silver）")
	assert_almost_eq(box15.size.y, 84.0 / CS * 0.8, 0.5, "box15 高 =84px/CS×0.8（gold）")
	assert_almost_eq(box5.position.x, -10.0 - 90.0 / CS * 0.8 / 2.0, 0.5, "box5 局部 x（RightMap 局部 -10）")
	assert_eq(box5.get_parent().name, "RightMap", "box5 挂 RightMap（源 parent）")
	assert_eq(box15.get_parent().name, "RightMap2", "box15 挂 RightMap2（源 parent）")
	panel.remove_window()
	root.queue_free()


func test_stage_n_runs() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	panel._on_stage_n(1)
	assert_true(panel.result_label.text.length() > 0, "_on_stage_n 更新 result")
	panel.remove_window()
	root.queue_free()


# 源 crusade.lua:431-441 start() pushScene battleprepare（mode=crusade + heroLimit 20）。
func test_start_opens_battle_prepare_mode_crusade() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var h1: HeroInstance = pd.hero_manager.get_hero(pd.hero_manager.heroes.keys()[0])
	if h1 != null: h1.level = 20   # 满足 heroLimit level=20
	var panel := CrusadePanel.new("crusade", {})
	panel.setup_panel(pd, BattleRng.new(1))
	panel.show_window(root)
	panel._on_stage_n(1)   # 选第 1 关
	var before: int = root.get_child_count()
	panel._on_start_pressed()
	assert_eq(root.get_child_count(), before + 1, "_on_start 弹 BattlePreparePanel")
	var bp: Node = root.get_child(before)
	assert_true(bp is BattlePreparePanel, "弹出的是 BattlePreparePanel")
	assert_eq((bp as BattlePreparePanel).mode, "crusade", "mode=crusade（源 crusade.lua:435）")
	assert_eq((bp as BattlePreparePanel).min_level, 20, "min_level=20（源 :436 heroLimit detail）")
	assert_eq((bp as BattlePreparePanel).stage_id, -3, "stage_id=-2-1=-3（源 :432 stageId=-2-currentStage）")
	assert_false(panel.start_btn.visible, "start_btn 隐藏（源 :440 battleLayer setVisible(false)）")
	(bp as BattlePreparePanel).queue_free()
	panel.remove_window()
	root.queue_free()


# crusade 战斗结束（同步）通过 crusade_battle_finished 信号回调刷新面板。
func test_crusade_battle_finished_refreshes_label() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root, 1)
	panel._on_crusade_battle_finished(true, 3)
	assert_true(panel.result_label.text.contains("胜利"), "won → result_label 含\"胜利\"")
	panel._on_crusade_battle_finished(false, 5)
	assert_true(panel.result_label.text.contains("失败"), "lost → result_label 含\"失败\"")
	panel.remove_window()
	root.queue_free()


# 源选关交互：点 stage → 选中 + 敌方预览 + 显 start（源 :206）。
func test_stage_n_selects_and_shows_preview() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	assert_false(panel.start_btn.visible, "未选关 start_btn 隐藏（源 :204）")
	panel._on_stage_n(1)
	assert_eq(panel.current_select, 1, "_on_stage_n 选中第 1 关")
	assert_true(panel.start_btn.visible, "选关后 start_btn 显示（源 :206）")
	assert_gt(panel.enemy_preview_box.get_child_count(), 0, "选关后敌方预览渲染（源 :224）")
	panel.remove_window()
	root.queue_free()


# Task 9 验收修复守卫：实跑序（setup_panel 先于 show_window，router:115）下，
# 离树赋值 scroll_horizontal 会被 HScrollBar 默认 max_value=100 钳制且进树后不
# 恢复（修复前 cur=10 期望 1150 落在 100 → 镜头错段、第一关图标滚出视口被误读
# 为被雾盖住）。修复 = 进树 + 首帧布局后重放。fog 层序照源不改（crusadeconfig
# UIRes fog4-1 声明在 Map 之后；PIL 实测 fog1 纹理左缘 0-80px 全透明，透明前缘
# 内容 x≈274.7 让出 battle1 右缘 253.25——cur=1 第一关清晰可见是源语义）。
func test_initial_scroll_survives_enter_tree() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	pd.crusade_manager.cur_stage = 10
	var panel := CrusadePanel.new("crusade", {})
	panel.setup_panel(pd, BattleRng.new(1))
	panel.show_window(root)
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll: ScrollContainer = (panel.container.get_child(0) as Control).get_node("%Scroll") as ScrollContainer
	assert_eq(scroll.scroll_horizontal, 1150, "cur=10 镜头 1150（源 (10-4)×50+450+400，进树重放生效）")
	assert_almost_eq(scroll.get_h_scroll_bar().max_value, 2023.05, 0.01, "scrollbar range 已展开到内容宽（布局完成）")
	panel.remove_window()
	root.queue_free()


# 源 crusade.lua:91 shakeBox 定时器（1.5s 周期，上一关 box 弹跳）。
func test_shake_timer_created() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	assert_not_null(panel._shake_timer, "shake timer 创建（源 :91）")
	if panel._shake_timer != null:
		assert_false(panel._shake_timer.is_stopped(), "shake timer 启动（1.5s 周期）")
	panel.remove_window()
	root.queue_free()


# 超进度不可选（源 refreshBattleState :324-325）。
func test_stage_beyond_progress_not_selectable() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root, 1)
	panel._on_stage_n(5)
	assert_eq(panel.current_select, 0, "超进度关卡不可选中")
	assert_true(panel.result_label.text.contains("未解锁"), "超进度提示未解锁")
	panel.remove_window()
	root.queue_free()


# 重置次数耗尽（源 resetBattle :660-661 leftTime<=0 toast）。
func test_reset_exhausted_blocked() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root, 1)
	for i in range(11):
		panel.player.crusade_manager.reset()
	panel._on_reset()
	assert_true(panel.result_label.text.contains("没有重置"), "重置次数耗尽被拦（源 LSTR）")
	panel.remove_window()
	root.queue_free()


# 超进度按钮 disabled 灰显（源 :329 enable(false) 视觉禁）。
func test_stage_disabled_beyond_progress() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root, 1)
	assert_true(panel.stage_buttons[4].disabled, "第 5 关超进度 disabled（源 :329）")
	assert_false(panel.stage_buttons[0].disabled, "第 1 关当前关 enabled")
	panel.remove_window()
	root.queue_free()


# reset 弹确认框（源 :665-679 showConfirmDialog → CrusadeResetConfirm 组件，接口勿破坏）。
func test_reset_shows_confirm_dialog() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root, 1)
	var before: int = panel.container.get_child_count()
	panel._on_reset()
	assert_eq(panel.container.get_child_count(), before + 1, "reset 弹确认框")
	var popup: Node = panel.container.get_child(before)
	assert_true(popup is CrusadeResetConfirm, "确认框是 CrusadeResetConfirm")
	popup.queue_free()
	panel.remove_window()
	root.queue_free()


# currentStageHint 导航箭头（源 refreshHintPos :298-323 + 浮动 :614-619）。
# 第二轮验收归源：hint anchor(0.5,0) 底部中心 = target 中心 + (offsetX,+30 cocos 上方)
# → Godot HintAnchor（零尺寸锚=箭头底边中心）global = battle1 全局中心 + (0,-30)。
func test_stage_hint_created_and_points_current() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	assert_not_null(panel.stage_hint, "导航箭头创建（源 currentStageHint）")
	if panel.stage_hint != null and panel.stage_hint is TextureRect:
		var hint_tex: TextureRect = panel.stage_hint as TextureRect
		assert_not_null(hint_tex.texture, "箭头纹理化 stagepointer.png")
	assert_true(panel._hint_anchor.visible, "首关箭头指向当前关（源 :306）")
	if panel.stage_buttons.size() > 0:
		var btn_center: Vector2 = panel.stage_buttons[0].get_global_rect().get_center()
		var anchor: Vector2 = panel._hint_anchor.global_position
		assert_almost_eq(anchor.x, btn_center.x, 1.0, "箭头 X=battle1 中心（源 :313-316 中心+offsetX=0）")
		assert_almost_eq(anchor.y, btn_center.y - 30.0, 1.0, "箭头底=battle1 中心上 30（源 pos.y+30）")


# 源 :311-316 分支二：前关 passed 未领奖 → 箭头指 boxButton{cur-1} 且 offsetX=40。
func test_stage_hint_points_box_when_prev_unrewarded() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root, 1)
	panel.player.crusade_manager.cur_stage = 2
	panel.player.crusade_manager.cleared_stages[1] = true
	panel._refresh_hint_pos()
	assert_true(panel._hint_anchor.visible, "前关未领奖箭头可见（源 :310 分支二）")
	var box_center: Vector2 = panel.box_rects[0].get_global_rect().get_center()
	var anchor: Vector2 = panel._hint_anchor.global_position
	assert_almost_eq(anchor.x, box_center.x + 40.0, 1.0, "箭头 X=box1 中心+40（源 :313 offsetX=40）")
	panel.remove_window()
	root.queue_free()


# 战节点两态归源守卫（第二轮验收）：源 crusadeconfig:285-286 battle 仅 normal/disable
# 两键（_current/_passed 系死资产零引用）；锁定走 texture_disabled（源 enable(false) 换图）。
func test_stage_textures_two_state_source_aligned() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root, 1)
	var stage_dir: String = "res://assets/ui/alpha/HVGA/crusade/stage/"
	var b1: TextureButton = panel.stage_buttons[0]
	assert_eq(b1.texture_normal.resource_path, stage_dir + "crusade_stage_1.png",
		"cur=1 battle1 用 normal 图（非 _current 死资产）")
	assert_eq(b1.texture_disabled.resource_path, stage_dir + "crusade_stage_1_locked.png",
		"battle1 disable 槽=_locked 图（源 disable 键）")
	assert_false(b1.disabled, "第 1 关当前关不锁（源 :328）")
	var b3: TextureButton = panel.stage_buttons[2]
	assert_true(b3.disabled, "第 3 关超进度锁定（源 :328 条件一）")
	assert_eq(b3.texture_disabled.resource_path, stage_dir + "crusade_stage_3_locked.png",
		"锁定关 disabled 图=_locked")
	assert_eq(b3.texture_normal.resource_path, stage_dir + "crusade_stage_3.png",
		"锁定关 normal 槽恒 normal 图")
	# 源 :328 条件二：cur==i 且前关未领奖且 i>1 → 锁（构造 cur=2、cleared[1] 未领）。
	panel.player.crusade_manager.cur_stage = 2
	panel.player.crusade_manager.cleared_stages[1] = true
	panel._refresh_stage_states()
	assert_true(panel.stage_buttons[1].disabled, "cur=2 且第 1 关未领奖 → battle2 锁（源条件二）")
	assert_false(panel.stage_buttons[0].disabled, "已通关的第 1 关不锁")
	panel.remove_window()
	root.queue_free()


# 源 :311 boxButton{i} 可点领奖（:395-424 hintBox/hintBoxDown）。
func test_box_pressed_passed_claim_reward() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root, 1)
	panel.player.crusade_manager.cur_stage = 2
	panel.player.crusade_manager.cleared_stages[1] = true
	panel._on_box_pressed(1)
	assert_true(panel.result_label.text.contains("第 1 关"), "点 passed 状态 box 触发领奖流程（源 hintBox :399-405）")
	panel.remove_window()
	root.queue_free()


func test_box_pressed_rewarded_blocked() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root, 1)
	panel.player.crusade_manager.rewarded_stages[1] = true
	panel._on_box_pressed(1)
	assert_true(panel.result_label.text.contains("已领取"), "rewarded 状态 box 不重复领奖（源 hintBox :396）")
	panel.remove_window()
	root.queue_free()


func test_box_pressed_unpassed_locked_no_claim() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root, 1)
	panel._on_box_pressed(5)
	# 超视野 box 源无反馈（hintBox :411-422 仅视野内弹预览浮窗，不动文案通道）——
	# F3 初始文案置空后 result_label 应保持空（未走领奖/预览任何路径）
	assert_eq(panel.result_label.text, "", "超进度 box 不可点领奖（源 :411-422）")
	panel.remove_window()
	root.queue_free()


# ==================== 规则页（源 crusade.lua:543-610 + crusadeconfig.lua:1534-1626）====================

# 规则页静态化（原 CrusadeRuleRenderer procedural 退役）：tscn 内 %RuleLayer
# visible 切换 show/close，17 条文本 fill。
func test_rule_layer_show_close() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root, 1)
	var rule_layer: Control = (panel.container.get_child(0) as Control).get_node("%RuleLayer") as Control
	assert_false(rule_layer.visible, "初始 RuleLayer 隐藏（源 initVisible 语义）")
	panel._show_rule_info()
	assert_true(rule_layer.visible, "show 后 RuleLayer visible")
	panel._close_rule_info()
	assert_false(rule_layer.visible, "close 后 RuleLayer 隐藏")
	panel.remove_window()
	root.queue_free()


# 17 条规则（6 叙事 + 1 空行 + 标题 + 7 规则 + 2 空行 = 静态 VBox 17 子，fill 只填文本）。
func test_rule_layer_has_17_items() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root, 1)
	panel._show_rule_info()
	var vbox: VBoxContainer = (panel.container.get_child(0) as Control).get_node("%RuleVBox") as VBoxContainer
	assert_eq(vbox.get_child_count(), 17, "17 条规则项（照源 initRuleLayer）")
	panel.remove_window()
	root.queue_free()


# 规则页背景框九宫格守卫：源 crusadeconfig.lua:1548 ruleInfo main_vit_tips.png
# capInsets CCRectMake(15,20,45,15)，贴图 103×61 PIL 实测
# → left=15/top=61-20-15=26/right=103-15-45=43/bottom=20（批 1 公式）。
func test_rule_layer_frame_patch_margins() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root, 1)
	var frame: NinePatchRect = (panel.container.get_child(0) as Control).get_node("%RuleFrame") as NinePatchRect
	assert_not_null(frame, "RuleFrame 为 NinePatchRect（源 Scale9Sprite）")
	if frame == null:
		panel.remove_window()
		root.queue_free()
		return
	assert_eq(frame.patch_margin_left, 12, "patch_margin_left=15（源 cap x=15）")
	assert_eq(frame.patch_margin_top, 20, "patch_margin_top=26（H-y-h=61-20-15）")
	assert_eq(frame.patch_margin_right, 34, "patch_margin_right=43（W-x-w=103-15-45）")
	assert_eq(frame.patch_margin_bottom, 16, "patch_margin_bottom=20（源 cap y=20）")
	panel.remove_window()
	root.queue_free()


# 规则页结构照源（:1535-1623）：框 550×360 居中 (480,320)、标题金 22、关闭钮右上、
# 列表 cliprect (140,90,500,250) → Godot (220,220)-(720,470)。
func test_rule_static_structure() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root, 1)
	var content: Control = panel.container.get_child(0) as Control
	var frame: NinePatchRect = content.get_node("%RuleFrame") as NinePatchRect
	assert_almost_eq(frame.size.x, 550.0, 0.01, "RuleFrame 宽 550（源 scaleSize）")
	assert_almost_eq(frame.size.y, 360.0, 0.01, "RuleFrame 高 360")
	assert_almost_eq(frame.position.x, 125.0, 0.01, "RuleFrame x=480-275（源 pos(400,240) 中心）")
	assert_almost_eq(frame.position.y, 60.0, 0.01, "RuleFrame y=320-180")
	var scroll: ScrollContainer = content.get_node("%RuleScroll") as ScrollContainer
	var sr: Rect2 = scroll.get_rect()
	assert_almost_eq(sr.position.x, 140.0, 0.01, "RuleScroll x=140+80（源 cliprect x=140）")
	assert_almost_eq(sr.position.y, 140.0, 0.01, "RuleScroll y=560-340（源 cliprect 顶 y=340）")
	assert_almost_eq(sr.size.x, 500.0, 0.01, "RuleScroll 宽 500（源 cliprect w）")
	assert_almost_eq(sr.size.y, 250.0, 0.01, "RuleScroll 高 250")
	var close_btn: TextureButton = content.get_node("%RuleCloseBtn") as TextureButton
	assert_not_null(close_btn, "RuleCloseBtn 存在（源 closeRuleInfo SpriteButton）")
	assert_almost_eq(close_btn.get_rect().get_center().x, 659.0, 0.5, "关闭钮 x（源局部 (534,340)）")
	var title_bg: TextureRect = content.get_node("%RuleTitleBg") as TextureRect
	assert_almost_eq(title_bg.size.x, 474.0 / CS * 1.3, 0.5, "标题底宽 =474px/CS×1.3（源 scalexy）")
	panel.remove_window()
	root.queue_free()


# 规则文本 fill：首条叙事富文本剥壳（<text|dark_white|…> → 文本+色不动）。
func test_rule_texts_filled() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root, 1)
	panel._show_rule_info()
	var item1: Label = (panel.container.get_child(0) as Control).get_node("%RuleItem1") as Label
	assert_true(item1.text.length() > 0, "RuleItem1 文本已 fill（LSTR）")
	assert_false(item1.text.contains("<text|"), "富文本前缀已剥壳")
	assert_false(item1.text.ends_with(">"), "闭合尾 > 已剥除")
	panel.remove_window()
	root.queue_free()


# ==================== 退役守卫（批 3 Task 7）====================

# builder + rule_renderer 双退役：文件删除 + panel 无引用（代码级守卫，头注不计）。
func test_builder_and_renderer_retired() -> void:
	assert_false(FileAccess.file_exists(BUILDER_PATH), "crusade_panel_builder.gd 已删除（Task 7 退役）")
	assert_false(FileAccess.file_exists(RENDERER_PATH), "crusade_rule_renderer.gd 已删除（静态进 tscn）")
	var panel_src: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_false(panel_src.contains("crusade_panel_builder"), "panel 无 builder preload 引用")
	assert_false(panel_src.contains("crusade_rule_renderer"), "panel 无 renderer 引用")
	assert_false(panel_src.contains("CrusadePanelBuilder"), "panel 无 Builder 类名引用")
	assert_false(panel_src.contains("CrusadeRuleRenderer"), "panel 无 Renderer 类名引用")


# panel .new( 宽口径白名单：仅动态行/弹窗/计时器（battle/box fill 已下沉 fills）；
# fills 侧白名单恰 TextureButton×2（格子动态行）。
func test_panel_new_whitelist() -> void:
	var panel_src: String = FileAccess.get_file_as_string(PANEL_PATH)
	var whitelist: Array[String] = [
		"TextureButton.new()", "ReadheroIcon.new()", "Timer.new()",
		"CrusadeResetConfirm.new()", "BattleRewardPopup.new(", "BattlePreparePanel.new()",
		"ShopManager.new(", "ShopPanel.new(",
		# 滚动条压平例外（源触屏拖拽无可见条，SOP 引擎缺口条款）
		"StyleBoxEmpty.new()",
	]
	var idx: int = 0
	var count: int = 0
	while true:
		idx = panel_src.find(".new(", idx)
		if idx == -1:
			break
		var line_start: int = panel_src.rfind("\n", idx) + 1
		var line: String = panel_src.substr(line_start, panel_src.find("\n", idx) - line_start).strip_edges()
		var ok: bool = false
		for w in whitelist:
			if line.contains(w):
				ok = true
				break
		assert_true(ok, "非白名单 .new(：'%s'" % line)
		count += 1
		idx += 5
	assert_eq(count, 11, "panel .new( 恰 11（icon+timer+3 弹窗+shop×2+滚动条例外×4）")
	# fills 白名单：格子动态行 TextureButton 恰 2 处。
	var fills_src: String = FileAccess.get_file_as_string("res://scripts/ui/crusade_fills.gd")
	assert_eq(fills_src.count("TextureButton.new()"), 2, "fills 恰 2 处 TextureButton（box+battle 动态行）")
