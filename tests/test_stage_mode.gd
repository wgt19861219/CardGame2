extends GutTest
# stage_select_panel 三模式切换测试：normal/elite/guild tab + 关卡过滤 + 章节进度。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_mgr() -> StageManager:
	var mgr := StageManager.new(cm)
	return mgr


func _make_panel() -> StageSelectPanel:
	var pd := PlayerData.new(cm)
	var mgr := _make_mgr()
	var rng := BattleRng.new(12345)
	var panel := StageSelectPanel.new("stageSelect", {})
	panel.setup_panel(mgr, pd, rng)
	return panel


func test_mode_default_normal() -> void:
	var panel := _make_panel()
	assert_eq(panel._mode, "normal", "默认 normal 模式")
	panel.queue_free()


func test_mode_switch_to_elite() -> void:
	var panel := _make_panel()
	panel._on_mode_pressed("elite")
	assert_eq(panel._mode, "elite", "切到 elite 模式")
	panel.queue_free()


func test_mode_switch_to_guild() -> void:
	var panel := _make_panel()
	panel._on_mode_pressed("guild")
	assert_eq(panel._mode, "guild", "切到 guild 模式")
	panel.queue_free()


func test_chapter_of_stage_elite() -> void:
	# 精英关 10001 的 Stage Group 应指向同章 normal 关
	var pd := PlayerData.new(cm)
	var panel := StageSelectPanel.new("stageSelect", {})
	panel.player = pd
	var ch: int = panel._chapter_of_stage(10001)
	assert_true(ch >= 1, "精英关 10001 应能反查到章节")
	panel.queue_free()


func test_normal_progress() -> void:
	var mgr := _make_mgr()
	mgr.progress = {1: 3, 2: 2, 3: 0}
	# 源 player.lua:858 getStageProgress：最远通关 2 + 下一关 3 存在于全量表 → 进度=3
	#（最新解锁关；0 星的 3 不计通关，但 3 存在 Stage 表故 +1 落在它身上）
	assert_eq(mgr.get_normal_progress(), 3, "进度 = 最远通关 2 +1（sid 3 存在）= 最新解锁关")


func test_elite_progress_with_group_check() -> void:
	var mgr := _make_mgr()
	# elite 10001 Stage Group=1，需 normal 1 也通关
	mgr.progress = {1: 3, 10001: 3}
	# 源 player.lua:875：最远通关 10001 + 下一精英关 10002 存在 → 进度=10002
	assert_eq(mgr.get_elite_progress(), 10002, "elite 10001 通关→+1=10002（源 :875）")
	mgr.progress = {10001: 3}  # normal 1 未通关
	assert_eq(mgr.get_elite_progress(), 0, "normal 未通关→elite 不计")


# ===== 2026-09-06 第一章通关无法切章根修回归（源 getStageProgress +1 → maxChapter 前移）=====

# 第一章 = sid 1-18（Stage 表 Chapter ID=1，2026-09-06 实测）；全通关 → 进度=19
#（第二章首关）→ get_max_chapter=2 → stageselect NextArrow 显示可切章。
func test_max_chapter_unlocks_next_after_chapter1_clear() -> void:
	var mgr := _make_mgr()
	var progress: Dictionary = {}
	for sid in range(1, 19):
		progress[sid] = 3
	mgr.progress = progress
	assert_eq(mgr.get_max_chapter("normal"), 2, "第一章全通关 → max_chapter=2（切章箭头出现）")


# 通关全部末关（268=chapter14 尾）→ +1=269 不存在于 Stage 表 → 停 chapter 14 不越界。
func test_max_chapter_caps_at_last_chapter() -> void:
	var mgr := _make_mgr()
	var progress: Dictionary = {}
	for sid in range(251, 269):
		progress[sid] = 3
	mgr.progress = progress
	assert_eq(mgr.get_max_chapter("normal"), 14, "通关末关 268 无 269 → 停 chapter 14")


# 章节等级门槛（源 playerlimit.lua:33-54；PlayerLevel.Chapter 实测 level1→1/5→2/8→3）
func test_player_chapter_level_limit() -> void:
	var pt: Dictionary = cm.get_raw_table(&"PlayerLevel")
	assert_eq(StageAccount.player_max_chapter(pt, 1), 1, "1 级 → chapter 1")
	assert_eq(StageAccount.player_max_chapter(pt, 5), 2, "5 级 → chapter 2")
	assert_eq(StageAccount.player_max_chapter(pt, 8), 3, "8 级 → chapter 3")
	assert_eq(StageAccount.chapter_unlock_level(pt, 2), 5, "chapter 2 解锁等级 = 5")
	assert_eq(StageAccount.chapter_unlock_level(pt, 3), 8, "chapter 3 解锁等级 = 8")
