class_name CrusadePanel
extends PopWindow

## 远征 UI（View 层）— 照源 ui/crusade.lua 核心翻译（2026-07-02）。
## UIRes 节点树缺（Cocos Studio 导出物，同 .Puppet 阻塞）→ 代码重建核心：
##   15 stage TextureButton + current/locked/passed 状态纹理 + 战斗入口 + 水平滚动。
## 留续（源 775 行装饰段）：自定义拖拽地图(dragLayerTouch)/雾遮罩 fog1-4/宝箱 box bronze-silver-gold/结算动画。
##
## 2026-07-17 .tscn 重构（hero_detail 范式）：位置/size 静态化进 crusade_content.tscn
## （FrameworkBg/CloseBtn/ResetBtn/FogLayer+4 Fog/StageScroll+HBox/EnemyPreviewHost/
## StartBtn/ResultLabel/HintAnchor+StageHint），panel instantiate + get_node("%..") 收集 +
## fill 动态数据。stage/box 15 行按钮仍 procedural 由 HBox 自动排版（位置非 cocos 坐标）。

# crusade_content.tscn：base 静态层（位置/size 编辑器可视化调）。
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/crusade_content.tscn")
# ResetBtn Scale9 样式（源 ui_normal_button：tavern_button_normal_1/2.png，cap 14,20,60,23）。
const RESET_BTN_RES: String = "res://assets/ui/alpha/HVGA/tavern_button_normal_1.png"
const RESET_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/tavern_button_normal_2.png"
const RESET_BTN_CAP: Rect2 = Rect2(14.0, 20.0, 60.0, 23.0)
const LSTR_RESET_KEY: String = "CRUSADECONFIG.RESTART"   # 源 :514 T(LSTR("CRUSADECONFIG.RESTART")) = "重新开始"
const STAGE_TEX_DIR := "res://assets/ui/alpha/HVGA/crusade/stage/crusade_stage_"
const STAGE_SIZE: Vector2 = Vector2(110.0, 110.0)
const BOX_SIZE: Vector2 = Vector2(60.0, 60.0)
const BOX_TEX_DIR := "res://assets/ui/alpha/HVGA/crusade/crusade_box_"
# 源 crusade.lua:30-41 shakeBox + :91 ListenTimer(Always(1.5)) 上一关 box 弹跳（提示有奖可领）
const SHAKE_INTERVAL: float = 1.5
const SHAKE_SCALE_PEAK: Vector2 = Vector2(1.15, 1.15)   # 源 :36 CCScaleTo(0.1,1.15)
const SHAKE_DURATION: float = 0.1   # 源 :36-37 各 0.1s
const REWARD_SCALE_PEAK: Vector2 = Vector2(1.3, 1.3)   # 源 :716 CCScaleTo(0.08,1.3)
const REWARD_DURATION: float = 0.08   # 源 :716-717 各 0.08s
# 源 mainLayer.currentStageHint 导航箭头（指当前关/上关宝箱 + 上下浮动）
const HINT_OFFSET_Y: float = -30.0      # 源 :321 pos.y+30（cocos y 向上→Godot -30 浮目标上方）
const HINT_OFFSET_BOX_X: float = 40.0   # 源 :313 上关宝箱 offsetX=40
const HINT_FLOAT_DELTA: float = 10.0    # 源 :616 ccp(0,10)
const HINT_FLOAT_TIME: float = 0.5      # 源 :616 0.5s
const TEAM_MAX: int = 5   # 上场英雄上限（源 5v5）
const ENEMY_ICON_SCALE: float = 0.65   # 源 :231 setScale(0.8) → 0.65 适配（5×104 太宽）
const ENEMY_ICON_GAP: int = 5
const ENEMY_HP_FULL: int = 10000   # 源 _hp_perc 满血万分比（:215 if 0<_hp_perc）
const CRUSADE_HERO_MIN_LEVEL: int = 20   # 源 crusade.lua:436 heroLimit level=20

var player: PlayerData = null
var rng: BattleRng = null
var stage_buttons: Array[TextureButton] = []
# 源 :311 boxButton{currentStage-1} —— 源中宝箱是 Button 可点（hintBox/hintBoxDown）。
var box_rects: Array[TextureButton] = []
var fog_rects: Array[TextureRect] = []
var result_label: Label = null
var current_select: int = 0   # 当前选中关（源 currentSelectStage）
var enemy_preview_box: Control = null   # 源 battleLayer.hero1-5 敌方阵容容器
var start_btn: TextureButton = null   # 源 battleLayer.start "开始战斗"（选关后 visible）
var _shake_timer: Timer = null   # 源 :91 shakeBox 定时器（1.5s 周期）
var _hint_anchor: Control = null   # 源 currentStageHint 锤点（绝对定位，子 stage_hint 浮动）
var stage_hint: Label = null   # 源 mainLayer.currentStageHint 导航箭头（▼ 降级）


