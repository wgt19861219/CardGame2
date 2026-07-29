class_name StageDetailPanel
extends PopWindow

const UiScale9Button := preload("res://scripts/ui/ui_scale9_button.gd")

## 关卡详情（View 层）— 照源 stagedetail.lua create:1536-1934 完整复刻。
## 重构（2026-07-17）：base 层静态节点位置/size 固化进 stage_detail_content.tscn（instantiate + fill 范式，
## 同 hero_detail/shop）。本类管数据装配（getInformation :772）+ checkEnabled :785 + go/sweep/reset/close 交互。
## 本项目单机化 pushScene→PopWindow，shade 透明 + .tscn %FrameworkBg 补 bg.jpg 还原源视觉。

const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/stage_detail_content.tscn")
const TEAM_MAX: int = 5
# SweepBtn Scale9 样式（源 stagedetail.lua:378/392 tavern_button_normal_1/2.png，cap 20,15,90,15）。
const SWEEP_BTN_RES: String = "res://assets/ui/alpha/HVGA/tavern_button_normal_1.png"
const SWEEP_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/tavern_button_normal_2.png"
const SWEEP_BTN_CAP: Rect2 = Rect2(20.0, 15.0, 90.0, 15.0)

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
	var bd := BattleData.from_config(player.cm, p_sid, 3)
	_enemies = bd.get_monsters()
	_res_info = StageDetailBuilder.get_res_info(StageAccount.stage_type(p_sid))
	setup()
	# 本项目单机化 pushScene→PopWindow，故 shade 透明（.tscn %FrameworkBg 已铺 bg.jpg 还原源视觉，同 PackagePanel 范式）。
	if shade_layer != null:
		shade_layer.color.a = 0
		shade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_content()


# 建 UI 内容。base 层从 .tscn instantiate + fill 动态数据/texture；敌人/奖励/星/扫荡挂各 host。
func _build_content() -> void:
	for c in container.get_children():
		c.queue_free()
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	var info: Dictionary = _get_stage_info()
	_ui = StageDetailBuilder.setup_content(content, info, _res_info, player.cm)
	StageDetailBuilder.create_enemy(content.get_node("%EnemyHost"), _enemies, player.cm)
	if _stage_data != null:
		StageDetailBuilder.create_reward(content.get_node("%RewardHost"), _stage_data.drops, player.cm)
	StageDetailBuilder.create_stars(content.get_node("%StarHost"), int(info.get("star", 0)), int(_res_info.get("star_gap", 55)))
	(_ui["go_button"] as TextureButton).pressed.connect(_on_go_pressed)
	(_ui["reset"] as TextureButton).pressed.connect(_on_reset_pressed)
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	if String(info.get("stage_type", "normal")) == "normal":
		(_ui["count_title"] as Label).visible = false
		(_ui["count_number"] as Label).visible = false
		(_ui["total_number"] as Label).visible = false
	_setup_sweep_button(content.get_node("%SweepBtn") as Button, int(info.get("star", 0)))
	_check_enabled()
	# 详情是关卡选择的子弹窗（stage_select_panel.gd detail.show_window(get_parent())），
	# 不碰 HudOverlay identity——遵循项目范式（battle_reward_popup / excavate_team_panel 等子弹窗
	# 同样不调 apply_identity）。否则关闭详情会把 identity 错误跳回 "main"，使头像/shortcut
	# 在仍在前台的关卡选择面板之上错误显示。identity 保持父级 stageselect，由 StageSelectPanel
	# 关闭时恢复 main。


# 项目 StageData 首次访问可能缺 row，"关卡 %d" fallback 是项目适配（源 row 必存在）。
func _get_stage_info() -> Dictionary:
	var row: Dictionary = player.cm.get_raw_table("Stage").get(str(stage_id), {})
	# Stage Name/description 存 LSTR key（535 条中 508/425 条是 key），需 get_lstr 本地化
	# （源 lua 直接取因 LSTR 宏已展开；本项目 JSON 存原始 key 须转换，否则标题显示英文 key）。
	var title_raw: String = String(row.get("Stage Name", "关卡 %d" % stage_id))
	var detail_raw: String = String(row.get("description", ""))
	return {
		"title": String(player.cm.get_lstr(title_raw)),
		"detail": String(player.cm.get_lstr(detail_raw)),
		"power": _stage_data.vitality_cost if _stage_data != null else 0,
		"count_limit": int(row.get("Daily Limit", 0)),
		"count": int(player.stage_limit.get(stage_id, 0)),
		"chapter": int(row.get("Chapter ID", 1)),
		"star": mgr.stage_stars(stage_id) if mgr != null else 0,
		"is_key_stage": false,
		"stage_type": StageAccount.stage_type(stage_id),
	}


