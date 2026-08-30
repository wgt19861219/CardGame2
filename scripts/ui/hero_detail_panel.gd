class_name HeroDetailPanel
extends PopWindow

## 英雄详情面板（View 层）— 属性 + 装备槽 + 升星/进阶按钮（信号）。内容静态化进 hero_detail_content.tscn，绘制 fill 外迁各模块，本文件留 setup/build/refresh/信号绑定/tab 切换/perform 封装。
signal evolve_requested
signal upgrade_rank_requested              # 进阶（rank+1，6 槽穿齐 Hero_equip[rank] 配方）
signal upgrade_skill_requested(idx: int)   # 技能升级（idx 0-3）
signal awake_requested                     # 觉醒（单机化新增，源无觉醒养成激活；碎片觉醒方案 C）

# base + tab view 子场景（Phase A+B 静态化：位置+size 在 .tscn 可视化）。
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/hero_detail_content.tscn")
const SKILL_COUNT: int = 4
# param.lua:54 skill_unlock_color_text（rank→颜色 LSTR key）。
const RANK_COLOR_LSTR: Dictionary = {
	1: "HERODETAILRES.WHITE", 2: "HERODETAILRES.GREEN", 3: "HERODETAILRES.GREEN",
	4: "HERODETAILRES.BLUE", 5: "HERODETAILRES.BLUE", 6: "HERODETAILRES.BLUE",
	7: "HERODETAILRES.PURPLE", 8: "HERODETAILRES.PURPLE", 9: "HERODETAILRES.PURPLE",
	10: "HERODETAILRES.PURPLE", 11: "HERODETAILRES.PURPLE",
	12: "HERODETAILRES.ORANGE", 13: "HERODETAILRES.ORANGE", 14: "HERODETAILRES.ORANGE",
	15: "HERODETAILRES.ORANGE", 16: "HERODETAILRES.ORANGE", 17: "HERODETAILRES.ORANGE",
	18: "HERODETAILRES.RED", 19: "HERODETAILRES.RED", 20: "HERODETAILRES.RED",
	21: "HERODETAILRES.RED", 22: "HERODETAILRES.RED", 23: "HERODETAILRES.RED",
}
# window.lua LSTR key（技能解锁文案）。
const LSTR_SKILL_UNLOCK: StringName = &"HERODETAILSKILL.ADVANCED_TO__S_TO_UNLOCK"
const GS_POP_SCALE: float = 1.2
const GS_POP_DURATION: float = 0.2
# createBottomButtons（window.lua:1395-1663）三 tab：detail(属性)/card(图鉴)/skill(技能)。
const TAB_DETAIL: String = "detail"
const TAB_CARD: String = "card"
const TAB_SKILL: String = "skill"
const TAB_EQUIP: String = "equip"   # 装备进阶列表（源 window.lua:466-477 doClickEvolveEquip setOpenMode("equip")；evolveequip.lua 独立弹窗→本项目并入 tab 侧滑）
const DEFAULT_TAB: String = TAB_CARD   # 用户指示（2026-07-17）：默认 card 图鉴（setOpenMode(nil)=doMoveBack 无 tab，用户要进显图鉴）
const BASE_SLIDE_OFFSET: float = 140.0   # doMove 140（window.lua:300 container 右移）源值直译。旧 178 系 bg 纹理直用时代 140×1.28 的 CS 遗漏补偿——2026-08-22 Bg ÷CS 修正后回归；card 态 bg left=338.5 与 card 框右缘 324.9（2026-08-22 内容回源实测）留 gap 13.6（源同）。CloseBtn 移出 base 固定屏幕右上（不随 base）
# doOpenDetail/Skill/Card pop endPos=ccp(-200,0)（window.lua:430/386/513）：tab 内容 container 显示态左移 200。
const TAB_POP_OFFSET_X: float = -200.0
# 进阶交互 LSTR（Toast 文案，常量在 HeroDetailUpgradeFx）
const LSTR_MAX_RANK: StringName = &"HERODETAIL.HAVE_EVOLVED_TO_TOP"
const LSTR_NEED_EQUIP: StringName = &"HERODETAIL.HERO_NEEDS_TO_WEAR_COMPLETE_EQUIPMENTS_FOR_ADVANCE"
const LSTR_ADVANCE_FAIL: StringName = &"HERODETAIL.ADVANCE_FAILED"
# tab 选中态 variation 切换（样式全在 default_theme，源 :321-323 切 _select visible）。
const TAB_VARIATION: StringName = &"HeroDetailTab"
const TAB_VARIATION_ACTIVE: StringName = &"HeroDetailTabActive"

