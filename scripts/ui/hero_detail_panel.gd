class_name HeroDetailPanel
extends PopWindow

## 英雄详情面板（View 层）— 属性 + 装备槽 + 升星/分解/强化按钮（信号）。
## 信号由调用方接 hero_manager.evolve/split + pd.enhance_equip（单机化省源 net 层）。
## 照源 heropackage.lua / equipstrengthen.lua 交互简化。

signal evolve_requested
signal split_requested
signal upgrade_rank_requested              # 进阶（rank+1，6 槽穿齐 Hero_equip[rank] 配方）
signal upgrade_skill_requested(idx: int)   # 技能升级（idx 0-3）

const DISPLAY_ATTRIBS: Array[String] = ["HP", "AD", "AP", "ARM", "MR"]
const LIST_TOP: float = 415.0
const LIST_LEFT: float = 24.0
const LINE_HEIGHT: float = 30.0
const CLOSE_BTN_POS: Vector2 = Vector2(800.0, 50.0)
const CLOSE_BTN_SIZE: Vector2 = Vector2(80.0, 40.0)
const EQUIP_ORIGIN: Vector2 = Vector2(24.0, 200.0)
const EQUIP_CELL: float = 80.0
const EQUIP_SLOT_COUNT: int = 6   # 源 createEquipIcons 6 槽（herodetail/window.lua:1080）
const EQUIP_GRAY_MODULATE: Color = Color(0.4, 0.4, 0.4, 1.0)   # 源 setSpriteGray 未穿戴配方灰显
const EVOLVE_BTN_POS: Vector2 = Vector2(600.0, 415.0)
const SPLIT_BTN_POS: Vector2 = Vector2(600.0, 365.0)
const UPGRADE_RANK_BTN_POS: Vector2 = Vector2(600.0, 465.0)   # 进阶（rank+1，源 heroDetail 进阶按钮）
const ENHANCE_BTN_POS: Vector2 = Vector2(600.0, 315.0)
const ACTION_BTN_SIZE: Vector2 = Vector2(100.0, 40.0)
const SKILL_COUNT: int = 4                 # 源 4 技能槽（skillstren.lua createSkill）
const SKILL_LIST_TOP: float = 130.0
const SKILL_LEFT: float = 24.0
const SKILL_LINE_HEIGHT: float = 35.0
const SKILL_LVL_OFFSET: float = 180.0
const SKILL_UPGRADE_BTN_OFFSET: float = 220.0
const SKILL_BTN_SIZE: Vector2 = Vector2(80.0, 28.0)
const SKILL_ICON_LEFT: float = 300.0       # 技能图标 x（源 skillstren.lua:424 ccp(320,...)）
const EQUIP_FRAME_WHITE_PATH: String = "res://assets/ui/alpha/HVGA/equip_frame_white.png"
const UI_PATH_PREFIX: String = "UI/"       # 源路径前缀 → res://assets/ui/
const UI_PATH_REPLACE: String = "res://assets/ui/"
const SKILL_GRAY_MODULATE: Color = Color(0.4, 0.4, 0.4, 1.0)   # 源 setSpriteGray 灰显近似
const SKILL_ICON_BTN_SIZE: Vector2 = Vector2(40.0, 40.0)   # 技能图标可点击区
const SKILL_DESC_POS: Vector2 = Vector2(400.0, 100.0)      # 描述弹板位置
const SKILL_GROWTH_COLOR: Color = Color(1.0, 0.81, 0.07)   # 源 ccc3(231,206,19) 成长值黄
const GS_LABEL_POS: Vector2 = Vector2(24.0, 445.0)         # 属性区上方（源 info_board 内 gs label 195,168）
const GS_LABEL_COLOR: Color = Color(146.0 / 255.0, 0.0, 4.0 / 255.0)   # 源 ccc3(146,0,4) 深红
const GS_LABEL_FONT_SIZE: int = 18                          # 源 size 18
const GS_POP_SCALE: float = 1.2                             # 源 ScaleTo(0.2,1.2)
const GS_POP_DURATION: float = 0.2                          # 源 0.2s

var hero: HeroInstance = null
var cm: Variant = null
var hero_manager: HeroManager = null
var pd: PlayerData = null
var _desc_label: Label = null   # 当前技能描述 Label（null 无，源 destroyDescBoard）
var _gs_label: Label = null     # GS 战斗力 Label（源 ui.gs createInfoBoard:1254-1268）
var _pre_gs: int = -1           # 源 pregs（上次显示 gs，refreshgsAfterWear:172/175 比对）


