extends Node

## 全局数据访问（autoload GameData）：ConfigManager + PlayerData + 技能库/技能组单例。
## View 层只读访问数据；Logic 模块依赖（skill_lib/sfx_hook 等）在 _ready 手工注入。
## _ready 加载配置 + 存档（无存档则新游戏）。存档用 SaveManager 原子写。
## 存档调度照源 main.lua：登录首存(:1120) + 脏标 mark_save_dirty + 60s startAutoSave(:761)。
## 测试隔离：check.sh 设 GODOT_TEST_MODE=1（或编辑器内跑 GUT）→ 不 load 不写真实存档，
## 避免 test_main_scene_entry 等 add main_scene 触发登录首存写盘污染下次门禁 _ready load
## （[[gamedata-save-pollutes-user-save-test-isolation]]）。

const PlayerDataScript = preload("res://scripts/data/player_data.gd")
const SaveManagerScript = preload("res://scripts/data/save_manager.gd")
const AUTO_SLOT: String = "auto"   # SaveManager.SLOT_NAMES[0]，老玩家默认档
const SLOT_META_NAME: String = "save_slot.txt"   # 活跃档位记录（下次启动自动进入）
const AUTOSAVE_INTERVAL: float = 60.0

# 存档目录（测试可注入沙箱隔离路径，勿真覆盖用户档——先例 SaveManagerPanel.save_file_path）。
var save_dir: String = "user://"
# 当前活跃档位（多档位受控增强）：save()/加载均指向此槽；_ready 从 SLOT_META_NAME 读。
var active_slot: String = AUTO_SLOT

var config: ConfigManager
var player: PlayerData
var skills: SkillLibrary
var skill_groups: SkillGroupData
var last_result: Dictionary = {}  # 最近战斗结算 param（结算场景 _ready 读，等价源 stagefailed/stagedone create(param)；battle 衔接存）
var battle_context: Dictionary = {}  # 战斗上下文（assemble 存 / battle_scene._ready 装配 + _finalize 结算读）
var pending_excavate: Dictionary = {}  # excavate 战斗结束待重弹标记（battle_scene._finalize_excavate 存 / main_scene._ready 读后清）
var pending_crusade: Dictionary = {}  # crusade 战斗结束待重弹远征面板标记（battle_scene_finalizer.finalize_crusade 存 / main_scene._ready 读后清）
var pending_stage_result: Dictionary = {}  # stage 结算页重试/下一关待重弹标记（settlement_common 存 / main_scene 读后清）
var _dirty: bool = false  # 脏标（照源 ed.saveDirty，60s Timer 合并刷盘）
var _test_mode: bool = false  # 测试模式（env GODOT_TEST_MODE / 编辑器 hint），隔离真实存档

func _ready() -> void:
	_test_mode = OS.get_environment("GODOT_TEST_MODE") != "" or Engine.is_editor_hint()
	config = ConfigManager.new()
	config.load_all()
	active_slot = _read_active_slot()
	player = _load_or_new_player()
	# ⚠️ 注入必须在 skills 创建之后（2026-08-18 战斗缠绕根因）：skill_lib 注入的是引用值，
	# 先注 null 后建库不会回填——阶段一注入化以来战役单位 skill_list 恒空，AI 无技能可用
	# 只能普攻走位互贴（excavate/crusade/ladder 自建 lib 故此前验收未暴露；e2e 只断言
	# has(won) 未断 won，超时判负也全绿）。
	skills = SkillLibrary.new(config)
	skill_groups = SkillGroupData.new(config)
	_wire_player(player)
	_start_autosave_timer()
	save()


# PlayerData 依赖注入（事件总线/存脏钩子/战斗音效钩子）。_ready 与 apply_imported_save
# （导入存档换 player 实例）共用——换实例必须重挂全部 hook，否则自动存档/音效断链。
func _wire_player(p_pd: PlayerData) -> void:
	p_pd.events = Events.bus  # 注入 EventBus（check_unlocks 升级解锁发 feature_unlocked → main_scene 弹公告）
	# T2 依赖倒置：Logic 写操作自动标脏（buy_vitality/midas exchange 等；缺省 Callable headless 可测）。
	p_pd.save_hook = mark_save_dirty
	p_pd.midas.save_hook = mark_save_dirty
	# T3 依赖倒置：战斗胜/败音效由 Logic 钩子回调（battle_engine 不再直调 AudioPlayer autoload）。
	var sfx: Callable = func(name: String) -> void: AudioPlayer.play_sfx(name)
	p_pd.stage_manager.sfx_hook = sfx; p_pd.stage_manager.skill_lib = skills
	p_pd.crusade_manager.sfx_hook = sfx
	p_pd.excavate.sfx_hook = sfx
	p_pd.ladder.sfx_hook = sfx
	# 每日奖励邮件落盘标脏（2026-09-17 竞技场每日排名奖励链）。
	p_pd.ladder.save_hook = mark_save_dirty

func _start_autosave_timer() -> void:
	var timer := Timer.new()
	timer.name = "AutosaveTimer"
	timer.wait_time = AUTOSAVE_INTERVAL
	timer.autostart = true
	timer.timeout.connect(_on_autosave_timeout)
	add_child(timer)

func _on_autosave_timeout() -> void:
	_recover_vitality()
	if _dirty:
		var err: int = save()
		if err == OK:
			_dirty = false
		else:
			# 写失败保留脏标等下一轮 tick 重试（曾无条件清零致这批脏改动丢失且无日志，
			# 2026-09-28 审查 P2-1）。
			push_error("GameData: 自动存档失败（err=%d），保留脏标待重试" % err)


