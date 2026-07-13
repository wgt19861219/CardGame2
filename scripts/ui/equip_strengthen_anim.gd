class_name EquipStrengthenAnim
extends RefCounted

## equipstrengthen NPC 对话 + 强化成功动画（View helper）— 从 EquipStrengthenPanel 拆出控 ≤300。
## static 方法第一参 panel，照 battle_unit_combat.gd 静态拆分。
## 主类 _do_speak/_do_talk/_hide_talk/_set_talk_text 转发本类（单测 panel._do_speak 不变）。
## 源 ui/equipstrengthen.lua createnpcTalk:11 + doSpeak:51 + doTalk:44 + hideTalk:62
## + initHeroEquip:1505 + playEnhanceAnim:1544 + playStarAnim:1512。

# NPC 对话系统（源 :11-67 createnpcTalk/doTalk/doSpeak/hideTalk + :2148-2157 NPC 头像装配）
const NPC_RES: String = "res://assets/ui/alpha/HVGA/equipupgrade/equipupgrade_npc_head.png"
const TALK_FRAME_RES: String = "res://assets/ui/alpha/HVGA/skill_talk_bg_down.png"
const PANEL_HEIGHT: float = 640.0                          # 源 HVGA 高（cocos y 向上 → Godot y 向下 转换基准）
const NPC_POS: Vector2 = Vector2(638.0, 378.0)             # 源 cocos anchor(0,0) 左下
const TALK_FRAME_TOP: Vector2 = Vector2(645.0, 305.0)      # 源 cocos anchor(0.5,1) 顶部中心
const TALK_LABEL_TOP: Vector2 = Vector2(645.0, 282.0)      # 源 cocos anchor(0.5,1) 顶部中心
const TALK_FRAME_SIZE: Vector2 = Vector2(224.0, 76.0)      # 源 :21 setContentSize
const TALK_LABEL_WIDTH: float = 200.0                      # 源 :31 setLabelDimensions 200
const TALK_FRAME_MIN_H: float = 60.0                       # 源 :40 max(60, h)
const TALK_FRAME_LABEL_PAD: float = 42.0                   # 源 :39 label.height + 42
const TALK_CAP_LEFT: int = 30                              # 源 :20 capInsets CCRectMake(30,30,145,20)
const TALK_CAP_TOP: int = 30
const TALK_CAP_CENTER_W: int = 145
const TALK_CAP_CENTER_H: int = 20
const SPEAK_DELAY: float = 1.0                             # 源 :56 CCDelayTime 1
const SPEAK_FADE: float = 0.2                              # 源 :57 CCFadeOut 0.2
# 强化成功动画（源 playEnhanceAnim:1544 + playStarAnim:1512；FCA eff_UI_enhance_success Spine 未落地→Tween 降级）
const STAR_ANIM_DELAY: float = 0.5           # 源 :1520 CCDelayTime 0.5（首颗 isdelay）
const STAR_ANIM_SHOW_SCALE: float = 2.0      # 源 :1524 setScale(2) 显形峰值
const STAR_ANIM_DUR: float = 0.2             # 源 :1527 CCScaleTo 0.2 EaseBackIn 缩回 osc
const ENHANCE_FX_DUR: float = 0.4            # FCA 降级脉冲淡出时长（源 FCA 时长未知，合理估）
const ENHANCE_FX_PEAK_SCALE: float = 3.0     # FCA 降级中心金星放大峰值
const HALF: float = 0.5


