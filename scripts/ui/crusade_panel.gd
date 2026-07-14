class_name CrusadePanel
extends PopWindow

## 远征 UI（View 层）— 照源 ui/crusade.lua 核心翻译（2026-07-02）。
## UIRes 节点树缺（Cocos Studio 导出物，同 .Puppet 阻塞）→ 代码重建核心：
##   15 stage TextureButton + current/locked/passed 状态纹理 + 战斗入口 + 水平滚动。
## 留续（源 775 行装饰段）：自定义拖拽地图(dragLayerTouch)/雾遮罩 fog1-4/宝箱 box bronze-silver-gold/结算动画。

const STAGE_TEX_DIR := "res://assets/ui/alpha/HVGA/crusade/stage/crusade_stage_"
const STAGE_SIZE: Vector2 = Vector2(110.0, 110.0)
const BOX_SIZE: Vector2 = Vector2(60.0, 60.0)
const BOX_TEX_DIR := "res://assets/ui/alpha/HVGA/crusade/crusade_box_"
const FOG_TEX_DIR := "res://assets/ui/alpha/HVGA/crusade/crusade_fog_"
const FOG_SIZE: Vector2 = Vector2(230.0, 90.0)
const FOG_POS: Vector2 = Vector2(20.0, 60.0)
const FOG_STEP: float = 235.0
const SCROLL_POS: Vector2 = Vector2(20.0, 120.0)
const SCROLL_SIZE: Vector2 = Vector2(920.0, 280.0)
const CLOSE_BTN_POS: Vector2 = Vector2(20.0, 15.0)  # 左上角留小边（用户偏好更靠左上角）
const RESET_BTN_POS: Vector2 = Vector2(700.0, 50.0)
const CLOSE_BTN_SIZE: Vector2 = Vector2(80.0, 40.0)
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/backbtn.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/backbtn-disabled.png"
const RESULT_POS: Vector2 = Vector2(30.0, 490.0)
const REWARD_BTN_POS: Vector2 = Vector2(30.0, 530.0)
const TEAM_MAX: int = 5  # 上场英雄上限（源 5v5）
# 源 crusade.lua:224 setEnemy 敌方阵容预览（5 英雄 createIcon + hp 满血血条，选关后展示）
const ENEMY_PREVIEW_POS: Vector2 = Vector2(30.0, 405.0)
const ENEMY_ICON_SCALE: float = 0.65   # 源 :231 setScale(0.8) → 0.65 适配面板（5×104 太宽）
const ENEMY_ICON_GAP: int = 5
const START_BTN_POS: Vector2 = Vector2(700.0, 410.0)
const ENEMY_HP_FULL: int = 10000   # 源 _hp_perc 满血万分比（敌方首场满血，:215 if 0<_hp_perc）
# 源 crusade.lua:30-41 shakeBox + :91 ListenTimer(Always(1.5)) 上一关 box 弹跳（提示有奖可领）
const SHAKE_INTERVAL: float = 1.5   # 源 :91 Timer:Always(1.5)
const SHAKE_SCALE_PEAK: Vector2 = Vector2(1.15, 1.15)   # 源 :36 CCScaleTo(0.1,1.15)
const SHAKE_DURATION: float = 0.1   # 源 :36-37 各 0.1s
const REWARD_SCALE_PEAK: Vector2 = Vector2(1.3, 1.3)   # 源 :716 领奖 CCScaleTo(0.08,1.3)
const REWARD_DURATION: float = 0.08   # 源 :716-717 各 0.08s
# 源 mainLayer.currentStageHint 导航箭头（指当前关/上关宝箱 + 上下浮动）
const HINT_OFFSET_Y: float = -30.0      # 源 :321 pos.y+30（cocos y 向上→Godot -30 浮目标上方）
const HINT_OFFSET_BOX_X: float = 40.0   # 源 :313 上关宝箱 offsetX=40（提示领奖）
const HINT_FLOAT_DELTA: float = 10.0    # 源 :616 ccp(0,10)
const HINT_FLOAT_TIME: float = 0.5      # 源 :616 0.5s
const HINT_MARK: String = "▼"           # currentStageHint 纹理缺（UIRes）→ 降级下箭头 Label

var player: PlayerData = null
var rng: BattleRng = null
var stage_buttons: Array[TextureButton] = []
var box_rects: Array[TextureRect] = []
var fog_rects: Array[TextureRect] = []
var result_label: Label = null
var current_select: int = 0   # 当前选中关（源 currentSelectStage，选关后预览敌方 + 点开战 run）
var enemy_preview_box: Control = null   # 源 battleLayer.hero1-5 敌方阵容容器
var start_btn: Button = null   # 源 battleLayer.start "开始战斗"按钮（选关后 visible）
var _shake_timer: Timer = null   # 源 :91 shakeBox 定时器（1.5s 周期）
var _hint_anchor: Control = null  # 源 currentStageHint 锤点（绝对定位，子 stage_hint 浮动）
var stage_hint: Label = null      # 源 mainLayer.currentStageHint 导航箭头（▼ 降级）


