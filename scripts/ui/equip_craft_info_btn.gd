class_name EquipCraftInfoBtn
extends RefCounted

## 装备合成 infoButton/穿戴/playCraftEffect/createNeedCraftPrompt helper（View 层）— 从 EquipCraftPanel 拆出控 ≤400。
## 静态方法第一参 panel，照 EquipCraftTree 静态拆分范式。
## 源 ui/equipcraft.lua createInfoButton:610-725 + doClickInfoButton:150-173
## + putonEquip:526-561 + putonReply:562-573 + playPutonEffect:484-501 + getJudgeLevel:519-525
## + playCraftEffect:409-482 + createNeedCraftPrompt:321-366（forbidInfoButton / forbidCraftButton 颜色控制 P2）。

# ── 坐标（源 cocos 值）──
# 源 hello.lua:311 setContentScaleFactor(615/480)=1.28125：cocos sprite contentSize=纹理/CS，position 不变。
# 纯 Sprite（CCSprite / ed.createSprite 无 fix_size）→ Godot 需 EXPAND_IGNORE_SIZE + size=tex/CS 等价。
const CONTENT_SCALE: float = 1.28125
const INFO_BTN_POS: Vector2 = Vector2(147.0, 40.0)        # 源 :689 infoButton
const INFO_REMARK_POS: Vector2 = Vector2(147.0, 80.0)     # 源 :678 infoButtonRemark
const CRAFT_EFFECT_END_POS: Vector2 = Vector2(142.0, 226.0)   # 源 playCraftEffect :411
const PROMPT_OFFSET_Y: float = -20.0                     # 源 :334 y+20（y-up → GD y-down 翻）
const PROMPT_LBL_POS: Vector2 = Vector2(10.0, 12.0)
const PROMPT_BG_PATH: String = "res://assets/ui/alpha/HVGA/craft_promt_bg.png"   # 源 :331
# ── 按钮纹理（源 :686/:695 package_button 双层 Sprite）──
const INFO_BTN_RES: String = "res://assets/ui/alpha/HVGA/package_button.png"
const INFO_BTN_PRESS_RES: String = "res://assets/ui/alpha/HVGA/package_button_down.png"
# ── 颜色（源 ccc3）──
const COLOR_BROWN: Color = Color(50.0 / 255.0, 41.0 / 255.0, 31.0 / 255.0)   # 源 50,41,31
const COLOR_RED: Color = Color(1.0, 0.0, 0.0)             # 源 255,0,0（等级不足 remark）
const COLOR_GREEN: Color = Color(24.0 / 255.0, 108.0 / 255.0, 0.0)   # 源 ed.toccc3(1598976)
const COLOR_WHITE: Color = Color(1.0, 1.0, 1.0)           # 源 normalColor :10
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


# 源 getJudgeLevel :519-525：ed.canWearEquip(hid,eid) → [hlv, elv]。
static func get_judge_level(panel) -> Array:
	var hlv: int = panel.hero.level if panel.hero != null else 0
	var elv: int = int(panel.cm.get_raw_table("Equip").get(str(panel._target_id), {}).get("Level Requirement", 0))
	return [hlv, elv]


# 源 self.isEquiped：英雄该槽装备 == 合成目标（_ 前缀：GDScript static context 调用同类 static 必须 private 命名）。
static func _is_equipped(panel) -> bool:
	if panel.hero == null or panel._sid < 0 or panel._sid >= panel.hero.equip_slots.size():
		return false
	return int(panel.hero.equip_slots[panel._sid]) == panel._target_id


