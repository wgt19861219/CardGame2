extends GutTest

# GameData 存档调度测试（照源 main.lua:761 startAutoSave + saveDirty + 登录首存:1120 + 退出补强）。
# 门禁 check.sh 设 GODOT_TEST_MODE=1 → GameData._test_mode=true，save() no-op 不写真实档，
# 故 _on_autosave_timeout 触发的 save 在门禁内无副作用（隔离 [[gamedata-save-pollutes-user-save-test-isolation]]）。

const SaveManagerScript = preload("res://scripts/data/save_manager.gd")

# 测试沙箱目录（与真实 user:// 存档隔离）。
const SANDBOX_DIR: String = "user://gut_test_saves/"


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
# 2026-09-05 根修：改写沙箱目录——原版 _test_mode=false 后直接写/删真实 user://save_auto.json，
# 每次跑门禁即删用户进度档（用户实测「每次提交后数据清空」根因）。
func test_real_save_writes_and_loads_auto_slot() -> void:
	var old_mode := GameData._test_mode
	var old_dir := GameData.save_dir
	var old_slot := GameData.active_slot
	var old_diamond := GameData.player.diamond
	GameData._test_mode = false
	GameData.save_dir = SANDBOX_DIR
	# 2026-09-19 隔离补：GUT 进程无 GODOT_TEST_MODE 时 _read_active_slot 读真实
	# user:// 档位记录——用户活跃档非 auto（多档位）则 save() 写别的槽、load 读 auto 槽
	# 永远空（断言随用户档位状态漂移）。固定写/读同槽，测后恢复。
	GameData.active_slot = GameData.AUTO_SLOT
	GameData.player.diamond = 777
	assert_eq(GameData.save(), OK, "真实模式 save() 返 OK")
	var sm := SaveManagerScript.new(SANDBOX_DIR)
	var loaded := sm.load_slot(GameData.AUTO_SLOT)
	assert_eq(int(loaded.get("diamond", 0)), 777, "save_auto.json 持久化 diamond（往返保真）")
	sm.delete_slot(GameData.AUTO_SLOT)
	GameData.player.diamond = old_diamond
	GameData._test_mode = old_mode
	GameData.save_dir = old_dir
	GameData.active_slot = old_slot


# ── 多档位（2026-09-17）：switch_slot 往返/空档新号/拒绝未知槽/活跃槽持久化/slot_metas ──

func _sandbox_wipe_slots() -> void:
	for f in ["save_auto.json", "save_save_1.json", "save_save_2.json", "save_slot.txt"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SANDBOX_DIR + f))


func test_switch_slot_rejects_unknown_slot() -> void:
	assert_eq(GameData.switch_slot("save_9"), ERR_INVALID_PARAMETER, "非 SLOT_NAMES 槽名拒绝（不动任何档）")

func test_switch_slot_roundtrip_new_game_and_back() -> void:
	var old_mode := GameData._test_mode
	var old_dir := GameData.save_dir
	var old_slot := GameData.active_slot
	var old_diamond := GameData.player.diamond
	GameData._test_mode = false
	GameData.save_dir = SANDBOX_DIR
	GameData.active_slot = "auto"
	_sandbox_wipe_slots()
	GameData.player.diamond = 987654
	assert_eq(GameData.save(), OK, "auto 档先落盘")
	# 切空档 save_1 = 在该档开新号（diamond 回默认 ≠标记值）+ 活跃槽切换并持久化。
	assert_eq(GameData.switch_slot("save_1"), OK, "切空档返 OK")
	assert_eq(GameData.active_slot, "save_1", "活跃槽已切")
	assert_ne(GameData.player.diamond, 987654, "空档切换走新号（进度不串档）")
	var sm := SaveManagerScript.new(SANDBOX_DIR)
	assert_true("save_1" in sm.list_slots(), "新档已立即落盘")
	# 切回 auto：标记值保真（换档零丢失）。
	assert_eq(GameData.switch_slot("auto"), OK, "切回 auto 返 OK")
	assert_eq(GameData.player.diamond, 987654, "切回原档进度保真")
	var f := FileAccess.open(SANDBOX_DIR + "save_slot.txt", FileAccess.READ)
	assert_not_null(f, "活跃槽记录文件已写")
	if f != null:
		assert_eq(f.get_as_text().strip_edges(), "auto", "活跃槽记录=当前档")
		f.close()
	_sandbox_wipe_slots()
	GameData.player.diamond = old_diamond
	GameData._test_mode = old_mode
	GameData.save_dir = old_dir
	GameData.active_slot = old_slot

func test_active_slot_read_falls_back_on_bad_value() -> void:
	var old_mode := GameData._test_mode
	var old_dir := GameData.save_dir
	GameData._test_mode = false
	GameData.save_dir = SANDBOX_DIR
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SANDBOX_DIR))
	var f := FileAccess.open(SANDBOX_DIR + "save_slot.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("garbage_slot")
		f.close()
	assert_eq(GameData._read_active_slot(), "auto", "坏值回退 AUTO_SLOT（老玩家兼容）")
	GameData._write_active_slot("save_2")
	assert_eq(GameData._read_active_slot(), "save_2", "合法槽名读写往返")
	GameData._write_active_slot("auto")
	GameData._test_mode = old_mode
	GameData.save_dir = old_dir
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SANDBOX_DIR + "save_slot.txt"))

func test_slot_metas_shape() -> void:
	var old_mode := GameData._test_mode
	var old_dir := GameData.save_dir
	var old_slot := GameData.active_slot
	GameData._test_mode = false
	GameData.save_dir = SANDBOX_DIR
	GameData.active_slot = "auto"
	_sandbox_wipe_slots()
	var sm := SaveManagerScript.new(SANDBOX_DIR)
	assert_eq(sm.save_slot("auto", {"team_level": 5}), OK, "裸档位 dict（slot_metas 只读 team_level）")
	var metas := GameData.slot_metas()
	assert_eq(metas.size(), 3, "三档 meta（SLOT_NAMES 顺序）")
	assert_eq(String(metas[0].get("slot")), "auto", "首槽 auto")
	assert_true(bool(metas[0].get("exists")), "auto 有档")
	assert_eq(int(metas[0].get("level")), 5, "等级从槽 dict 读取")
	assert_true(bool(metas[0].get("active")), "auto 为活跃档")
	assert_false(bool(metas[1].get("exists")), "save_1 空档")
	assert_false(bool(metas[1].get("active")), "save_1 非活跃")
	_sandbox_wipe_slots()
	GameData._test_mode = old_mode
	GameData.save_dir = old_dir
	GameData.active_slot = old_slot

func test_slot_metas_test_mode_synthesizes() -> void:
	# 测试模式合成数据不触真实档（含坏档 rename 备份副作用隔离）。
	if not GameData._test_mode:
		assert_true(true, "非 test_mode 跳过（合成分支只在测试模式生效）")
		return
	var metas := GameData.slot_metas()
	assert_eq(metas.size(), 3, "测试模式同样返回三档结构")
	assert_true(bool(metas[0].get("active")), "合成数据 auto 为活跃档")
	assert_false(bool(metas[2].get("exists")), "合成数据 save_2 为空档")
