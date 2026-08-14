class_name EquipStrengthenPanel
extends PopWindow

## 装备强化面板（View 层主类）— 照源 ui/equipstrengthen.lua（2176 行）。
## 重构拆分：装备槽/属性/经验条/cost → EquipStrengthenAtt；材料列表/网格/飘字 → EquipStrengthenMaterial；
## NPC 对话/强化动画 → EquipStrengthenAnim（static helper 照 battle_unit_combat.gd 模式，第一参 panel）。
## 本类保留：装配骨架 + select_slot 编排 + 强化流程（do_click_*/perform_*/_on_enhance_done）+ EE 接线
## + 单测访问的私有转发（_add_material/_delete_material/_do_talk/_do_speak/_hide_talk/_set_talk_text/_get_equip_pos）。
## 单机化：从 HeroDetailPanel 进（hero 已定），跳过源选英雄流程（doChangeHero:1720）。
## Phase A 静态化（2026-07-17）：bg/frame/hero_icon/close/stren/faststren/钻石 cost label
## 从 procedural 改 instantiate equip_strengthen_content.tscn（位置/size 编辑器可视化，照 hero_detail 范式）。
## att（属性四列）/material（材料）子组件保留 procedural 挂 container（本批只静态化 panel 层）。

# 静态 panel 层子场景（位置/size 在 .tscn 可视化）。
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/equip_strengthen_content.tscn")
# Scale9 按钮样式（.tscn 普通 Button 套用，源 stren/faststren capInsets CCRectMake(20,20,53,29)）。
const STREN_BTN_RES: String = "res://assets/ui/alpha/HVGA/herodetail-upgrade.png"
const STREN_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/herodetail-upgrade-mask.png"
const SCALE9_CAP: Rect2 = Rect2(20.0, 20.0, 53.0, 29.0)
const BTN_LABEL_COLOR: Color = Color(0.918, 0.882, 0.804)
const SELECT_FADE_DUR: float = 0.2
# 提示文案 LSTR key（源 equipstrengthen.lua 各处 T(LSTR(...))，运行时 cm.get_lstr 解析为当前语言）。
# 单机化降级项：TEXT_DIAMOND_SHORT（源 upFastStren:706 showHandyDialog toRecharge 充值弹窗省略，无对应 LSTR → fallback 中文）。
const TEXT_LOW_QUALITY_KEY: String = "EQUIPSTRENGTHEN.ONLY_GREEN_AND_OVER_THE_QUALITY_OF_THE_EQUIPMENT_CAN_BE_ENCHANTED"
const TEXT_ADD_MATERIAL_KEY: String = "EQUIPSTRENGTHEN.NO_MATERIAL_ADDED"
const TEXT_MAX_LEVEL_KEY: String = "EQUIPSTRENGTHEN.YOUR_ENCHANTING_LEVEL_HAS_BEEN_MAXED_OUT"
const TEXT_PLEASE_ADD_KEY: String = "EQUIPSTRENGTHEN.PLEASE_ADD_MATERIAL_IT_CAN_BE_ADDED_TO_ALL_EQUIPMENTS"
const TEXT_EXP_MAXED_KEY: String = "EQUIPSTRENGTHEN.EXPERIENCE_MAXED_OUT"
const TEXT_SUCCESS_KEY: String = "EQUIPSTRENGTHEN.CONGRATULATIONS_ENCHANTED_SUCCESSFULLY"
const TEXT_FAIL_KEY: String = "EQUIPSTRENGTHEN.UNFORTUNATELY_ENCHANTED_FAILED"
const TEXT_ENCHANT_KEY: String = "EQUIPSTRENGTHEN.ENCHANTING"
const TEXT_ONECLICK_KEY: String = "EQUIPSTRENGTHEN.ONECLICK_ENCHANTING"
const TEXT_DIAMOND_SHORT: String = "钻石不足"   # 单机化 fallback（源 toRecharge 弹窗省略）