# 源 createInfoButton :610-725：信息按钮（context 决定文字）+ remarkText 等级需求 + 点击 doClickInfoButton。
# 重构（2026-07-17）：infoButton + infoButtonLabel + infoButtonRemark 已静态化进 equip_craft_content.tscn
# （%InfoButton + %InfoButtonLabel + %InfoRemark，位置/size 可视化）。本函数改为 fill 文字/颜色（不再建节点）。
# pressed 信号在 panel._build_content 连接（EquipCraftInfoBtn._on_info_pressed.bind(panel)）。
static func create_info_button(panel) -> void:
	var text: String = panel.cm.get_lstr(LSTR_EQUIPMENT)
	var remark_text: String = panel.cm.get_lstr(LSTR_BINDS_WHEN_EQUIPPED)
	var remark_color: Color = COLOR_GREEN   # 源 :646 ed.toccc3(1598976)
	if panel._context == "heroDetail":
		var judge: Array = get_judge_level(panel)
		if _is_equipped(panel):
			text = panel.cm.get_lstr(LSTR_CONFIRM)                    # 源 :618
			remark_text = panel.cm.get_lstr(LSTR_REQUIRED_HERO_LEVEL) % int(judge[1])
		elif panel._get_amount(panel._target_id) == 0:
			# 源 :621-625 amount==0：有配方→合成公式 / 无配方→获得途径
			if panel._get_components(panel._target_id) == 0:
				text = panel.cm.get_lstr(LSTR_WAY_TO_GET)
			else:
				text = panel.cm.get_lstr(LSTR_SYNTHESIS_FORMULA)
		if int(judge[0]) < int(judge[1]):                               # 源 :648-652 等级不足红字
			remark_text = panel.cm.get_lstr(LSTR_REQUIRED_HERO_LEVEL) % int(judge[1])
			remark_color = COLOR_RED
	else:
		# 源 :633-644 handbook：未开→合成公式/获得途径，已开→确定
		text = panel.cm.get_lstr(LSTR_CONFIRM)
		var elv: int = int(panel.cm.get_raw_table("Equip").get(str(panel._target_id), {}).get("Level Requirement", 0))
		remark_text = panel.cm.get_lstr(LSTR_REQUIRED_HERO_LEVEL) % elv  # 源 :657-658
	# fill .tscn 已建节点（源 :669-714 ui_info 等价）
	panel._info_remark.text = remark_text
	panel._info_remark.modulate = remark_color
	panel._info_button_label.text = text
	panel._info_button_label.modulate = COLOR_WHITE


# 包内工具：static func + panel 绑定（GDScript 4 static func .bind 行为稳）。
static func callable_for_panel(fn: Callable, panel) -> Callable:
	return fn.bind(panel)


# 源 doClickInfoButton :150-173：handbook→open/destroy，heroDetail amount>0→putonEquip，isEquiped→destroy。
static func _on_info_pressed(panel) -> void:
	if panel._context == "handbook":
		if not panel._is_open:
			panel._open_craft_panel()
		else:
			panel.remove_window()
		return
	if panel._get_amount(panel._target_id) > 0 and not _is_equipped(panel):
		AudioPlayer.play_sfx("common_click_feedback")   # 源 equipcraftlsr clickWearEquip :27
		puton_equip(panel)                               # 源 :162
		return
	if panel._get_amount(panel._target_id) == 0 and not _is_equipped(panel) and not panel._is_open:
		panel._open_craft_panel()                        # 源 :166
		return
	if _is_equipped(panel):
		panel.remove_window()                            # 源 :169


# 源 putonEquip :526-561 + putonReply :562-573：heroDetail 穿戴闭环。
# 本项目 HeroManager.wear_equip(inst_id, slot) 照源 main.lua:1750（从 hero_equip[tid][rank] 查目标穿），
# 不传 eid（合成目标=hero_equip 该槽应穿装备）、不校验 level/rank（合成时保证）。等级 UI 防护照源 :528。
static func puton_equip(panel) -> void:
	var judge: Array = get_judge_level(panel)
	if int(judge[0]) < int(judge[1]):
		panel._show_toast(panel.cm.get_lstr(LSTR_REQUIRED_HERO_LEVEL) % int(judge[1]))   # 源 :529
		return
	if panel.pd != null and panel.pd.hero_manager != null and panel.hero != null:
		panel.pd.hero_manager.wear_equip(panel._hid, panel._sid)   # 源 :538-541 send wear_equip
		panel.equipped_changed.emit()                              # 通知调用方刷新（HeroDetailPanel refresh_content）
	panel.remove_window()                                          # 源 putonReply :570 destroy


# 源 playPutonEffect :484-501：穿戴提示（hlv>=elv 才提示，一次性）。
# 源 puton_promt.png 闪烁动画待 Phase 4 视觉资源补齐，本项目仅记录一次性 flag（核心闭环照源）。
static func play_puton_effect(panel) -> void:
	if panel._has_play_puton_effect:
		return
	var judge: Array = get_judge_level(panel)
	if int(judge[0]) < int(judge[1]):
		return
	panel._has_play_puton_effect = true                          # 源 :500


