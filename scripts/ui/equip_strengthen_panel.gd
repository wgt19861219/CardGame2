class_name EquipStrengthenPanel
extends PopWindow

## 装备强化面板（View 层主类）— 照源 ui/equipstrengthen.lua（2176 行）。
## 重构拆分：装备槽/属性/经验条/cost → EquipStrengthenAtt；材料列表/网格/飘字 → EquipStrengthenMaterial；
## NPC 对话/强化动画 → EquipStrengthenAnim（static helper 照 battle_unit_combat.gd 模式，第一参 panel）。
## 本类保留：装配骨架 + select_slot 编排 + 强化流程（do_click_*/perform_*/_on_enhance_done）+ EE 接线
## + 单测访问的私有转发（_add_material/_delete_material/_do_talk/_do_speak/_hide_talk/_set_talk_text/_get_equip_pos）。
## 单机化：从 HeroDetailPanel 进（hero 已定），跳过源选英雄流程（doChangeHero:1720）。

# 主类布局/cost 按钮 const（Att/Material/Anim 各持自己的 const）
const CLOSE_BTN_POS: Vector2 = Vector2(20.0, 15.0)  # 左上角留小边（用户偏好更靠左上角）
const CLOSE_BTN_SIZE: Vector2 = Vector2(80.0, 40.0)
const CLOSE_RES: String = "res://assets/ui/alpha/HVGA/backbtn.png"
const CLOSE_PRESS_RES: String = "res://assets/ui/alpha/HVGA/backbtn-disabled.png"
const STREN_BTN_POS: Vector2 = Vector2(620.0, 540.0)     # 源 stren :666,145
const STREN_BTN_SIZE: Vector2 = Vector2(130.0, 40.0)
const FASTSTREN_BTN_POS: Vector2 = Vector2(620.0, 585.0) # 源 faststren :666,60
const FASTSTREN_BTN_SIZE: Vector2 = Vector2(130.0, 40.0)
const STREN_BTN_RES: String = "res://assets/ui/alpha/HVGA/herodetail-upgrade.png"
const STREN_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-upgrade-mask.png"
const SCALE9_CAP: Rect2 = Rect2(20.0, 20.0, 53.0, 29.0)  # 源 stren/faststren capInsets CCRectMake(20,20,53,29)
const BTN_LABEL_COLOR: Color = Color(0.918, 0.882, 0.804)  # 源 ccc3(234,225,205) 浅金
const DIAMOND_COST_POS: Vector2 = Vector2(620.0, 510.0)  # 源 rmb label :715,100
const SELECT_FADE_DUR: float = 0.2                      # 源 selectEquip:1672-1674 CCFadeTo 0.2s
# 提示文案（do_click/select/_show_hint 用；Att/Material 持各自域的）
const TEXT_LOW_QUALITY: String = "品质不足，仅绿色及以上可附魔"  # 源 selectEquip:1647
const TEXT_ADD_MATERIAL: String = "请添加材料"      # 源 doTalk:1664
const TEXT_MAX_LEVEL: String = "已满级"             # 源 doTalk:1662
const TEXT_PLEASE_ADD: String = "请添加材料，所有装备都可附魔"  # 源 selectEquip:1664
const TEXT_EXP_MAXED: String = "经验已满"           # 源 addMaterial:278
const TEXT_SUCCESS: String = "恭喜附魔成功"         # 源 doStrenReply:73
const TEXT_FAIL: String = "附魔失败"                # 源 doStrenReply:75
const TEXT_MAXED_OUT: String = "已满级，无需强化"   # 源 upFastStren:703
const TEXT_DIAMOND_SHORT: String = "钻石不足"       # 源 upFastStren:706 toRecharge 单机化
const TEXT_ENCHANT: String = "附魔"                 # 源 EQUIPSTRENGTHEN.ENCHANTING
const TEXT_ONECLICK: String = "一键附魔"            # 源 EQUIPSTRENGTHEN.ONECLICK_ENCHANTING
# --- P1-11 主背景层（源 :1995-2027 mainLayer ui_info：bg+frame+heroIcon）---
const PANEL_HEIGHT: float = 560.0   # Cocos(800×480,左下)→Godot(960×640,左上) Y 翻转基准（=源高 480 + 80 居中边距，照 battle_view_coords.gd BASE_Y）
const BG_RES: String = "res://assets/ui/alpha/HVGA/bg.jpg"
const BG_SIZE: Vector2 = Vector2(960.0, 640.0)   # 全屏背景
const FRAME_RES: String = "res://assets/ui/alpha/HVGA/equipupgrade/equipupgrade_frame.png"
const FRAME_COCOS: Vector2 = Vector2(400.0, 230.0)   # 源 :2013
const FRAME_SIZE: Vector2 = Vector2(800.0, 500.0)   # 面板主框
const HERO_ICON_RES: String = "res://assets/ui/alpha/HVGA/hero_icon_frame_1.png"
const HERO_ICON_COCOS: Vector2 = Vector2(135.0, 340.0)  # 源 :2024
const HERO_ICON_SIZE: Vector2 = Vector2(104.0, 104.0)   # readhero frame 标准

