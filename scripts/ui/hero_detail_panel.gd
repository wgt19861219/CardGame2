class_name HeroDetailPanel
extends PopWindow

## 英雄详情面板（View 层）— 属性 + 装备槽 + 升星/进阶按钮（信号）。
## Phase A+B 重构（2026-07-17）：base 层 + tab view 全静态化进 hero_detail_content.tscn（instantiate + fill），
## 位置/size 编辑器可视化调。tab（detail=属性 / card=图鉴 / skill=技能）visible 切换（不再 free+重建）。
## task#9 拆分（2026-07-20）：纯绘制 fill 外迁 HeroDetailAttribs（属性）+ HeroDetailTabs（card/skill 绘制），
## 本文件留 setup/build/refresh/signal 绑定/tab 切换/equip/perform 信号封装（测试引用 + panel 状态）。
## 信号由调用方接 hero_manager.evolve/split + pd.enhance_equip（单机化省源 net 层）。
## 照源 heropackage.lua / equipstrengthen.lua 交互简化。

signal evolve_requested
signal upgrade_rank_requested              # 进阶（rank+1，6 槽穿齐 Hero_equip[rank] 配方）
signal upgrade_skill_requested(idx: int)   # 技能升级（idx 0-3）
signal awake_requested                     # 觉醒（单机化新增，源无觉醒养成激活；碎片觉醒方案 C）

# base + tab view 子场景（Phase A+B 静态化：位置+size 在 .tscn 可视化）。
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/hero_detail_content.tscn")
const EQUIP_SLOT_COUNT: int = 6       # 源 createEquipIcons :1080 6 槽
const EQUIP_GRAY_MODULATE: Color = Color(0.4, 0.4, 0.4, 1.0)   # 源 setSpriteGray 未穿戴配方灰显
const SKILL_COUNT: int = 4                 # 源 4 技能槽（skillstren.lua createSkill）
# 源 skillstren.lua 技能行坐标（skillLayer 挂 animLayer 原点，ccp 为 cocos 世界坐标）。
# ori_height=350（:750）/ bd_height=90（:751 行高）。第 i 行（i 从 0）：icon ccp(320, 350-90*i)。
const SKILL_ORI_HEIGHT: float = 350.0       # 源 :750 ori_height
const SKILL_BD_HEIGHT: float = 90.0         # 源 :751 bd_height（行高）
const SKILL_ICON_COCOS_X: float = 320.0     # 源 :424 icon ccp(320, ori-bd*i)
const SKILL_NAME_COCOS_X: float = 365.0     # 源 :427 nameLabel ccp(365, ori+20-bd*i)
const SKILL_LVL_COCOS_X: float = 365.0      # 源 :322 lvl ccp(365, ori-5-bd*i)
const SKILL_BTN_COCOS_X: float = 495.0      # 源 :351 升级按钮 ccp(495, ori-15-bd*i)
const SKILL_NAME_DY: float = 20.0           # 源 name y 偏移 +20
const SKILL_LVL_DY: float = -5.0            # 源 lvl y 偏移 -5
const SKILL_BTN_DY: float = -15.0           # 源 btn y 偏移 -13-2
# 源 param.lua:54 skill_unlock_color_text（rank→颜色 LSTR key）。
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
# 源 window.lua LSTR key（技能解锁文案）。
const LSTR_SKILL_UNLOCK: StringName = &"HERODETAILSKILL.ADVANCED_TO__S_TO_UNLOCK"
const GS_POP_SCALE: float = 1.2                             # 源 ScaleTo(0.2,1.2)
const GS_POP_DURATION: float = 0.2                          # 源 0.2s
# 源 createBottomButtons（window.lua:1395-1663）三 tab：detail(属性)/card(图鉴)/skill(技能)。
const TAB_DETAIL: String = "detail"   # 源 doClickDetail → setOpenMode("att") 属性层
const TAB_CARD: String = "card"       # 源 doClickCard → setOpenMode("card") 图鉴层
const TAB_SKILL: String = "skill"     # 源 doClickSkill → setOpenMode("skill") 技能层
const DEFAULT_TAB: String = TAB_CARD   # 用户指示（2026-07-17）：默认 card 图鉴。源 setOpenMode(nil)=doMoveBack 无 tab，用户要进显图鉴
const BASE_SLIDE_OFFSET: float = 178.0   # 源 doMove 140（window.lua:300 container 右移）。目标 1:1 框偏大（CS 遗漏）。CloseBtn 移出 base 固定屏幕右上（不随 base），base 自由：178 让 bg left=399.5，card/popup 框与 bg 留 gap 10
# 源 doOpenDetail/Skill/Card pop endPos=ccp(-200,0)（window.lua:430/386/513）：tab 内容 container 显示态左移 200。
const TAB_POP_OFFSET_X: float = -200.0

