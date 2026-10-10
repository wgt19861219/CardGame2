extends GutTest
# 倍速档持久化守卫（2026-08-31 四轮）：源 battle_scene.lua:14/1050 CCUserDefault
# "battle_speed_state"（启动读+切档写回，跨战斗/跨启动）；本项目此前 scene 实例变量每场归 1。
# 守卫：切档落盘 + 新按钮（=新战斗）setup 读回 + 越界语义（<1 回 1；>MAX_STATE 回落最大档，
# 2026-10-10 修正：旧 4x 遗产档值每场被扔回 1x 即"倍速又重置"根因）+ assembler 回写同步。
# 全部按钮注入 user://battle_test_speed.cfg（cfg_path 可注入），与玩家真实档 user://battle.cfg
# 完全隔离——多测试共享 user:// 会互踩（曾致 test_battle_scene 读到取证残留档断言错位）。

const TEST_CFG_PATH: String = "user://battle_test_speed.cfg"
const REAL_CFG_PATH: String = "user://battle.cfg"
const ASSEMBLER_PATH: String = "res://scripts/view/battle/battle_hud_assembler.gd"


func _make_button() -> BattleSpeedButton:
	var btn: BattleSpeedButton = BattleSpeedButton.new()
	btn.cfg_path = TEST_CFG_PATH   # new 后 setup 前注入，隔离玩家真实档
	return btn


# 切档写盘 + 新按钮（=下一场战斗）setup 读回同一档（源跨场景 curSpeedState 共享）。
# 前置固定初态 1：不依赖文件残留（共享 user:// 的测试状态依赖曾致全量跑读到残留 4 档错位）。
func test_speed_state_persists_across_buttons() -> void:
	var pre := ConfigFile.new()
	pre.set_value("battle", "speed_state", 1)
	pre.save(TEST_CFG_PATH)
	var btn_a: BattleSpeedButton = _make_button()
	add_child_autofree(btn_a)
	btn_a.setup(1)
	btn_a._on_pressed()   # 1→2
	btn_a._on_pressed()   # 2→3
	assert_eq(btn_a.get_state(), 3, "A 切到 3 档")
	var btn_b: BattleSpeedButton = _make_button()
	add_child_autofree(btn_b)
	btn_b.setup(1)   # 注入 fallback 1，应被持久化档 3 覆盖
	assert_eq(btn_b.get_state(), 3, "新按钮（新战斗）读回 3 档")


# 越界语义（2026-10-10 修正）：<1 垃圾值回 1；>MAX_STATE（旧 4x 时代档值 4 等）回落
# 最大档——裁 3 档后照源"越界回 1"会让旧 4x 玩家每场被扔回 1x（用户两轮反馈
# "倍速又重置"实锤：档值 4 → 每场 1x，点一下 2x 写档）。
func test_out_of_range_resets_to_one() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("battle", "speed_state", 0)
	cfg.save(TEST_CFG_PATH)
	var btn: BattleSpeedButton = _make_button()
	add_child_autofree(btn)
	btn.setup(1)
	assert_eq(btn.get_state(), 1, "cfg 垃圾值 0 回 1")
	var cfg9 := ConfigFile.new()
	cfg9.set_value("battle", "speed_state", 9)
	cfg9.save(TEST_CFG_PATH)
	var btn9: BattleSpeedButton = _make_button()
	add_child_autofree(btn9)
	btn9.setup(1)
	assert_eq(btn9.get_state(), 3, "cfg 越界值 9 回最大档 3（旧 4x 遗产映射）")


# 3→1 循环也落盘（源 :1049-1050 切换即写回；2026-10-06 用户拍板 4 档裁 3 档，
# 循环边界从 4→1 改 3→1）。
func test_cycle_back_to_one_saved() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("battle", "speed_state", 3)
	cfg.save(TEST_CFG_PATH)
	var btn: BattleSpeedButton = _make_button()
	add_child_autofree(btn)
	btn.setup(1)
	assert_eq(btn.get_state(), 3, "读回 3 档")
	btn._on_pressed()   # 3→1 循环
	var cfg2 := ConfigFile.new()
	cfg2.load(TEST_CFG_PATH)
	assert_eq(int(cfg2.get_value("battle", "speed_state", -1)), 1, "3→1 循环写盘")
	# 裁档后遗留的旧 4 档 cfg 值 → 回落最大档 3（保住"最快"偏好，2026-10-10）
	cfg.set_value("battle", "speed_state", 4)
	cfg.save(TEST_CFG_PATH)
	var btn2: BattleSpeedButton = _make_button()
	add_child_autofree(btn2)
	btn2.setup(1)
	assert_eq(btn2.get_state(), 3, "旧 4 档遗留值回最大档 3（>MAX_STATE 回落）")


# assembler 回写同步（源静态类变量共享；本项目 scene 实例变量须显式 set_speed_state，engine 倍速才生效）。
func test_assembler_syncs_persisted_state_to_scene() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("battle", "speed_state", 2)
	cfg.save(TEST_CFG_PATH)
	var src: String = FileAccess.get_file_as_string(ASSEMBLER_PATH)
	assert_true(src.contains("scene.set_speed_state(btn.get_state())"),
		"create_speed_button 应回写读出档位到 scene（持久化 2 档 engine 才加速）")


# 本套件全程不碰玩家真实档（cfg_path 注入），真实文件内容在任意测试前后不变。
func test_real_cfg_untouched() -> void:
	var before: String = FileAccess.get_file_as_string(REAL_CFG_PATH)
	var btn: BattleSpeedButton = _make_button()
	add_child_autofree(btn)
	btn.setup(1)
	btn._on_pressed()
	btn._on_pressed()
	var after: String = FileAccess.get_file_as_string(REAL_CFG_PATH)
	assert_eq(after, before, "真实 user://battle.cfg 不被测试触碰")
