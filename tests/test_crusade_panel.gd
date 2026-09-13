extends GutTest
# Crusade UI 守卫测试（2026-07-02 初建；2026-07-17 .tscn 重构；2026-08-16 批 3 Task 7
# 两件套改造重写：格子照源散点（HBox 均排退役）+ fog 归源（scale=4 等比）+ 美术层/
# 规则页静态进 tscn + builder/rule_renderer 退役）。用例 18→28 不缩水（第二轮验收
# +2：两态贴图归源 + hint box 分支）。
# 2026-09-13 参考页对齐：两态守卫反转四态（_current/_passed 死资产受控启用）+
# 新增卷轴标题/可领宝箱金光守卫（28→30）；同日二轮：四态换图回退两态（黑剪影
# 观感"透明"）改白光底晕叠加 + 浮窗拥挤治理守卫（30→31）。

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
	# 2026-09-14 crusade 战斗改装配切 battle_scene 观战：旧同步信号链退役（防回潮守卫）。
	assert_false(bp.has_signal("crusade_battle_finished"), "crusade_battle_finished 信号已退役")
	assert_false(panel.has_method("_on_crusade_battle_finished"), "面板旧回调已退役")
	(bp as BattlePreparePanel).queue_free()
	panel.remove_window()
	root.queue_free()


# 旧 test_crusade_battle_finished_refreshes_label（同步信号刷新 label）随 2026-09-14
# 战斗观战化退役：结束反馈改经 pending_crusade 重弹面板由 setup_panel 全量刷新承载。


# 源选关交互：点 stage → 选中 + 敌方预览 + 显 start（源 :206）。
func test_stage_n_selects_and_shows_preview() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root)
	assert_false(panel.start_btn.visible, "未选关 start_btn 隐藏（源 :204）")
	panel._on_stage_n(1)
	assert_eq(panel.current_select, 1, "_on_stage_n 选中第 1 关")
	# 2026-08-29 按源升级弹窗后：开战钮在弹窗内（源 start @battleinfo），面板级 start_btn 不再因选关显示
	assert_false(panel.start_btn.visible, "面板级 start_btn 不再显示（源开战钮在 battleLayer 内）")
	# 2026-08-29 按源升级为 battleLayer 弹窗（撤常驻简化）：选关后弹窗可见且敌方头像已 fill
	assert_true(panel.battle_layer.visible, "选关后敌方阵容弹窗显示（源 showBattleInfo）")
	var hosts_n: int = 0
	for host in panel._bl_hero_hosts:
		hosts_n += (host as Control).get_child_count()
	assert_gt(hosts_n, 0, "弹窗内敌方英雄头像渲染（源 :224-235）")
	panel._close_battle_info()
	assert_false(panel.battle_layer.visible, "关闭弹窗隐藏（源 closeBattleInfo）")
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


# 战节点两态归源守卫（2026-09-13 二轮回归）：battle 恒 normal/locked 两态——
# 2026-09-13 一轮曾受控启用 _current/_passed 黑剪影资产，实机观感"透底发灰+光晕
# 暗淡"（用户验收"图标变透明了"），与 2026-08-17 归源判断一致，已回退；已通关
# 标记改 StageLight 白光底晕叠加（不换图）。锁定走 texture_disabled=_locked。
func test_stage_textures_two_state_with_cleared_glow() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root, 1)
	var stage_dir: String = "res://assets/ui/alpha/HVGA/crusade/stage/"
	var b1: TextureButton = panel.stage_buttons[0]
	assert_eq(b1.texture_normal.resource_path, stage_dir + "crusade_stage_1.png",
		"cur=1 battle1 恒 normal 彩色图（_current 黑剪影已回退）")
	assert_eq(b1.texture_disabled.resource_path, stage_dir + "crusade_stage_1_locked.png",
		"battle1 disable 槽=_locked 图（源 disable 键）")
	assert_false(b1.disabled, "第 1 关当前关不锁（源 :328）")
	# StageLight 白光底晕：未 cleared 隐藏；cleared 点亮。
	assert_eq(panel.stage_lights.size(), CrusadeData.MAX_STAGE, "15 StageLight 与 stages 对位")
	assert_false(panel.stage_lights[0].visible, "未通关 battle1 白光隐藏")
	panel.player.crusade_manager.cur_stage = 2
	panel.player.crusade_manager.cleared_stages[1] = true
	panel._refresh_stage_states()
	assert_true(panel.stage_lights[0].visible, "cleared battle1 白光底晕点亮（参考页已过标记等价）")
	assert_eq(b1.texture_normal.resource_path, stage_dir + "crusade_stage_1.png",
		"cleared 后 battle1 仍 normal 彩色图（标记走光效叠加非换图）")
	assert_false(panel.stage_lights[1].visible, "未通关 battle2 白光隐藏")
	assert_true(panel.stage_buttons[1].disabled, "cur=2 且第 1 关未领奖 → battle2 锁（源条件二）")
	assert_false(panel.stage_buttons[0].disabled, "已通关的第 1 关不锁")
	panel.remove_window()
	root.queue_free()