var hero: HeroInstance = null
var cm: Variant = null
var hero_manager: HeroManager = null
var pd: PlayerData = null
var _desc_label: Control = null   # 技能描述弹板（NinePatchRect bg + label 子，源 createDescBoard；null 无 = destroyDescBoard）
var _gs_label: Label = null     # GS 战斗力 Label（.tscn %GsNum，源 ui.gs createInfoBoard:1254-1268）
var _pre_gs: int = -1           # 源 pregs（上次显示 gs，refreshgsAfterWear:172/175 比对）
var _current_tab: String = ""   # 当前激活 tab（源 self.openMode：nil/att/card/skill）
var _tab_buttons: Dictionary = {}   # tab_key → Button（.tscn %TabBtn，源 ui.detail/card/skill）
var _base_layer: Control = null   # .tscn %BaseLayer（base 元素层），开 tab 时整体右移让位（照源 doMove window.lua:300 ccp(140,0)）
var _tab_views: Dictionary = {}    # Phase B：tab_key → Control（.tscn %TabCardView/Detail/Skill，visible 切换）
var _skill_host: Control = null    # .tscn %SkillListHost（技能行动态挂）
var _desc_host: Control = null     # .tscn %DescHost（技能描述动态挂）


func setup_panel(p_hero: HeroInstance, p_cm: Variant, p_mgr: HeroManager = null, p_pd: PlayerData = null) -> void:
	hero = p_hero
	cm = p_cm
	hero_manager = p_mgr
	pd = p_pd
	setup()   # PopWindow.setup（shade + container）
	_build_content()


# 建 UI 内容。Phase A+B：base + tab view 从 .tscn instantiate（位置/size 可视化）+ fill 动态数据/样式；
# tab 内容 fill 一次到各 host（visible 切换，不再 free+重建）。
# 源 createWindow（window.lua:2384-2396）base 常显 + setOpenMode 开 tab overlay。
func _build_content(tab: String = DEFAULT_TAB) -> void:
	var content := CONTENT_SCENE.instantiate()
	container.add_child(content)
	_base_layer = content.get_node("%BaseLayer") as Control
	var result: Dictionary = HeroDetailBuilder.setup_base(_base_layer, hero, cm)
	_gs_label = result["gs_label"] as Label
	_tab_buttons = result["tab_buttons"] as Dictionary
	if hero_manager != null:
		HeroDetailBuilder.fill_stone_bar(_base_layer, hero, cm, hero_manager)
	_pre_gs = hero.gs if hero != null else -1
	_bind_signals()
	_show_equips()
	_tab_views = {
		"card": content.get_node("%TabCardView") as Control,
		"detail": content.get_node("%TabDetailView") as Control,
		"skill": content.get_node("%TabSkillView") as Control,
	}
	# tab view 的 z_index 由 .tscn 决定，运行时不再强制覆盖：
	# - TabCardView z=2（高于 BaseLayer z=0，让 Art 立绘盖在 herodetail-bg 之上）
	# - TabDetailView / TabSkillView z=-1（自带 PopupBg 当背景）
	# 先前循环 `z_index = -1` 是 bug：把 TabCardView 拉到 BaseLayer/Bg 之下，Art 从 CardFrame
	# 镂空区被全屏 bg 盖住，立绘"看起来暗"实为根本没显示。源 card.lua:129-154 cardLayer
	# 是 CCLayerColor(opacity=0 透明)整个盖住 baseLayer + cardLayer:setZOrder(10)，本项目的
	# 等价实现就是让 TabCardView z > BaseLayer/Bg z。
	_skill_host = (_tab_views["skill"] as Control).get_node("%SkillListHost") as Control
	_desc_host = (_tab_views["skill"] as Control).get_node("%DescHost") as Control
	_fill_card_view()
	# 隐藏 AttribListHost 的垂直滚动条视觉，保留滚动功能。
	# 方案：给 ScrollContainer 内的 VScrollBar 用 StyleBoxEmpty 覆盖 grabber/scroll 等 theme 项
	# （visible=false 会禁用滚动，必须用 stylebox 透明）。
	# 滚轮事件本身不靠 ScrollContainer 内置处理（gui_input 收不到 WHEEL_UP/DOWN），
	# 改由本脚本 _input 接管（仅 detail tab 激活 + 鼠标在 host 上时滚，见 _handle_scroll_event）。
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
	_fill_skills()
	_show_tab_content(tab)


