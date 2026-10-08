extends GutTest
# 自动战斗偏好持久化守卫（2026-10-08 用户需求）：源 battle_scene.lua:1207-1257 auto 按钮每场
# 重置 off（scene 局部变量），本项目受控增强为跨战斗记忆——照倍速 speed_state 应用级
# ConfigFile 范式（user://battle.cfg 同档同 section，不入玩家存档）。
# 同日用户指示取消通关门槛（源 pve stars>=3 才显示）：全模式恒显示恒读档，不再按星数 gating。
# 守卫：切换落盘 + 新按钮（=新战斗）读回 + speed/auto 同档互不覆盖 + assembler 恒读档回写
# scene.auto_combat（门槛常量不得回归）+ 全程不碰玩家真实档。

const TEST_CFG_PATH: String = "user://battle_test_auto.cfg"
const REAL_CFG_PATH: String = "user://battle.cfg"
const ASSEMBLER_PATH: String = "res://scripts/view/battle/battle_hud_assembler.gd"
const SPEED_BTN_PATH: String = "res://scripts/view/battle/battle_speed_button.gd"


func _make_button() -> BattleAutoButton:
	var btn: BattleAutoButton = BattleAutoButton.new()
	btn.cfg_path = TEST_CFG_PATH   # new 后 setup 前注入，隔离玩家真实档
	return btn


# 切换写盘 + 新按钮（=下一场战斗）读回同一档（跨战斗记忆语义）。
# 前置固定初态 off：不依赖文件残留（共享 user:// 的测试状态依赖曾致全量跑错位）。
func test_auto_state_persists_across_buttons() -> void:
	var pre := ConfigFile.new()
	pre.set_value("battle", "auto_combat", false)
	pre.save(TEST_CFG_PATH)
	var btn_a: BattleAutoButton = _make_button()
	add_child_autofree(btn_a)
	btn_a.setup(false)
	btn_a._on_pressed()   # off→on
	assert_true(btn_a.is_on(), "A 切到 on")
	var btn_b: BattleAutoButton = _make_button()
	add_child_autofree(btn_b)
	var read_back: bool = btn_b.read_persisted_on(false)
	assert_true(read_back, "新战斗（新按钮）读回 on")
	btn_b.setup(read_back)
	assert_true(btn_b.is_on(), "读出档 on 作为初始态")


# speed/auto 同档共存互不覆盖（save 前先 load；缺此守护任一方写盘即丢对方 key）。
func test_speed_and_auto_coexist_in_cfg() -> void:
	var pre := ConfigFile.new()
	pre.set_value("battle", "auto_combat", true)
	pre.set_value("battle", "speed_state", 2)
	pre.save(TEST_CFG_PATH)
	# 切 auto（on→off）：speed_state 2 应保留
	var auto_btn: BattleAutoButton = _make_button()
	add_child_autofree(auto_btn)
	auto_btn.setup(true)
	auto_btn._on_pressed()   # on→off
	var cfg1 := ConfigFile.new()
	cfg1.load(TEST_CFG_PATH)
	assert_eq(int(cfg1.get_value("battle", "speed_state", -1)), 2, "切 auto 后 speed_state 仍在")
	assert_eq(bool(cfg1.get_value("battle", "auto_combat", true)), false, "auto 落盘 off")
	# 切 speed（2→3）：auto_combat off 应保留
	var speed_btn: BattleSpeedButton = BattleSpeedButton.new()
	speed_btn.cfg_path = TEST_CFG_PATH
	add_child_autofree(speed_btn)
	speed_btn.setup(2)
	speed_btn._on_pressed()   # 2→3
	var cfg2 := ConfigFile.new()
	cfg2.load(TEST_CFG_PATH)
	assert_eq(bool(cfg2.get_value("battle", "auto_combat", true)), false, "切 speed 后 auto_combat 仍在")
	assert_eq(int(cfg2.get_value("battle", "speed_state", -1)), 3, "speed 落盘 3 档")


# assembler 恒读档回写（源码断言，照 test_battle_speed_persist 先例；运行时行为由
# test_battle_scene 侧装配覆盖）。2026-10-08 取消通关门槛：无 gating 条件，门槛常量不得回归。
func test_assembler_reads_persist_without_gate() -> void:
	var src: String = FileAccess.get_file_as_string(ASSEMBLER_PATH)
	assert_false(src.contains("AUTO_UNLOCK_STARS"),
		"通关门槛常量已删（2026-10-08 用户指示：大招自动释放不再受通关星数限制）")
	assert_false(src.contains("_auto_button_visible"),
		"门槛判定函数已删（create_auto_button 不再按星数 gating）")
	assert_true(src.contains("read_persisted_on(false)"),
		"create_auto_button 应无条件读偏好档（全模式恒显示恒读档）")
	assert_true(src.contains("scene.auto_combat = btn.is_on()"),
		"create_auto_button 应回写读出档到 scene（持久化 on 引擎才自动放技能）")


# speed 按钮 save 先 load（保 auto key）的连带修复守卫（源码断言）。
func test_speed_save_loads_before_write() -> void:
	var src: String = FileAccess.get_file_as_string(SPEED_BTN_PATH)
	var save_body: int = src.find("func _save_speed_state")
	assert_ne(save_body, -1, "找到 _save_speed_state")
	var load_line: int = src.find("cfg.load(cfg_path)", save_body)
	var set_line: int = src.find("cfg.set_value", save_body)
	assert_ne(load_line, -1, "_save_speed_state 含 load")
	assert_ne(set_line, -1, "_save_speed_state 含 set_value")
	assert_true(load_line < set_line, "save 前 load：保住同档 auto_combat")


# 本套件全程不碰玩家真实档（cfg_path 注入），真实文件内容在任意测试前后不变。
func test_real_cfg_untouched() -> void:
	var before: String = FileAccess.get_file_as_string(REAL_CFG_PATH)
	var btn: BattleAutoButton = _make_button()
	add_child_autofree(btn)
	btn.setup(false)
	btn._on_pressed()
	btn._on_pressed()
	var after: String = FileAccess.get_file_as_string(REAL_CFG_PATH)
	assert_eq(after, before, "真实 user://battle.cfg 不被测试触碰")