var hero: HeroInstance = null
var cm: Variant = null
var hero_manager: HeroManager = null
var pd: PlayerData = null
var _desc_label: Control = null   # 技能描述弹板（NinePatchRect bg + label 子，源 createDescBoard；null 无 = destroyDescBoard）
var _gs_label: Label = null     # GS 战斗力 Label（.tscn %GsNum，源 ui.gs createInfoBoard:1254-1268）
var _pre_gs: int = -1           # pregs（上次显示 gs，refreshgsAfterWear:172/175 比对）
var _current_tab: String = ""   # 当前激活 tab（源 self.openMode：nil/att/card/skill）
var _tab_buttons: Dictionary = {}   # tab_key → Button（.tscn %TabBtn，源 ui.detail/card/skill）
var _base_layer: Control = null   # .tscn %BaseLayer（base 元素层），开 tab 时整体右移让位（照源 doMove window.lua:300 ccp(140,0)）
var _tab_views: Dictionary = {}    # Phase B：tab_key → Control（.tscn %TabCardView/Detail/Skill，visible 切换）
var _skill_host: Control = null    # .tscn %SkillListHost（技能行动态挂）
var _desc_host: Control = null     # .tscn %DescHost（技能描述动态挂）
var _upgrade_light: Sprite2D = null   # 进阶按钮光效（可进阶时 fade 循环闪烁）
var _light_tween: Tween = null        # 光效动画 tween（退出 kill 防泄漏）
var _hero_ids: Array = []          # 拥有英雄 inst_id 列表（hero_manager.get_owned_hero_ids；翻页用）
var _current_idx: int = -1         # hero.inst_id 在 _hero_ids 中的索引（无则 -1）

func setup_panel(p_hero: HeroInstance, p_cm: Variant, p_mgr: HeroManager = null, p_pd: PlayerData = null) -> void:
	hero = p_hero
	cm = p_cm
	hero_manager = p_mgr
	pd = p_pd
	_hero_ids = hero_manager.get_owned_hero_ids() if hero_manager != null and hero != null else []
	_current_idx = _hero_ids.find(hero.inst_id) if hero != null else -1
	# popwindow.lua:33（源）：herodetail {touch_priority=-130} 黑半透 shade 吞点击、无点外关闭（关闭仅 %CloseBtn）。
	# 缺省时内容区（全 IGNORE）点击穿透 shade 触发点外关闭 → 点详情页任意位置误返回英雄包裹（2026-08-29 用户反馈）。
	shade_close_on_click = false
	setup()   # PopWindow.setup（shade + container）
	_build_content()


