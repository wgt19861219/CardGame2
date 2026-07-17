class_name StageDetailPanel
extends PopWindow

## 关卡详情（View 层）— 照源 stagedetail.lua create:1536-1934 完整复刻。
## 委托 StageDetailBuilder 装配节点（cocos→Godot 坐标转换），本类管数据装配（getInformation :772）
## + checkEnabled :785 + go/sweep/reset/close 交互。源四步 stageselect→stagedetail→battleprepare→battle，
## 本项目点开战→弹 BattlePreparePanel 布阵面板→进 battle_scene。

const TEAM_MAX: int = 5
const CLOSE_BTN_POS: Vector2 = Vector2(20.0, 15.0)  # 左上角留小边（用户偏好更靠左上角）
const CLOSE_BTN_SIZE: Vector2 = Vector2(50.0, 30.0)
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/backbtn.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/backbtn-disabled.png"
const SWEEP_BTN_POS: Vector2 = Vector2(380.0, 380.0)
const SWEEP_BTN_SIZE: Vector2 = Vector2(100.0, 40.0)
# 源 framework.lua:749 pushScene 场景自动加全屏 bg.jpg（stagedetail.lua:1550 是 pushScene 独立场景）。
const FRAMEWORK_BG: String = "res://assets/ui/alpha/HVGA/bg.jpg"

var stage_id: int = 0
var mgr: StageManager = null
var player: PlayerData = null
var rng: BattleRng = null
var _stage_data: StageData = null
var _enemies: Array[Dictionary] = []
var _ui: Dictionary = {}
var _res_info: Dictionary = {}
var _is_vitality_enabled: bool = false
var _is_count_enabled: bool = false


func setup_panel(p_sid: int, p_mgr: StageManager, p_player: PlayerData, p_rng: BattleRng) -> void:
	stage_id = p_sid
	mgr = p_mgr
	player = p_player
	rng = p_rng
	_stage_data = StageData.from_config(player.cm, p_sid)
	var bd := BattleData.from_config(player.cm, p_sid, 3)  # 源 :695 step 默认 3（最后一波）
	_enemies = bd.get_monsters()
	_res_info = StageDetailBuilder.get_res_info(StageAccount.stage_type(p_sid))
	setup()
	# 源 stagedetail.lua:1550 pushScene 独立场景（framework.lua:749 自动建全屏 bg.jpg），
	# 本项目单机化 pushScene→PopWindow，故 shade 透明 + 补全屏 bg.jpg 还原源视觉（同 PackagePanel 范式）。
	if shade_layer != null:
		shade_layer.color.a = 0
		shade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


# 源 framework.lua:749-751 pushScene 场景全屏 bg.jpg（stagedetail 源是独立场景）。
# _build 每次开新 stage 会 queue_free 全部子节点，故 bg 需随每次重建补回（保持最底层）。
func _create_fullscreen_bg() -> void:
	var bg := TextureRect.new()
	bg.texture = load(FRAMEWORK_BG)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.position = Vector2.ZERO
	bg.size = Vector2(960.0, 640.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)


func _build() -> void:
	for c in container.get_children():
		c.queue_free()
	_create_fullscreen_bg()
	var info: Dictionary = _get_stage_info()
	_ui = StageDetailBuilder.build(container, info, _res_info, player.cm)
	StageDetailBuilder.create_enemy(container, _enemies, player.cm)
	if _stage_data != null:
		StageDetailBuilder.create_reward(container, _stage_data.drops, player.cm)
	StageDetailBuilder.create_stars(container, int(info.get("star", 0)), int(_res_info.get("star_gap", 55)))
	(_ui["go_button"] as TextureButton).pressed.connect(_on_go_pressed)
	(_ui["reset"] as TextureButton).pressed.connect(_on_reset_pressed)
	# 源 :1906-1910 normal/act/guild 隐藏 count（无 daily limit）。
	if String(info.get("stage_type", "normal")) == "normal":
		(_ui["count_title"] as Label).visible = false
		(_ui["count_number"] as Label).visible = false
		(_ui["total_number"] as Label).visible = false
	_create_sweep_button(int(info.get("star", 0)))
	_create_close_button()
	_check_enabled()


# 源 getStageInformation（Stage 表字段映射）。源 :613 info.title = row["Stage Name"]（无 fallback）；
# 项目 StageData 首次访问可能缺 row，"关卡 %d" fallback 是项目适配（源 row 必存在）。
func _get_stage_info() -> Dictionary:
	var row: Dictionary = player.cm.get_raw_table("Stage").get(str(stage_id), {})
	return {
		"title": String(row.get("Stage Name", "关卡 %d" % stage_id)),
		"detail": String(row.get("description", "")),
		"power": _stage_data.vitality_cost if _stage_data != null else 0,
		"count_limit": int(row.get("Daily Limit", 0)),
		"count": int(player.stage_limit.get(stage_id, 0)),
		"chapter": int(row.get("Chapter ID", 1)),
		"star": mgr.stage_stars(stage_id) if mgr != null else 0,
		"is_key_stage": false,
		"stage_type": StageAccount.stage_type(stage_id),
	}


