class_name CrusadePanel
extends PopWindow

const UiScale9Button := preload("res://scripts/ui/ui_scale9_button.gd")
const CrusadePanelBuilder := preload("res://scripts/ui/crusade_panel_builder.gd")

## UIRes 节点树缺（Cocos Studio 导出物，同 .Puppet 阻塞）→ 代码重建核心：
##   15 stage TextureButton + current/locked/passed 状态纹理 + 战斗入口 + 水平滚动。
##
## 2026-07-17 .tscn 重构（hero_detail 范式）：位置/size 静态化进 crusade_content.tscn
## （FrameworkBg/CloseBtn/ResetBtn/FogLayer+4 Fog/StageScroll+HBox/EnemyPreviewHost/
## StartBtn/ResultLabel/HintAnchor+StageHint），panel instantiate + get_node("%..") 收集 +
## fill 动态数据。stage/box 15 行按钮仍 procedural 由 HBox 自动排版（位置非 cocos 坐标）。

# crusade_content.tscn：base 静态层（位置/size 编辑器可视化调）。
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/crusade_content.tscn")
const RESET_BTN_RES: String = "res://assets/ui/alpha/HVGA/tavern_button_normal_1.png"
const RESET_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/tavern_button_normal_2.png"
const RESET_BTN_CAP: Rect2 = Rect2(14.0, 20.0, 60.0, 23.0)
const LSTR_RESET_KEY: String = "CRUSADECONFIG.RESTART"
const STAGE_TEX_DIR := "res://assets/ui/alpha/HVGA/crusade/stage/crusade_stage_"
const STAGE_SIZE: Vector2 = Vector2(110.0, 110.0)
const BOX_SIZE: Vector2 = Vector2(60.0, 60.0)
const BOX_TEX_DIR := "res://assets/ui/alpha/HVGA/crusade/crusade_box_"
const SHAKE_INTERVAL: float = 1.5
const SHAKE_SCALE_PEAK: Vector2 = Vector2(1.15, 1.15)
const SHAKE_DURATION: float = 0.1
const REWARD_SCALE_PEAK: Vector2 = Vector2(1.3, 1.3)
const REWARD_DURATION: float = 0.08
const HINT_OFFSET_Y: float = -30.0
const HINT_OFFSET_BOX_X: float = 40.0
const HINT_FLOAT_DELTA: float = 10.0
const HINT_FLOAT_TIME: float = 0.5
const ENEMY_ICON_SCALE: float = 0.65
const ENEMY_ICON_GAP: int = 5
const ENEMY_HP_FULL: int = 10000
const CRUSADE_HERO_MIN_LEVEL: int = 20
# ruleLayer 规则页按钮（照源 crusadeconfig.lua:965-987 showrule Scale9Button）
const RULE_SHOWRULE_BTN_POS: Vector2 = Vector2(560.0, 50.0)
const RULE_SHOWRULE_BTN_SIZE: Vector2 = Vector2(120.0, 48.0)
const RULE_LABEL_FONT_SIZE: int = 18
const LSTR_SHOW_RULE: String = "CRUSADECONFIG.REVIEW_RULES"

var player: PlayerData = null
var rng: BattleRng = null
var stage_buttons: Array[TextureButton] = []
var box_rects: Array[TextureButton] = []
var fog_rects: Array[TextureRect] = []
var result_label: Label = null
var current_select: int = 0
var enemy_preview_box: Control = null
var start_btn: TextureButton = null
var _shake_timer: Timer = null
var _hint_anchor: Control = null
var stage_hint: CanvasItem = null
var _rule_layer: Control = null   # 规则页层（null=未建，visible 切换 show/close）


func setup_panel(p_player: PlayerData, p_rng: BattleRng) -> void:
	hud_identity = "crusade"   # T4：原 apply/remove override 样板上收基类
	transparent_shade = true   # T4：原 shade 透明 hack 上收基类
	player = p_player
	rng = p_rng
	player.ensure_crusade(rng)
	setup()
	# 本项目单机化 pushScene→PopWindow，故 shade 透明 + .tscn 已补全屏 bg.jpg 还原源视觉。
	_build_content()
	_create_shake_timer()
	_refresh_stage_states()
	register_on_enter(_refresh_hint_pos)