# 建 UI 内容（base + tab view instantiate + fill；createWindow window.lua:2384-2396；animate_tab 仅升级反馈）。
func _build_content(tab: String = DEFAULT_TAB, animate_tab: bool = false) -> void:
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	_base_layer = content.get_node("%BaseLayer") as Control
	var result: Dictionary = HeroDetailFills.setup_base(_base_layer, hero, cm)
	_gs_label = result["gs_label"] as Label
	_tab_buttons = result["tab_buttons"] as Dictionary
	if hero_manager != null:
		HeroDetailFills.fill_stone_bar(_base_layer, hero, cm, hero_manager)
	_pre_gs = hero.gs if hero != null else -1
	_bind_signals()
	# 装备槽外迁 HeroDetailEquipSlots（open_equip_craft 契约参数；pd 供 wear/cannotwear 角标判定）
	HeroDetailEquipSlots.show_equips(hero, cm, pd, _base_layer,
			func(slot: int) -> void:
				HeroDetailEquipSlots.open_equip_craft(slot, hero, cm, pd,
					get_parent(), refresh_content,
					func(stage_id: int) -> void:
						HeroDetailEquipSlots.on_equip_craft_jump(stage_id, self)))
	_tab_views = {
		"card": content.get_node("%TabCardView") as Control,
		"detail": content.get_node("%TabDetailView") as Control,
		"skill": content.get_node("%TabSkillView") as Control,
		"equip": content.get_node("%TabEquipView") as Control,
	}
	# tab view z_index 由 .tscn 决定（CardView z=2 让 Art 显在 bg 上，其余 z=-1；先前循环强制 z=-1 是 bug）。
	_skill_host = (_tab_views["skill"] as Control).get_node("%SkillListHost") as Control
	_desc_host = (_tab_views["skill"] as Control).get_node("%DescHost") as Control
	_fill_card_view()
	# 隐藏 AttribListHost 垂直滚动条视觉（StyleBoxEmpty 覆盖；visible=false 禁用滚动）。滚轮改由 _input 接管。
	var detail_host := (_tab_views["detail"] as Control).get_node("AttribListHost") as ScrollContainer
	var detail_v_scroll := detail_host.get_node_or_null("_v_scroll") as Control
	if detail_v_scroll != null:
		var empty := StyleBoxEmpty.new()
		detail_v_scroll.add_theme_stylebox_override("scroll", empty)
		detail_v_scroll.add_theme_stylebox_override("grabber", empty)
		detail_v_scroll.add_theme_stylebox_override("grabber_highlight", empty)
		detail_v_scroll.add_theme_stylebox_override("grabber_pressed", empty)
	var detail_vbox: VBoxContainer = detail_host.get_node("AttribVBox") as VBoxContainer
	HeroDetailAttribs.fill_attributes(detail_vbox, hero, cm)
	# gold 不够 cost 变红（refreshCostColor），skl_add 显 levelAdd "+N"（refreshSkillAdd）。
	var gold_for_skills: int = hero_manager.gold if hero_manager != null else -1
	HeroDetailUpgradeFx.fill_skills(_tab_views["skill"] as Control, hero, cm, SKILL_COUNT, RANK_COLOR_LSTR, LSTR_SKILL_UNLOCK, _toggle_skill_desc, _on_skill_upgrade_clicked, gold_for_skills, HeroDetailUpgradeFx.calculate_skl_bonus(hero, cm))
	_show_tab_content(tab, animate_tab)
	_refresh_upgrade_light()   # 可进阶时按钮光效（源 createUpgradeButtonLight）
	_setup_arrows()


# 翻页箭头（window.lua:1843-1936 createArrowButton）。多于 1 个英雄才显示；重建内容后需重连。
func _setup_arrows() -> void:
	var show: bool = _hero_ids.size() > 1
	_wire_arrow("%LeftArrow", show, func() -> void: _advance(-1))
	_wire_arrow("%RightArrow", show, func() -> void: _advance(1))


func _wire_arrow(node_path: String, show: bool, cb: Callable) -> void:
	var btn: TextureButton = _base_layer.get_node_or_null(node_path) as TextureButton
	if btn == null:
		return
	# visible 统一归 _set_arrows_visible（_show_tab_content/_close_tab 必经，含 equip 排除）。
	for c in btn.pressed.get_connections():
		btn.pressed.disconnect(c.callable)
	if show:
		btn.pressed.connect(cb)