## 升星/技能升级后刷新内容（数据变 → 重建 UI）。call_deferred 避信号处理中 free 按钮自身崩。
func refresh_content() -> void:
	call_deferred("_rebuild_content")


func _rebuild_content() -> void:
	var saved_tab: String = _current_tab if _current_tab != "" else DEFAULT_TAB
	for c in container.get_children():
		c.free()
	_desc_label = null   # 旧 desc label 已 free，清引用
	_build_content(saved_tab)


# 绑定 .tscn 静态按钮信号：%CloseBtn + 2 action（升星/进阶）+ 3 tab。
# 源 herodetail 右侧只有 2 按钮（evolve 升星 + upgrade 进阶）；split 在 heropackage（源 :459-477）、
# strengthen 在 main_scene estren（源 main.lua:1424-1434）。回源架构，4→2（2026-07-18）。
func _bind_signals() -> void:
	(_base_layer.get_parent().get_node("%CloseBtn") as BaseButton).pressed.connect(func() -> void:
		AudioPlayer.play_sfx("common_close_popup_window")   # 源 heroDetail.closeWindow（soundres.lua:204）
		remove_window())
	_wire_action_button("%GetStoneBtn", evolve_requested, "common_click_feedback")   # +号按钮执行升星（简化偏离源，源 evolve 文字按钮已删）
	_wire_action_button("%UpgradeRankBtn", upgrade_rank_requested, "common_click_feedback")   # 源 hero_upgrade（:867-901 rank+1）
	_setup_awake_button()   # 单机化新增：觉醒按钮（Can Awake=true + 碎片够 才显示）
	for key in _tab_buttons:
		(_tab_buttons[key] as BaseButton).pressed.connect(_on_tab_pressed.bind(key))


func _wire_action_button(node_path: String, sig: Signal, sound_key: String) -> void:
	(_base_layer.get_node(node_path) as BaseButton).pressed.connect(func() -> void:
		if not sound_key.is_empty():
			AudioPlayer.play_sfx(sound_key)
		sig.emit())


# 觉醒按钮可见性 + Scale9 样式（单机化新增，源 hero_detail 无觉醒入口）。
# 显示条件：Unit.Can Awake=true 且 hero.awake==false；扣碎片够不够由点击时 perform_awake 再校验。
# 按钮用 hero_detail 通用 Scale9 样式（_apply_detail_style 等价），文字 "觉醒"（源 LSTR 缺走 fallback）。
const AWAKE_LSTR_KEY: StringName = &"HERODETAIL.AWAKE_"
const AWAKE_FALLBACK_TEXT: String = "觉醒"
func _setup_awake_button() -> void:
	var awake_btn: BaseButton = _base_layer.get_node_or_null("%AwakeBtn") as BaseButton
	if awake_btn == null:
		return
	var can_show: bool = hero != null and not hero.awake and cm != null and cm.get_bool(&"Unit", int(hero.tid), &"Can Awake")
	awake_btn.visible = can_show
	if not can_show:
		return
	# 套 Scale9 样式（复用 UpgradeRankBtn 的 detail-n 样式，照源 action button Scale9Sprite 等价）
	if awake_btn is Button:
		HeroDetailBuilder._apply_detail_style(awake_btn as Button)
		var lbl: Label = awake_btn.get_node_or_null("%AwakeLabel") as Label
		if lbl != null:
			lbl.text = String(cm.get_lstr(AWAKE_LSTR_KEY)) if cm != null and cm.has_method("get_lstr") else AWAKE_FALLBACK_TEXT
			if lbl.text == String(AWAKE_LSTR_KEY):
				lbl.text = AWAKE_FALLBACK_TEXT
	awake_btn.pressed.connect(func() -> void:
		AudioPlayer.play_sfx("common_click_feedback")
		awake_requested.emit())