func setup_panel(p_player: PlayerData, p_rng: BattleRng) -> void:
	player = p_player
	rng = p_rng
	player.ensure_crusade(rng)
	setup()
	_create_close_button()
	_create_reset_button()
	_create_stage_list()
	_create_fog()
	_create_enemy_preview()
	_create_start_button()
	_create_result_label()
	_create_reward_button()
	_create_shake_timer()
	_create_stage_hint()
	_refresh_stage_states()
	register_on_enter(_refresh_hint_pos)


func _create_close_button() -> void:
	var btn: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, CLOSE_BTN_POS)
	btn.pressed.connect(remove_window)
	container.add_child(btn)


## 源 resetBattle(:660)：重置远征（cur_stage 回 1 + 清跨关状态，enemies 保留同敌人重来）。
func _create_reset_button() -> void:
	var btn := Button.new()
	btn.text = "重置"
	btn.position = RESET_BTN_POS
	btn.size = CLOSE_BTN_SIZE
	btn.pressed.connect(_on_reset)
	container.add_child(btn)


## 源 resetBattle :660-680：leftTime<=0 toast + showConfirmDialog（确认框）。
## P1-2（2026-07-11）：照源补确认框（原降级直接执行 → 独立 CrusadeResetConfirm 组件）。
func _on_reset() -> void:
	if player == null or player.crusade_manager == null:
		return
	if player.crusade_manager.get_reset_left() <= 0:
		result_label.text = "今日重置次数已用完"
		return
	# 源 :665-679 showConfirmDialog → 弹确认框，确认才执行 reset
	var popup := CrusadeResetConfirm.new()
	popup.confirmed.connect(_on_reset_confirmed)
	container.add_child(popup)


func _on_reset_confirmed() -> void:
	if player == null or player.crusade_manager == null:
		return
	player.crusade_manager.reset()
	_refresh_stage_states()
	result_label.text = "远征已重置（剩余 %d 次）" % player.crusade_manager.get_reset_left()


## 源领奖入口（getReward:705 + draw_reward）：领上一通关关奖励。
func _create_reward_button() -> void:
	var btn := Button.new()
	btn.text = "领取奖励"
	btn.position = REWARD_BTN_POS
	btn.size = CLOSE_BTN_SIZE
	btn.pressed.connect(_on_draw_reward)
	container.add_child(btn)


func _on_draw_reward() -> void:
	if player == null or player.crusade_manager == null:
		return
	var stage: int = player.crusade_manager.cur_stage - 1  # 上一通关关
	if stage < 1:
		result_label.text = "无奖励可领"
		return
	var slots: Array = player.crusade_manager.draw_reward_slots(stage)
	if slots.is_empty():
		result_label.text = "第 " + str(stage) + " 关 不可领"
	else:
		player.crusade_manager.apply_rewards(slots, player, rng)  # 领奖→发奖到 player
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


## 源 refreshFog(:42-67)：fog1-4 分段遮罩（currentStage>3/6/9/12 逐个隐，解锁区域）。
## UIRes 节点定位缺 → 简化为水平装饰行（照源显隐逻辑）。
func _create_fog() -> void:
	var x: float = FOG_POS.x
	var i: int = 1
	while i <= 4:
		var fog := TextureRect.new()
		fog.texture = _load_tex(FOG_TEX_DIR + str(i) + ".png")
		fog.position = Vector2(x, FOG_POS.y)
		fog.size = FOG_SIZE
		fog.custom_minimum_size = FOG_SIZE
		fog.ignore_texture_size = true
		fog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		container.add_child(fog)
		fog_rects.append(fog)
		x += FOG_STEP
		i += 1


## 源 refreshFog：currentStage>3 fog1 隐 / >6 fog2 隐 / >9 fog3 隐 / >12 fog4 隐。
func _refresh_fog() -> void:
	if fog_rects.size() < 4 or player == null or player.crusade_manager == null:
		return
	var cur: int = player.crusade_manager.cur_stage
	fog_rects[0].visible = cur <= 3
	fog_rects[1].visible = cur <= 6
	fog_rects[2].visible = cur <= 9
	fog_rects[3].visible = cur <= 12


