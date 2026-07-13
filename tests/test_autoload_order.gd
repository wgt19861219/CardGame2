extends GutTest
# P1-GUT-3：autoload game_data→Events 顺序依赖守护测试。
# game_data._ready 第 24 行 player.events = Events.bus 依赖 Events autoload 已初始化。
# 本测试验证：(1) GameData 初始化后 player.events 非 null (2) Events.bus 是 EventBus 实例
# (3) game_data.notify_changed 不崩（依赖 Events.bus 存在）。
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


func test_game_data_notify_changed_uses_events_bus() -> void:
	# notify_changed 依赖 Events.bus.emit_data_changed，验证不崩 + 信号触发
	var gd_script := preload("res://scripts/autoload/game_data.gd")
	var game_data := gd_script.new()
	add_child(game_data)
	watch_signals(Events.bus)
	# notify_changed 应通过 Events.bus 发 data_changed（不崩 = Events.bus 已就绪）
	game_data.notify_changed(&"hero")
	assert_signal_emitted(Events.bus, "data_changed", "notify_changed 应触发 Events.bus.data_changed")
	game_data.queue_free()
