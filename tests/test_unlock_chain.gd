extends GutTest
# unlock 触发链路集成测试：PlayerData.check_unlocks → EventBus.feature_unlocked 信号。
# 验证升级→解锁→发信号完整 Logic 链路（不依赖 View/Node/bridge，headless 可测）。

var cm: ConfigManager
var _received: Array[StringName] = []


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func before_each() -> void:
	_received.clear()


func _on_step(step: StringName) -> void:
	_received.append(step)


# 升到 7 级 → check_unlocks → 发 unlockSkillUpgrade 信号。
func test_upgrade_emits_feature_unlocked() -> void:
	var pd := PlayerData.new(cm)
	var bus := EventBus.new()
	pd.events = bus
	bus.feature_unlocked.connect(_on_step)
	pd.team_level = 6
	pd.add_team_exp(100)  # 升到 7+（level 6 Exp=30，连升）
	assert_true(_received.has(&"unlockSkillUpgrade"), "升到 7 级触发 unlockSkillUpgrade 信号")


# 未升级不发信号（happenPlayerLevelup 标志语义）。
func test_no_upgrade_no_signal() -> void:
	var pd := PlayerData.new(cm)
	var bus := EventBus.new()
	pd.events = bus
	bus.feature_unlocked.connect(_on_step)
	pd.team_level = 1
	pd.add_team_exp(1)  # 不够升级（level 1 需 25 exp）
	assert_eq(_received.size(), 0, "未升级不发信号")


# record 守卫：重复 check_unlocks 只发一次信号。
func test_repeat_check_unlocks_no_duplicate() -> void:
	var pd := PlayerData.new(cm)
	var bus := EventBus.new()
	pd.events = bus
	bus.feature_unlocked.connect(_on_step)
	pd.team_level = 7
	pd.check_unlocks()
	pd.check_unlocks()
	assert_eq(_received.count(&"unlockSkillUpgrade"), 1, "重复 check_unlocks 只发一次（record 守卫）")


# events 注入为 null 时 check_unlocks 仍 set record（仅不发信号，headless 单测兼容）。
func test_check_unlocks_null_events_still_sets_record() -> void:
	var pd := PlayerData.new(cm)  # events 默认 null
	pd.team_level = 7
	var newly: Array[StringName] = pd.check_unlocks()
	assert_true(newly.has(&"unlockSkillUpgrade"), "返新解锁列表")
	assert_eq(pd.get_tutorial_record(54), 1, "record 已设（即使 events null）")
	assert_eq(_received.size(), 0, "events null 不发信号")