# 翻页箭头：显隐=多英雄；任一 tab 打开时左箭头平移列表左缘外（全局 12，各 tab 面板左缘 56 外；
# 2026-08-30 用户两轮定谳：equip 平移合格后要求三 tab 同样处理）。局部 x：源位 38 / tab 态 -128。
func _refresh_arrows(tab_open: bool) -> void:
	var l: TextureButton = _base_layer.get_node("%LeftArrow") as TextureButton
	l.position.x = -128.0 if tab_open else 38.0
	l.visible = _hero_ids.size() > 1
	(_base_layer.get_node("%RightArrow") as TextureButton).visible = _hero_ids.size() > 1


# turnPrePage/turnNextPage：环形索引切 hero，refresh 复用 _rebuild_content。
func _advance(delta: int) -> void:
	if _hero_ids.is_empty() or hero_manager == null:
		return
	AudioPlayer.play_sfx("common_click_feedback")
	var n: int = _hero_ids.size()
	_current_idx = (_current_idx + delta + n) % n
	var new_hero: HeroInstance = hero_manager.get_hero(int(_hero_ids[_current_idx])) as HeroInstance
	if new_hero == null or new_hero == hero:
		return
	hero = new_hero
	refresh_content()


## 升星/技能升级/进阶/穿装后刷新（deferred 避信号中 free 崩）；animate_slide=true 仅升级反馈滑入（七轮定谳）。
func refresh_content(animate_slide: bool = false) -> void:
	call_deferred("_rebuild_content", animate_slide)


func _rebuild_content(animate_slide: bool = false) -> void:
	var saved_tab: String = _current_tab if _current_tab != "" else DEFAULT_TAB
	for c in container.get_children():
		c.free()
	_desc_label = null   # 旧 desc label 已 free，清引用
	_build_content(saved_tab, animate_slide)


# 绑定 .tscn 静态按钮信号：%CloseBtn + 升星/进阶/觉醒 + 3 tab。
func _bind_signals() -> void:
	(_base_layer.get_parent().get_node("%CloseBtn") as BaseButton).pressed.connect(_close_panel)
	_wire_action_button("%GetStoneBtn", evolve_requested, "common_click_feedback")   # +号按钮执行升星（简化偏离源，源 evolve 文字按钮已删）
	_wire_action_button("%UpgradeRankBtn", upgrade_rank_requested, "common_click_feedback")
	HeroDetailUpgradeFx.setup_awake_button(_base_layer, hero, cm, AWAKE_LSTR_KEY, AWAKE_FALLBACK_TEXT, func() -> void: awake_requested.emit())
	for key in _tab_buttons:
		(_tab_buttons[key] as BaseButton).pressed.connect(_on_tab_pressed.bind(key))
	# 装备进阶入口（左上浮动按钮，非底栏第 4 tab；源 window.lua:902-911 equip_button → doClickEvolveEquip）。
	(_base_layer.get_node("%EquipAdvanceBtn") as BaseButton).pressed.connect(_on_tab_pressed.bind(TAB_EQUIP))


# 关闭面板统一入口（外层 %CloseBtn + card_tab 内 %CardCloseBtn 共用，源 card.lua:158-180 close 按钮 → closeWindow）。
func _close_panel() -> void:
	AudioPlayer.play_sfx("common_close_popup_window")   # heroDetail.closeWindow（soundres.lua:204）
	remove_window()


func _wire_action_button(node_path: String, sig: Signal, sound_key: String) -> void:
	(_base_layer.get_node(node_path) as BaseButton).pressed.connect(func() -> void:
		if not sound_key.is_empty():
			AudioPlayer.play_sfx(sound_key)
		sig.emit())


# 觉醒按钮（单机化新增）。显示条件：Unit.Can Awake=true 且 hero.awake==false（扣碎片由 perform_awake 校验）。
const AWAKE_LSTR_KEY: StringName = &"HERODETAIL.AWAKE_"
const AWAKE_FALLBACK_TEXT: String = "觉醒"