var hero: HeroInstance = null
var cm: Variant = null
var pd: PlayerData = null
var _selected_slot: int = -1
var _equip_icons: Array = []        # 6 槽 Control（源 self.equips[i]）
var _talk_container: Control = null  # 源 talkContainer（NPC 头像 + 气泡 + 文字）
var _talk_frame: NinePatchRect = null  # 源 talkui.frame（Scale9 气泡）
var _talk_label: Label = null         # 源 talkui.label（18 号对话文字）
var _npc_sprite: TextureRect = null   # 源 ui.npc（NPC 头像）
var _speak_tween: Tween = null        # 源 doSpeak CCDelayTime+CCFadeOut 序列
var _materials: Array = []          # 源 allmt：getMaterialList 过滤排序结果
var _mt_nodes: Array = []           # 源 self.mts：每 {icon,amount_label,info,add,minus}
var _addmt_info: Dictionary = {}    # 源 addmtInfo {item_id:int}
var _ori_exp: float = 0.0           # 源 oriExp
var _target_exp: float = 0.0        # 源 targetExp
var _cost_label: Label = null
var _stren_btn: Button = null           # 源 strenui.stren（普通强化按钮）
var _faststren_btn: Button = null       # 源 strenui.faststren（钻石一键满级按钮）
var _diamond_cost_label: Label = null   # 源 strenui.rmb（钻石 cost 显示）
var _pre_enhance_level: int = -1   # 强化前装备等级（缓存，供 _on_enhance_done 算升级差播 playEnhanceAnim）
var _exp_bar_tween: Tween = null   # 源 refreshExpBar updateHandler（经验条 oriExp→targetExp 缓动）
var _material_bg: NinePatchRect = null   # 源 ui.material_bg（材料区背景，doShowmbPrompt 宽窄切换）
var _material_label: Label = null        # 源 ui.material_label（材料区提示文字）


func setup_panel(p_hero: HeroInstance, p_cm: Variant, p_pd: PlayerData = null) -> void:
	hero = p_hero
	cm = p_cm
	pd = p_pd
	setup()
	_create_background()
	_create_close_button()
	EquipStrengthenAtt.show_material_bg(self, -1)   # 源 doShowmbPrompt nil → 宽背景（先建 z 底）
	EquipStrengthenAtt.show_equips(self)
	_show_hint(TEXT_ADD_MATERIAL)
	_create_stren_buttons()
	if pd != null:
		_materials = EquipStrengthenMaterial.build_material_list(self)
		EquipStrengthenMaterial.show_materials(self)
	# 源 enterScene:2172 进面板 teach EEclickHero（EE 起点）。单机化架构：从 HeroDetail 进（hero 已选），
	# 推进 EEclickHero/EEselectHero 到 EEclickEquip 等 select_slot(0) emit（架构无选英雄动作）。
	_maybe_start_ee()
	select_slot(0)   # 默认选槽 0（源 create:2163 doSelectSlot）+ emit EEclickEquip/EEopenMaterial