# 建 UI 内容：base 从 .tscn instantiate（位置/size 静态化）+ 收集 + bind + fill 动态层。
func _build_content() -> void:
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	# 收集 .tscn 静态节点（位置/size 已固化，运行时只 fill 数据/纹理/visible）。
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	var reset_btn: Button = content.get_node("%ResetBtn") as Button
	_apply_reset_button_style(reset_btn)
	(content.get_node("%ResetLabel") as Label).text = _lstr(LSTR_RESET_KEY, "重新开始")
	reset_btn.pressed.connect(_on_reset)
	(content.get_node("%StartBtn") as BaseButton).pressed.connect(_on_start_pressed)
	result_label = content.get_node("%ResultLabel") as Label
	enemy_preview_box = content.get_node("%EnemyPreviewHost") as Control
	start_btn = content.get_node("%StartBtn") as TextureButton
	start_btn.visible = false
	result_label.text = "远征：第 " + str(player.crusade_manager.cur_stage) + " 关"
	_hint_anchor = content.get_node("%HintAnchor") as Control
	stage_hint = content.get_node("%StageHint") as CanvasItem
	_start_hint_float()
	# Fog1-4 .tscn 静态，instantiate 后收集（按 currentStage 显隐）。
	fog_rects.clear()
	for i in range(1, 5):
		fog_rects.append(content.get_node("%Fog" + str(i)) as TextureRect)
	# 静态美术层（5 类缺图：bg 三段滚动背景 + frame 外框 + light 光效 + title_bg 标题底 + reset_bg 底部栏）。
	# 必须在 _create_stage_list 之前建：HBox 子后建，bg/frame 在 .tscn 静态层之上、关卡按钮之下。
	CrusadePanelBuilder.build_crusade(content)
	# HBox 内 15 VBox ×（stage btn + box btn）。
	var hbox: HBoxContainer = content.get_node("%StageHBox") as HBoxContainer
	_create_stage_list(hbox)
	# 规则页按钮（照源 crusadeconfig.lua:976 showrule Scale9Button handleName=showRuleInfo）
	_create_rule_button(content)
	# HudOverlay 切 identity=crusade（shortcut 隐藏，仅货币栏）。




func _create_stage_list(hbox: HBoxContainer) -> void:
	for i in range(1, CrusadeData.MAX_STAGE + 1):
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var btn := TextureButton.new()
		btn.texture_normal = _load_tex(_stage_texture(i))
		btn.custom_minimum_size = STAGE_SIZE
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.pressed.connect(Callable(self, "_on_stage_n").bind(i))
		vbox.add_child(btn)
		var box := TextureButton.new()
		box.texture_normal = _load_tex(_box_texture(i))
		box.custom_minimum_size = BOX_SIZE
		box.ignore_texture_size = true
		box.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		box.pressed.connect(Callable(self, "_on_box_pressed").bind(i))
		vbox.add_child(box)
		hbox.add_child(vbox)
		stage_buttons.append(btn)
		box_rects.append(box)


func _box_tier(i: int) -> String:
	if i == 15:
		return "gold"
	if i == 5 or i == 10:
		return "silver"
	return "bronze"


func _box_texture(i: int) -> String:
	var state: String = "open" if player.crusade_manager.is_stage_rewarded(i) else "closed"
	return BOX_TEX_DIR + _box_tier(i) + "_" + state + ".png"


## 资源安全加载（exists 预检，避 headless/未 import 时 load push_error）。
static func _load_tex(path: String) -> Variant:
	return load(path) if ResourceLoader.exists(path) else null