# ---- Phase B：tab 内容 fill（挂各 host，visible 切换）----

# fill card view：builder.setup_card_view 填 frame/art/name + tabs.fill_card_view 补图标/星数（源 card.lua:127-140）。
func _fill_card_view() -> void:
	if cm == null:
		return
	var view: Control = _tab_views["card"] as Control
	# 清空 .tscn 编辑器占位节点（PH_ 前缀，挂在 view 根下或 CardArtHost 下）
	for c in view.get_children():
		if c is Control and c.name.begins_with("PH_"):
			c.queue_free()
	var art_host := view.get_node("%CardArtHost") as Control
	for c in art_host.get_children():
		if c.name.begins_with("PH_"):
			c.queue_free()
	HeroDetailTabs.fill_card_view(view, hero, cm)
	# 接 card_tab 内 %CardCloseBtn（card 平铺后便捷关闭入口，照源 card 弹窗独立 close；_bind_signals 阶段 _tab_views 未就绪故在此接）。
	var close_btn: BaseButton = view.get_node_or_null("%CardCloseBtn") as BaseButton
	if close_btn != null:
		# 用户 2026-08-22 指示去掉 card 层关闭钮（与主 %CloseBtn 重复，保留主钮）：隐藏不再接关闭。
		close_btn.visible = false


# skillstren.lua createSkill 等：每槽技能图标+边框+Display Name；rank 未达解锁 → 灰显 + "rank X 解锁"。
# 否则 lv.X 显示等级 + 升级按钮（:452 createSkillLevelBoard）。等级 = skill_levels - InitLevel + 1。
# 技能升级按钮回调（源 skillstren.lua:345 升级按钮 pressHandler：tutorial + upgrade 信号）。
func _on_skill_upgrade_clicked(idx: int) -> void:
	Events.bus.emit_tutorial_step(&"SUclickLevelup")   # Phase 8 SU（技能升级 → tutorial try_complete）
	upgrade_skill_requested.emit(idx)


# detail tab 滚轮接管：ScrollContainer accept_event 后不冒泡，改走 _input + 鼠标命中 AttribListHost 时改 scroll_vertical（一格 50px，兼容触控板 PanGesture）。
func _input(event: InputEvent) -> void:
	_handle_scroll_event(event)


func _handle_scroll_event(event: InputEvent) -> void:
	if not is_inside_tree() or _current_tab != TAB_DETAIL:
		return
	var host := (_tab_views["detail"] as Control).get_node("AttribListHost") as ScrollContainer
	if host == null:
		return
	var scroll_delta: int = 0
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not host.get_global_rect().has_point(mb.global_position):
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_delta = -50
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_delta = 50
	elif event is InputEventPanGesture:
		var pan := event as InputEventPanGesture
		var mouse_pos := get_global_mouse_position()
		if not host.get_global_rect().has_point(mouse_pos):
			return
		scroll_delta = int(pan.delta.y * 50.0)
	else:
		return
	if scroll_delta == 0:
		return
	host.scroll_vertical = max(0, host.scroll_vertical + scroll_delta)
	get_viewport().set_input_as_handled()


# window.lua:170-191 refreshgsAfterWear：gs 变 → 更新文本 + 居中 scale 1.2→1（EASE_BACK_OUT）+ 还原锚点左中。本项目 hero_manager.calc_gs 重算（语义等价）。
func refresh_gs_after_wear() -> void:
	if hero == null or hero_manager == null or _gs_label == null:
		return
	var gs: int = hero_manager.calc_gs(hero)
	if gs == _pre_gs:
		return
	_gs_label.text = str(gs)
	_gs_label.pivot_offset = _gs_label.size * 0.5   # setNodeAnchor(0.5,0.5) 居中缩放
	_pre_gs = gs
	var tw := create_tween()
	tw.tween_property(_gs_label, "scale", Vector2(GS_POP_SCALE, GS_POP_SCALE), GS_POP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_gs_label, "scale", Vector2.ONE, GS_POP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if _gs_label != null:
			_gs_label.pivot_offset = Vector2(0, _gs_label.size.y * 0.5))   # :180 还原 (0,0.5)