func _check_enabled() -> void:
	var left: int = _left_times()
	var cn: Label = _ui.get("count_number", null) as Label
	if cn != null:
		cn.text = str(left)
		cn.add_theme_color_override("font_color", StageDetailBuilder.C_DISABLE if left < 1 else StageDetailBuilder.C_NUM)
	var power: int = _stage_data.vitality_cost if _stage_data != null else 0
	_is_vitality_enabled = player.vitality >= power
	var count_limit: int = _daily_limit()
	_is_count_enabled = count_limit > int(player.stage_limit.get(stage_id, 0)) or count_limit <= 0
	var reset_btn: TextureButton = _ui.get("reset", null) as TextureButton
	if reset_btn != null:
		reset_btn.visible = not _is_count_enabled
	var pn: Label = _ui.get("power_number", null) as Label
	var gs: TextureRect = _ui.get("go_button_shade", null) as TextureRect
	if _is_vitality_enabled and _is_count_enabled:
		if pn != null:
			pn.add_theme_color_override("font_color", StageDetailBuilder.C_NUM)
		if gs != null:
			gs.visible = false
	elif gs != null:
		gs.visible = true


func _left_times() -> int:
	return _daily_limit() - int(player.stage_limit.get(stage_id, 0))


func _daily_limit() -> int:
	return int(player.cm.get_raw_table("Stage").get(str(stage_id), {}).get("Daily Limit", 0))


# .tscn %SweepBtn 默认 visible=false，3 星 + 有 mgr 时切 visible=true + 绑信号。
# 套 Scale9 stylebox（tavern_button_normal_1/2 cap 20,15,90,15）+ fill 独立 Label 子节点 %SweepLabel
# （Button.text 内嵌 label 受 stylebox content_margin 干扰字偏左上，范式同 hero_detail）。
func _setup_sweep_button(btn: Button, star: int) -> void:
	if mgr == null or star < 3:
		btn.visible = false
		return
	btn.visible = true
	btn.add_theme_stylebox_override("normal", UiScale9Button._make_sb(SWEEP_BTN_RES, SWEEP_BTN_CAP))
	btn.add_theme_stylebox_override("hover", UiScale9Button._make_sb(SWEEP_BTN_RES, SWEEP_BTN_CAP))
	btn.add_theme_stylebox_override("pressed", UiScale9Button._make_sb(SWEEP_BTN_PRESS_RES, SWEEP_BTN_CAP))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	(btn.get_node("SweepLabel") as Label).text = String(player.cm.get_lstr("PRIVILEGE.FARM"))
	btn.pressed.connect(_on_sweep_pressed)


func _on_go_pressed() -> void:
	if not (_is_vitality_enabled and _is_count_enabled):
		return
	AudioPlayer.play_sfx("common_click_feedback")
	if mgr == null or player == null or rng == null:
		return
	var panel := BattlePreparePanel.new()
	panel.setup(stage_id, player, mgr, rng, player.cm)
	var parent: Node = get_parent()
	if parent != null:
		parent.add_child(panel)
	remove_window()


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


# 流程：getResetEliteCost 读 GradientPrice[times+1]["Elite Reset"]（梯度计费 20/50/.../1000）
# + checkStageLimitResetTimesMax VIP 次数上限（needHighervip dialog 拒绝）
# + 弹确认框（showConfirmDialog，RESET_COSTS 文案 + 已重置次数）
# + doResetElite 扣钻 + refreshStageEliteLimit（清 stage_limit + reset_times++）。
# 项目单机化：CrusadeResetConfirm 范式简化（文案 + 确认/取消），needHighervip/toRecharge 用 Toast。
func _on_reset_pressed() -> void:
	AudioPlayer.play_sfx("common_click_feedback")
	if StageResetData.is_reset_times_max(player, stage_id):
		Toast.show_message("VIP 等级不足，无法继续重置")  # 项目适配 toast（源 needHighervip dialog）
		return
	var cost: int = StageResetData.get_reset_cost(player, stage_id)
	if cost <= 0:
		Toast.show_message("该关卡无法购买次数")
		return
	var times: int = StageResetData.get_reset_times(player, stage_id)
	# 项目单机化：CrusadeResetConfirm 范式（独立 Control 确认框）。
	var msg: String = String(player.cm.get_lstr("STAGEDETAIL.RESET_COSTS__D_DIAMONDS_\\N_WISH_TO_CONTINUEYOU_HAVE_RESET__D_TIMES_TODAY"))
	if msg == "STAGEDETAIL.RESET_COSTS__D_DIAMONDS_\\N_WISH_TO_CONTINUEYOU_HAVE_RESET__D_TIMES_TODAY":
		msg = "重置关卡进入次数需要花费%d钻石.\n是否继续？（今日已重置%d次）"
	msg = msg % [cost, times]
	var popup := StageResetConfirm.new()
	popup.setup_msg(msg, player.cm)
	popup.confirmed.connect(_do_reset_elite.bind(cost))
	var parent: Node = get_parent()
	if parent != null:
		parent.add_child(popup)


# 单机化：源走 netdata/netreply 网络流程，项目直接本地执行（doResetEliteLimit handler 内逻辑）。
func _do_reset_elite(cost: int) -> void:
	if player.diamond < cost:
		Toast.show_message("钻石不足，请充值")  # 项目适配 toast（源 toRecharge dialog）
		return
	player.diamond -= cost
	StageResetData.refresh_elite_limit(player, stage_id)
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