func setup_panel(p_player: PlayerData, p_rng: BattleRng) -> void:
	player = p_player
	rng = p_rng
	player.ensure_crusade(rng)
	setup()
	# 源 crusade.lua:622/749 pushScene 独立场景（framework.lua:749 自动建全屏 bg.jpg），
	# 本项目单机化 pushScene→PopWindow，故 shade 透明 + .tscn 已补全屏 bg.jpg 还原源视觉。
	if shade_layer != null:
		shade_layer.color.a = 0
		shade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_content()
	_create_shake_timer()
	_refresh_stage_states()
	register_on_enter(_refresh_hint_pos)


# 建 UI 内容：base 从 .tscn instantiate（位置/size 静态化）+ 收集 + bind + fill 动态层。
# 源 crusade.lua:621 create + onEnterCrusade :89-99（注册定时器 + refreshFogAnimation）。
func _build_content() -> void:
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	# 收集 .tscn 静态节点（位置/size 已固化，运行时只 fill 数据/纹理/visible）。
	(content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	var reset_btn: Button = content.get_node("%ResetBtn") as Button
	_apply_reset_button_style(reset_btn)
	# 源 LSTR("CRUSADECONFIG.RESTART") = "重新开始"（降级 fallback；原"重置"是旧项目降级文字，照源改）
	(content.get_node("%ResetLabel") as Label).text = _lstr(LSTR_RESET_KEY, "重新开始")
	reset_btn.pressed.connect(_on_reset)
	(content.get_node("%StartBtn") as BaseButton).pressed.connect(_on_start_pressed)
	result_label = content.get_node("%ResultLabel") as Label
	enemy_preview_box = content.get_node("%EnemyPreviewHost") as Control
	start_btn = content.get_node("%StartBtn") as TextureButton
	start_btn.visible = false   # 源 :204 未选关隐藏
	result_label.text = "远征：第 " + str(player.crusade_manager.cur_stage) + " 关"
	_hint_anchor = content.get_node("%HintAnchor") as Control
	stage_hint = content.get_node("%StageHint") as Label
	_start_hint_float()   # 源 :614-619 CCMoveBy(0.5,(0,10))+back RepeatForever 上下浮动
	# Fog1-4 .tscn 静态，instantiate 后收集（源 refreshFog :42-67 按 currentStage 显隐）。
	fog_rects.clear()
	for i in range(1, 5):
		fog_rects.append(content.get_node("%Fog" + str(i)) as TextureRect)
	# 源 dragLayer 内 battle1-15 + box1-15：HBox 内 15 VBox ×（stage btn + box btn）。
	var hbox: HBoxContainer = content.get_node("%StageHBox") as HBoxContainer
	_create_stage_list(hbox)


## 源 dragLayer 内 battle1-15 节点 → HBox 内 VBox 水平排列（替自定义拖拽；滚动由 ScrollContainer）。
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
		# 源 :311 boxButton{i}：宝箱是 Button 可点（hintBox/hintBoxDown 领奖/预览）。
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


## 源 boxImg(:24)：index 5/10 silver、15 gold、其余 bronze。
func _box_tier(i: int) -> String:
	if i == 15:
		return "gold"
	if i == 5 or i == 10:
		return "silver"
	return "bronze"


## 源 refreshBattleState(:333-340)：rewarded→open，else→closed。
func _box_texture(i: int) -> String:
	var state: String = "open" if player.crusade_manager.is_stage_rewarded(i) else "closed"
	return BOX_TEX_DIR + _box_tier(i) + "_" + state + ".png"


## 资源安全加载（exists 预检，避 headless/未 import 时 load push_error）。
static func _load_tex(path: String) -> Variant:
	return load(path) if ResourceLoader.exists(path) else null


# .tscn 普通 Button 套 Scale9 StyleBoxTexture（normal/hover=tavern_button_normal_1, pressed=tavern_button_normal_2）。
# 视觉等价源 ui_normal_button Scale9Sprite + press mask。文字 fill 到独立 Label 子节点 %ResetLabel
# （Button.text 内嵌 label 受 stylebox content_margin 干扰字偏左上，范式同 hero_detail）。
func _apply_reset_button_style(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_sb(RESET_BTN_RES, RESET_BTN_CAP))
	btn.add_theme_stylebox_override("hover", _make_sb(RESET_BTN_RES, RESET_BTN_CAP))
	btn.add_theme_stylebox_override("pressed", _make_sb(RESET_BTN_PRESS_RES, RESET_BTN_CAP))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func _make_sb(res: String, cap_insets: Rect2) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	var tex: Texture2D = load(res) as Texture2D
	sb.texture = tex
	sb.texture_margin_left = cap_insets.position.x
	sb.texture_margin_top = cap_insets.position.y
	if tex != null:
		sb.texture_margin_right = tex.get_width() - cap_insets.position.x - cap_insets.size.x
		sb.texture_margin_bottom = tex.get_height() - cap_insets.position.y - cap_insets.size.y
	return sb


## 源 refreshBattleState:324-343 + boxImg:23-25：current/locked/passed 状态纹理。
func _stage_texture(i: int) -> String:
	var state: String = "locked"
	if player.crusade_manager.cur_stage == i:
		state = "current"
	elif player.crusade_manager.is_stage_cleared(i):
		state = "passed"
	return STAGE_TEX_DIR + str(i) + "_" + state + ".png"


## 源 resetBattle(:660)：重置远征（cur_stage 回 1 + 清跨关状态，enemies 保留同敌人重来）。
## P1-2（2026-07-11）：照源补确认框（原降级直接执行 → 独立 CrusadeResetConfirm 组件）。
## P1（2026-07-16）：toast 文案 cm.get_lstr 化（源 :662 LSTR CRUSADE.NO_RESET_TIMES_LEFT_TODAY）。
func _on_reset() -> void:
	if player == null or player.crusade_manager == null:
		return
	if player.crusade_manager.get_reset_left() <= 0:
		result_label.text = _lstr("CRUSADE.NO_RESET_TIMES_LEFT_TODAY", "今日已没有重置次数")
		return
	var popup := CrusadeResetConfirm.new()
	popup.confirmed.connect(_on_reset_confirmed)
	container.add_child(popup)


# 源 reset 后走 ed.replaceScene 刷新整面板（:702），无 toast。
# 降级显式反馈：用源 refreshLeftTime :494-496 同款 LSTR 表达剩余次数（避免自造无源文案）。
func _on_reset_confirmed() -> void:
	if player == null or player.crusade_manager == null:
		return
	player.crusade_manager.reset()
	_refresh_stage_states()
	result_label.text = _lstr("CRUSADE.THE_REMAINING_TIMES_OF_TODAY___D", "今日剩余次数:%d") % player.crusade_manager.get_reset_left()


# 源 LSTR 走 player.cm（PlayerData 必携 ConfigManager）；cm 缺失 fallback 中文兜底（不阻塞 View）。
func _lstr(key: String, fallback: String) -> String:
	if player != null and player.cm != null:
		return player.cm.get_lstr(key)
	return fallback


## 源领奖入口（hintBox:395-406 + hintBoxDown:407-424 + getReward:705）。
## 源 :311 boxButton{i} press → hintBox(i)/hintBoxDown(i)：rewarded→return / passed→领奖 / unpassed→预览。
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


# 源 getReward:705-745 —— 领指定关奖励（apply_rewards + box 弹跳 + 结算 pop）。
func _apply_box_reward(stage: int) -> void:
	var slots: Array = player.crusade_manager.draw_reward_slots(stage)
	if slots.is_empty():
		result_label.text = "第 " + str(stage) + " 关 不可领"
		return
	player.crusade_manager.apply_rewards(slots, player, rng)
	_bounce_box_at(stage - 1, REWARD_SCALE_PEAK, REWARD_DURATION)   # 源 :715-718 领奖 box 弹跳
	var reward_text: String = ""
	for s in slots:
		reward_text += String(s["type"]) + "×" + str(s["amount"]) + " "
	result_label.text = "第 " + str(stage) + " 关 奖励：" + reward_text
	# pop 结算奖励弹窗（照源 crusade.lua showRewardResult :344 rewardLayer）
	var reward_popup := BattleRewardPopup.new("crusadeReward", {})
	reward_popup.setup_rewards(slots, player.cm)
	reward_popup.show_window(get_parent())
	_refresh_stage_states()


# 源 initRewardUI:247-297 unpassed 关卡奖励预览。UIRes rewardInfo 节点缺 → 降级 result_label 显示。
func _show_reward_preview(i: int) -> void:
	var slots: Array = player.crusade_manager.draw_reward_slots(i)
	if slots.is_empty():
		result_label.text = "第 " + str(i) + " 关 暂无奖励预览"
		return
	var preview_text: String = "第 " + str(i) + " 关 预览："
	for s in slots:
		preview_text += String(s["type"]) + "×" + str(s["amount"]) + " "
	result_label.text = preview_text


## 源 refreshFog(:42-67)：fog1-4 分段遮罩（currentStage>3/6/9/12 逐个隐）。
func _refresh_fog() -> void:
	if fog_rects.size() < 4 or player == null or player.crusade_manager == null:
		return
	var cur: int = player.crusade_manager.cur_stage
	fog_rects[0].visible = cur <= 3
	fog_rects[1].visible = cur <= 6
	fog_rects[2].visible = cur <= 9
	fog_rects[3].visible = cur <= 12


## 源 :211-233 遍历 data._oppos → createIcon(id/rank/level/stars/hp)。敌方首场满血 hp=10000。
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


## 源 crusade 选关交互：点 stage → 选中 + setEnemy 预览敌方 + 显 start 按钮（:206）。
## P1-2026-07-10：照源 refreshBattleState :324-325 超进度 disable（i > cur_stage 不可选）。
func _on_stage_n(i: int) -> void:
	if player == null or player.crusade_manager == null:
		return
	var cm_mgr = player.crusade_manager
	if cm_mgr.is_stage_cleared(i):
		result_label.text = "第 " + str(i) + " 关 已通关"
		return
	if _is_stage_locked(i):
		result_label.text = "第 " + str(i) + " 关 未解锁（需先通关前序/领上关奖）"
		return   # 源 :328 enable(false) 不可选
	current_select = i
	_refresh_enemy_preview(i)
	if start_btn != null:
		start_btn.visible = true
	# P1-14：照源 showBattleInfo :179-183 敌方信息（currentBattle + level 范围）
	var enemies_arr: Array = cm_mgr.get_stage_enemies(i)
	var enemy_count: int = enemies_arr.size()
	var max_stage: int = CrusadeManager.MAX_STAGE   # 源 maxBattleMax=15
	if enemy_count > 0:
		var first_lvl: int = int(enemies_arr[0].get("_level", 1))
		result_label.text = "第 %d/%d 关  敌方 %d 人  Lv.%d" % [i, max_stage, enemy_count, first_lvl]
	else:
		result_label.text = "第 %d/%d 关  (无敌人数据)" % [i, max_stage]


## 源 doClickStart：点"开战" → run_crusade_battle + 刷新状态。
func _on_start_pressed() -> void:
	if player == null or rng == null or current_select == 0:
		return
	var tids: Array[int] = _team_tids()
	if tids.is_empty():
		result_label.text = "无上场英雄"
		return
	var r: Dictionary = player.crusade_manager.run_crusade_battle(current_select, player, tids, rng)
	if bool(r.get("won", false)):
		result_label.text = "第 " + str(current_select) + " 关 胜利"
	else:
		result_label.text = "第 " + str(current_select) + " 关 失败"
	_refresh_stage_states()


## 上场英雄 tid 列表（player.team inst_id → tid；空则取前 TEAM_MAX 个英雄）。
## P1-2026-07-10：照源 crusade.lua:436 heroLimit={type="level",detail=20} 等级≥20 过滤。
func _team_tids() -> Array[int]:
	var tids: Array[int] = []
	for inst_id in player.team:
		var hero: HeroInstance = player.hero_manager.get_hero(int(inst_id))
		if hero != null and hero.level >= CRUSADE_HERO_MIN_LEVEL:
			tids.append(hero.tid)
	if tids.is_empty():
		for inst_id in player.hero_manager.heroes:
			var hero: HeroInstance = player.hero_manager.heroes[inst_id]
			if hero.level >= CRUSADE_HERO_MIN_LEVEL:
				tids.append(hero.tid)
			if tids.size() >= TEAM_MAX:
				break
	return tids


## 源 crusade.lua:91 ListenTimer(Timer:Always(1.5), shakeBox) —— 每 1.5s 触发 box 弹跳检查。
func _create_shake_timer() -> void:
	_shake_timer = Timer.new()
	_shake_timer.wait_time = SHAKE_INTERVAL
	_shake_timer.one_shot = false
	_shake_timer.autostart = true   # 进树时自动 start
	_shake_timer.timeout.connect(_shake_box)
	add_child(_shake_timer)


## 源 :30-41 shakeBox —— 上一关 passed 时对应 box 弹跳（scale 1.15→1.0，提示有奖可领）。
func _shake_box() -> void:
	if not is_inside_tree() or player == null or player.crusade_manager == null:
		return
	var prev: int = player.crusade_manager.cur_stage - 1
	if prev < 1 or not player.crusade_manager.is_stage_cleared(prev):
		return
	_bounce_box_at(prev - 1, SHAKE_SCALE_PEAK, SHAKE_DURATION)


## box 弹跳通用（scale → peak → 1.0）。shakeBox(:36) + getReward(:716) 共用。
func _bounce_box_at(idx: int, peak_scale: Vector2, duration: float) -> void:
	if idx < 0 or idx >= box_rects.size():
		return
	var box: TextureButton = box_rects[idx]
	var tw := create_tween()
	tw.tween_property(box, "scale", peak_scale, duration)
	tw.tween_property(box, "scale", Vector2.ONE, duration)


## 源 :614-619 CCMoveBy(0.5,(0,10))+back RepeatForever 上下浮动（相对 anchor，不干扰定位）。
func _start_hint_float() -> void:
	if stage_hint == null:
		return
	var tw := create_tween()
	tw.set_loops(-1)
	tw.tween_property(stage_hint, "position:y", -HINT_FLOAT_DELTA, HINT_FLOAT_TIME).as_relative()
	tw.tween_property(stage_hint, "position:y", HINT_FLOAT_DELTA, HINT_FLOAT_TIME).as_relative()


## 源 refreshHintPos :298-323：全通关隐；当前关 unpassed+上关 rewarded/首关→指 battle{cur}（offsetX=0）；
## 上关 passed→指 boxButton{cur-1}（offsetX=40 提示领奖）。pos.y+30（cocos→Godot -30 浮上）。
func _refresh_hint_pos() -> void:
	if _hint_anchor == null or player == null or player.crusade_manager == null:
		return
	var cm_mgr = player.crusade_manager
	if cm_mgr.is_stage_rewarded(CrusadeManager.MAX_STAGE):   # 源 :300 全通关
		_hint_anchor.visible = false
		return
	var cur: int = cm_mgr.cur_stage
	var target: Control = null
	var offset_x: float = 0.0
	if not cm_mgr.is_stage_cleared(cur) and (cur <= 1 or cm_mgr.is_stage_rewarded(cur - 1)):
		if cur - 1 >= 0 and cur - 1 < stage_buttons.size():
			target = stage_buttons[cur - 1]   # 源 :307-308 battle{current}
	elif cur > 1 and cm_mgr.is_stage_cleared(cur - 1):
		if cur - 2 >= 0 and cur - 2 < box_rects.size():
			target = box_rects[cur - 2]   # 源 :311 boxButton{current-1}
			offset_x = HINT_OFFSET_BOX_X
	if target == null:
		_hint_anchor.visible = false
		return
	_hint_anchor.visible = true
	var target_global: Vector2 = target.get_global_rect().position
	var origin: Vector2 = container.get_global_rect().position
	_hint_anchor.position = target_global - origin + Vector2(offset_x, HINT_OFFSET_Y)


## 刷新 stage 按钮状态纹理（通关/当前/锁定）+ disabled（源 :328 enable(false)）+ box 宝箱。
func _refresh_stage_states() -> void:
	var i: int = 1
	while i <= stage_buttons.size():
		stage_buttons[i - 1].texture_normal = _load_tex(_stage_texture(i))
		stage_buttons[i - 1].disabled = _is_stage_locked(i)   # 源 :329 enable(false) 超进度灰显
		if i - 1 < box_rects.size():
			box_rects[i - 1].texture_normal = _load_tex(_box_texture(i))
		i += 1
	_refresh_fog()
	_refresh_hint_pos()


## 源 :328 enable(false) 条件：未通关且超进度，或当前关且上关未领奖（i>1）。
func _is_stage_locked(i: int) -> bool:
	if player == null or player.crusade_manager == null:
		return false
	if player.crusade_manager.is_stage_cleared(i):
		return false   # 已通关可选（领奖）
	var cur: int = player.crusade_manager.cur_stage
	if i > cur:
		return true   # 超进度
	if i == cur and i > 1 and not player.crusade_manager.is_stage_rewarded(i - 1):
		return true   # 当前关但上关未领奖（源 :328 第二条件）
	return false
