class_name CrusadePanel
extends PopWindow

## 远征（十字军征途）面板 — 照源 ui/crusade.lua（775 行）+ gametable/crusadeconfig.lua UIRes。
## 2026-08-16 批 3 Task 7 两件套改造：静态层（Scroll 视口=源 clipNode 内缩 + Bg1-3/
## 三段地图容器 + Fog1-4 + Light1-2/Frame/TitleBg/Title/BottomFrame/底栏三按钮/
## 规则页全树）静态进 crusade_content.tscn；原 procedural 美术工厂（174 行）与
## 规则页渲染器（125 行）双退役；格子从 HBox 均排改照源散点（battle1-15/box1-15
## 挂三段 Map 容器，逐图 px/CS 实测尺寸）；
## fog 四张 scale=4.0 等比归源（1998.05×396.49，ratio 5.04，旧 230×90 失真 2.56）。
## 格子/规则页 fill 下沉 crusade_fills.gd（LINT005 View 400 行）。

const CrusadeFills := preload("res://scripts/ui/crusade_fills.gd")
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/crusade_content.tscn")
const SHAKE_INTERVAL: float = 1.5
const SHAKE_SCALE_PEAK: Vector2 = Vector2(1.15, 1.15)
const SHAKE_DURATION: float = 0.1
const REWARD_SCALE_PEAK: Vector2 = Vector2(1.3, 1.3)
const REWARD_DURATION: float = 0.08
const HINT_OFFSET_Y: float = -30.0
const HINT_OFFSET_BOX_X: float = 40.0
const HINT_FLOAT_DELTA: float = 10.0
const HINT_FLOAT_TIME: float = 0.5
const ENEMY_ICON_SCALE: float = 0.8   # 源 crusade.lua:231 heroIcon.icon:setScale(0.8)（2026-08-22 巡检照源订正旧 0.65）
const ENEMY_ICON_GAP: int = 5
const BL_ENEMY_ICON_SCALE: float = 0.65   # 源 enemyIcon scale 0.65（crusadeconfig :1360）
const ENEMY_HP_FULL: int = 10000
const CRUSADE_HERO_MIN_LEVEL: int = 20
# 源 initDragPos（crusade.lua:497-507）：分段偏移系数。
const SCROLL_STEP_PER_STAGE: float = 50.0
const SCROLL_MID_JUMP: float = 450.0
const SCROLL_MID_FROM: int = 5
const SCROLL_TAIL_JUMP: float = 400.0
const SCROLL_TAIL_FROM: int = 9
const SCROLL_MAX: float = 1259.0
# 源 lefttime 动态文案（crusade.lua:494-496 refreshLeftTime）。
const LSTR_LEFTTIME_KEY: String = "CRUSADE.THE_REMAINING_TIMES_OF_TODAY___D"
const LSTR_LEFTTIME_FALLBACK: String = "今日剩余次数:%d"
const LSTR_RESET_KEY: String = "CRUSADECONFIG.RESTART"
const LSTR_RESET_FALLBACK: String = "重新开始"
const LSTR_SHOW_RULE: String = "CRUSADECONFIG.REVIEW_RULES"
const LSTR_SHOW_RULE_FALLBACK: String = "查看规则"
const LSTR_SHOP_KEY: String = "CRUSADECONFIG.REDEEM"
const LSTR_SHOP_FALLBACK: String = "兑换奖励"
# 源公会行 hint（crusade.lua:238-240 无公会时 guildHint=NOT_IN_GUILDS；2026-09-13 三轮补全）。
const LSTR_GUILD_HINT_KEY: String = "CRUSADE.NOT_IN_GUILDS"
const LSTR_GUILD_HINT_FALLBACK: String = "未加入公会"
# 源 openShop（crusade.lua:681-683）pushScene shop.create(4) → 龙鳞（crusadepoint）商店。
const CRUSADE_SHOP_ID: int = 4

