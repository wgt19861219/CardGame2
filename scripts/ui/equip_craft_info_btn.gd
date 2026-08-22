class_name EquipCraftInfoBtn
extends RefCounted

## 装备合成 infoButton/穿戴/playCraftEffect/createNeedCraftPrompt helper（View 层）— 从 EquipCraftPanel 拆出控 ≤400。
## 静态方法第一参 panel，照 EquipCraftTree 静态拆分范式。
## + putonEquip:526-561 + putonReply:562-573 + playPutonEffect:484-501 + getJudgeLevel:519-525
## + playCraftEffect:409-482 + createNeedCraftPrompt:321-366（forbidInfoButton / forbidCraftButton 颜色控制 P2）。

# ── 坐标（源 cocos 值）──
# 纯 Sprite（CCSprite / ed.createSprite 无 fix_size）→ Godot 需 EXPAND_IGNORE_SIZE + size=tex/CS 等价。
const CONTENT_SCALE: float = 1.28125
const INFO_BTN_POS: Vector2 = Vector2(147.0, 40.0)
const INFO_REMARK_POS: Vector2 = Vector2(147.0, 80.0)
const CRAFT_EFFECT_END_POS: Vector2 = Vector2(142.0, 226.0)
const PROMPT_OFFSET_Y: float = -20.0
const PROMPT_LBL_POS: Vector2 = Vector2(10.0, 12.0)
const PROMPT_BG_PATH: String = "res://assets/ui/alpha/HVGA/craft_promt_bg.png"
# ── 按钮纹理（源 :686/:695 package_button 双层 Sprite）──
const INFO_BTN_RES: String = "res://assets/ui/alpha/HVGA/package_button.png"
const INFO_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/package_button_down.png"
# ── 颜色（源 ccc3）──
const COLOR_BROWN: Color = Color(50.0 / 255.0, 41.0 / 255.0, 31.0 / 255.0)
const COLOR_RED: Color = Color(1.0, 0.0, 0.0)
const COLOR_GREEN: Color = Color(24.0 / 255.0, 102.0 / 255.0, 0.0)
const COLOR_WHITE: Color = Color(1.0, 1.0, 1.0)
# ── LSTR key（源 LSTR 宏，cm.get_lstr 取实际值）──
const LSTR_EQUIPMENT: String = "EQUIPCRAFT.EQUIPMENT"
const LSTR_CONFIRM: String = "CHATCONFIG.CONFIRM"
const LSTR_WAY_TO_GET: String = "EQUIPCRAFT.WAY_TO_GET"
const LSTR_SYNTHESIS_FORMULA: String = "EQUIPCRAFT.SYNTHESIS_FORMULA"
const LSTR_BINDS_WHEN_EQUIPPED: String = "EQUIPCRAFT.BINDS_WHEN_EQUIPPED_WITH_THE_HERO"
const LSTR_REQUIRED_HERO_LEVEL: String = "EQUIPCRAFT.REQUIRED_HERO_LEVEL___D"
const LSTR_SYNTHESIS_SUCCESS: String = "EQUIPCRAFT.SYNTHESIS_SUCCESS"
const LSTR_NO_MATERIAL: String = "EQUIPCRAFT.NO_SUITABLE_MATERIAL_GO_TO_COLLECT_SOME"
const LSTR_NEED_CRAFT_FIRST: String = "EQUIPCRAFT.THIS_PIECE_OF_EQUIPMENT_NEED_TO_BE_SYNTHESIZED_FIRST"


static func get_judge_level(panel) -> Array:
	var hlv: int = panel.hero.level if panel.hero != null else 0
	var elv: int = int(panel.cm.get_raw_table("Equip").get(str(panel._target_id), {}).get("Level Requirement", 0))
	return [hlv, elv]


static func _is_equipped(panel) -> bool:
	if panel.hero == null or panel._sid < 0 or panel._sid >= panel.hero.equip_slots.size():
		return false
	return int(panel.hero.equip_slots[panel._sid]) == panel._target_id


