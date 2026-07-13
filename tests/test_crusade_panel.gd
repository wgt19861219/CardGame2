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
	# close + reset + fog(4) + scroll + enemy_preview + start_btn + result_label + reward_btn + hint_anchor = 12
	assert_eq(panel.container.get_child_count(), 12, "close + reset + fog4 + scroll + enemy_preview + start + result + reward + hint")
	assert_eq(panel.stage_buttons.size(), CrusadeData.MAX_STAGE, "15 stage 按钮")
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
	assert_true(panel.result_label.text.contains("用完"), "重置次数耗尽被拦")
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