# ---- Phase B：tab 内容 fill（挂各 host，visible 切换）----

# 标记动态 tab 内容子节点（测试识别 "tab 内容已渲染"；Phase B 不用于 free）。
func _add_tab_content(host: Control, node: Node) -> void:
	node.set_meta(&"tab_content", true)
	host.add_child(node)


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


# 源 skillstren.lua createSkill + createSkillIcon + createSkillUnlockLabel。
# 每槽：技能图标（SkillGroup.Icon + equip_frame_white 边框）+ Display Name。
# rank < SkillGroup[slot].Unlock → 灰显图标 + "rank X 解锁"（源 :442-451，不显示等级+按钮）。
# 否则：lv.X 显示等级 + 升级按钮（源 :452 createSkillLevelBoard）。
# 显示等级 = skill_levels[slot] - InitLevel + 1（源 controller.getCacheSkillLevelDisplay）。
func _fill_skills() -> void:
	if hero == null:
		return
	# skill 行节点全静态化进 hero_detail_skill_tab.tscn（%Skill{1..4}Board/Frame/Icon/Name/Lvl/Btn），
	# 本函数只 fill 数据 + 绑信号，位置/size 留 .tscn 编辑器可视化调（AGENTS.md .tscn 子场景范式）。
	var skill_view: Control = _tab_views["skill"] as Control
	var sg: Dictionary = cm.get_raw_table(&"SkillGroup").get(str(hero.tid), {})
	for i in SKILL_COUNT:
		var slot_info: Dictionary = sg.get(str(i + 1), {})
		var display_name: String = cm.get_lstr(String(slot_info.get("Display Name", "skill" + str(i + 1))))
		var init_level: int = int(slot_info.get("Init Level", 1))
		var unlock_rank: int = int(slot_info.get("Unlock", 1))
		var icon_res: String = String(slot_info.get("Icon", ""))
		var locked: bool = hero.rank < unlock_rank
		var slot_idx: int = i + 1   # .tscn 节点名 1-based（%Skill1Icon..%Skill4Icon）
		# fill icon 纹理（动态，每技能不同）+ 灰显锁定 + 测试 meta
		var icon_btn: TextureButton = skill_view.get_node("%Skill" + str(slot_idx) + "Icon") as TextureButton
		var icon_tex: Texture2D = HeroDetailTabs.load_skill_icon(icon_res)
		if icon_tex != null:
			icon_btn.texture_normal = icon_tex
			icon_btn.texture_hover = icon_tex
		icon_btn.modulate = HeroDetailTabs.SKILL_GRAY_MODULATE if locked else Color.WHITE
		icon_btn.set_meta(&"skill_icon", true)
		for c in icon_btn.pressed.get_connections():
			icon_btn.pressed.disconnect(c.callable)
		icon_btn.pressed.connect(_toggle_skill_desc.bind(i))
		# frame 灰显锁定
		var frame: TextureRect = skill_view.get_node("%Skill" + str(slot_idx) + "Frame") as TextureRect
		frame.modulate = HeroDetailTabs.SKILL_GRAY_MODULATE if locked else Color.WHITE
		# fill name 文本
		var name_lbl: Label = skill_view.get_node("%Skill" + str(slot_idx) + "Name") as Label
		name_lbl.text = display_name
		# fill lvl 文本（锁定显示"rank X 解锁"+隐藏 btn，已解锁显示 lv.X+显示 btn）+ 测试 meta
		var lvl_lbl: Label = skill_view.get_node("%Skill" + str(slot_idx) + "Lvl") as Label
		var btn: TextureButton = skill_view.get_node("%Skill" + str(slot_idx) + "Btn") as TextureButton
		if locked:
			var color_text: String = HeroDetailAttribs.get_lstr_fallback(String(RANK_COLOR_LSTR.get(unlock_rank, "")), str(unlock_rank), cm)
			lvl_lbl.text = HeroDetailAttribs.get_lstr_fallback(String(LSTR_SKILL_UNLOCK), "rank %s 解锁", cm) % color_text
			btn.visible = false
		else:
			var cur_level: int = int(hero.skill_levels[i]) if i < hero.skill_levels.size() else 1
			var show_level: int = cur_level - init_level + 1
			lvl_lbl.text = "lv." + str(show_level)
			btn.visible = true
			for c in btn.pressed.get_connections():
				btn.pressed.disconnect(c.callable)
			btn.pressed.connect(_on_skill_upgrade_clicked.bind(i))
			btn.set_meta(&"skill_upgrade", true)