# 重构（2026-07-17）：infoButton + infoButtonLabel + infoButtonRemark 已静态化进 equip_craft_content.tscn
# （%InfoButton + %InfoButtonLabel + %InfoRemark，位置/size 可视化）。本函数改为 fill 文字/颜色（不再建节点）。
# pressed 信号在 panel._build_content 连接（EquipCraftInfoBtn._on_info_pressed.bind(panel)）。
static func create_info_button(panel) -> void:
	var text: String = panel.cm.get_lstr(LSTR_EQUIPMENT)
	var remark_text: String = panel.cm.get_lstr(LSTR_BINDS_WHEN_EQUIPPED)
	var remark_color: Color = COLOR_GREEN
	if panel._context == "heroDetail":
		var judge: Array = get_judge_level(panel)
		if _is_equipped(panel):
			text = panel.cm.get_lstr(LSTR_CONFIRM)
			remark_text = panel.cm.get_lstr(LSTR_REQUIRED_HERO_LEVEL) % int(judge[1])
		elif panel._get_amount(panel._target_id) == 0:
			if panel._get_components(panel._target_id) == 0:
				text = panel.cm.get_lstr(LSTR_WAY_TO_GET)
			else:
				text = panel.cm.get_lstr(LSTR_SYNTHESIS_FORMULA)
		if int(judge[0]) < int(judge[1]):
			remark_text = panel.cm.get_lstr(LSTR_REQUIRED_HERO_LEVEL) % int(judge[1])
			remark_color = COLOR_RED
	else:
		text = panel.cm.get_lstr(LSTR_CONFIRM)
		var elv: int = int(panel.cm.get_raw_table("Equip").get(str(panel._target_id), {}).get("Level Requirement", 0))
		remark_text = panel.cm.get_lstr(LSTR_REQUIRED_HERO_LEVEL) % elv
	# fill .tscn 已建节点（源 :669-714 ui_info 等价）
	panel._info_remark.text = remark_text
	panel._info_remark.modulate = remark_color
	panel._info_button_label.text = text
	panel._info_button_label.modulate = COLOR_WHITE


# 包内工具：static func + panel 绑定（GDScript 4 static func .bind 行为稳）。
static func callable_for_panel(fn: Callable, panel) -> Callable:
	return fn.bind(panel)


static func _on_info_pressed(panel) -> void:
	if panel._context == "handbook":
		if not panel._is_open:
			panel._open_craft_panel()
		else:
			panel.remove_window()
		return
	if panel._get_amount(panel._target_id) > 0 and not _is_equipped(panel):
		AudioPlayer.play_sfx("common_click_feedback")
		puton_equip(panel)
		return
	if panel._get_amount(panel._target_id) == 0 and not _is_equipped(panel) and not panel._is_open:
		panel._open_craft_panel()
		return
	if _is_equipped(panel):
		panel.remove_window()


# 本项目 HeroManager.wear_equip(inst_id, slot) 照源 main.lua:1750（从 hero_equip[tid][rank] 查目标穿），
# 不传 eid（合成目标=hero_equip 该槽应穿装备）、不校验 level/rank（合成时保证）。等级 UI 防护照源 :528。
static func puton_equip(panel) -> void:
	var judge: Array = get_judge_level(panel)
	if int(judge[0]) < int(judge[1]):
		panel._show_toast(panel.cm.get_lstr(LSTR_REQUIRED_HERO_LEVEL) % int(judge[1]))
		return
	if panel.pd != null and panel.pd.hero_manager != null and panel.hero != null:
		if panel.pd.hero_manager.wear_equip(panel._hid, panel._sid):
			GameData.save()
			panel.equipped_changed.emit()                              # 通知调用方刷新（HeroDetailPanel refresh_content）
	panel.remove_window()


# 源 puton_promt.png 闪烁动画待 Phase 4 视觉资源补齐，本项目仅记录一次性 flag（核心闭环照源）。
static func play_puton_effect(panel) -> void:
	if panel._has_play_puton_effect:
		return
	var judge: Array = get_judge_level(panel)
	if int(judge[0]) < int(judge[1]):
		return
	panel._has_play_puton_effect = true


