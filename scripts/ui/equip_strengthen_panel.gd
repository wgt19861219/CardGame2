class_name EquipStrengthenPanel
extends PopWindow

## 装备强化面板（View 层主类）— 照源 ui/equipstrengthen.lua（2176 行）。
## 拆分：属性/经验条/费用 fill → EquipStrengthenAtt；材料网格/飘字 → EquipStrengthenMaterial；
## NPC 对话/强化动画 → EquipStrengthenAnim（static helper 第一参 panel，照 battle_unit_combat.gd）。
## 本类保留：装配骨架 + select_slot 编排 + 强化流程（do_click_*/perform_*/_on_enhance_done）+ EE 接线。
## 单机化：从 HeroDetailPanel 进（hero 已定），跳过源选英雄流程（doChangeHero:1720）。
##
## 两件套范式（批 1 Task 5，2026-08-15）：静态结构全在 equip_strengthen_content.tscn
## （框架/NPC 对话/经验条/属性底板/按钮/裁剪层/槽 host，零静态节点构造）；本文件只做业务、
## 信号 connect、fill（%Xxx 取节点填动态数据）。静态色/字号走 EquipStren* variation。

# 静态 panel 层子场景（位置/size 在 .tscn 可视化）。
const CONTENT_SCENE: PackedScene = preload("res://scenes/ui/equip_strengthen_content.tscn")
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
# 换英雄三态提示（源 setHeroIcon:1765-1773 count/maxQuality/allMax 分支）
const TEXT_NO_EQUIP_KEY: String = "EQUIPSTRENGTHEN.THIS_HERO_DOE_NOT_WEAR_ANY_EQUIPMENT_PLEASE_RESELECT_HERO"
const TEXT_NO_ENCHANTABLE_KEY: String = "EQUIPSTRENGTHEN.THIS_HERO_DOESNT_HAVE_EQUIPMENT_FOR_ENHANCED_PLEASE_RESELECT_HERO"
const TEXT_ALL_MAXED_KEY: String = "EQUIPSTRENGTHEN.THIS_HERO_HAS_ALL_EQUIPMENTS_ENHANCED_TO_THE_MAXED_LEVEL_PLEASE_RESELECT_HERO"
const TEXT_PLEASE_SELECT_EQUIP_KEY: String = "EQUIPSTRENGTHEN.PLEASE_SELECT_EQUIPMENT"
const TEXT_PLEASE_SELECT_HERO_KEY: String = "EQUIPSTRENGTHEN.PLEASE_SELECT_HERO"   # 源 create:2165 未选态提示
const TEXT_SWITCH_HEROES_KEY: String = "EQUIPSTRENGTHEN.SWITCH_HEROES"   # 源 :1257 换过英雄后按钮文字

var hero: HeroInstance = null
var cm: Variant = null
var pd: PlayerData = null
var _selected_slot: int = -1
var _equip_icons: Array = []        # 6 槽 icon/空位引用（源 self.equips[i].icon）
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
var _stren_btn: Button = null
var _faststren_btn: Button = null
var _diamond_cost_label: Label = null   # %RmbLabel（源 strenui.rmb 钻石花费数字）
var _material_label: Label = null
var _pre_enhance_level: int = -1   # 强化前装备等级（缓存，供 _on_enhance_done 算升级差播 playEnhanceAnim）
var _exp_bar_tween: Tween = null
var _content: Control = null       # .tscn 根（fill 节点入口）


func setup_panel(p_hero: HeroInstance, p_cm: Variant, p_pd: PlayerData = null) -> void:
	hud_identity = "equipstrengthen"   # 源 extends basescene pushScene 无 HUD（2026-08-29 用户反馈 HUD 透叠）
	hero = p_hero
	cm = p_cm
	pd = p_pd
	setup()
	_build_content()
	EquipStrengthenAtt.show_material_bg(self, -1)
	if hero == null:
		# 源 create 未选英雄态（2026-09-08 四轮补回）：nohead 占位 + doTalk「请选择英雄」
		# （:2165），材料/装备区空（initMaterialData 在 setHeroIcon 选英雄后才跑），
		# 经验条不显示（源 createExpBar :1114-1116 空数据移除容器）
		_fill_hero_head()
		(_content.get_node("BarHost") as Control).visible = false
		_show_hint_sticky(_T(TEXT_PLEASE_SELECT_HERO_KEY))
		_maybe_start_ee()
		return
	EquipStrengthenAtt.show_equips(self)
	_show_hint(_T(TEXT_ADD_MATERIAL_KEY))
	if pd != null:
		_materials = EquipStrengthenMaterial.build_material_list(self)
		EquipStrengthenMaterial.show_materials(self)
	# 推进 EEclickHero/EEselectHero 到 EEclickEquip 等 select_slot(0) emit（架构无选英雄动作）。
	_maybe_start_ee()
	_auto_select_or_hint()   # 源 create:2163 doSelectSlot() 无参 + setHeroIcon:1765-1773 三态提示


