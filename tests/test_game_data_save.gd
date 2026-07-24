extends GutTest

# GameData 存档调度测试（照源 main.lua:761 startAutoSave + saveDirty + 登录首存:1120 + 退出补强）。
# 门禁 check.sh 设 GODOT_TEST_MODE=1 → GameData._test_mode=true，save() no-op 不写真实档，
# 故 _on_autosave_timeout 触发的 save 在门禁内无副作用（隔离 [[gamedata-save-pollutes-user-save-test-isolation]]）。

const SaveManagerScript = preload("res://scripts/data/save_manager.gd")


func test_mark_save_dirty_sets_flag() -> void:
	GameData._dirty = false
	GameData.mark_save_dirty()
	assert_true(GameData._dirty, "mark_save_dirty 应置脏标（照源 ed.saveDirty=true）")


func test_autosave_timer_attached() -> void:
	# _ready 应挂 60s AutosaveTimer 子节点（照源 main.lua:761 startAutoSave）
	var timer := GameData.get_node_or_null("AutosaveTimer")
	assert_not_null(timer, "_ready 应挂 AutosaveTimer")
	if timer != null:
		assert_eq((timer as Timer).wait_time, 60.0, "AutosaveTimer 周期 60s（照源 startAutoSave）")


func test_autosave_timeout_flushes_dirty() -> void:
	if not GameData._test_mode:
		assert_true(true, "非 test_mode 跳过（避免 _on_autosave_timeout 触发写真实档）")
		return
	GameData._dirty = true
	GameData._on_autosave_timeout()
	assert_false(GameData._dirty, "autosave 超时应刷盘并清脏标")


func test_save_in_test_mode_is_noop() -> void:
	if not GameData._test_mode:
		assert_true(true, "非 test_mode 跳过 save() 隔离验证")
		return
	assert_eq(GameData.save(), OK, "test_mode 下 save() no-op 返 OK（不写真实档）")


# 端到端：临时真实模式验证 GameData.save() 写 auto 槽 + load 往返保真（照源 ed.saveGame 持久化）。
# 用完 delete 清理避免残留（门禁 test_mode 本不 load auto，此为双重保险）。
func test_real_save_writes_and_loads_auto_slot() -> void:
	var old_mode := GameData._test_mode
	var old_diamond := GameData.player.diamond
	GameData._test_mode = false
	GameData.player.diamond = 777
	assert_eq(GameData.save(), OK, "真实模式 save() 返 OK")
	var sm := SaveManagerScript.new()
	var loaded := sm.load_slot(GameData.AUTO_SLOT)
	assert_eq(int(loaded.get("diamond", 0)), 777, "save_auto.json 持久化 diamond（往返保真）")
	sm.delete_slot(GameData.AUTO_SLOT)
	GameData.player.diamond = old_diamond
	GameData._test_mode = old_mode