# 技能升级按钮回调（源 skillstren.lua:345 升级按钮 pressHandler：tutorial + upgrade 信号）。
func _on_skill_upgrade_clicked(idx: int) -> void:
	Events.bus.emit_tutorial_step(&"SUclickLevelup")   # Phase 8 SU（技能升级 → tutorial try_complete）
	upgrade_skill_requested.emit(idx)


# detail tab 滚轮接管：ScrollContainer 内置 _gui_input 处理滚轮后 accept_event，
# 既不 emit gui_input 信号也不让事件冒泡，故 host.gui_input 收不到 WHEEL_UP/DOWN。
# 改走 _input（所有事件都过此处，先于 GUI/_gui_input），仅当 detail tab 激活 +
# 鼠标落在 AttribListHost 上时改 scroll_vertical（滚轮一格 50px，Godot 默认等价）。
# 兼容触控板：PanGesture（笔记本两指滑动）按 delta.y 滚。
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


# 源 window.lua:170-191 refreshgsAfterWear：gs 变了 → 更新文本 + 锚点居中 + scale 1.2→1
# （EASE_BACK_OUT）+ 还原锚点左中。本项目调 hero_manager.calc_gs 重算（源读 hero._gs，
# 本项目重算语义等价，第二十七轮）。
func refresh_gs_after_wear() -> void:
	if hero == null or hero_manager == null or _gs_label == null:
		return
	var gs: int = hero_manager.calc_gs(hero)
	if gs == _pre_gs:
		return
	_gs_label.text = str(gs)
	_gs_label.pivot_offset = _gs_label.size * 0.5   # 源 setNodeAnchor(0.5,0.5) 居中缩放
	_pre_gs = gs
	var tw := create_tween()
	tw.tween_property(_gs_label, "scale", Vector2(GS_POP_SCALE, GS_POP_SCALE), GS_POP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_gs_label, "scale", Vector2.ONE, GS_POP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if _gs_label != null:
			_gs_label.pivot_offset = Vector2(0, _gs_label.size.y * 0.5))   # 源 :180 还原 (0,0.5)


# 源 createEquipIcons（herodetail/window.lua:1071-1098）6 槽全显示 + createEquipIcon（:1110-1135）三态：
# ceid>0 已穿戴 / eid>0 未穿戴配方灰显 / eid==0 无配方 unknown 占位（ReadequipIcon.create_icon(0) white 边框）。
# 空槽也连 gui_input 可点进 equipcraft（源 doClickEquip 不检查 isEquiped）。
func _show_equips() -> void:
	if hero == null:
		return
	var rank_equip: Dictionary = cm.get_raw_table(&"Hero_equip").get(str(hero.tid), {}).get(str(hero.rank), {})
	for i in EQUIP_SLOT_COUNT:
		var ceid: int = int(hero.equip_slots[i]) if i < hero.equip_slots.size() else 0   # 已穿戴
		var eid: int = int(rank_equip.get("Equip" + str(i + 1) + " ID", 0))              # Hero_equip 配方
		var icon: Control = _create_equip_slot_icon(ceid, eid)
		# 装备槽静态化进 .tscn（EquipSlot1-6 挂 EquipSlotHost/{Left,Right}Column VBox）：挂 icon 到静态槽
		# （position=0 相对槽本地坐标 + 清占位 texture 避免双框，不设 icon.size 避免干扰 VBox 布局）。
		var slot_host: TextureRect = _base_layer.get_node_or_null("%EquipSlot" + str(i + 1)) as TextureRect
		if slot_host == null:
			icon.free()
			continue
		slot_host.texture = null
		icon.position = Vector2.ZERO
		icon.gui_input.connect(_make_equip_click_handler(i))
		slot_host.add_child(icon)