## 体力时间恢复接线（源 player.lua:622 refreshVitality 惰性补点；2026-09-17 经济单机优化）：
## 60s tick 节流调 VitalityManager.recover（幂等，按时间差补点，挂机回来一次补齐），
## 有恢复量才标脏随 60s 存档落盘。此前 recover 零调用 = 恢复链路断链（只靠升级/购买）。
func _recover_vitality() -> void:
	if player == null:
		return
	var recovered: int = VitalityManager.recover(player, int(Time.get_unix_time_from_system()))
	if recovered > 0:
		mark_save_dirty()

func _notification(what: int) -> void:
	# 引擎适配补强（源 hello.lua:431 applicationDidEnterBackground 无 saveGame，源疏漏）：
	# 窗口关闭/返回键时强制存盘，避免杀进程丢最多 60s 进度。
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		save()

func _load_or_new_player() -> PlayerData:
	return _load_slot_or_new(active_slot)


func _load_slot_or_new(slot: String) -> PlayerData:
	if _test_mode:
		var def_pd := PlayerDataScript.new(config)
		def_pd.apply_default_data()
		return def_pd
	var sm := SaveManagerScript.new(save_dir)
	var data: Dictionary = sm.load_slot(slot)
	if data.is_empty():
		var new_pd := PlayerDataScript.new(config)
		new_pd.apply_default_data()
		return new_pd
	return PlayerDataScript.from_dict(data, config)

## 存档到活跃档位（原子写，治旧版崩溃丢档）。测试模式 no-op（隔离真实存档）。
func save() -> int:
	if _test_mode:
		return OK
	var sm := SaveManagerScript.new(save_dir)
	return sm.save_slot(active_slot, player.to_dict())

## 标脏（照源 ed.saveDirty=true）：等 60s Timer 合并刷盘，避免高频操作每次写盘。
func mark_save_dirty() -> void:
	_dirty = true


## 导入存档落地（save_manager_panel 导入确认后调，源 savemanager.lua:235-251 等价）：
## 从 dict 重建 PlayerData + 重挂全部 hook（_wire_player）+ 立即存盘。返回是否成功。
## 失败（from_dict 异常/存盘错误码非 OK）时 player 保持原实例不动。测试模式存盘 no-op（OK）。
func apply_imported_save(data: Dictionary) -> int:
	var new_pd: PlayerData = PlayerDataScript.from_dict(data, config)
	if new_pd == null:
		return ERR_INVALID_DATA
	player = new_pd
	_wire_player(player)
	return save()


# ── 多档位（Godot 原生阶段受控增强，源单账号无对应物）──
# 固定三档（SaveManager.SLOT_NAMES）：save_auto/save_1/save_2；空档切换 = 在该档开新号。

## 切换活跃档位：当前档刷盘 → 目标槽加载（空档走新号）→ 重挂 hook → 新档立即落盘
## + 持久化活跃槽（下次启动自动进入）。非 SLOT_NAMES 槽名返回 ERR_INVALID_PARAMETER；
## 当前档刷盘失败时原样不动。换 player 实例复用 apply_imported_save 模式（hook 必须重挂）。
func switch_slot(slot: String) -> int:
	if slot not in SaveManagerScript.SLOT_NAMES:
		return ERR_INVALID_PARAMETER
	var flush_err: int = save()
	if flush_err != OK:
		return flush_err
	var new_pd := _load_slot_or_new(slot)
	player = new_pd
	_wire_player(player)
	active_slot = slot
	_write_active_slot(slot)
	return save()

## 档位元信息（存档管理面板档位条渲染用）：[{slot,exists,level,active}]，按 SLOT_NAMES 顺序。
## 直接从槽 dict 取 team_level（不重建 PlayerData，三档开销可接受）。
## 测试模式合成数据不触盘（隔离真实档——load_slot 对坏档有 rename 备份副作用）。
func slot_metas() -> Array[Dictionary]:
	var metas: Array[Dictionary] = []
	if _test_mode:
		for slot in SaveManagerScript.SLOT_NAMES:
			var is_auto := slot == AUTO_SLOT
			metas.append({
				"slot": slot,
				"exists": is_auto,
				"level": player.team_level if is_auto else 1,
				"active": is_auto,
			})
		return metas
	var sm := SaveManagerScript.new(save_dir)
	for slot in SaveManagerScript.SLOT_NAMES:
		var data: Dictionary = sm.load_slot(slot)
		metas.append({
			"slot": slot,
			"exists": not data.is_empty(),
			"level": int(data.get("team_level", 1)),
			"active": slot == active_slot,
		})
	return metas

func _active_slot_path() -> String:
	return save_dir + SLOT_META_NAME

## 读活跃档位记录；缺失/坏值回退 AUTO_SLOT（老玩家无此文件 → 行为与单档时代一致）。
func _read_active_slot() -> String:
	if _test_mode:
		return AUTO_SLOT
	var f := FileAccess.open(_active_slot_path(), FileAccess.READ)
	if f == null:
		return AUTO_SLOT
	var text := f.get_as_text().strip_edges()
	f.close()
	if text not in SaveManagerScript.SLOT_NAMES:
		return AUTO_SLOT
	return text

func _write_active_slot(slot: String) -> void:
	if _test_mode:
		return
	var f := FileAccess.open(_active_slot_path(), FileAccess.WRITE)
	if f != null:
		f.store_string(slot)
		f.close()