var player: PlayerData = null
var rng: BattleRng = null
var stage_buttons: Array[TextureButton] = []
var box_rects: Array[TextureButton] = []
var stage_lights: Array[TextureRect] = []
var fog_rects: Array[TextureRect] = []
var result_label: Label = null
var current_select: int = 0
var battle_layer: Control = null
var _bl_name_lbl: Label = null
var _bl_level_lbl: Label = null
var _bl_cur_lbl: Label = null
var _bl_enemy_host: Control = null
var _bl_hero_hosts: Array = []
var _bl_start: TextureButton = null
var start_btn: TextureButton = null
var _shake_timer: Timer = null
var _hint_anchor: Control = null
var stage_hint: CanvasItem = null
var _content: Control = null
var _scroll: ScrollContainer = null


func setup_panel(p_player: PlayerData, p_rng: BattleRng) -> void:
	hud_identity = "crusade"
	transparent_shade = true   # .tscn 已补全屏 bg.jpg 还原源视觉
	player = p_player
	rng = p_rng
	player.ensure_crusade(rng)
	setup()
	_build_content()
	_fill_stage_grid()
	CrusadeFills.fill_rule_layer(_content, player.cm)
	_fill_lefttime()
	_apply_initial_scroll()
	_create_shake_timer()
	_refresh_stage_states()
	register_on_enter(_refresh_hint_pos)


## connect 静态层信号 + 收集引用（静态美术层/规则页已在 .tscn，builder/renderer 退役）。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	_scroll = _content.get_node("%Scroll") as ScrollContainer
	# 源触屏拖拽无可见滚动条：压平 HScrollBar（min 占位 8px 会把视口高 405.76 钳到
	# 413.76；引擎缺口例外，同 SOP 滚动条条款，树内实证 BAR_MIN=(0,0) 后 rect 归位）。
	var h_bar: HScrollBar = _scroll.get_h_scroll_bar()
	h_bar.custom_minimum_size = Vector2.ZERO
	h_bar.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
	h_bar.add_theme_stylebox_override("grabber", StyleBoxEmpty.new())
	h_bar.add_theme_stylebox_override("grabber_highlight", StyleBoxEmpty.new())
	h_bar.add_theme_stylebox_override("grabber_pressed", StyleBoxEmpty.new())
	# 源拖动后 refreshHintPos 重算（crusade.lua:471-474）：滚动值变化 → 箭头跟随重算。
	h_bar.value_changed.connect(_on_scroll_moved)
	(_content.get_node("%CloseBtn") as BaseButton).pressed.connect(remove_window)
	# 参考页对齐（2026-09-13）：卷轴标题文字（参考页"远征"大字），LSTR 复用规则页键。
	(_content.get_node("%TitleBg/TitleLabel") as Label).text = _lstr(CrusadeFills.RULE_TITLE_KEY, CrusadeFills.RULE_TITLE_FALLBACK)
	# 源公会行（crusadeconfig :1497-1523）：单机无公会恒显 NOT_IN_GUILDS（2026-09-13 三轮补全）。
	(_content.get_node("%BattleLayer/BattleInfo/GuildHintLbl") as Label).text = _lstr(LSTR_GUILD_HINT_KEY, LSTR_GUILD_HINT_FALLBACK)
	var reset_btn: Button = _content.get_node("%ResetBtn") as Button
	(_content.get_node("%ResetLabel") as Label).text = _lstr(LSTR_RESET_KEY, LSTR_RESET_FALLBACK)
	reset_btn.pressed.connect(_on_reset)
	(_content.get_node("%StartBtn") as BaseButton).pressed.connect(_on_start_pressed)
	(_content.get_node("%RuleBtn") as BaseButton).pressed.connect(_show_rule_info)
	(_content.get_node("%ShopBtn") as BaseButton).pressed.connect(_on_shop_pressed)
	(_content.get_node("%RuleLabel") as Label).text = _lstr(LSTR_SHOW_RULE, LSTR_SHOW_RULE_FALLBACK)
	(_content.get_node("%ShopLabel") as Label).text = _lstr(LSTR_SHOP_KEY, LSTR_SHOP_FALLBACK)
	(_content.get_node("%RuleCloseBtn") as BaseButton).pressed.connect(_close_rule_info)
	(_content.get_node("%RuleShade") as Control).gui_input.connect(_on_rule_shade_input)
	result_label = _content.get_node("%ResultLabel") as Label
	battle_layer = _content.get_node("%BattleLayer") as Control
	_bl_name_lbl = _content.get_node("%BattleLayer/BattleInfo/HeroNameLbl") as Label
	_bl_level_lbl = _content.get_node("%BattleLayer/BattleInfo/LevelLbl") as Label
	_bl_cur_lbl = _content.get_node("%BattleLayer/BattleInfo/CurrentBattleLbl") as Label
	_bl_enemy_host = _content.get_node("%BattleLayer/BattleInfo/EnemyIconHost") as Control
	_bl_start = _content.get_node("%BattleLayer/BattleInfo/StartBtn2") as TextureButton
	for i in range(5):
		_bl_hero_hosts.append(_content.get_node("%BattleLayer/BattleInfo/HeroHost" + str(i + 1)) as Control)
	(_content.get_node("%BattleLayer/BattleInfo/BlCloseBtn") as TextureButton).pressed.connect(_close_battle_info)
	(_content.get_node("%BattleLayer/Shade") as ColorRect).gui_input.connect(_on_shade_clicked)
	_bl_start.pressed.connect(_on_bl_start_pressed)
	start_btn = _content.get_node("%StartBtn") as TextureButton
	start_btn.visible = false
	# F3（2026-08-27 走查）：源打开面板无常驻标题文字（当前关仅用箭头 StageHint 标记），
	# 「远征：第 N 关」系发明；本 label 只作事件反馈通道（受控偏离见 tscn），初始置空。
	result_label.text = ""
	_hint_anchor = _content.get_node("%HintAnchor") as Control
	stage_hint = _content.get_node("%StageHint") as CanvasItem
	_start_hint_float()
	# Fog1-4 .tscn 静态挂 %ScrollContent（= 源 dragContainer，随格滚动），按 cur 显隐。
	fog_rects.clear()
	var scroll_content: Control = _content.get_node("%ScrollContent") as Control
	for i in range(1, 5):
		fog_rects.append(scroll_content.get_node("%Fog" + str(i)) as TextureRect)