## 源 dragLayer 内 battle1-15 节点 → ScrollContainer + HBox 水平滚动（替自定义拖拽）。
func _create_stage_list() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = SCROLL_POS
	scroll.size = SCROLL_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var hbox := HBoxContainer.new()
	var i: int = 1
	while i <= CrusadeData.MAX_STAGE:
		# 源 dragLayer：每关 battle{i}(关卡按钮) + box{i}(宝箱) 并列
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		var btn := TextureButton.new()
		btn.texture_normal = _load_tex(_stage_texture(i))
		btn.custom_minimum_size = STAGE_SIZE
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.pressed.connect(Callable(self, "_on_stage_n").bind(i))
		vbox.add_child(btn)
		var box := TextureRect.new()
		box.texture = _load_tex(_box_texture(i))
		box.custom_minimum_size = BOX_SIZE
		box.ignore_texture_size = true
		box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vbox.add_child(box)
		hbox.add_child(vbox)
		stage_buttons.append(btn)
		box_rects.append(box)
		i += 1
	scroll.add_child(hbox)
	container.add_child(scroll)


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


## 源 refreshBattleState:324-343 + boxImg:23-25：current/locked/passed 状态纹理。
func _stage_texture(i: int) -> String:
	var state: String = "locked"
	if player.crusade_manager.cur_stage == i:
		state = "current"
	elif player.crusade_manager.is_stage_cleared(i):
		state = "passed"
	return STAGE_TEX_DIR + str(i) + "_" + state + ".png"


## 源 crusade.lua:224 setEnemy 5 敌方英雄 createIcon（敌方阵容预览容器，选关后 refresh）。
func _create_enemy_preview() -> void:
	enemy_preview_box = Control.new()
	enemy_preview_box.position = ENEMY_PREVIEW_POS
	container.add_child(enemy_preview_box)


## 源 battleLayer.start "开始战斗" 按钮（:204-206 setVisible，选关后显）。
func _create_start_button() -> void:
	start_btn = Button.new()
	start_btn.text = "开战"
	start_btn.position = START_BTN_POS
	start_btn.size = CLOSE_BTN_SIZE
	start_btn.visible = false   # 源 :204 未选关隐藏
	start_btn.pressed.connect(_on_start_pressed)
	container.add_child(start_btn)


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
			"hp": ENEMY_HP_FULL,   # 源 :229 hp=dyna._hp_perc（敌方首场满血 10000）
		}, player.cm)
		icon.scale = Vector2(ENEMY_ICON_SCALE, ENEMY_ICON_SCALE)   # 源 :231 setScale(0.8)
		icon.position = Vector2(float(idx) * slot_w, 0.0)
		enemy_preview_box.add_child(icon)
		idx += 1


func _create_result_label() -> void:
	result_label = Label.new()
	result_label.position = RESULT_POS
	result_label.text = "远征：第 " + str(player.crusade_manager.cur_stage) + " 关"
	container.add_child(result_label)


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
const CRUSADE_HERO_MIN_LEVEL: int = 20  # 源 crusade.lua:436 battleprepare heroLimit level=20
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
	_shake_timer.autostart = true   # 进树时自动 start（setup_panel 时 self 未在树，手调 start 报错）
	_shake_timer.timeout.connect(_shake_box)
	add_child(_shake_timer)


## 源 :30-41 shakeBox —— 上一关 passed 时对应 box 弹跳（scale 1.15→1.0，提示有奖可领）。
func _shake_box() -> void:
	if not is_inside_tree() or player == null or player.crusade_manager == null:
		return
	var prev: int = player.crusade_manager.cur_stage - 1
	if prev < 1 or not player.crusade_manager.is_stage_cleared(prev):
		return
	_bounce_box_at(prev - 1, SHAKE_SCALE_PEAK, SHAKE_DURATION)   # box[prev]=box_rects[prev-1]


## box 弹跳通用（scale → peak → 1.0）。shakeBox(:36) + getReward(:716) 共用。
func _bounce_box_at(idx: int, peak_scale: Vector2, duration: float) -> void:
	if idx < 0 or idx >= box_rects.size():
		return
	var box: TextureRect = box_rects[idx]
	var tw := create_tween()
	tw.tween_property(box, "scale", peak_scale, duration)
	tw.tween_property(box, "scale", Vector2.ONE, duration)


## 源 mainLayer.currentStageHint（UIRes 纹理缺→降级 “▼” Label）导航箭头：指当前关/上关宝箱 + 浮动。
func _create_stage_hint() -> void:
	_hint_anchor = Control.new()
	_hint_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_anchor.visible = false
	container.add_child(_hint_anchor)
	stage_hint = Label.new()
	stage_hint.text = HINT_MARK
	stage_hint.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
	stage_hint.add_theme_font_size_override("font_size", 28)
	stage_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_anchor.add_child(stage_hint)
	_start_hint_float()


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
			box_rects[i - 1].texture = _load_tex(_box_texture(i))
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