# 绑 .tscn 静态节点 + fill 静态文案（动态数据走 helper fill 函数）。零静态节点构造。
func _build_content() -> void:
	_content = CONTENT_SCENE.instantiate() as Control
	container.add_child(_content)
	# 普通强化按钮（源 createStrenButton :899-912 label LSTR ENCHANTING）
	_stren_btn = _content.get_node("%StrenBtn") as Button
	_stren_btn.pressed.connect(do_click_stren)
	(_stren_btn.get_child(0) as Label).text = _T(TEXT_ENCHANT_KEY)
	# 一键强化按钮（源 :1009-1023 label LSTR ONECLICK_ENCHANTING）
	_faststren_btn = _content.get_node("%FastStrenBtn") as Button
	_faststren_btn.pressed.connect(do_click_fast_stren)
	(_faststren_btn.get_child(0) as Label).text = _T(TEXT_ONECLICK_KEY)
	# 钻石花费数字（源 :961-977 rmb label）
	_diamond_cost_label = _content.get_node("%RmbLabel") as Label
	# 材料区提示（源 :2126-2145 material_label）
	_material_label = _content.get_node("%MaterialLabel") as Label
	# NPC 对话三件（源 createnpcTalk :11-42，静态进 tscn）
	_talk_container = _content.get_node("%TalkContainer") as Control
	_npc_sprite = _content.get_node("%NpcSprite") as TextureRect
	_talk_frame = _content.get_node("%TalkFrame") as NinePatchRect
	_talk_label = _content.get_node("%TalkLabel") as Label
	# 返回按钮（源 doClickBack :1861）
	var close_btn: TextureButton = _content.get_node("%CloseBtn") as TextureButton
	close_btn.pressed.connect(func() -> void:
		AudioPlayer.play_sfx("common_close_popup_window")
		remove_window())
	# 6 槽 host gui_input 绑定（一次性；fill 逻辑在 EquipStrengthenAtt.show_equips）
	for i in EquipStrengthenAtt.SLOT_COUNT:
		var host: Control = _content.get_node("%EquipSlot" + str(i)) as Control
		host.gui_input.connect(_make_slot_handler(i))
	# 换英雄入口（源 doSelectHeroTouch:1830 → doChangeHero:1720）：「选择英雄」按钮（源 select_hero
	# 按钮组，2026-09-08 三轮补回可见入口）+ 点头像/名字区弹浮层（保留便利交互）
	(_content.get_node("%SelectHeroBtn") as Button).pressed.connect(_on_select_hero_btn)
	(_content.get_node("%HeroHeadHost") as Control).gui_input.connect(_on_hero_head_clicked)
	(_content.get_node("%HeroName") as Control).gui_input.connect(_on_hero_head_clicked)
	_fill_hero_head()


# 英雄头像 + 名字（源 setHeroIcon:1728-1776：readhero.createIcon 替换 heroIcon 框
# + createHeroName 名字；单机化 hero 已定 → setup 即 fill，贴图名降级 Label）。
# 换英雄重入（switch_hero）：先清宿主旧头像再挂新。
# hero==null 未选态（源 create nohead 占位）：显示 heroIcon 框 + NoHead 锁图 + 空名字。
func _fill_hero_head() -> void:
	var head_host: Control = _content.get_node("%HeroHeadHost") as Control
	for c in head_host.get_children():
		c.queue_free()
	var hero_icon: TextureRect = _content.get_node("HeroIcon") as TextureRect
	var name_lbl: Label = _content.get_node("%HeroName") as Label
	if hero == null:
		hero_icon.visible = true   # 框 + 子 NoHead 占位随显（源 nohead @ heroIcon 内 z=-1）
		name_lbl.text = ""
		return
	var head := ReadheroIcon.new()
	head.setup({"id": int(hero.tid), "rank": int(hero.rank), "stars": int(hero.stars)}, cm)
	head_host.add_child(head)   # Node2D 默认 (0,0)=Host 左上，104×104 恰铺满 Host
	hero_icon.visible = false   # 源 :1741 框被替换（NoHead 级联隐藏）
	name_lbl.text = HeroDetailFills.get_display_name(hero, cm)


func _maybe_start_ee() -> void:
	if pd == null or pd.tutorial_manager == null:
		return
	var tm: TutorialManager = pd.tutorial_manager
	if not (tm.is_done() and tm.steps.size() > 0 and String(tm.steps[0]) == "FTintoMain"):
		return   # FT 未完成 / 已进入 EE·SU（done）→ 不重复触发
	Events.bus.emit_tutorial_switch(Array(TutorialData.EE_STEPS))
	Events.bus.emit_tutorial_step(&"EEclickHero")    # 架构无选英雄 → 推进
	Events.bus.emit_tutorial_step(&"EEselectHero")   # 推进到 EEclickEquip 等 select_slot