## 格子 fill 下沉 crusade_fills（照源散点 + 位置表），此处只收结果引用。
func _fill_stage_grid() -> void:
	var grid: Dictionary = CrusadeFills.fill_stage_grid(
		_content, player, Callable(self, "_on_stage_n"), Callable(self, "_on_box_pressed"))
	stage_buttons = grid["stages"]
	box_rects = grid["boxes"]
	stage_lights = grid["lights"]


## 源 refreshLeftTime（:494-496）：lefttime 节点动态文案（格式化剩余次数）。
func _fill_lefttime() -> void:
	if player == null or player.crusade_manager == null:
		return
	# 跨日清零 reset_times（源 crusade.lua:536-538 服务器每日重置；单机化本地跨日，
	# 2026-08-22 巡检接线）。
	player.crusade_manager.check_daily_reset(int(Time.get_unix_time_from_system()))
	var left: int = player.crusade_manager.get_reset_left()
	var lbl: Label = _content.get_node("%LefttimeLabel") as Label
	lbl.text = _lstr(LSTR_LEFTTIME_KEY, LSTR_LEFTTIME_FALLBACK) % left


## 源 initDragPos（:497-507）：offset = max(cur-4,0)×50 + (cur>5?450) + (cur>9?400)，
## clamp [0,1259]（源 maxRight=-1259 取负）。
## Task 9 验收修复：实跑序 setup_panel 先于 show_window（main_scene_entry_router:115），
## 离树时 scroll_horizontal 赋值被 HScrollBar 默认 max_value=100 钳制且进树后不恢复
## （实测 cur=10 期望 1150 落在 100）——镜头错段+第一关图标滚出视口被误读为
## "被雾盖住"。须进树 + 首帧布局（scrollbar range 展开到内容宽）后重放。
func _apply_initial_scroll() -> void:
	if _scroll == null or player == null or player.crusade_manager == null:
		return
	var target: int = _initial_scroll_target()
	_scroll.scroll_horizontal = target
	if not is_inside_tree():
		await tree_entered
		await get_tree().process_frame
		if is_instance_valid(_scroll) and _scroll.scroll_horizontal != target:
			_scroll.scroll_horizontal = target