var hero: HeroInstance = null
var cm: Variant = null
var pd: PlayerData = null
var _selected_slot: int = -1
var _equip_icons: Array = []        # 6 槽 Control（源 self.equips[i]）
var _talk_container: Control = null
var _talk_frame: NinePatchRect = null
var _talk_label: Label = null
var _npc_sprite: TextureRect = null
var _speak_tween: Tween = null
var _materials: Array = []
var _mt_nodes: Array = []
var _addmt_info: Dictionary = {}
var _ori_exp: float = 0.0
var _target_exp: float = 0.0
var _cost_label: Label = null
var _stren_btn: Button = null
var _faststren_btn: Button = null
var _diamond_cost_label: Label = null
var _pre_enhance_level: int = -1   # 强化前装备等级（缓存，供 _on_enhance_done 算升级差播 playEnhanceAnim）
var _exp_bar_tween: Tween = null
var _material_bg: NinePatchRect = null
var _material_label: Label = null


func setup_panel(p_hero: HeroInstance, p_cm: Variant, p_pd: PlayerData = null) -> void:
	hero = p_hero
	cm = p_cm
	pd = p_pd
	setup()
	_build_content()
	EquipStrengthenAtt.show_material_bg(self, -1)
	EquipStrengthenAtt.show_equips(self)
	_show_hint(_T(TEXT_ADD_MATERIAL_KEY))
	if pd != null:
		_materials = EquipStrengthenMaterial.build_material_list(self)
		EquipStrengthenMaterial.show_materials(self)
	# 推进 EEclickHero/EEselectHero 到 EEclickEquip 等 select_slot(0) emit（架构无选英雄动作）。
	_maybe_start_ee()
	select_slot(0)   # 默认选槽 0（源 create:2163 doSelectSlot）+ emit EEclickEquip/EEopenMaterial


# Phase A：panel 层静态节点从 .tscn instantiate（bg/frame/hero_icon/close/stren/faststren/钻石 label），
# 位置/size .tscn 固化。Scale9 样式 + LSTR 文字 + 信号绑定运行时补（.tscn 普通 Button 无九宫格）。
# att/material 子组件保留 procedural 挂 container（本批只静态化 panel 层）。
func _build_content() -> void:
	var content: Control = CONTENT_SCENE.instantiate() as Control
	container.add_child(content)
	# .tscn 普通 Button 套 Scale9 StyleBoxTexture（源 herodetail-upgrade cap 20,20,53,29，照 hero_detail 范式）。
	_stren_btn = content.get_node("%StrenBtn") as Button
	UiScale9Button.apply_with_label(_stren_btn, STREN_BTN_RES, STREN_BTN_PRESS_RES, SCALE9_CAP, _T(TEXT_ENCHANT_KEY), BTN_LABEL_COLOR)
	_stren_btn.pressed.connect(do_click_stren)
	_faststren_btn = content.get_node("%FastStrenBtn") as Button
	UiScale9Button.apply_with_label(_faststren_btn, STREN_BTN_RES, STREN_BTN_PRESS_RES, SCALE9_CAP, _T(TEXT_ONECLICK_KEY), BTN_LABEL_COLOR)
	_faststren_btn.pressed.connect(do_click_fast_stren)
	_diamond_cost_label = content.get_node("%DiamondCostLabel") as Label
	var close_btn: TextureButton = content.get_node("%CloseBtn") as TextureButton
	close_btn.pressed.connect(func() -> void:
		AudioPlayer.play_sfx("common_close_popup_window")
		remove_window())


func _maybe_start_ee() -> void:
	if pd == null or pd.tutorial_manager == null:
		return
	var tm: TutorialManager = pd.tutorial_manager
	if not (tm.is_done() and tm.steps.size() > 0 and String(tm.steps[0]) == "FTintoMain"):
		return   # FT 未完成 / 已进入 EE·SU（done）→ 不重复触发
	Events.bus.emit_tutorial_switch(Array(TutorialData.EE_STEPS))
	Events.bus.emit_tutorial_step(&"EEclickHero")    # 架构无选英雄 → 推进
	Events.bus.emit_tutorial_step(&"EEselectHero")   # 推进到 EEclickEquip 等 select_slot


# 槽点击 handler（Att.show_equips gui_input.connect 用）。
func _make_slot_handler(slot: int) -> Callable:
	return func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			select_slot(slot)