# 源 createEquipIcon 三态：icon_id = ceid or eid；未穿戴配方（ceid<=0 and eid>0）灰显 setSpriteGray。
func _create_equip_slot_icon(ceid: int, eid: int) -> Control:
	var icon_id: int = ceid if ceid > 0 else eid   # 源 equips[i].id = 0<ceid and ceid or eid
	var icon: Control = ReadequipIcon.create_icon(icon_id, 1, cm)
	icon.set_meta(&"equip_slot", true)   # 标记装备槽（测试计数 + 节点识别）
	if ceid <= 0 and eid > 0:
		icon.modulate = EQUIP_GRAY_MODULATE   # 源 setSpriteGray（未穿戴配方灰显）
	return icon


# 源 heropackage → equipcraft：点装备槽图标 → 弹 EquipCraftPanel（合成/查看该装备配方）。
func _make_equip_click_handler(slot: int) -> Callable:
	return func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_open_equip_craft(slot)


# 源 doClickEquip（herodetail/window.lua:247-276）：item_id = ceid（已穿戴）or eid（配方），传 equipcraft 合成/查看。
func _open_equip_craft(slot: int) -> void:
	if hero == null:
		return
	var ceid: int = int(hero.equip_slots[slot]) if slot >= 0 and slot < hero.equip_slots.size() else 0
	var rank_equip: Dictionary = cm.get_raw_table(&"Hero_equip").get(str(hero.tid), {}).get(str(hero.rank), {})
	var eid: int = int(rank_equip.get("Equip" + str(slot + 1) + " ID", 0))
	var item_id: int = ceid if ceid > 0 else eid   # 源 equips[id].id = ceid or eid
	if item_id <= 0:
		return   # 无配方无穿戴（eid==0 unknown 占位），不弹
	var panel := EquipCraftPanel.new("equipcraft", {})
	panel.setup_panel(item_id, cm, pd, hero, "heroDetail", slot)
	panel.equipped_changed.connect(refresh_content)   # 穿戴后刷新装备槽（灰显配方→已穿戴图标）
	panel.jump_to_stage.connect(_on_equip_craft_jump)   # P1-10：获取途径跳转（源 doClickGetWay）
	panel.show_window(get_parent())   # openWindow 音效由 EquipCraftPanel register_on_enter 自播


# P1-10 源 equipcraft doClickGetWay :83 pushScene(stageselect.createByStage(id))。
# 本项目 stageselect 是弹窗（非场景）：关 hero_detail + 托 main_scene 打开 StageSelectPanel（定位章）。
func _on_equip_craft_jump(stage_id: int) -> void:
	remove_window()   # 源 pushScene 换场景 → 关 hero_detail
	var ms: Node = get_tree().current_scene
	if ms != null and ms.has_method("open_stage_select_by_stage"):
		ms.open_stage_select_by_stage(stage_id)


# 源 skillstren.lua:14 createDescBoard + :8 destroyDescBoard。点击图标 toggle 描述（源按住 board_i 显示）。
# 建 board 逻辑外迁 HeroDetailTabs.build_skill_desc（本方法留 toggle 状态入口 + _desc_label 字段，测试直调）。
func _toggle_skill_desc(slot: int) -> void:
	Events.bus.emit_tutorial_step(&"SUclickSkillButton")   # 源 herodetail/window.lua:1659（点技能按钮）
	if _desc_label != null and int(_desc_label.get_meta("slot", -1)) == slot:
		_hide_skill_desc()
		return
	_hide_skill_desc()
	if hero == null:
		return
	var bg: Control = HeroDetailTabs.build_skill_desc(hero, slot, cm)
	_add_tab_content(_desc_host, bg)
	_desc_label = bg


func _hide_skill_desc() -> void:
	if _desc_label != null:
		_desc_label.queue_free()
		_desc_label = null


# ---- 底栏 tab 切换（源 createBottomButtons + setOpenMode/doClickDetail/Card/Skill）----

# 源 doClickDetail/Card/Skill（window.lua:454/519/391）：点 tab → setOpenMode。同 tab 再点 → setOpenMode(nil) 关（base 回位）。
func _on_tab_pressed(key: String) -> void:
	AudioPlayer.play_sfx("common_click_feedback")   # 源 tab 点击反馈
	if _current_tab == key:
		_close_tab()   # 源 doClickX: if layer setOpenMode(nil)（同 tab toggle 关，base 回位）
		return
	_show_tab_content(key)