func _initial_scroll_target() -> int:
	var cur: int = player.crusade_manager.cur_stage
	var offset: float = maxf(float(cur) - 4.0, 0.0) * SCROLL_STEP_PER_STAGE
	if cur > SCROLL_MID_FROM:
		offset += SCROLL_MID_JUMP
	if cur > SCROLL_TAIL_FROM:
		offset += SCROLL_TAIL_JUMP
	return int(clampf(offset, 0.0, SCROLL_MAX))


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
	_fill_lefttime()
	_apply_initial_scroll()
	result_label.text = _lstr(LSTR_LEFTTIME_KEY, LSTR_LEFTTIME_FALLBACK) % player.crusade_manager.get_reset_left()


func _lstr(key: String, fallback: String) -> String:
	if player != null and player.cm != null:
		var v: String = player.cm.get_lstr(key)
		return v if v != key else fallback
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
	# 源 hintBoxDown（crusade.lua:407-423）雾视野内未通关宝箱可预览：cur<=3 则 index<=3
	# 可预览（边界 3/6/9/12）——i <= ceil(cur/3)*3。2026-08-22 巡检照源订正旧锁判定。
	if i <= ceili(float(cm_mgr.cur_stage) / 3.0) * 3:
		_show_reward_preview(i)


func _apply_box_reward(stage: int) -> void:
	# 单机去 VIP 限制：宝箱奖励档按特权档（满级 Crusade Chest Bonus Valid）取 VIP 加成档。
	var slots: Array = player.crusade_manager.draw_reward_slots(stage, player.is_vip_unlocked("Crusade Chest Bonus Valid"))
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


var _reward_preview: Control = null


func _show_reward_preview(i: int) -> void:
	# 源 initRewardUI（crusade.lua:247-297）读配置表 battleReward（数据预览非运行时领取）——
	# 用 CrusadeRewardsData.get_reward_slots 无副作用版（旧误用 draw_reward_slots 带领取
	# 标记副作用）。浮层构建下沉 CrusadeFills；2026-08-22 巡检重做旧 result_label 文本降级。
	_clear_reward_preview()
	# 单机去 VIP 限制：预览与实发同档（特权满级 → VIP 加成档）。
	var slots: Array = CrusadeRewardsData.get_reward_slots(player.cm, i, 1, player.is_vip_unlocked("Crusade Chest Bonus Valid"))
	if slots.is_empty():
		return
	_reward_preview = CrusadeFills.build_reward_preview(_content, slots, player.cm)
	if is_inside_tree():
		_reward_preview.pivot_offset = _reward_preview.size * 0.5
		_reward_preview.scale = Vector2.ZERO
		var tw := create_tween()   # 源 :294-296 CCScaleTo(0.1,1)
		tw.tween_property(_reward_preview, "scale", Vector2.ONE, 0.1)


func _clear_reward_preview() -> void:
	if _reward_preview != null:
		_reward_preview.queue_free()
		_reward_preview = null


## 源 refreshFog（:42-67）：fog_i visible = cur <= 3×i（四层叠放随进度消散）；
## 消散走 1.5s FadeOut（refreshFogAnimation :68-88，2026-08-22 巡检补译）。
func _refresh_fog() -> void:
	if fog_rects.size() < 4 or player == null or player.crusade_manager == null:
		return
	_clear_reward_preview()
	var cur: int = player.crusade_manager.cur_stage
	for k in range(4):
		var fog: TextureRect = fog_rects[k]
		if cur <= (k + 1) * 3:
			fog.modulate.a = 1.0
			fog.visible = true
		elif fog.visible and fog.modulate.a > 0.0:
			var tw := create_tween()
			tw.tween_property(fog, "modulate:a", 0.0, 1.5)
			tw.tween_callback(func() -> void: fog.visible = false)