# 源 checkEnabled :785-837。count_number 色 + 体力/次数判定 + reset/go_button_shade 显隐。
func _check_enabled() -> void:
	var left: int = _left_times()
	var cn: Label = _ui.get("count_number", null) as Label
	if cn != null:
		cn.text = str(left)
		cn.add_theme_color_override("font_color", StageDetailBuilder.C_DISABLE if left < 1 else StageDetailBuilder.C_NUM)
	var power: int = _stage_data.vitality_cost if _stage_data != null else 0
	_is_vitality_enabled = player.vitality >= power
	var count_limit: int = _daily_limit()
	# 源 :813 (limit > getStageLimit) or limit<=0 → countEnabled，reset 隐藏（简化：getStageLimit 用 stage_limit 已用替）。
	_is_count_enabled = count_limit > int(player.stage_limit.get(stage_id, 0)) or count_limit <= 0
	var reset_btn: TextureButton = _ui.get("reset", null) as TextureButton
	if reset_btn != null:
		reset_btn.visible = not _is_count_enabled  # 源 :816 isCountEnabled → reset 隐藏
	var pn: Label = _ui.get("power_number", null) as Label
	var gs: Sprite2D = _ui.get("go_button_shade", null) as Sprite2D
	if _is_vitality_enabled and _is_count_enabled:
		if pn != null:
			pn.add_theme_color_override("font_color", StageDetailBuilder.C_NUM)
		if gs != null:
			gs.visible = false
	elif gs != null:
		gs.visible = true


# 源 getLeftTimes :779-783 countLimit - stage_limit[normalStage]。
func _left_times() -> int:
	return _daily_limit() - int(player.stage_limit.get(stage_id, 0))


func _daily_limit() -> int:
	return int(player.cm.get_raw_table("Stage").get(str(stage_id), {}).get("Daily Limit", 0))


# 源 createRepeatBattle :266-469（3 星 + normal/elite 显示扫荡）。once_label 文案源 :454 PRIVILEGE.FARM。
func _create_sweep_button(star: int) -> void:
	if mgr == null or star < 3:
		return
	var btn := Button.new()
	btn.text = String(player.cm.get_lstr("PRIVILEGE.FARM"))  # 源 :454 T(LSTR("PRIVILEGE.FARM"))="扫荡"
	btn.position = SWEEP_BTN_POS
	btn.size = SWEEP_BTN_SIZE
	btn.pressed.connect(_on_sweep_pressed)
	container.add_child(btn)


func _create_close_button() -> void:
	var btn: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, CLOSE_BTN_POS)
	btn.pressed.connect(remove_window)
	container.add_child(btn)


# 源 doClickGo → battleprepare→battle。本项目弹布阵面板 BattlePreparePanel。
func _on_go_pressed() -> void:
	if not (_is_vitality_enabled and _is_count_enabled):
		return  # 源 go_button_shade 禁用态，不可进入
	AudioPlayer.play_sfx("common_click_feedback")
	if mgr == null or player == null or rng == null:
		return
	var panel := BattlePreparePanel.new()
	panel.setup(stage_id, player, mgr, rng, player.cm)
	var parent: Node = get_parent()
	if parent != null:
		parent.add_child(panel)
	remove_window()


# 源 doClickSweep → doSendSweep：扣体力+扫荡券发奖励（sweep_stage 已在 stage_manager 实现）。
# 注：源用 repeatRewardWindow 显示战利品（stagedetail.lua:1946），项目单机化用 Toast 简化反馈。
func _on_sweep_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	if mgr == null or player == null:
		return
	var r: Dictionary = mgr.sweep(stage_id, 1, rng, player, "free")
	if bool(r.get("ok", false)):
		Toast.show_message("扫荡成功")  # 源无此 toast（用 repeatRewardWindow），项目单机化简化
		_check_enabled()
	else:
		Toast.show_message(String(r.get("msg", "扫荡失败")))  # 项目适配 toast


# 源 createRepeatBattle :266-469 购买次数（钻石）。源 :519-522 needHighervip dialog / :541 toRecharge dialog；
# 项目单机化用 Toast 简化（无 dialog 系统），文案是项目自定（源用 dialog 体系无对应 LSTR key）。
func _on_reset_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	var cost: int = int(player.cm.get_raw_table("Stage").get(str(stage_id), {}).get("Reset Cost", 0))
	if cost <= 0:
		Toast.show_message("该关卡无法购买次数")  # 项目适配 toast（源 needHighervip dialog）
		return
	if player.diamond < cost:
		Toast.show_message("钻石不足")  # 项目适配 toast（源 :541 toRecharge dialog）
		return
	player.diamond -= cost
	player.stage_limit[stage_id] = int(player.stage_limit.get(stage_id, 0)) - 1
	_check_enabled()


## 上场英雄 tid 列表（player.team inst_id → tid；同 stage_select_panel 范式）。
func _team_tids() -> Array[int]:
	var tids: Array[int] = []
	if player == null or player.hero_manager == null:
		return tids
	for inst_id in player.team:
		var hero: HeroInstance = player.hero_manager.get_hero(int(inst_id))
		if hero != null:
			tids.append(hero.tid)
	if tids.is_empty():
		for inst_id in player.hero_manager.heroes:
			tids.append(int((player.hero_manager.heroes[inst_id] as HeroInstance).tid))
			if tids.size() >= TEAM_MAX:
				break
	return tids