func select_slot(slot: int) -> void:
	if hero == null or slot < 0 or slot >= EquipStrengthenAtt.SLOT_COUNT:
		return
	var item_id: int = int(hero.equip_slots[slot])
	if item_id <= 0:
		return   # 空槽不可选（源 :1641 容错）
	var ml: int = int(ReadequipData.get_equip_level_exp(item_id, cm)["ml"])
	if ml == 0:
		_show_hint(_T(TEXT_LOW_QUALITY_KEY))
		return
	_selected_slot = slot
	Events.bus.emit_tutorial_step(&"EEclickEquip")
	Events.bus.emit_tutorial_step(&"EEopenMaterial")
	for i in EquipStrengthenAtt.SLOT_COUNT:
		if i < _equip_icons.size():
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
	EquipStrengthenAtt.refresh_fast_stren_cost(self)
	EquipStrengthenAtt.show_material_bg(self, slot)
	if EquipStrengthenAtt.is_max_level_current(self):
		_show_hint_sticky(_T(TEXT_MAX_LEVEL_KEY))
	else:
		_show_hint_sticky(_T(TEXT_PLEASE_ADD_KEY))


func _init_exp_state(slot: int) -> void:
	if hero == null or slot < 0:
		_ori_exp = 0.0
		_target_exp = 0.0
		return
	_ori_exp = float(hero.equip_exp[slot])
	_target_exp = _ori_exp


func _add_exp(exp_delta: int) -> void:
	_target_exp = max(0.0, _target_exp + float(exp_delta))
	EquipStrengthenAtt.refresh_exp_bar_preview(self)
	EquipStrengthenAtt.refresh_stren_cost(self)


# LSTR 解析包装（源 T(LSTR(key)) 等价；cm 缺失时返空串避免 null 解引用，照 ConfigManager.get_lstr fallback 行为）。
func _T(key: String) -> String:
	if cm == null:
		return ""
	return String(cm.get_lstr(key))


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


# 装备强化：EquipCraftManager.enhance_equip（源 doClickStren:667 收集 addmtInfo→net；本项目强化按钮调）。
func perform_enhance(materials: Dictionary = {}) -> bool:
	if pd == null or hero == null or _selected_slot < 0:
		return false
	var mats: Dictionary = materials if not materials.is_empty() else _addmt_info
	return EquipCraftManager.enhance_equip(pd, hero.inst_id, _selected_slot, mats)


func perform_enhance_fast() -> bool:
	if pd == null or hero == null or _selected_slot < 0:
		return false
	return EquipCraftManager.enhance_equip_to_max(pd, hero.inst_id, _selected_slot)


func do_click_stren() -> void:
	Events.bus.emit_tutorial_step(&"EEclickEnhance")
	if pd == null or hero == null or _selected_slot < 0:
		return
	if EquipStrengthenAtt.is_max_level_target(self):
		_show_hint(_T(TEXT_EXP_MAXED_KEY))
		return
	var mats: Dictionary = get_addmt_info()
	if mats.is_empty():
		_show_hint(_T(TEXT_ADD_MATERIAL_KEY))
		return
	_pre_enhance_level = EquipStrengthenAtt.get_slot_level(self, _selected_slot)   # 缓存强化前等级
	var ok: bool = perform_enhance(mats)
	_on_enhance_done(ok)


# 单机化：省 showConfirmDialog（无通用确认框组件）+ playerlimit VIP 锁（视为解锁）。
func do_click_fast_stren() -> void:
	if pd == null or hero == null or _selected_slot < 0:
		return
	if EquipStrengthenAtt.is_max_level_current(self):
		_show_hint(_T(TEXT_MAX_LEVEL_KEY))
		return
	var cost: int = EquipStrengthenAtt.get_current_fast_cost(self)
	if cost <= 0:
		return
	if pd.diamond < cost:
		_show_hint(TEXT_DIAMOND_SHORT)
		return
	_pre_enhance_level = EquipStrengthenAtt.get_slot_level(self, _selected_slot)
	var ok: bool = perform_enhance_fast()
	_on_enhance_done(ok)


func _on_enhance_done(success: bool) -> void:
	_show_hint(_T(TEXT_SUCCESS_KEY) if success else _T(TEXT_FAIL_KEY))
	if not success:
		return
	GameData.save()
	# Phase 8 EE→SU 连续（单机化）：强化成功 + EE done → switch SU（源独立 SkillUpgrade 解锁触发，无 playerlimit 故连续）
	if pd != null and pd.tutorial_manager != null:
		var tm: TutorialManager = pd.tutorial_manager
		if tm.is_done() and tm.steps.size() > 0 and String(tm.steps[0]) == "EEclickHero":
			Events.bus.emit_tutorial_switch(Array(TutorialData.SU_STEPS))
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