# ===== playCraftEffect + createNeedCraftPrompt（从 panel 拆入控 ≤400）=====

# FCA eff_UI_craft_above/below.abc 待 Phase 4 FCA UI 特效支持，本项目 Tween 实现材料飞行（核心表现）。
static func play_craft_effect(panel) -> void:
	var children: Array = panel._tree_data.get("children", [])
	if children.is_empty():
		return
	var end_pos: Vector2 = EquipCraftTree._gl(CRAFT_EFFECT_END_POS)
	var node_need: Array = panel._craft_window_data.get("nodeNeed", [])
	var nodeid: Array = panel._craft_window_data.get("nodeid", [])
	for k in range(children.size()):
		var amount: int = int(node_need[k]) if k < node_need.size() else 0
		var fly_count: int = min(amount, 5)
		for i in range(fly_count):
			var element: Control = ReadequipIcon.create_icon(int(nodeid[k]), 0, panel.cm)
			# 源 equipcraft.lua:420 createSmallIcon → readequip.lua:877 createIcon(id,38)
			# 飞行元素 38 点（2026-08-22 巡检订正：误用树子节点 45 档）。
			var fly_scale: float = 38.0 / (94.0 / 1.28125)
			element.scale = Vector2(fly_scale, fly_scale)
			element.position = (children[k] as Control).position
			panel._tree.add_child(element)
			var tw: Tween = panel.create_tween().set_parallel(false)
			tw.tween_interval(0.05 * i)
			tw.tween_property(element, "position", end_pos, 0.4).set_trans(Tween.TRANS_SINE)
			tw.tween_property(element, "modulate:a", 0.0, 0.2)
			tw.tween_callback(element.queue_free)
	panel._refresh_reply_data()
	panel._show_toast(panel.cm.get_lstr(LSTR_SYNTHESIS_SUCCESS))
	panel._create_craft_tree(panel._craft_id, true)
	if panel._context == "heroDetail":
		play_puton_effect(panel)


# 遍历 nodeAmount<nodeNeed 且 isCraftable 的材料 → 显示"需先合成"提示框；否则 showToast NO_MATERIAL。
static func create_need_craft_prompt(panel) -> void:
	var node_amount: Array = panel._craft_window_data.get("nodeAmount", [])
	var node_need: Array = panel._craft_window_data.get("nodeNeed", [])
	var nodeid: Array = panel._craft_window_data.get("nodeid", [])
	var children: Array = panel._tree_data.get("children", [])
	var show_need: bool = false
	for i in range(node_amount.size()):
		if int(node_amount[i]) < int(node_need[i]) and panel._is_craftable(int(nodeid[i])):
			if i < children.size() and is_instance_valid(children[i]):
				_create_prompt_box(panel, children[i])
			show_need = true
			break
	if not show_need:
		panel._show_toast(panel.cm.get_lstr(LSTR_NO_MATERIAL))


static func _create_prompt_box(panel, icon_node: Control) -> void:
	var prompt_bg := TextureRect.new()
	prompt_bg.texture = load(PROMPT_BG_PATH)
	# 原 PROMPT_SIZE=(180,40) 硬编码与源纹理原尺寸关系未知；改 tex/CS 等价源 sprite 显示，EXPAND_IGNORE_SIZE 让 size 生效。
	prompt_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prompt_bg.size = TexDisplaySize.display_size(PROMPT_BG_PATH)
	prompt_bg.position = (icon_node as Control).position + Vector2(0.0, PROMPT_OFFSET_Y)
	prompt_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel._tree.add_child(prompt_bg)
	var lbl := Label.new()
	lbl.text = panel.cm.get_lstr(LSTR_NEED_CRAFT_FIRST)
	lbl.position = PROMPT_LBL_POS
	lbl.modulate = COLOR_BROWN
	prompt_bg.add_child(lbl)
	var tw: Tween = panel.create_tween().set_parallel(false)
	tw.tween_interval(1.0)
	tw.tween_property(prompt_bg, "modulate:a", 0.0, 0.5)
	tw.tween_callback(prompt_bg.queue_free)