# 源 showBattleInfo（crusade.lua :177-235）：battleLayer 弹窗 fill——敌方玩家名/等级/场次
# (N/M)/头像（getHeroIconByID avatar）+ 5 英雄 ReadheroIcon（rank/level/stars/hp 满血）；
# passed/rewarded 隐藏 start。单机敌方摘要 crusade_manager.enemies[s]（name/level/avatar）。
func _show_battle_info(stage: int) -> void:
	if battle_layer == null or player == null or player.crusade_manager == null:
		return
	var cm_mgr = player.crusade_manager
	var info: Dictionary = cm_mgr.enemies.get(stage, {})
	_bl_name_lbl.text = str(info.get("name", "?"))
	_bl_level_lbl.text = str(info.get("level", 1))
	_bl_cur_lbl.text = "(%d/%d)" % [stage, CrusadeManager.MAX_STAGE]
	for c in _bl_enemy_host.get_children():
		c.queue_free()
	var avatar_id: int = int(info.get("avatar", 0))
	if avatar_id > 0:
		var head := ReadheroIcon.new()
		head.setup({"id": avatar_id, "rank": 1}, player.cm)
		head.scale = Vector2(BL_ENEMY_ICON_SCALE, BL_ENEMY_ICON_SCALE)
		_bl_enemy_host.add_child(head)
	for host in _bl_hero_hosts:
		for c in (host as Control).get_children():
			c.queue_free()
	var enemies_arr: Array = cm_mgr.get_stage_enemies(stage)
	var idx: int = 0
	for hero in enemies_arr:
		if idx >= _bl_hero_hosts.size():
			break
		var icon := ReadheroIcon.new()
		icon.setup({
			"id": int(hero.get("_tid", 0)),
			"rank": int(hero.get("_rank", 1)),
			"level": int(hero.get("_level", 1)),
			"stars": int(hero.get("_stars", 0)),
			"hp": ENEMY_HP_FULL,
		}, player.cm)
		# 源 crusade.lua:231 heroIcon.icon:setScale(0.8)——2026-09-13 二轮补施（旧漏施
		# 致 104×104 原大相邻叠 29px，浮窗拥挤主根因之一）。
		icon.scale = Vector2(ENEMY_ICON_SCALE, ENEMY_ICON_SCALE)
		(_bl_hero_hosts[idx] as Control).add_child(icon)
		idx += 1
	_bl_start.visible = not cm_mgr.is_stage_cleared(stage)
	battle_layer.visible = true


# 源 closeBattleInfo（:105-108）：battleLayer 隐藏。
func _close_battle_info() -> void:
	if battle_layer != null:
		battle_layer.visible = false


func _on_shade_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_close_battle_info()


# 弹窗内开战钮 → 复用面板开战链（源 handleName="start" 同一处理）。
func _on_bl_start_pressed() -> void:
	_close_battle_info()
	_on_start_pressed()


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
	_show_battle_info(i)
	var enemies_arr: Array = cm_mgr.get_stage_enemies(i)
	var enemy_count: int = enemies_arr.size()
	var max_stage: int = CrusadeManager.MAX_STAGE
	if enemy_count > 0:
		var first_lvl: int = int(enemies_arr[0].get("_level", 1))
		result_label.text = "第 %d/%d 关  敌方 %d 人  Lv.%d" % [i, max_stage, enemy_count, first_lvl]
	else:
		result_label.text = "第 %d/%d 关  (无敌人数据)" % [i, max_stage]


## 目标单机化：弹 BattlePreparePanel（mode=crusade，源 :431-441 heroLimit level=20）；
## 2026-09-14 起确认开战后装配切 battle_scene 观战，结束经 pending_crusade 回本面板
## （旧 crusade_battle_finished 同步信号链随 _run_crusade_go 退役）。
func _on_start_pressed() -> void:
	if player == null or rng == null or current_select == 0:
		return
	var stage_id: int = -2 - current_select
	var panel := BattlePreparePanel.new()
	panel.setup(stage_id, player, player.crusade_manager, rng, player.cm, "crusade", CRUSADE_HERO_MIN_LEVEL)
	var parent: Node = get_parent()
	if parent != null:
		parent.add_child(panel)
	if start_btn != null:
		start_btn.visible = false