func setup_panel(p_hero: HeroInstance, p_cm: Variant, p_mgr: HeroManager = null, p_pd: PlayerData = null) -> void:
	hero = p_hero
	cm = p_cm
	hero_manager = p_mgr
	pd = p_pd
	setup()   # PopWindow.setup（shade + container）
	_build_content()


# 建 UI 内容（close + 属性/GS/装备/技能 + 升星/分解/强化）。setup_panel 与 refresh_content 共用。
func _build_content() -> void:
	HeroDetailBuilder.create_background(container)
	HeroDetailBuilder.create_portrait(container, hero, cm)
	HeroDetailBuilder.create_name_board(container, hero, cm)
	HeroDetailBuilder.create_stars(container, hero.stars)
	_create_close_button()
	_show_attributes()
	_show_gs()
	_show_equips()
	_show_skills()
	_create_action_button("升星", EVOLVE_BTN_POS, evolve_requested, "common_click_feedback", true)   # 源 heroDetail.clickUpgrade（soundres.lua:217）
	_create_action_button("进阶", UPGRADE_RANK_BTN_POS, upgrade_rank_requested, "common_click_feedback", false)   # 源 hero_upgrade（:867-901 rank+1）
	# 分解按钮单独建（照源 herosplit:88 firstConfirm 二次确认，_create_action_button 第3参 Signal 不兼容 Callable）。
	var split_btn: Button = HeroDetailBuilder.create_action_button(container, "分解", SPLIT_BTN_POS, false)
	split_btn.pressed.connect(_on_split_pressed)
	_create_strengthen_button()   # 强化 → 弹 EquipStrengthenPanel（源独立面板，本项目从 HeroDetailPanel 进）


## 升星/技能升级后刷新内容（数据变 → 重建 UI）。call_deferred 避信号处理中 free 按钮自身崩。
func refresh_content() -> void:
	call_deferred("_rebuild_content")


func _rebuild_content() -> void:
	for c in container.get_children():
		c.free()
	_build_content()


func _create_close_button() -> void:
	var btn: TextureButton = HeroDetailBuilder.create_close_button(container)   # 照源 :1976 detail-close 图
	btn.pressed.connect(func() -> void:
		AudioPlayer.play_sfx("common_close_popup_window")   # 源 heroDetail.closeWindow（soundres.lua:204）
		remove_window())


# 源 getHeroAtt：base/add/all → "key: all (+add)"
func _show_attributes() -> void:
	if hero == null:
		return
	var att: Dictionary = ReadheroAttribs.get_hero_att_by_hero(hero, cm)
	var y: float = LIST_TOP
	for key in DISPLAY_ATTRIBS:
		if att.has(key):
			var row: Dictionary = att[key]
			var lbl := Label.new()
			lbl.text = key + ": " + str(int(row["all"])) + " (+" + str(int(row["add"])) + ")"
			lbl.position = Vector2(LIST_LEFT, y)
			container.add_child(lbl)
			y -= LINE_HEIGHT


# 源 window.lua:1210 createInfoBoard 的 gs Label（:1254-1268 position 195,168 anchor 0,0.5 size 18
# color 深红）+ :1293 pregs=hero._gs 初始化。本项目无 info_board，GS Label 放属性区上方。
func _show_gs() -> void:
	if hero == null or hero_manager == null:
		return
	var lbl := Label.new()
	lbl.text = "GS " + str(hero.gs)
	lbl.position = GS_LABEL_POS
	lbl.add_theme_font_size_override("font_size", GS_LABEL_FONT_SIZE)
	lbl.modulate = GS_LABEL_COLOR
	container.add_child(lbl)
	_gs_label = lbl
	_pre_gs = hero.gs


# 源 window.lua:170-191 refreshgsAfterWear：gs 变了 → 更新文本 + 锚点居中 + scale 1.2→1
# （EASE_BACK_OUT）+ 还原锚点左中。本项目调 hero_manager.calc_gs 重算（源读 hero._gs，
# 本项目重算语义等价，第二十七轮）。
func refresh_gs_after_wear() -> void:
	if hero == null or hero_manager == null or _gs_label == null:
		return
	var gs: int = hero_manager.calc_gs(hero)
	if gs == _pre_gs:
		return
	_gs_label.text = "GS " + str(gs)
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
		icon.position = Vector2(EQUIP_ORIGIN.x + EQUIP_CELL * i, EQUIP_ORIGIN.y)
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.gui_input.connect(_make_equip_click_handler(i))   # 源 doClickEquip → equipcraft（空槽也可点）
		container.add_child(icon)


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


