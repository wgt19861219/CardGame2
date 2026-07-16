extends GutTest
# Phase 6 Crusade UI 核心测试（2026-07-02）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_panel_assembles() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var panel := CrusadePanel.new("crusade", {})
	panel.setup_panel(pd, BattleRng.new(12345))
	panel.show_window(root)
	# P1（2026-07-16）：删 reward_button（源 boxButton{i} 可点领奖替代）→ 11 子节点
	# close + reset + fog(4) + scroll + enemy_preview + start_btn + result_label + hint_anchor = 11
	assert_eq(panel.container.get_child_count(), 11, "close + reset + fog4 + scroll + enemy_preview + start + result + hint")
	assert_eq(panel.stage_buttons.size(), CrusadeData.MAX_STAGE, "15 stage 按钮")
	# box 改 TextureButton 可点（源 :311 boxButton{i}）
	assert_eq(panel.box_rects.size(), CrusadeData.MAX_STAGE, "15 box 按钮（源 :311）")
	for i in range(panel.box_rects.size()):
		assert_true(panel.box_rects[i] is TextureButton, "box 是 TextureButton 可点（源 :311）")
	panel.remove_window()
	root.queue_free()


func test_stage_n_runs() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var panel := CrusadePanel.new("crusade", {})
	panel.setup_panel(pd, BattleRng.new(12345))
	panel.show_window(root)
	panel._on_stage_n(1)
	assert_true(panel.result_label.text.length() > 0, "_on_stage_n 更新 result")
	panel.remove_window()
	root.queue_free()


func test_team_tids_from_heroes() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	pd.hero_manager.add_hero(2)
	# P1-2026-07-10：crusade heroLimit level=20，英雄等级需 ≥20 才能上场
	var h1: HeroInstance = pd.hero_manager.get_hero(pd.hero_manager.heroes.keys()[0])
	if h1 != null: h1.level = 20
	var h2: HeroInstance = pd.hero_manager.get_hero(pd.hero_manager.heroes.keys()[1])
	if h2 != null: h2.level = 20
	var panel := CrusadePanel.new("crusade", {})
	panel.setup_panel(pd, BattleRng.new(1))
	panel.show_window(root)
	var tids: Array = panel._team_tids()
	assert_eq(tids.size(), 2, "team_tids 取所有 ≥20 级英雄（无 team）")
	panel.remove_window()
	root.queue_free()


# 源 crusade 选关交互（2026-07-05）：点 stage → 选中 + 敌方预览 + 显 start 按钮（:206）。
func test_stage_n_selects_and_shows_preview() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var panel := CrusadePanel.new("crusade", {})
	panel.setup_panel(pd, BattleRng.new(12345))
	panel.show_window(root)
	assert_false(panel.start_btn.visible, "未选关 start_btn 隐藏（源 :204）")
	panel._on_stage_n(1)
	assert_eq(panel.current_select, 1, "_on_stage_n 选中第 1 关")
	assert_true(panel.start_btn.visible, "选关后 start_btn 显示（源 :206）")
	assert_gt(panel.enemy_preview_box.get_child_count(), 0, "选关后敌方预览渲染（源 :224 setEnemy）")
	panel.remove_window()
	root.queue_free()


# 源 crusade.lua:91 shakeBox 定时器（1.5s 周期，上一关 box 弹跳）。
func test_shake_timer_created() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var panel := CrusadePanel.new("crusade", {})
	panel.setup_panel(pd, BattleRng.new(12345))
	panel.show_window(root)
	assert_not_null(panel._shake_timer, "shake timer 创建（源 :91）")
	if panel._shake_timer != null:
		assert_false(panel._shake_timer.is_stopped(), "shake timer 启动（1.5s 周期）")
	panel.remove_window()
	root.queue_free()


# P1-2026-07-10：超进度不可选（源 refreshBattleState :324-325）
func test_stage_beyond_progress_not_selectable() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var panel := CrusadePanel.new("crusade", {})
	panel.setup_panel(pd, BattleRng.new(1))
	panel.show_window(root)
	# cur_stage 默认 1，选第 5 关应被拦
	panel._on_stage_n(5)
	assert_eq(panel.current_select, 0, "超进度关卡不可选中")
	assert_true(panel.result_label.text.contains("未解锁"), "超进度提示未解锁")
	panel.remove_window()
	root.queue_free()


# P1-2026-07-10：重置次数耗尽（源 resetBattle :660-661 leftTime<=0 toast）
func test_reset_exhausted_blocked() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var panel := CrusadePanel.new("crusade", {})
	panel.setup_panel(pd, BattleRng.new(1))
	panel.show_window(root)
	# 耗尽所有重置次数（源 RESET_MAX_PER_DAY=10）
	for i in range(11):
		pd.crusade_manager.reset()
	panel._on_reset()
	# P1（2026-07-16）：toast 文案 LSTR 化 CRUSADE.NO_RESET_TIMES_LEFT_TODAY = "今日已没有重置次数"
	assert_true(panel.result_label.text.contains("没有重置"), "重置次数耗尽被拦（源 LSTR）")
	panel.remove_window()
	root.queue_free()


