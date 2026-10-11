extends GutTest
# LichMapPanel 手指指引守卫（2026-10-10 用户实测反馈：通关结算返回地图后手指停在
# 已通关关）。setup_panel 语义：focus 传入且未通关 → 照源 forGetWay 指向它；
# focus 已通关（结算返回 lichmap 场景）或未传 → 指向下一个待通关关；全通关不高亮。

const PANEL_PATH: String = "res://scripts/ui/lich_map_panel.gd"


func _make_panel(p_progress: Dictionary, p_focus: int) -> LichMapPanel:
	var mgr := StageManager.new(GameData.config)
	mgr.progress = p_progress.duplicate(true)
	var panel: LichMapPanel = (load(PANEL_PATH) as GDScript).new("lichMap", {})
	add_child_autofree(panel)
	panel.setup_panel(GameData.player, mgr, BattleRng.new(randi()), p_focus)
	return panel


func test_guide_defaults_to_first_uncleared() -> void:
	var panel := _make_panel({}, 0)
	assert_eq(panel._focus_stage_id, 50022, "空进度无 focus → 指第一关 50022")


func test_guide_moves_past_cleared_stage() -> void:
	# 结算返回传刚通关关 50022（已通关）→ 手指改指下一个待通关
	var panel := _make_panel({50022: 3}, 50022)
	assert_eq(panel._focus_stage_id, 50023, "focus=已通关 50022 → 指下一关 50023")


func test_guide_crosses_volume_boundary() -> void:
	# 卷 1 全通关（50022-50024）→ 指卷 2 首关 50025 且翻到卷 2
	var panel := _make_panel({50022: 3, 50023: 3, 50024: 3}, 50024)
	assert_eq(panel._focus_stage_id, 50025, "卷 1 全通关 → 指卷 2 首关 50025")
	assert_eq(panel._current, 1, "自动翻到卷 2（_current=1）")


func test_guide_cleared_focus_uncleared_keeps_source_semantics() -> void:
	# 获取途径跳转语义保留：focus 未通关时照源指向该关（定位分卷+手指）
	var panel := _make_panel({50022: 3}, 50025)
	assert_eq(panel._focus_stage_id, 50025, "focus=未通关关 → 照源 forGetWay 指向它")


func test_guide_none_when_all_cleared() -> void:
	var progress: Dictionary = {}
	for sid in range(50022, 50031):
		progress[sid] = 3
	var panel := _make_panel(progress, 50030)
	assert_eq(panel._focus_stage_id, 0, "全通关 → 不高亮（无手指）")