# 源 enterScene（equipstrengthen.lua:2170-2175）进强化面板 → teach EEclickHero（EE 链起点）。
func _maybe_start_ee() -> void:
	if pd == null or pd.tutorial_manager == null:
		return
	var tm: TutorialManager = pd.tutorial_manager
	if not (tm.is_done() and tm.steps.size() > 0 and String(tm.steps[0]) == "FTintoMain"):
		return   # FT 未完成 / 已进入 EE·SU（done）→ 不重复触发
	Events.bus.emit_tutorial_switch(Array(TutorialData.EE_STEPS))
	Events.bus.emit_tutorial_step(&"EEclickHero")    # 架构无选英雄 → 推进
	Events.bus.emit_tutorial_step(&"EEselectHero")   # 推进到 EEclickEquip 等 select_slot


# 源 :1995-2027 mainLayer ui_info：bg + frame + heroIcon（z 底层，最先 add）。
func _create_background() -> void:
	_add_bg(BG_RES, Vector2.ZERO, BG_SIZE)
	_add_bg(FRAME_RES, _cocos_center_to_topleft(FRAME_COCOS, FRAME_SIZE), FRAME_SIZE)
	_add_bg(HERO_ICON_RES, _cocos_center_to_topleft(HERO_ICON_COCOS, HERO_ICON_SIZE), HERO_ICON_SIZE)


# 源 anchor 0.5,0.5 pos=中心 → Godot Control 左上。Cocos(800×480,左下)→Godot(960×640,左上)：X+80 居中，Y 翻(PANEL_HEIGHT=560)。
func _cocos_center_to_topleft(cocos: Vector2, sz: Vector2) -> Vector2:
	return Vector2(cocos.x - sz.x * 0.5 + 80.0, PANEL_HEIGHT - cocos.y - sz.y * 0.5)


func _add_bg(path: String, pos: Vector2, sz: Vector2) -> void:
	if not ResourceLoader.exists(path):
		return
	var tr := TextureRect.new()
	tr.position = pos
	tr.size = sz
	tr.texture = load(path)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	container.add_child(tr)


func _create_close_button() -> void:
	var btn: TextureButton = UiButton.make_at(CLOSE_RES, CLOSE_PRESS_RES, CLOSE_BTN_POS)
	btn.pressed.connect(func() -> void:
		AudioPlayer.play_sfx("common_close_popup_window")   # 源 clickReturn
		remove_window())
	container.add_child(btn)


# 槽点击 handler（Att.show_equips gui_input.connect 用）。
func _make_slot_handler(slot: int) -> Callable:
	return func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			select_slot(slot)


# 源 selectEquip:1640-1680：ml==0 提示 + 6 槽 alpha 高亮 + 初始化 exp/材料状态。
func select_slot(slot: int) -> void:
	if hero == null or slot < 0 or slot >= EquipStrengthenAtt.SLOT_COUNT:
		return
	var item_id: int = int(hero.equip_slots[slot])
	if item_id <= 0:
		return   # 空槽不可选（源 :1641 容错）
	var ml: int = int(ReadequipData.get_equip_level_exp(item_id, cm)["ml"])
	if ml == 0:
		_show_hint(TEXT_LOW_QUALITY)   # 源 :1646-1648 quality 1 不可附魔
		return
	_selected_slot = slot
	Events.bus.emit_tutorial_step(&"EEclickEquip")    # 源 doClickEquip:1779（点装备槽）
	Events.bus.emit_tutorial_step(&"EEopenMaterial")  # 源 createMaterialLayer:443（selectEquip 后材料层显示）
	for i in EquipStrengthenAtt.SLOT_COUNT:
		if i < _equip_icons.size():
			# 源 selectEquip:1666-1678：icon stopAllActions + CCFadeTo 0.2s（选中 255 / 未选 75）
			var icon: Control = _equip_icons[i]
			if is_instance_valid(icon):
				var target_a: float = 1.0 if i == slot else EquipStrengthenAtt.SLOT_DIM_ALPHA
				if is_inside_tree():   # setup_panel 末尾 select_slot(0) 时面板未入树 → 直接设值
					var tw := create_tween()
					tw.tween_property(icon, "modulate:a", target_a, SELECT_FADE_DUR)
				else:
					icon.modulate.a = target_a
	_init_exp_state(slot)
	EquipStrengthenMaterial.reset_material_selection(self)
	EquipStrengthenAtt.show_equip_att(self, slot)
	EquipStrengthenAtt.show_exp_bar(self, slot)
	_add_exp(0)   # 触发预览刷新（源 selectEquip 后 refreshStrenCost）
	EquipStrengthenAtt.refresh_fast_stren_cost(self)   # 源 initStrenButton:476 rmbCost 显示
	EquipStrengthenAtt.show_material_bg(self, slot)   # 源 doShowmbPrompt(slot) → 窄背景 + label
	# 源 selectEquip:1661-1665：满级/未满级 doTalk 常驻提示
	if EquipStrengthenAtt.is_max_level_current(self):
		_show_hint_sticky(TEXT_MAX_LEVEL)
	else:
		_show_hint_sticky(TEXT_PLEASE_ADD)