# 源 setOpenMode（window.lua:318-367）：切 tab layer visible + base 右移让位 + 切选中态。
# Phase B：tab view 常驻（.tscn），visible 切换（不再 free+重建）。
func _show_tab_content(key: String) -> void:
	_current_tab = key
	HeroDetailBuilder.set_tab_selected(_tab_buttons, key)
	_slide_base_to(BASE_SLIDE_OFFSET)
	# 源 tab layer pop CCMoveTo(-200,0)：tab 内容从左滑入（止态 -75，在树时从 +400 屏幕外滑入）
	for k in _tab_views:
		var v: Control = _tab_views[k] as Control
		if k == key:
			v.visible = true
			var start_x: float = 400.0 if is_inside_tree() else -75.0
			v.offset_left = start_x
			v.offset_right = start_x
			if is_inside_tree():
				var tw: Tween = create_tween()
				tw.tween_property(v, "offset_left", -75.0, 0.2)
				tw.parallel().tween_property(v, "offset_right", -75.0, 0.2)
		else:
			v.visible = false


# 源 doMove/doMoveBack container CCMoveTo 0.2s（在树+非止态才动画，首次 _build_content 不在树直接设止态）。
func _slide_base_to(target_x: float) -> void:
	if _base_layer != null and is_inside_tree() and not is_equal_approx(_base_layer.position.x, target_x):
		create_tween().tween_property(_base_layer, "position:x", target_x, 0.2)
	elif _base_layer != null:
		_base_layer.position.x = target_x


# 源 setOpenMode(nil) → doMoveBack（window.lua:289-296 base 回 (0,0)）+ destroyXLayer。
func _close_tab() -> void:
	_current_tab = ""
	HeroDetailBuilder.set_tab_selected(_tab_buttons, "")
	_slide_base_to(0.0)
	for k in _tab_views:
		(_tab_views[k] as CanvasItem).visible = false
	_hide_skill_desc()


# ---- 信号→Logic 便捷封装（调用方接信号后调，或直调）----

# 升星：hero_manager.evolve（扣碎片+金币，stars+1）。返是否成功。
func perform_evolve() -> bool:
	if hero_manager == null or hero == null:
		return false
	var ok: bool = hero_manager.evolve(hero.inst_id)
	if ok:
		AudioPlayer.play_sfx("common_hero_upgrade")   # 源 heroDetail.upgradeReply（升星回复成功，soundres.lua:223）
		GameData.save()   # 照源 main.lua:1991 evolve 回调后即时存（升星扣碎片+金币）
	else:
		AudioPlayer.play_sfx("common_alert")          # 源 heroDetail.clickDisabledUpgrade（条件不满足拒，soundres.lua:216）
	return ok


# 进阶：hero_manager.upgrade_rank（6 槽穿齐 Hero_equip[rank] 配方 → rank+1 + 重置槽 + 重算 gs）。返是否成功。
func perform_upgrade_rank() -> bool:
	if hero_manager == null or hero == null:
		return false
	var ok: bool = hero_manager.upgrade_rank(hero.inst_id)
	if ok:
		AudioPlayer.play_sfx("common_hero_upgrade")
		GameData.save()   # 照源即时存（进阶：6 槽穿齐 Hero_equip[rank] → rank+1 重置槽重算 gs）
	else:
		AudioPlayer.play_sfx("common_alert")
	return ok


# 技能升级：pd.upgrade_hero_skill（扣技能点 + hero_manager.upgrade_skill_level 扣金币+升技能）。
func perform_upgrade_skill(idx: int) -> bool:
	if pd == null or hero == null:
		return false
	var ok: bool = pd.upgrade_hero_skill(hero.inst_id, idx)
	if ok:
		GameData.mark_save_dirty()   # 照源 local_server:1480 技能升级脏标（扣技能点+金币，60s/退出刷）
	return ok


# 觉醒（单机化新增）：AwakeHelper.awake_hero 扣 50 专属碎片 + hero.awake=true。
# 成功后弹 HeroAwakePanel（B）展示觉醒动画，关闭后 refresh_content 隐藏按钮。
# 源无觉醒养成激活逻辑（源 awake 由服务器 protoAwake 注入）；本项目用户授权碎片觉醒方案。
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