# 初始槽选择 + 三态提示（源 create:2163 doSelectSlot() 无参 + setHeroIcon:1762-1774）。
# 源为未选态等玩家点槽；本项目便利：自动选第一个可附魔未满级槽（select_slot 内含 EE emit），
# 无可附魔装备时播源三态常驻提示引导换英雄（2026-09-08 根修「附魔锁死船长」）。
func _auto_select_or_hint() -> void:
	if hero == null:
		return
	var count: int = 0
	var max_quality: int = 0
	var all_max: bool = true
	var first_ok: int = -1
	for i in EquipStrengthenAtt.SLOT_COUNT:
		var item_id: int = int(hero.equip_slots[i])
		if item_id <= 0:
			continue
		count += 1
		var quality: int = int(cm.get_raw_table(&"Equip").get(str(item_id), {}).get("Quality", 0))
		max_quality = maxi(max_quality, quality)
		if not _slot_is_max(i):
			all_max = false
			if first_ok < 0 and int(ReadequipData.get_equip_level_exp(item_id, cm)["ml"]) > 0:
				first_ok = i
	if first_ok >= 0:
		select_slot(first_ok)
		return
	if count <= 0:
		_show_hint_sticky(_T(TEXT_NO_EQUIP_KEY))
	elif max_quality <= 1:
		_show_hint_sticky(_T(TEXT_NO_ENCHANTABLE_KEY))
	elif all_max:
		_show_hint_sticky(_T(TEXT_ALL_MAXED_KEY))
	else:
		_show_hint_sticky(_T(TEXT_PLEASE_SELECT_EQUIP_KEY))


# 单槽满级判定（源 checkMaxLevel:1306-1313；白装 le 空 total=0 恒满级，不计入 all_max 翻转）。
func _slot_is_max(slot: int) -> bool:
	var total: float = EquipStrengthenAtt.get_total_exp(self, slot)
	if total <= 0.0:
		return true
	return float(hero.equip_exp[slot]) >= total


# 「选择英雄」按钮（源 doSelectHeroTouch → doChangeHero；Button 不需要 InputEvent 判定）。
# 英雄列表=全部拥有英雄（源 selectwindow ofhero 遍历 ed.player.heroes，非仅 team）。
func _on_select_hero_btn() -> void:
	if pd == null:
		return
	var heroes: Array = []
	for h in pd.hero_manager.heroes.values():
		heroes.append(h)
	if heroes.size() <= 1:
		return   # 单英雄无需选择（源 selectwindow 列表空同理）
	var sel := EquipStrengthenHeroSelect.new("equip_strengthen_hero_select", {})
	sel.setup_panel(heroes, int(hero.inst_id) if hero != null else -1, cm, switch_hero)
	sel.show_window(self)


# 点头像/名字 → 弹 team 英雄选择浮层（源 doChangeHero:1720-1727 selectwindow(hero)）。
func _on_hero_head_clicked(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed):
		return
	_on_select_hero_btn()


# 换英雄（源 setHeroIcon:1728-1776：initMaterialData + 换头像/名 + createEquip + doSelectSlot + 三态提示）。
# :1731-1735 换过英雄后按钮文字「选择英雄」→「切换英雄」（hid 置位标记，首次切换生效）。
func switch_hero(p_hero: HeroInstance) -> void:
	if p_hero == null or (hero != null and int(p_hero.inst_id) == int(hero.inst_id)):
		return
	hero = p_hero
	_selected_slot = -1
	_addmt_info = {}
	_fill_hero_head()
	EquipStrengthenAtt.show_equips(self)
	EquipStrengthenAtt.show_material_bg(self, -1)
	if pd != null:
		_materials = EquipStrengthenMaterial.build_material_list(self)
		EquipStrengthenMaterial.show_materials(self)
		var sel_label: Label = _content.get_node("%SelectHeroBtn/SelectHeroBtnLabel") as Label
		if sel_label.text != _T(TEXT_SWITCH_HEROES_KEY):
			sel_label.text = _T(TEXT_SWITCH_HEROES_KEY)
	_auto_select_or_hint()


# 槽点击 handler（EquipSlot host gui_input.connect 用）。
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


# 清动态 fill 节点（meta 标记：att 属性行 / mt 材料格），静态 .tscn 节点不带 meta 不受影响。
func _clear_meta_children(meta_key: String) -> void:
	_clear_meta_recursive(_content, meta_key)


func _clear_meta_recursive(node: Node, meta_key: String) -> void:
	for child in node.get_children():
		if child.has_meta(meta_key):
			child.queue_free()
		_clear_meta_recursive(child, meta_key)


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
		if hero != null:
			_show_hint(_T(TEXT_PLEASE_SELECT_EQUIP_KEY))   # 无槽选中不再静默（源初始态 NPC 引导等价）
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
		if hero != null:
			_show_hint(_T(TEXT_PLEASE_SELECT_EQUIP_KEY))   # 无槽选中不再静默
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