# ===== playCraftEffect + createNeedCraftPrompt（从 panel 拆入控 ≤400）=====

# 源 playCraftEffect :409-482：合成成功动画（材料飞向终点 142,226 + refresh + 重建 + putonEffect）。
# FCA eff_UI_craft_above/below.abc 待 Phase 4 FCA UI 特效支持，本项目 Tween 实现材料飞行（核心表现）。
static func play_craft_effect(panel) -> void:
	var children: Array = panel._tree_data.get("children", [])
	if children.is_empty():
		return
	var end_pos: Vector2 = EquipCraftTree._gl(CRAFT_EFFECT_END_POS)   # 源 :411
	var node_need: Array = panel._craft_window_data.get("nodeNeed", [])
	var nodeid: Array = panel._craft_window_data.get("nodeid", [])
	for k in range(children.size()):
		var amount: int = int(node_need[k]) if k < node_need.size() else 0
		var fly_count: int = min(amount, 5)        # 源 :418 math.min(amount, 5)
		for i in range(fly_count):
			var element: Control = ReadequipIcon.create_icon(int(nodeid[k]), 0, panel.cm)
			element.scale = Vector2(EquipCraftTree.CHILD_ICON_SCALE, EquipCraftTree.CHILD_ICON_SCALE)
			element.position = (children[k] as Control).position
			panel._tree.add_child(element)
			var tw: Tween = panel.create_tween().set_parallel(false)
			tw.tween_interval(0.05 * i)            # 源 :428 dt=0.05*(i-1)
			tw.tween_property(element, "position", end_pos, 0.4).set_trans(Tween.TRANS_SINE)
			tw.tween_property(element, "modulate:a", 0.0, 0.2)
			tw.tween_callback(element.queue_free)
	panel._refresh_reply_data()                          # 源 refreshReplyData :443
	panel._show_toast(panel.cm.get_lstr(LSTR_SYNTHESIS_SUCCESS))   # 源 :450/454
	panel._create_craft_tree(panel._craft_id, true)     # 源 :444 重建合成树
	if panel._context == "heroDetail":                   # 源 :446-451 heroDetail 合成成功 → putonEffect
		play_puton_effect(panel)


# 源 createNeedCraftPrompt :321-366：lackOfComponent 时点合成按钮的提示。
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
		panel._show_toast(panel.cm.get_lstr(LSTR_NO_MATERIAL))   # 源 :364


# 源 :331-356 prompt 提示框（craft_promt_bg + Label + DelayTime 1 + FadeOut 0.5）。
static func _create_prompt_box(panel, icon_node: Control) -> void:
	var prompt_bg := TextureRect.new()
	prompt_bg.texture = load(PROMPT_BG_PATH)
	# 源 equipcraft.lua:331 ed.createSprite("craft_promt_bg.png") 无 fix_size（纯 Sprite 显示=纹理/CS）。
	# 原 PROMPT_SIZE=(180,40) 硬编码与源纹理原尺寸关系未知；改 tex/CS 等价源 sprite 显示，EXPAND_IGNORE_SIZE 让 size 生效。
	prompt_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prompt_bg.size = TexDisplaySize.display_size(PROMPT_BG_PATH)
	prompt_bg.position = (icon_node as Control).position + Vector2(0.0, PROMPT_OFFSET_Y)
	prompt_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel._tree.add_child(prompt_bg)
	var lbl := Label.new()
	lbl.text = panel.cm.get_lstr(LSTR_NEED_CRAFT_FIRST)   # 源 :338
	lbl.position = PROMPT_LBL_POS
	lbl.modulate = COLOR_BROWN
	prompt_bg.add_child(lbl)
	var tw: Tween = panel.create_tween().set_parallel(false)
	tw.tween_interval(1.0)             # 源 :345 DelayTime 1
	tw.tween_property(prompt_bg, "modulate:a", 0.0, 0.5)  # 源 :346 FadeOut 0.5
	tw.tween_callback(prompt_bg.queue_free)