# .tscn 普通 Button 套 Scale9 StyleBoxTexture（normal/hover=tavern_button_normal_1, pressed=tavern_button_normal_2）。
# 视觉等价 Scale9Sprite + press mask。文字 fill 到独立 Label 子节点 %ResetLabel
# （Button.text 内嵌 label 受 stylebox content_margin 干扰字偏左上，范式同 hero_detail）。
func _apply_reset_button_style(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", UiScale9Button._make_sb(RESET_BTN_RES, RESET_BTN_CAP))
	btn.add_theme_stylebox_override("hover", UiScale9Button._make_sb(RESET_BTN_RES, RESET_BTN_CAP))
	btn.add_theme_stylebox_override("pressed", UiScale9Button._make_sb(RESET_BTN_PRESS_RES, RESET_BTN_CAP))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _stage_texture(i: int) -> String:
	var state: String = "locked"
	if player.crusade_manager.cur_stage == i:
		state = "current"
	elif player.crusade_manager.is_stage_cleared(i):
		state = "passed"
	return STAGE_TEX_DIR + str(i) + "_" + state + ".png"


func _on_reset() -> void:
	if player == null or player.crusade_manager == null:
		return
	if player.crusade_manager.get_reset_left() <= 0:
		result_label.text = _lstr("CRUSADE.NO_RESET_TIMES_LEFT_TODAY", "今日已没有重置次数")
		return
	var popup := CrusadeResetConfirm.new()
	popup.confirmed.connect(_on_reset_confirmed)
	container.add_child(popup)


func _on_reset_confirmed() -> void:
	if player == null or player.crusade_manager == null:
		return
	player.crusade_manager.reset()
	_refresh_stage_states()
	result_label.text = _lstr("CRUSADE.THE_REMAINING_TIMES_OF_TODAY___D", "今日剩余次数:%d") % player.crusade_manager.get_reset_left()


func _lstr(key: String, fallback: String) -> String:
	if player != null and player.cm != null:
		return player.cm.get_lstr(key)
	return fallback


func _on_box_pressed(i: int) -> void:
	if player == null or player.crusade_manager == null:
		return
	var cm_mgr = player.crusade_manager
	if cm_mgr.is_stage_rewarded(i):
		result_label.text = "第 %d 关 已领取" % i
		return
	if cm_mgr.is_stage_cleared(i):
		_apply_box_reward(i)
		return
	if not _is_stage_locked(i):
		_show_reward_preview(i)


func _apply_box_reward(stage: int) -> void:
	var slots: Array = player.crusade_manager.draw_reward_slots(stage)
	if slots.is_empty():
		result_label.text = "第 " + str(stage) + " 关 不可领"
		return
	player.crusade_manager.apply_rewards(slots, player, rng)
	_bounce_box_at(stage - 1, REWARD_SCALE_PEAK, REWARD_DURATION)
	var reward_text: String = ""
	for s in slots:
		reward_text += String(s["type"]) + "×" + str(s["amount"]) + " "
	result_label.text = "第 " + str(stage) + " 关 奖励：" + reward_text
	var reward_popup := BattleRewardPopup.new("crusadeReward", {})
	reward_popup.setup_rewards(slots, player.cm)
	reward_popup.show_window(get_parent())
	_refresh_stage_states()


func _show_reward_preview(i: int) -> void:
	var slots: Array = player.crusade_manager.draw_reward_slots(i)
	if slots.is_empty():
		result_label.text = "第 " + str(i) + " 关 暂无奖励预览"
		return
	var preview_text: String = "第 " + str(i) + " 关 预览："
	for s in slots:
		preview_text += String(s["type"]) + "×" + str(s["amount"]) + " "
	result_label.text = preview_text


func _refresh_fog() -> void:
	if fog_rects.size() < 4 or player == null or player.crusade_manager == null:
		return
	var cur: int = player.crusade_manager.cur_stage
	fog_rects[0].visible = cur <= 3
	fog_rects[1].visible = cur <= 6
	fog_rects[2].visible = cur <= 9
	fog_rects[3].visible = cur <= 12


func _refresh_enemy_preview(stage: int) -> void:
	if enemy_preview_box == null or player == null or player.crusade_manager == null:
		return
	for c in enemy_preview_box.get_children():
		c.queue_free()
	var enemies_arr: Array = player.crusade_manager.get_stage_enemies(stage)
	var slot_w: float = ReadheroIcon.CONTAINER_SIZE.x * ENEMY_ICON_SCALE + float(ENEMY_ICON_GAP)
	var idx: int = 0
	for hero in enemies_arr:
		var icon := ReadheroIcon.new()
		icon.setup({
			"id": int(hero.get("_tid", 0)),
			"rank": int(hero.get("_rank", 1)),
			"level": int(hero.get("_level", 1)),
			"stars": int(hero.get("_stars", 0)),
			"hp": ENEMY_HP_FULL,
		}, player.cm)
		icon.scale = Vector2(ENEMY_ICON_SCALE, ENEMY_ICON_SCALE)
		icon.position = Vector2(float(idx) * slot_w, 0.0)
		enemy_preview_box.add_child(icon)
		idx += 1


func _on_stage_n(i: int) -> void:
	if player == null or player.crusade_manager == null:
		return
	var cm_mgr = player.crusade_manager
	if cm_mgr.is_stage_cleared(i):
		result_label.text = "第 " + str(i) + " 关 已通关"
		return
	if _is_stage_locked(i):
		result_label.text = "第 " + str(i) + " 关 未解锁（需先通关前序/领上关奖）"
		return
	current_select = i
	_refresh_enemy_preview(i)
	if start_btn != null:
		start_btn.visible = true
	var enemies_arr: Array = cm_mgr.get_stage_enemies(i)
	var enemy_count: int = enemies_arr.size()
	var max_stage: int = CrusadeManager.MAX_STAGE
	if enemy_count > 0:
		var first_lvl: int = int(enemies_arr[0].get("_level", 1))
		result_label.text = "第 %d/%d 关  敌方 %d 人  Lv.%d" % [i, max_stage, enemy_count, first_lvl]
	else:
		result_label.text = "第 %d/%d 关  (无敌人数据)" % [i, max_stage]


## 目标单机化：弹 BattlePreparePanel（mode=crusade），玩家战前调阵容/看敌方；战斗同步执行，
## 通过 crusade_battle_finished 信号回调刷新本面板。
func _on_start_pressed() -> void:
	if player == null or rng == null or current_select == 0:
		return
	var stage_id: int = -2 - current_select
	var panel := BattlePreparePanel.new()
	panel.setup(stage_id, player, player.crusade_manager, rng, player.cm, "crusade", CRUSADE_HERO_MIN_LEVEL)
	panel.crusade_battle_finished.connect(_on_crusade_battle_finished)
	var parent: Node = get_parent()
	if parent != null:
		parent.add_child(panel)
	if start_btn != null:
		start_btn.visible = false


func _on_crusade_battle_finished(won: bool, stage: int) -> void:
	if won:
		result_label.text = "第 " + str(stage) + " 关 胜利"
	else:
		result_label.text = "第 " + str(stage) + " 关 失败"
	_refresh_stage_states()


func _create_shake_timer() -> void:
	_shake_timer = Timer.new()
	_shake_timer.wait_time = SHAKE_INTERVAL
	_shake_timer.one_shot = false
	_shake_timer.autostart = true   # 进树时自动 start
	_shake_timer.timeout.connect(_shake_box)
	add_child(_shake_timer)


func _shake_box() -> void:
	if not is_inside_tree() or player == null or player.crusade_manager == null:
		return
	var prev: int = player.crusade_manager.cur_stage - 1
	if prev < 1 or not player.crusade_manager.is_stage_cleared(prev):
		return
	_bounce_box_at(prev - 1, SHAKE_SCALE_PEAK, SHAKE_DURATION)


func _bounce_box_at(idx: int, peak_scale: Vector2, duration: float) -> void:
	if idx < 0 or idx >= box_rects.size():
		return
	var box: TextureButton = box_rects[idx]
	var tw := create_tween()
	tw.tween_property(box, "scale", peak_scale, duration)
	tw.tween_property(box, "scale", Vector2.ONE, duration)


func _start_hint_float() -> void:
	if stage_hint == null:
		return
	var tw := create_tween()
	tw.set_loops(-1)
	tw.tween_property(stage_hint, "position:y", -HINT_FLOAT_DELTA, HINT_FLOAT_TIME).as_relative()
	tw.tween_property(stage_hint, "position:y", HINT_FLOAT_DELTA, HINT_FLOAT_TIME).as_relative()


func _refresh_hint_pos() -> void:
	if _hint_anchor == null or player == null or player.crusade_manager == null:
		return
	var cm_mgr = player.crusade_manager
	if cm_mgr.is_stage_rewarded(CrusadeManager.MAX_STAGE):
		_hint_anchor.visible = false
		return
	var cur: int = cm_mgr.cur_stage
	var target: Control = null
	var offset_x: float = 0.0
	if not cm_mgr.is_stage_cleared(cur) and (cur <= 1 or cm_mgr.is_stage_rewarded(cur - 1)):
		if cur - 1 >= 0 and cur - 1 < stage_buttons.size():
			target = stage_buttons[cur - 1]
	elif cur > 1 and cm_mgr.is_stage_cleared(cur - 1):
		if cur - 2 >= 0 and cur - 2 < box_rects.size():
			target = box_rects[cur - 2]
			offset_x = HINT_OFFSET_BOX_X
	if target == null:
		_hint_anchor.visible = false
		return
	_hint_anchor.visible = true
	var target_global: Vector2 = target.get_global_rect().position
	var origin: Vector2 = container.get_global_rect().position
	_hint_anchor.position = target_global - origin + Vector2(offset_x, HINT_OFFSET_Y)


## 刷新 stage 按钮状态纹理（通关/当前/锁定）+ disabled + box 宝箱。
func _refresh_stage_states() -> void:
	var i: int = 1
	while i <= stage_buttons.size():
		stage_buttons[i - 1].texture_normal = _load_tex(_stage_texture(i))
		stage_buttons[i - 1].disabled = _is_stage_locked(i)
		if i - 1 < box_rects.size():
			box_rects[i - 1].texture_normal = _load_tex(_box_texture(i))
		i += 1
	_refresh_fog()
	_refresh_hint_pos()


func _is_stage_locked(i: int) -> bool:
	if player == null or player.crusade_manager == null:
		return false
	if player.crusade_manager.is_stage_cleared(i):
		return false   # 已通关可选（领奖）
	var cur: int = player.crusade_manager.cur_stage
	if i > cur:
		return true   # 超进度
	if i == cur and i > 1 and not player.crusade_manager.is_stage_rewarded(i - 1):
		return true
	return false


# ==================== 规则页（照源 crusade.lua:425-610 ruleLayer）====================

# 规则按钮（照源 crusadeconfig.lua:965-987 showrule Scale9Button）。
func _create_rule_button(content: Node) -> void:
	var btn := Button.new()
	btn.add_theme_stylebox_override("normal", UiScale9Button._make_sb(RESET_BTN_RES, RESET_BTN_CAP))
	btn.add_theme_stylebox_override("hover", UiScale9Button._make_sb(RESET_BTN_RES, RESET_BTN_CAP))
	btn.add_theme_stylebox_override("pressed", UiScale9Button._make_sb(RESET_BTN_PRESS_RES, RESET_BTN_CAP))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.position = RULE_SHOWRULE_BTN_POS
	btn.size = RULE_SHOWRULE_BTN_SIZE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var lbl := Label.new()
	lbl.text = player.cm.get_lstr(LSTR_SHOW_RULE)
	lbl.add_theme_font_size_override("font_size", RULE_LABEL_FONT_SIZE)
	lbl.anchors_preset = Control.PRESET_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)
	btn.pressed.connect(_show_rule_info)
	content.add_child(btn)


func _show_rule_info() -> void:
	if _rule_layer == null:
		_rule_layer = CrusadeRuleRenderer.build_rule_layer(container, player.cm, _close_rule_info)
	_rule_layer.visible = true


func _close_rule_info() -> void:
	if _rule_layer != null:
		_rule_layer.visible = false