## 源 openShop（:681-683）：shop.create(4) 龙鳞商店 → 单机化弹 ShopPanel(shop_id=4)。
func _on_shop_pressed() -> void:
	if player == null or rng == null:
		return
	var mgr := ShopManager.new(player.cm)
	var shop := ShopPanel.new("shop", {})
	shop.setup_panel(CRUSADE_SHOP_ID, mgr, player, rng)
	shop.show_window(get_parent())


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
	# 源 crusade.lua:31 battleState=="passed"（通关未领）才摇，"rewarded" 不摇——
	# 2026-08-22 巡检订正：cleared 含已领，旧条件致已领宝箱永久摇。
	if prev < 1 or not player.crusade_manager.is_stage_cleared(prev) or player.crusade_manager.is_stage_rewarded(prev):
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


## 源 refreshHintPos（:298-323）：hint 指向当前关 battle 或上关宝箱 boxButton。
## 位置语义（第二轮验收归源 2026-08-17）：源取 target.sprite 锚点（中心）世界坐标
## +（offsetX,+30 cocos 上方）→ hint anchor(0.5,0) 底部中心落在该点；即 Godot
## HintAnchor（零尺寸=底边中心锚）= target 全局中心 + (offsetX, -30)。旧实现误用
## target 左上角致箭头整体偏左上（截图实证 battle1 圆心未对准）。
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
	var anchor_pt: Vector2 = target.get_global_rect().get_center() + Vector2(offset_x, HINT_OFFSET_Y)
	_hint_anchor.global_position = anchor_pt


## 源拖动语义（:461-475）：dragContainer 偏移变化后 refreshHintPos 重算（拖动中隐藏）。
## 本项目滚动=ScrollContainer：HScrollBar value 变化即重算（deferred 等布局重排）。
func _on_scroll_moved(_value: float) -> void:
	_refresh_hint_pos.call_deferred()


## 刷新 stage 按钮状态（源 :324-343 两态：normal + disable 换图）+ disabled + box 宝箱
## + 已通关白光底晕/可领宝箱金光（2026-09-13 二轮：四态换图回归两态，标记改光效叠加）。
func _refresh_stage_states() -> void:
	var i: int = 1
	while i <= stage_buttons.size():
		stage_buttons[i - 1].texture_normal = CrusadeFills.stage_button_normal_texture(i)
		stage_buttons[i - 1].texture_disabled = CrusadeFills.stage_button_locked_texture(i)
		stage_buttons[i - 1].disabled = _is_stage_locked(i)
		if i - 1 < stage_lights.size():
			stage_lights[i - 1].visible = player.crusade_manager.is_stage_cleared(i)
		if i - 1 < box_rects.size():
			box_rects[i - 1].texture_normal = CrusadeFills.box_button_texture(player, i)
			CrusadeFills.set_box_light(box_rects[i - 1],
				player.crusade_manager.is_stage_cleared(i) and not player.crusade_manager.is_stage_rewarded(i))
		i += 1
	_refresh_fog()
	_refresh_hint_pos()


## 源 :328 布尔直译下沉 fills（stage_locked），此处只转发（单一来源）。
func _is_stage_locked(i: int) -> bool:
	if player == null or player.crusade_manager == null:
		return false
	return CrusadeFills.stage_locked(player, i)


# ==================== 规则页（源 crusade.lua:425-430 + :543-595）====================

func _show_rule_info() -> void:
	(_content.get_node("%RuleLayer") as Control).visible = true


func _close_rule_info() -> void:
	(_content.get_node("%RuleLayer") as Control).visible = false


## 源 ruleLayer touchInfo 吞点击（点遮罩关闭，conformReward/rewardLayerTouch 同语义）。
func _on_rule_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_close_rule_info()