# 点击图标 toggle 技能描述（源 skillstren createDescBoard；board 逻辑外迁 HeroDetailTabs）。
func _toggle_skill_desc(slot: int) -> void:
	Events.bus.emit_tutorial_step(&"SUclickSkillButton")   # herodetail/window.lua:1659（点技能按钮）
	if _desc_label != null and int(_desc_label.get_meta("slot", -1)) == slot:
		_hide_skill_desc()
		return
	_hide_skill_desc()
	if hero == null:
		return
	var bg: Control = HeroDetailTabs.build_skill_desc(hero, slot, cm)
	bg.set_meta(&"tab_content", true)   # 标记动态 tab 内容（测试识别 "tab 内容已渲染"）
	_desc_host.add_child(bg)
	_desc_label = bg


func _hide_skill_desc() -> void:
	if _desc_label != null:
		_desc_label.queue_free()
		_desc_label = null


# ---- 底栏 tab 切换（源 createBottomButtons + setOpenMode/doClickDetail/Card/Skill）----

# doClickDetail/Card/Skill：点 tab → setOpenMode。同 tab 再点 → 关（base 回位）。
func _on_tab_pressed(key: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")   # tab 点击反馈
	if _current_tab == key:
		_close_tab()   # doClickX: if layer setOpenMode(nil)（同 tab toggle 关，base 回位）
		return
	_show_tab_content(key)


# setOpenMode：切 tab visible + base 右移让位 + 切选中态（Phase B visible 切换）。
func _show_tab_content(key: String, animate: bool = true) -> void:
	_current_tab = key
	_set_tab_selected(key)
	_slide_base_to(BASE_SLIDE_OFFSET, animate)
	# tab layer pop endPos=ccp(-200,0)（window.lua:386/430/513 三 tab 同值）：tab 内容从左滑入，
	# 止态 -200（源 doOpenDetail/Skill/Card pop 终点）。旧 -75 系 960 口径迁移遗留（2026-08-22 回源；
	# detail/skill 子节点已按源声明坐标直译，card 子节点 +125 平移保现状视觉）。
	for k in _tab_views:
		var v: Control = _tab_views[k] as Control
		if k == key:
			v.visible = true
			var start_x: float = 400.0 if animate and is_inside_tree() else TAB_POP_OFFSET_X
			v.offset_left = start_x
			v.offset_right = start_x
			if animate and is_inside_tree():
				var tw: Tween = create_tween()
				tw.tween_property(v, "offset_left", TAB_POP_OFFSET_X, 0.2)
				tw.parallel().tween_property(v, "offset_right", TAB_POP_OFFSET_X, 0.2)
		else:
			v.visible = false
	# 进入 skill tab 时 fill 技能点信息栏（源 skillstren.lua createInformationBar:476-486）。
	if key == TAB_SKILL:
		_refresh_skill_point_bar()
	# 进入 equip tab 时 fill 装备进阶列表（源 doClickEvolveEquip → evolveequip createEquipList）。
	if key == TAB_EQUIP:
		EvolveEquipFills.fill_equip_list(_tab_views[TAB_EQUIP] as Control, hero, cm,
				func(eid: int) -> void: HeroDetailEquipSlots.open_equip_craft_by_id(eid, cm, pd, get_parent(), self))
	_refresh_arrows(true)   # 任一 tab 打开：箭头平移面板左缘外（含 equip，2026-08-30 用户定谳）


# 切 tab 选中态 variation：选中 → HeroDetailTabActive，未选 → HeroDetailTab。
func _set_tab_selected(selected_key: String) -> void:
	for key in _tab_buttons:
		var btn: Button = _tab_buttons[key] as Button
		btn.theme_type_variation = TAB_VARIATION_ACTIVE if key == selected_key else TAB_VARIATION


func _slide_base_to(target_x: float, animate: bool = true) -> void:
	# animate=false 重建止态直设（新 base 从 0 起 tween=整界面右挫，十一轮视频实锤）
	if _base_layer != null and animate and is_inside_tree() and not is_equal_approx(_base_layer.position.x, target_x):
		create_tween().tween_property(_base_layer, "position:x", target_x, 0.2)
	elif _base_layer != null:
		_base_layer.position.x = target_x


# setOpenMode(nil) → doMoveBack（window.lua:289-296 base 回 (0,0)）+ destroyXLayer。
func _close_tab() -> void:
	_current_tab = ""
	_set_tab_selected("")
	_slide_base_to(0.0)
	for k in _tab_views:
		(_tab_views[k] as CanvasItem).visible = false
	_refresh_arrows(false)
	_hide_skill_desc()


# ---- 信号→Logic 便捷封装 ----

# 升星：hero_manager.evolve（扣碎片+金币，stars+1）。
func perform_evolve() -> bool:
	if hero_manager == null or hero == null:
		return false
	var ok: bool = hero_manager.evolve(hero.inst_id)
	if ok:
		AudioPlayer.play_sfx("common_hero_upgrade")   # heroDetail.upgradeReply（升星回复成功，soundres.lua:223）
		GameData.save()   # 照源 main.lua:1991 evolve 回调后即时存（升星扣碎片+金币）
	else:
		AudioPlayer.play_sfx("common_alert")          # heroDetail.clickDisabledUpgrade（条件不满足拒，soundres.lua:216）
	return ok


# 进阶：upgrade_rank + 照源补失败 Toast + 成功特效/飘字（doClickUpgrade/upgradeReply）。
func perform_upgrade_rank() -> bool:
	if hero_manager == null or hero == null:
		return false
	# 满级判定（源 doClickUpgrade :701-705）
	if hero.rank >= HeroManager.MAX_EQUIP_RANK:
		Toast.show_message(String(cm.get_lstr(LSTR_MAX_RANK)) if cm != null else "已进阶到顶级")
		AudioPlayer.play_sfx("common_alert")
		return false
	# 未穿齐判定（源 doClickUpgrade :707-716，can_upgrade_rank 已含此判）
	if not hero_manager.can_upgrade_rank(hero.inst_id):
		Toast.show_message(String(cm.get_lstr(LSTR_NEED_EQUIP)) if cm != null else "英雄穿齐装备才能进阶")
		AudioPlayer.play_sfx("common_alert")
		return false
	var old_gs: int = hero.gs   # 飘字 snapshot 进阶前 gs
	var ok: bool = hero_manager.upgrade_rank(hero.inst_id)
	if ok:
		AudioPlayer.play_sfx("common_hero_upgrade")
		GameData.save()
		HeroDetailUpgradeFx.play_upgrade_effect(_base_layer)
		HeroDetailUpgradeFx.play_att_addition_anim(_base_layer, _gs_label, old_gs, hero.gs, self)
	else:
		Toast.show_message(String(cm.get_lstr(LSTR_ADVANCE_FAIL)) if cm != null else "进阶失败")
		AudioPlayer.play_sfx("common_alert")
	return ok


# 进阶按钮光效（源 createUpgradeButtonLight）。
func _refresh_upgrade_light() -> void:
	if _base_layer == null or hero_manager == null or hero == null:
		return
	var btn: Button = _base_layer.get_node_or_null("%UpgradeRankBtn") as Button
	if btn == null:
		return
	var can_upgrade: bool = hero_manager.can_upgrade_rank(hero.inst_id)
	var r: Dictionary = HeroDetailUpgradeFx.refresh_upgrade_light(_base_layer, btn, can_upgrade, self, _upgrade_light, _light_tween)
	_upgrade_light = r.get("light") as Sprite2D
	_light_tween = r.get("tween") as Tween


# 技能升级：SkillPointManager.upgrade_hero_skill（扣技能点 + hero_manager.upgrade_skill_level 扣金币+升技能）。
func perform_upgrade_skill(idx: int) -> bool:
	if pd == null or hero == null: return false
	var ok: bool = SkillPointManager.upgrade_hero_skill(pd, hero.inst_id, idx)
	if ok:
		GameData.mark_save_dirty()   # local_server:1480 技能升级脏标
		HeroDetailUpgradeFx.play_skill_upgrade_fx(_tab_views.get("skill", null) as Control, idx, self)
		_refresh_skill_point_bar()   # 点数扣了，刷新信息栏（点数=0 时切购买按钮）
	else: HeroDetailUpgradeFx.show_upgrade_fail_reason(hero, idx, hero_manager, pd, cm)   # 照源 doClickLvupButton 失败 Toast
	return ok


# 刷新技能点信息栏（点数 / 购买按钮）。skill tab fill + 升级后调用。
func _refresh_skill_point_bar() -> void:
	var skill_view: Control = _tab_views.get("skill", null) as Control
	if skill_view == null:
		return
	var label: Label = skill_view.get_node_or_null("%SkillPointLabel") as Label
	var buy_btn: TextureButton = skill_view.get_node_or_null("%BuySkillPointBtn") as TextureButton
	HeroDetailUpgradeFx.fill_skill_point_bar(label, buy_btn, pd)
	if buy_btn != null:
		# 重连避免 _rebuild_content 后重复 connect（fill_skill_point_bar 控 visible，pressed 此处接）。
		for c in buy_btn.pressed.get_connections():
			buy_btn.pressed.disconnect(c.callable)
		buy_btn.pressed.connect(_on_buy_skill_point)


# 购买技能点（源 skillstren.lua:463-468 getResetCost + local_server:2184-2193 buySkillStrenPoint）。
# 钻石梯度计费，每次买 10 点。失败（钻石不足 / VIP 上限）Toast 提示。
func _on_buy_skill_point() -> void:
	if pd == null:
		return
	AudioPlayer.play_sfx("common_click_feedback")
	var ok: bool = SkillPointManager.buy_stren_point(pd)
	if ok:
		GameData.mark_save_dirty()
		Toast.show_message("技能点 +%d" % SkillPointManager.BUY_AMOUNT)
		_refresh_skill_point_bar()
	else:
		Toast.show_message("钻石不足")   # 源无显式 Toast（lua 弹窗），本项目单机化用 Toast 兜底


# 觉醒（单机化）：AwakeHelper.awake_hero 扣碎片 + 弹 HeroAwakePanel 展示 + 关闭后 refresh。
func perform_awake() -> bool:
	if pd == null or hero == null:
		return false
	var result: Dictionary = AwakeHelper.awake_hero(pd, hero)
	if not bool(result.get("ok", false)):
		AudioPlayer.play_sfx("common_alert")   # 碎片不足或其他校验失败
		return false
	AudioPlayer.play_sfx("common_hero_upgrade")   # 觉醒成功音效（复用升星音）
	GameData.save()   # 觉醒即时存（扣50专属碎片+awake=true；本项目碎片觉醒方案，源 protoAwake 死代码）
	_show_awake_popup()
	return true


# 弹觉醒展示弹窗（B），关闭后刷新本面板（按钮隐藏 + stars/gs 等更新）。
func _show_awake_popup() -> void:
	if not is_inside_tree():
		return
	var panel := HeroAwakePanel.new("popheroawake", {})
	panel.setup_awake(hero, cm)
	panel.closed.connect(refresh_content)
	panel.show_window(get_parent())