# 源 equipstrengthen 独立面板（2176 行），本项目从 HeroDetailPanel "强化"按钮进。
func _create_strengthen_button() -> void:
	var btn: Button = HeroDetailBuilder.create_action_button(container, "强化", ENHANCE_BTN_POS, true)
	btn.pressed.connect(func() -> void:
		AudioPlayer.play_sfx("common_click_feedback")
		var panel := EquipStrengthenPanel.new("equipstrengthen", {})
		panel.setup_panel(hero, cm, pd)
		panel.show_window(get_parent()))


func _create_action_button(text: String, pos: Vector2, sig: Signal, sound_key: String = "", use_upgrade_res: bool = false) -> void:
	var btn: Button = HeroDetailBuilder.create_action_button(container, text, pos, use_upgrade_res)
	btn.pressed.connect(func() -> void:
		if not sound_key.is_empty():
			AudioPlayer.play_sfx(sound_key)
		sig.emit())


# 源 skillstren.lua createSkill + createSkillIcon + createSkillUnlockLabel。
# 每槽：技能图标（SkillGroup.Icon + equip_frame_white 边框）+ Display Name。
# rank < SkillGroup[slot].Unlock → 灰显图标 + "rank X 解锁"（源 :442-451，不显示等级+按钮）。
# 否则：lv.X 显示等级 + 升级按钮（源 :452 createSkillLevelBoard）。
# 显示等级 = skill_levels[slot] - InitLevel + 1（源 controller.getCacheSkillLevelDisplay）。
func _show_skills() -> void:
	if hero == null:
		return
	var sg: Dictionary = cm.get_raw_table(&"SkillGroup").get(str(hero.tid), {})
	for i in SKILL_COUNT:
		var slot_info: Dictionary = sg.get(str(i + 1), {})
		var display_name: String = cm.get_lstr(String(slot_info.get("Display Name", "skill" + str(i + 1))))
		var init_level: int = int(slot_info.get("Init Level", 1))
		var unlock_rank: int = int(slot_info.get("Unlock", 1))
		var icon_res: String = String(slot_info.get("Icon", ""))
		var y: float = SKILL_LIST_TOP - i * SKILL_LINE_HEIGHT
		var locked: bool = hero.rank < unlock_rank
		_create_skill_icon(icon_res, y, locked, i)   # 源 createSkillIcon + :433 灰显
		var name_lbl := Label.new()
		name_lbl.text = display_name
		name_lbl.position = Vector2(SKILL_LEFT, y)
		container.add_child(name_lbl)
		if locked:   # 源 createSkillUnlockLabel :442 未解锁
			var unlock_lbl := Label.new()
			unlock_lbl.text = "rank " + str(unlock_rank) + " 解锁"
			unlock_lbl.position = Vector2(SKILL_LEFT + SKILL_LVL_OFFSET, y)
			container.add_child(unlock_lbl)
		else:   # 已解锁 → 等级 + 升级按钮
			var cur_level: int = int(hero.skill_levels[i]) if i < hero.skill_levels.size() else 1
			var show_level: int = cur_level - init_level + 1
			var lvl_lbl := Label.new()
			lvl_lbl.text = "lv." + str(show_level)
			lvl_lbl.position = Vector2(SKILL_LEFT + SKILL_LVL_OFFSET, y)
			container.add_child(lvl_lbl)
			_create_skill_upgrade_button(i, Vector2(SKILL_LEFT + SKILL_UPGRADE_BTN_OFFSET, y))


# 源 readhero.lua:1011 createSkillIcon + skillstren.lua:758 board_i pressHandler。
# 边框 Sprite2D（equip_frame_white centered 居中）+ 图标 TextureButton（可点击 → 描述弹板）。
# locked=true 灰显（源 skillstren.lua:434 setSpriteGray，modulate 降亮近似）。
func _create_skill_icon(icon_res: String, y: float, locked: bool, slot: int) -> void:
	var tex: Texture2D = _load_ui_texture(icon_res)
	if tex == null:
		return
	var frame := Sprite2D.new()
	frame.texture = _load_texture(EQUIP_FRAME_WHITE_PATH)
	if frame.texture != null:
		frame.position = Vector2(SKILL_ICON_LEFT, y)
		if locked:
			frame.modulate = SKILL_GRAY_MODULATE
		container.add_child(frame)
	var btn := TextureButton.new()
	btn.texture_normal = tex
	btn.texture_hover = tex
	btn.ignore_texture_size = true
	btn.size = SKILL_ICON_BTN_SIZE
	btn.position = Vector2(SKILL_ICON_LEFT - SKILL_ICON_BTN_SIZE.x * 0.5, y - SKILL_ICON_BTN_SIZE.y * 0.5)
	if locked:
		btn.modulate = SKILL_GRAY_MODULATE
	btn.pressed.connect(func() -> void: _toggle_skill_desc(slot))
	btn.set_meta(&"skill_icon", true)   # 标记技能图标（测试区分 vs close/action 按钮图）
	container.add_child(btn)