# 源 createnpcTalk：首次建 NPC 头像 + Scale9 气泡 + Label 容器；后续仅更新文字与气泡高度。
# cocos→Godot 坐标转换：源 y 向上、anchor 多样；Godot Control y 向下、position=左上角。
static func ensure_talk_container(panel) -> void:
	if panel._talk_container != null and is_instance_valid(panel._talk_container):
		return
	panel._talk_container = Control.new()
	panel._talk_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel._talk_container.set_meta("talk", true)
	panel.container.add_child(panel._talk_container)
	# NPC 头像（源 :2148-2157 anchor 默认 (0,0) 左下）
	panel._npc_sprite = TextureRect.new()
	panel._npc_sprite.texture = load(NPC_RES)
	panel._npc_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var npc_size: Vector2 = panel._npc_sprite.texture.get_size()
	panel._npc_sprite.position = Vector2(NPC_POS.x, PANEL_HEIGHT - NPC_POS.y - npc_size.y)
	panel._talk_container.add_child(panel._npc_sprite)
	# 气泡 Scale9（源 :20-24 anchor(0.5,1) 顶部中心 224×76；capInsets 30,30,145,20）
	panel._talk_frame = NinePatchRect.new()
	panel._talk_frame.texture = load(TALK_FRAME_RES)
	panel._talk_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex_size: Vector2 = panel._talk_frame.texture.get_size()
	panel._talk_frame.patch_margin_left = TALK_CAP_LEFT
	panel._talk_frame.patch_margin_top = TALK_CAP_TOP
	panel._talk_frame.patch_margin_right = max(0, int(tex_size.x) - TALK_CAP_LEFT - TALK_CAP_CENTER_W)
	panel._talk_frame.patch_margin_bottom = max(0, int(tex_size.y) - TALK_CAP_TOP - TALK_CAP_CENTER_H)
	panel._talk_frame.size = TALK_FRAME_SIZE
	panel._talk_frame.position = Vector2(TALK_FRAME_TOP.x - TALK_FRAME_SIZE.x / 2.0, PANEL_HEIGHT - TALK_FRAME_TOP.y)
	panel._talk_container.add_child(panel._talk_frame)
	# 文字 Label（源 :26-32 anchor(0.5,1) 顶部中心，18 号，200 宽，左对齐自动换行）
	panel._talk_label = Label.new()
	panel._talk_label.add_theme_font_size_override("font_size", 18)
	panel._talk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	panel._talk_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	panel._talk_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel._talk_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel._talk_label.custom_minimum_size = Vector2(TALK_LABEL_WIDTH, 0.0)
	panel._talk_label.size = Vector2(TALK_LABEL_WIDTH, 0.0)
	panel._talk_label.position = Vector2(TALK_LABEL_TOP.x - TALK_LABEL_WIDTH / 2.0, PANEL_HEIGHT - TALK_LABEL_TOP.y)
	panel._talk_container.add_child(panel._talk_label)


# 源 createnpcTalk :38-41：setLabel + 重算气泡高度 max(60, label.height+42)。
static func set_talk_text(panel, text: String) -> void:
	ensure_talk_container(panel)
	panel._talk_label.text = text
	var label_h: float = float(panel._talk_label.get_combined_minimum_size().y)
	var h: float = max(TALK_FRAME_MIN_H, label_h + TALK_FRAME_LABEL_PAD)
	panel._talk_frame.size = Vector2(TALK_FRAME_SIZE.x, h)


static func stop_speak_tween(panel) -> void:
	if panel._speak_tween != null and panel._speak_tween.is_valid():
		panel._speak_tween.kill()
	panel._speak_tween = null


# 源 doSpeak :51-61：createnpcTalk + 不透明 + 1s 后淡出 0.2。
# 守卫：setup_panel 在 show_window 前调用（面板未入树），create_tween 需在树内 → 未入树时仅常驻显示。
static func do_speak(panel, text: String) -> void:
	set_talk_text(panel, text)
	stop_speak_tween(panel)
	panel._talk_container.modulate.a = 1.0
	if panel.is_inside_tree():
		panel._speak_tween = panel.create_tween()
		panel._speak_tween.tween_interval(SPEAK_DELAY)
		panel._speak_tween.tween_property(panel._talk_container, "modulate:a", 0.0, SPEAK_FADE)


# 源 doTalk :44-49：createnpcTalk + 不透明 + 常驻（停止淡出序列）。
static func do_talk(panel, text: String) -> void:
	set_talk_text(panel, text)
	stop_speak_tween(panel)
	panel._talk_container.modulate.a = 1.0


# 源 hideTalk :62-66：停止序列 + 透明。
static func hide_talk(panel) -> void:
	if panel._talk_container == null or not is_instance_valid(panel._talk_container):
		return
	stop_speak_tween(panel)
	panel._talk_container.modulate.a = 0.0