# 源 createExpBar:1122 oriExp=getItemExp(slot), targetExp=oriExp。
func _init_exp_state(slot: int) -> void:
	if hero == null or slot < 0:
		_ori_exp = 0.0
		_target_exp = 0.0
		return
	_ori_exp = float(hero.equip_exp[slot])
	_target_exp = _ori_exp


# 源 addExp:1103：targetExp += exp + refreshExpBar + refreshStrenCost。
func _add_exp(exp_delta: int) -> void:
	_target_exp = max(0.0, _target_exp + float(exp_delta))
	EquipStrengthenAtt.refresh_exp_bar_preview(self)
	EquipStrengthenAtt.refresh_stren_cost(self)


# _show_hint → NPC doSpeak（源多数提示走 doSpeak 淡出）。
func _show_hint(text: String) -> void:
	EquipStrengthenAnim.do_speak(self, text)


# _show_hint_sticky → NPC doTalk（源 selectEquip:1662/1664 满级/未满级常驻提示）。
func _show_hint_sticky(text: String) -> void:
	EquipStrengthenAnim.do_talk(self, text)


func get_talk_text() -> String:
	if _talk_label == null or not is_instance_valid(_talk_label):
		return ""
	return _talk_label.text


func is_talk_visible() -> bool:
	if _talk_container == null or not is_instance_valid(_talk_container):
		return false
	return _talk_container.modulate.a > 0.0


func _clear_meta_children(meta_key: String) -> void:
	for child in container.get_children():
		if child.has_meta(meta_key):
			child.queue_free()


func get_addmt_info() -> Dictionary:
	return _addmt_info.duplicate()


# 装备强化：pd.enhance_equip（源 doClickStren:667 收集 addmtInfo→net；本项目强化按钮调）。
func perform_enhance(materials: Dictionary = {}) -> bool:
	if pd == null or hero == null or _selected_slot < 0:
		return false
	var mats: Dictionary = materials if not materials.is_empty() else _addmt_info
	return pd.enhance_equip(hero.inst_id, _selected_slot, mats)


# 源 upFastStren → PlayerData.enhance_equip_to_max（op_type=2 钻石满级）。
func perform_enhance_fast() -> bool:
	if pd == null or hero == null or _selected_slot < 0:
		return false
	return pd.enhance_equip_to_max(hero.inst_id, _selected_slot)


# 源 createStrenButton:804-1028 — 普通强化按钮 + 钻石一键满级按钮 + 钻石 cost label。
func _create_stren_buttons() -> void:
	_stren_btn = UiScale9Button.make(STREN_BTN_RES, STREN_BTN_PRESS_RES, STREN_BTN_POS, STREN_BTN_SIZE, SCALE9_CAP, TEXT_ENCHANT, BTN_LABEL_COLOR)
	_stren_btn.set_meta("stren", true)
	_stren_btn.pressed.connect(do_click_stren)
	container.add_child(_stren_btn)
	_faststren_btn = UiScale9Button.make(STREN_BTN_RES, STREN_BTN_PRESS_RES, FASTSTREN_BTN_POS, FASTSTREN_BTN_SIZE, SCALE9_CAP, TEXT_ONECLICK, BTN_LABEL_COLOR)
	_faststren_btn.set_meta("stren", true)
	_faststren_btn.pressed.connect(do_click_fast_stren)
	container.add_child(_faststren_btn)
	_diamond_cost_label = Label.new()
	_diamond_cost_label.position = DIAMOND_COST_POS
	_diamond_cost_label.set_meta("stren", true)
	container.add_child(_diamond_cost_label)


