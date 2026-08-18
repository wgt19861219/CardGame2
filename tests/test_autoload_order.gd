extends GutTest
# P1-GUT-3：autoload game_data→Events 顺序依赖守护测试。
# game_data._ready 第 24 行 player.events = Events.bus 依赖 Events autoload 已初始化。
# 本测试验证：(1) GameData 初始化后 player.events 非 null (2) Events.bus 是 EventBus 实例。
# project.godot autoload 顺序：Events(21) < GameData(24)，守护此顺序不被破坏。

func test_game_data_injects_event_bus_to_player() -> void:
	# 模拟 autoload 链路：Events 先就绪 → GameData._ready 注入 Events.bus 到 player.events
	var gd_script := preload("res://scripts/autoload/game_data.gd")
	var game_data := gd_script.new()
	add_child(game_data)   # 触发 _ready（config.load_all + player + Events.bus 注入）
	assert_not_null(game_data.player, "GameData._ready 后 player 应初始化")
	assert_not_null(game_data.player.events, "player.events 应注入 Events.bus（依赖 Events autoload 先就绪）")
	# Events.bus 是 EventBus 实例（信号总线）
	assert_true(game_data.player.events is EventBus, "player.events 应是 EventBus 实例")
	game_data.queue_free()


func test_events_autoload_ready_before_game_data() -> void:
	# 守护 project.godot autoload 顺序：Events 必须在 GameData 之前
	# （game_data._ready 直接用 Events.bus，顺序反了 player.events 会是 null）
	# P2-GUT-4：限定 [autoload] 段内比较顺序（裸 find 整文件脆弱——他处出现 Events= 子串会误判）
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	assert_not_null(file, "project.godot 可读")
	var content := file.get_as_text()
	file.close()
	var header := "[autoload]"
	var sec_start := content.find(header) + header.length()
	var sec_end := content.find("\n[", sec_start)
	if sec_end < 0:
		sec_end = content.length()
	var section := content.substr(sec_start, sec_end - sec_start)
	var events_idx: int = section.find("Events=")
	var game_data_idx: int = section.find("GameData=")
	assert_gt(events_idx, 0, "Events autoload 应存在于 [autoload] 段")
	assert_gt(game_data_idx, 0, "GameData autoload 应存在于 [autoload] 段")
	assert_lt(events_idx, game_data_idx, "Events 必须在 GameData 之前（game_data._ready 依赖 Events.bus）")


# ── 2026-08-18 战斗缠绕根因回归守卫（skill_lib 注入顺序）──
# game_data._ready 曾把 stage_manager.skill_lib = skills 写在 skills 创建之前（阶段一注入化
# 引入），注入 null 后建库不回填 → 战役单位 skill_list 恒空 → AI 无技能只普攻贴脸（用户实跑
# "交织缠绕"）。excavate/crusade/ladder 自建 lib 故未暴露；dungeon e2e 只断言 has(won) 未拦。

func test_game_data_injects_skill_lib_after_creation() -> void:
	var gd_script := preload("res://scripts/autoload/game_data.gd")
	var game_data := gd_script.new()
	add_child(game_data)
	assert_not_null(game_data.skills, "GameData._ready 后 skills 库就绪")
	assert_not_null(game_data.player.stage_manager.skill_lib,
		"player.stage_manager.skill_lib 已注入（非 null——2026-08-18 缠绕根因回归守卫）")
	if game_data.player.stage_manager.skill_lib != null:
		assert_same(game_data.skills, game_data.player.stage_manager.skill_lib,
			"注入的是同一 SkillLibrary 实例")
	game_data.queue_free()


func test_stage_assemble_units_have_skills() -> void:
	# 装配端到端守卫：真实入口同款（player.stage_manager）装配 stage1，单位技能表非空
	var mgr: StageManager = GameData.player.stage_manager
	if mgr == null or mgr.skill_lib == null:
		fail_test("player.stage_manager.skill_lib 未注入（注入顺序回归）")
		return
	var r: Dictionary = mgr.assemble_stage_battle(1, GameData.player, [1, 2, 3, 4, 5], BattleRng.new(7))
	if not bool(r.get("ok", false)):
		fail_test("stage1 装配失败: %s" % str(r.get("error", "")))
		return
	var eng: BattleEngine = r["engine"]
	var skilled: int = 0
	for u in eng.foreach_alive_unit(BattleEngine.CAMP_BOTH):
		if u.skill_list.size() > 0:
			skilled += 1
	assert_gt(skilled, 0, "装配单位至少 1 个技能非空（skill_lib 注入链不断，AI 可施法）")