# 源 initHeroEquip:1505-1510：refreshHeroItemStar（refresh_stars 重建星态）+ playEnhanceAnim。
# _pre_enhance_level<new_level（升级）才播（失败/无升级时 playStarAnim 立即 return，等价源 level<nl 守卫）。
static func play_upgrade_anim(panel) -> void:
	if panel._selected_slot < 0 or panel._selected_slot >= panel._equip_icons.size():
		return
	if panel._pre_enhance_level < 0:
		return
	var new_level: int = EquipStrengthenAtt.get_slot_level(panel, panel._selected_slot)
	if panel._pre_enhance_level >= new_level:
		return   # 源 level<nl 守卫（无升级不播）
	var icon: Control = panel._equip_icons[panel._selected_slot]
	ReadequipIcon.refresh_stars(icon, new_level)   # 源 :1508 refreshHeroItemStar
	play_enhance_anim(panel, icon, panel._pre_enhance_level, new_level)   # 源 :1509
	panel._pre_enhance_level = -1   # 复位（一次性）


# 源 playEnhanceAnim:1544-1564：old_level<new_level → FCA 成功特效（icon 中心，降级 Tween）+ 隐藏新星 + playStarAnim。
static func play_enhance_anim(panel, icon: Control, old_level: int, new_level: int) -> void:
	var stars: Array = ReadequipIcon.get_stars(icon)
	if stars.is_empty():
		return
	play_enhance_effect(panel, icon)   # 源 :1554-1557 FCA eff_UI_enhance_success（降级）
	# 源 :1559-1562 隐藏新星（0-based old_level..new_level-1）
	for i in range(old_level, new_level):
		if i < stars.size():
			var s = stars[i].get("icon", null)
			if s != null and is_instance_valid(s):
				(s as CanvasItem).visible = false
	play_star_anim(panel, stars, old_level, new_level, true)   # 源 :1563（0-based 从 old_level 到 new_level）


# 源 playStarAnim:1512-1542：递归逐颗点亮（delay 0.5 首颗→scale 2 显形→0.2s EaseBackIn 缩回 osc→下一颗）。
# 0-based index 从 start 到 eof（不含）；index>=eof 终止（源 eof<index return 的 0-based 等价）。
static func play_star_anim(panel, stars: Array, index: int, eof: int, isdelay: bool) -> void:
	if index >= eof:   # 源 :1513 eof<index return
		return
	if index >= stars.size():
		return
	var star: CanvasItem = stars[index].get("icon", null)
	if star == null or not is_instance_valid(star):
		return
	var osc: float = ReadequipIcon.STAR_SCALE   # 源 :1518 getScale（0.9）
	var tw: Tween = panel.create_tween()
	if isdelay:
		tw.tween_interval(STAR_ANIM_DELAY)   # 源 :1520（首颗 isdelay）
	tw.tween_callback(func() -> void:   # 源 :1521-1526 f1 setVisible(true)+setScale(2)
		if is_instance_valid(star):
			star.visible = true
			star.scale = Vector2(STAR_ANIM_SHOW_SCALE, STAR_ANIM_SHOW_SCALE))
	tw.tween_property(star, "scale", Vector2(osc, osc), STAR_ANIM_DUR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)   # 源 :1527-1528 EaseBackIn
	tw.tween_callback(func() -> void:   # 源 :1529-1533 f2 递归
		EquipStrengthenAnim.play_star_anim(panel, stars, index + 1, eof, false))


# 源 playEnhanceAnim:1554-1557 FCA eff_UI_enhance_success（icon 中心 addFca 注册播放）。
# Spine 方案 C 未落地 → Tween 降级：icon 中心金星放大淡出（成功爆裂感，复刻铁律允许纯 Godot 适配）。
static func play_enhance_effect(panel, icon: Control) -> void:
	var tex: Texture2D = load(ReadequipIcon.STAR_BLUE_RES)
	var glow := TextureRect.new()
	if tex != null:
		glow.texture = tex
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex_size: Vector2 = tex.get_size() if tex != null else Vector2(20.0, 20.0)
	glow.position = icon.size * HALF - tex_size * HALF   # icon 中心
	glow.scale = Vector2.ZERO
	icon.add_child(glow)
	var tw: Tween = panel.create_tween()
	tw.tween_property(glow, "scale", Vector2(ENHANCE_FX_PEAK_SCALE, ENHANCE_FX_PEAK_SCALE), ENHANCE_FX_DUR * HALF).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(glow, "modulate:a", 0.0, ENHANCE_FX_DUR)
	tw.tween_callback(glow.queue_free)