# 敌队浮窗拥挤治理守卫（2026-09-13 二轮）：icon 照源 :231 setScale(0.8)（旧漏施致
# 104×104 原大相邻叠 29px）+ Host 步进 91（icon 显示 83×83 间隙 8）。
func test_battle_info_icon_scale_and_spacing() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root, 1)
	panel._on_stage_n(1)
	for host in panel._bl_hero_hosts:
		for c in (host as Control).get_children():
			assert_almost_eq((c as Node2D).scale.x, 0.8, 0.01,
				"敌方英雄 icon scale=0.8（源 crusade.lua:231，防漏施复发）")
	var h1: Control = panel._bl_hero_hosts[0] as Control
	var h2: Control = panel._bl_hero_hosts[1] as Control
	assert_almost_eq(h2.position.x - h1.position.x, 91.0, 0.5,
		"头像 Host 步进 91（icon 83 显示宽 + 8 间隙，旧 75 致叠 29px）")
	var start_btn: TextureButton = (panel.container.get_child(0) as Control).get_node("%BattleLayer/BattleInfo/StartBtn2") as TextureButton
	assert_gt(start_btn.position.x, (panel._bl_hero_hosts[4] as Control).position.x + 83.0,
		"开战钮 x > 第 5 头像图标右缘（旧骑跨重叠 66px 已分离）")
	# 三轮（2026-09-13）照源补全守卫：start scale 0.75（99.9×96×0.75=74.9×72，旧漏乘
	# 偏大 25%）+ 名字条底板/分隔线/公会行三装饰元素（源 crusadeconfig :1371/:1482/:1497）。
	assert_almost_eq(start_btn.size.x, 74.9, 0.5, "开战钮宽 =99.9×0.75（源 start config scale=0.75 漏乘订正）")
	var info: Control = (panel.container.get_child(0) as Control).get_node("%BattleLayer/BattleInfo") as Control
	assert_not_null((info.get_node("TipDetailBg") as TextureRect).texture, "名字条底板 tip_detail_bg 挂载（源 :1371-1378）")
	assert_not_null((info.get_node("TipDelimiter") as TextureRect).texture, "底部分隔线 pvp_tip_delimiter 挂载（源 :1482-1492）")
	var guild_hint: Label = info.get_node("%GuildHintLbl") as Label
	assert_eq(guild_hint.text, "未加入公会", "公会行=LSTR NOT_IN_GUILDS（单机无公会恒显，源 :238-240）")
	panel.remove_window()
	root.queue_free()


# 卷轴标题文字（参考页对齐 2026-09-13）：TitleLabel 挂 TitleBg 下，fill LSTR
# BURNING_CRUSADE（源面板无标题文字系当年缺资产，参考页"远征"大字设计受控补齐）。
func test_title_label_filled() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root, 1)
	var title: Label = (panel.container.get_child(0) as Control).get_node("%TitleBg/TitleLabel") as Label
	assert_not_null(title, "TitleLabel 挂 TitleBg 下")
	if title != null:
		assert_eq(title.text, "燃烧的远征", "标题文字=LSTR 燃烧的远征")
	panel.remove_window()
	root.queue_free()


# 可领宝箱金光（参考页对齐 2026-09-13）：cleared 未 rewarded → BoxLight 点亮；
# 未通关隐藏；领取后熄灭。呼吸 tween 挂 box（随 1.5s 摇晃弹跳联动）。
func test_box_light_on_claimable() -> void:
	var root := Node.new()
	add_child(root)
	var panel := _make_panel(root, 1)
	panel.player.crusade_manager.cur_stage = 2
	panel.player.crusade_manager.cleared_stages[1] = true
	panel._refresh_stage_states()
	var light1: TextureRect = panel.box_rects[0].get_node_or_null("BoxLight") as TextureRect
	assert_not_null(light1, "box1 挂 BoxLight 光效子节点")
	if light1 != null:
		assert_true(light1.visible, "可领（cleared 未领）box1 金光点亮")
	var light2: TextureRect = panel.box_rects[1].get_node_or_null("BoxLight") as TextureRect
	if light2 != null:
		assert_false(light2.visible, "未通关 box2 金光隐藏")
	panel.player.crusade_manager.rewarded_stages[1] = true
	panel._refresh_stage_states()
	if light1 != null:
		assert_false(light1.visible, "领取后 box1 金光熄灭")
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
	assert_eq(count, 12, "panel .new( 恰 12（icon+timer+3 弹窗+shop×2+滚动条例外×4+battleLayer 敌方头像）")
	# fills 白名单：格子动态行 TextureButton 恰 2 处。
	var fills_src: String = FileAccess.get_file_as_string("res://scripts/ui/crusade_fills.gd")
	assert_eq(fills_src.count("TextureButton.new()"), 2, "fills 恰 2 处 TextureButton（box+battle 动态行）")


# 2026-09-14 战斗观战化：胜利后经 pending_crusade 重弹远征面板（源 endBattle :702
# replaceScene(crusade.create())）。守卫：pending 非空 → 清空 + open_crusade 弹面板。
func test_maybe_resume_crusade_reopens_panel() -> void:
	var root := Node.new()
	add_child(root)
	var old_pd: Variant = GameData.player
	GameData.player = PlayerData.new(cm)
	GameData.player.hero_manager.add_hero(1)
	GameData.pending_crusade = {"won": true}
	MainSceneEntryRouter.open_crusade(root)
	var found: bool = false
	for c in root.get_children():
		if c is CrusadePanel:
			found = true
			c.queue_free()
	assert_true(found, "open_crusade 弹出 CrusadePanel（pending 重弹目标）")
	GameData.pending_crusade.clear()
	GameData.player = old_pd
	root.queue_free()