# 源 doClickStren:626-667 收集 addmtInfo → net op_type=1 → doStrenReply。
func do_click_stren() -> void:
	Events.bus.emit_tutorial_step(&"EEclickEnhance")   # 源 doClickStren:572（点击强化按钮即完成，不依赖结果）
	if pd == null or hero == null or _selected_slot < 0:
		return
	if EquipStrengthenAtt.is_max_level_target(self):
		_show_hint(TEXT_EXP_MAXED)
		return
	var mats: Dictionary = get_addmt_info()
	if mats.is_empty():
		_show_hint(TEXT_ADD_MATERIAL)   # 源 no_cost 未添加材料
		return
	_pre_enhance_level = EquipStrengthenAtt.get_slot_level(self, _selected_slot)   # 缓存强化前等级
	var ok: bool = perform_enhance(mats)
	_on_enhance_done(ok)


# 源 doClickFastStren:724-748 + upFastStren:701-722 op_type=2。
# 单机化：省 showConfirmDialog（无通用确认框组件）+ playerlimit VIP 锁（视为解锁）。
func do_click_fast_stren() -> void:
	if pd == null or hero == null or _selected_slot < 0:
		return
	if EquipStrengthenAtt.is_max_level_current(self):
		_show_hint(TEXT_MAXED_OUT)   # 源 :703
		return
	var cost: int = EquipStrengthenAtt.get_current_fast_cost(self)
	if cost <= 0:
		return
	if pd.diamond < cost:
		_show_hint(TEXT_DIAMOND_SHORT)   # 源 :706 showHandyDialog toRecharge
		return
	_pre_enhance_level = EquipStrengthenAtt.get_slot_level(self, _selected_slot)
	var ok: bool = perform_enhance_fast()
	_on_enhance_done(ok)


# 源 doStrenReply:68-84：doSpeak 成功/失败 + initmtList（重建网格）+ initStrenButton + initBar + initEquipAtt。
func _on_enhance_done(success: bool) -> void:
	_show_hint(TEXT_SUCCESS if success else TEXT_FAIL)
	if not success:
		return
	# Phase 8 EE→SU 连续（单机化）：强化成功 + EE done → switch SU（源独立 SkillUpgrade 解锁触发，无 playerlimit 故连续）
	if pd != null and pd.tutorial_manager != null:
		var tm: TutorialManager = pd.tutorial_manager
		if tm.is_done() and tm.steps.size() > 0 and String(tm.steps[0]) == "EEclickHero":
			Events.bus.emit_tutorial_switch(Array(TutorialData.SU_STEPS))
	# 源 doStrenReply:81 initHeroEquip → refreshHeroItemStar + playEnhanceAnim（升级时播星点亮）
	EquipStrengthenAnim.play_upgrade_anim(self)
	# initmtList:414：材料消耗后 items 变 → 重建材料网格（源 refreshmtList 移除 amount<=0）
	_materials = EquipStrengthenMaterial.build_material_list(self)
	EquipStrengthenMaterial.show_materials(self)
	# initBar/initStrenButton：重置 exp 状态（oriExp=targetExp=强化后新 exp）+ cost
	_init_exp_state(_selected_slot)
	EquipStrengthenMaterial.reset_material_selection(self)
	EquipStrengthenAtt.show_equip_att(self, _selected_slot)
	EquipStrengthenAtt.show_exp_bar(self, _selected_slot)
	EquipStrengthenAtt.refresh_fast_stren_cost(self)
	_add_exp(0)   # 触发金币预览刷新（无材料 → no_cost)