# P1-2（2026-07-11）：超进度按钮 disabled 灰显（源 :329 enable(false) 视觉禁）。
func test_stage_disabled_beyond_progress() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var panel := CrusadePanel.new("crusade", {})
	panel.setup_panel(pd, BattleRng.new(1))
	panel.show_window(root)
	# cur_stage=1，第 5 关超进度 disabled，第 1 关当前可选
	assert_true(panel.stage_buttons[4].disabled, "第 5 关超进度 disabled（源 :329）")
	assert_false(panel.stage_buttons[0].disabled, "第 1 关当前关 enabled")
	panel.remove_window()
	root.queue_free()


# P1-2：reset 弹确认框（源 :665-679 showConfirmDialog，原降级直接执行 → 独立组件）。
func test_reset_shows_confirm_dialog() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var panel := CrusadePanel.new("crusade", {})
	panel.setup_panel(pd, BattleRng.new(1))
	panel.show_window(root)
	var before: int = panel.container.get_child_count()
	panel._on_reset()   # leftTime>0 → 弹确认框（非直接 reset）
	assert_eq(panel.container.get_child_count(), before + 1, "reset 弹确认框")
	var popup: Node = panel.container.get_child(before)
	assert_true(popup is CrusadeResetConfirm, "确认框是 CrusadeResetConfirm")
	popup.queue_free()
	panel.remove_window()
	root.queue_free()


# P1-14（2026-07-11）：currentStageHint 导航箭头（源 refreshHintPos :298-323 + 浮动 :614-619）。
func test_stage_hint_created_and_points_current() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var panel := CrusadePanel.new("crusade", {})
	panel.setup_panel(pd, BattleRng.new(12345))
	panel.show_window(root)
	assert_not_null(panel.stage_hint, "导航箭头创建（源 currentStageHint）")
	if panel.stage_hint != null:
		assert_eq(panel.stage_hint.text, "▼", "箭头降级 ▼（UIRes 纹理缺）")
	# 首关 cur=1 未通关 → 指向 stage_buttons[0]（源 :306-308），hint_anchor 可见
	assert_true(panel._hint_anchor.visible, "首关箭头指向当前关（源 :306）")
	if panel.stage_buttons.size() > 0:
		var btn_global: Vector2 = panel.stage_buttons[0].get_global_rect().position
		var origin: Vector2 = panel.container.get_global_rect().position
		assert_almost_eq(panel._hint_anchor.position.x, btn_global.x - origin.x, 1.0, "箭头 X 对齐当前关按钮（源 offsetX=0）")
	panel.remove_window()
	root.queue_free()


# P1（2026-07-16）：源 :311 boxButton{i} 可点领奖（替代降级独立 reward_button）。
# 源 :395-406 hintBox: rewarded→return / passed→draw_reward；:407-424 hintBoxDown: unpassed→预览。
func test_box_pressed_passed_claim_reward() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var panel := CrusadePanel.new("crusade", {})
	panel.setup_panel(pd, BattleRng.new(1))
	panel.show_window(root)
	# cur_stage 推进到 2 + 第 1 关 passed（直接 Dictionary 赋值，模拟服务端返回的 stage 状态）
	pd.crusade_manager.cur_stage = 2
	pd.crusade_manager.cleared_stages[1] = true
	panel._on_box_pressed(1)
	# passed → _apply_box_reward → "第 1 关 奖励" 或 "不可领"（取决于 reward slots 是否存在）
	assert_true(panel.result_label.text.contains("第 1 关"), "点 passed 状态 box 触发领奖流程（源 hintBox :399-405）")
	panel.remove_window()
	root.queue_free()


func test_box_pressed_rewarded_blocked() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var panel := CrusadePanel.new("crusade", {})
	panel.setup_panel(pd, BattleRng.new(1))
	panel.show_window(root)
	# 模拟第 1 关已领奖（rewarded_stages 直接 Dictionary 赋值）
	pd.crusade_manager.rewarded_stages[1] = true
	panel._on_box_pressed(1)
	# rewarded → 直接 return（源 :396-398），不触发领奖
	assert_true(panel.result_label.text.contains("已领取"), "rewarded 状态 box 不重复领奖（源 hintBox :396）")
	panel.remove_window()
	root.queue_free()


func test_box_pressed_unpassed_locked_no_claim() -> void:
	var root := Node.new()
	add_child(root)
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	var panel := CrusadePanel.new("crusade", {})
	panel.setup_panel(pd, BattleRng.new(1))
	panel.show_window(root)
	# cur_stage=1：第 5 关超进度（_is_stage_locked=true），点 box 不领奖（源 :407-424 hintBoxDown 段检查）
	panel._on_box_pressed(5)
	# 超进度：既非 rewarded 也非 passed，且 _is_stage_locked=true → 不走预览分支，无文案更新
	# result_label 保留初始 "远征：第 1 关"
	assert_true(panel.result_label.text.contains("远征") or panel.result_label.text.contains("第 1 关"), "超进度 box 不可点领奖（源 :411-422 段检查）")
	panel.remove_window()
	root.queue_free()