func _create_skill_upgrade_button(idx: int, pos: Vector2) -> void:
	var btn := Button.new()
	btn.text = "升级"
	btn.position = pos
	btn.size = SKILL_BTN_SIZE
	btn.pressed.connect(func() -> void:
		Events.bus.emit_tutorial_step(&"SUclickLevelup")   # Phase 8 SU（技能升级 → tutorial try_complete）
		upgrade_skill_requested.emit(idx))
	container.add_child(btn)


# 源 UI 路径 "UI/ITEM/s10.jpg" → res://assets/ui/ITEM/s10.jpg（仿 readhero_icon.gd:81 Portrait 映射）。
func _load_ui_texture(ui_path: String) -> Texture2D:
	if ui_path.is_empty():
		return null
	var path: String = ui_path.replace(UI_PATH_PREFIX, UI_PATH_REPLACE) if ui_path.begins_with(UI_PATH_PREFIX) else ui_path
	return _load_texture(path)


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


# 源 skillstren.lua:14 createDescBoard + :8 destroyDescBoard。点击图标 toggle 描述（源按住 board_i 显示）。
# 描述 = Skill.Description（get_skill_description）+ 成长值（get_skill_desc，黄色）。
func _toggle_skill_desc(slot: int) -> void:
	Events.bus.emit_tutorial_step(&"SUclickSkillButton")   # 源 herodetail/window.lua:1659（点技能按钮）
	if _desc_label != null and int(_desc_label.get_meta("slot", -1)) == slot:
		_hide_skill_desc()
		return
	_hide_skill_desc()
	if hero == null:
		return
	var desc: String = ReadheroSkill.get_skill_description(hero, slot + 1, cm)
	var growth: String = ReadheroSkill.get_skill_desc(hero, slot + 1, cm)
	var lbl := Label.new()
	lbl.text = desc + ("\n" + growth if not growth.is_empty() else "")
	lbl.position = SKILL_DESC_POS
	lbl.add_theme_font_size_override("font_size", 13)
	if not growth.is_empty():
		lbl.modulate = SKILL_GROWTH_COLOR
	container.add_child(lbl)
	lbl.set_meta("slot", slot)
	_desc_label = lbl


func _hide_skill_desc() -> void:
	if _desc_label != null:
		_desc_label.queue_free()
		_desc_label = null


# ---- 信号→Logic 便捷封装（调用方接信号后调，或直调）----

# 升星：hero_manager.evolve（扣碎片+金币，stars+1）。返是否成功。
func perform_evolve() -> bool:
	if hero_manager == null or hero == null:
		return false
	var ok: bool = hero_manager.evolve(hero.inst_id)
	if ok:
		AudioPlayer.play_sfx("common_hero_upgrade")   # 源 heroDetail.upgradeReply（升星回复成功，soundres.lua:223）
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
	else:
		AudioPlayer.play_sfx("common_alert")
	return ok


# 分解按钮：照源 herosplit/window.lua:88 firstConfirm popConfirmDialog 二次确认 → emit split_requested。
func _on_split_pressed() -> void:
	# 源 herosplit:97-99 firstConfirm msg 含 Unit Display Name（selectStone 碎片选择目标内联分解简化无）。
	var display_name: String = cm.get_lstr(String(cm.get_raw_table(&"Unit").get(str(hero.tid), {}).get("Display Name", "")))
	var confirm := HeroSplitConfirm.new()
	confirm.set_message("确认分解 %s？" % display_name)
	confirm.confirmed.connect(func() -> void: emit_signal("split_requested"))
	get_parent().add_child(confirm)


# 分解：hero_manager.split（移除英雄，返碎片 {fragment_id,count}）。
func perform_split() -> Dictionary:
	if hero_manager == null or hero == null:
		return {}
	return hero_manager.split(hero.inst_id)


# 装备强化：pd.enhance_equip（照源 ui/equipstrengthen + local_server：材料 Enhance Value 经验 +
# Unit Price 金币双消耗，exp 累积）。materials: {item_id:count}（玩家选材料，扣 PlayerData.items）。
# 材料选择 UI 下轮做（源独立 equipstrengthen 面板 2176 行）。
func perform_enhance(slot: int, materials: Dictionary) -> bool:
	if pd == null or hero == null:
		return false
	return pd.enhance_equip(hero.inst_id, slot, materials)


# 技能升级：pd.upgrade_hero_skill（扣技能点 + hero_manager.upgrade_skill_level 扣金币+升技能）。
func perform_upgrade_skill(idx: int) -> bool:
	if pd == null or hero == null:
		return false
	return pd.upgrade_hero_skill(hero.inst_id, idx)
