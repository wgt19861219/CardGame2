class_name EquipStrengthenAnim
extends RefCounted

## equipstrengthen NPC 对话 fill + 强化成功动画（View helper）。
## 两件套范式（批 1 Task 5，2026-08-15）：NPC 头像/气泡/对话文字静态在 content.tscn
## （%TalkContainer/%NpcSprite/%TalkFrame/%TalkLabel，panel._build_content 绑定引用）；
## 本类只做对话文本/气泡高度 fill 与显示控制（doTalk/doSpeak/hideTalk）+ 强化播放动画。
## static 方法第一参 panel，照 battle_unit_combat.gd 静态拆分。
## + 源对照：createnpcTalk:11 + doTalk:44 + doSpeak:51 + hideTalk:62 +
## initHeroEquip:1505 + playEnhanceAnim:1544 + playStarAnim:1512。

const AtlasSprite = preload("res://scripts/ui/atlas_sprite.gd")
const FcaAnimation = preload("res://scripts/ui/fca_animation.gd")

# 气泡高度（源 createnpcTalk :39-41：height=max(60, label.height+42)，宽恒 224）
const TALK_FRAME_MIN_H: float = 60.0
const TALK_FRAME_LABEL_PAD: float = 42.0
# 强化成功动画（源 playEnhanceAnim:1544 + playStarAnim:1512）：FCA eff_UI_enhance_success
# （方案 C 已落地，2026-09-08 特效根修；资源缺失时 Tween 金星降级兜底）。
const ENHANCE_FX_RES: String = "eff_UI_enhance_success"
const STAR_ANIM_DELAY: float = 0.5
const STAR_ANIM_SHOW_SCALE: float = 2.0
const STAR_ANIM_DUR: float = 0.2
const ENHANCE_FX_DUR: float = 0.4            # Tween 降级脉冲淡出时长（源 FCA 时长未知，合理估）
const ENHANCE_FX_PEAK_SCALE: float = 3.0     # Tween 降级中心金星放大峰值
const ENHANCE_FX_FALLBACK_LIFE: float = 2.0  # FCA 挂 icon 后保险寿命（防 action_finished 缺发泄漏）
const SPEAK_DELAY: float = 1.0
const SPEAK_FADE: float = 0.2
const HALF: float = 0.5


# 对话文本 fill（源 createnpcTalk :38-41 setString + 气泡高度随文字高）。
static func set_talk_text(panel, text: String) -> void:
	if panel._talk_label == null or not is_instance_valid(panel._talk_label):
		return
	panel._talk_label.text = text
	var label_h: float = float(panel._talk_label.get_combined_minimum_size().y)
	var h: float = max(TALK_FRAME_MIN_H, label_h + TALK_FRAME_LABEL_PAD)
	panel._talk_frame.offset_bottom = panel._talk_frame.offset_top + h


static func stop_speak_tween(panel) -> void:
	if panel._speak_tween != null and panel._speak_tween.is_valid():
		panel._speak_tween.kill()
	panel._speak_tween = null


# doSpeak（源 :51-60：常驻显示 1s 后淡出 0.2s）。守卫：面板未入树时 create_tween 不可用 → 仅常驻显示。
static func do_speak(panel, text: String) -> void:
	set_talk_text(panel, text)
	stop_speak_tween(panel)
	panel._talk_container.modulate.a = 1.0
	if panel.is_inside_tree():
		panel._speak_tween = panel.create_tween()
		panel._speak_tween.tween_interval(SPEAK_DELAY)
		panel._speak_tween.tween_property(panel._talk_container, "modulate:a", 0.0, SPEAK_FADE)


# doTalk（源 :44-49：常驻显示不淡出）。
static func do_talk(panel, text: String) -> void:
	set_talk_text(panel, text)
	stop_speak_tween(panel)
	panel._talk_container.modulate.a = 1.0


static func hide_talk(panel) -> void:
	if panel._talk_container == null or not is_instance_valid(panel._talk_container):
		return
	stop_speak_tween(panel)
	panel._talk_container.modulate.a = 0.0


# _pre_enhance_level<new_level（升级）才播（失败/无升级时 playStarAnim 立即 return，等价源 level<nl 守卫）。
static func play_upgrade_anim(panel) -> void:
	if panel._selected_slot < 0 or panel._selected_slot >= panel._equip_icons.size():
		return
	if panel._pre_enhance_level < 0:
		return
	var new_level: int = EquipStrengthenAtt.get_slot_level(panel, panel._selected_slot)
	if panel._pre_enhance_level >= new_level:
		return
	var icon: Control = panel._equip_icons[panel._selected_slot]
	ReadequipIcon.refresh_stars(icon, new_level)
	play_enhance_anim(panel, icon, panel._pre_enhance_level, new_level)
	panel._pre_enhance_level = -1   # 复位（一次性）


static func play_enhance_anim(panel, icon: Control, old_level: int, new_level: int) -> void:
	var stars: Array = ReadequipIcon.get_stars(icon)
	if stars.is_empty():
		return
	play_enhance_effect(panel, icon)
	for i in range(old_level, new_level):
		if i < stars.size():
			var s = stars[i].get("icon", null)
			if s != null and is_instance_valid(s):
				(s as CanvasItem).visible = false
	play_star_anim(panel, stars, old_level, new_level, true)


# 0-based index 从 start 到 eof（不含）；index>=eof 终止（源 eof<index return 的 0-based 等价）。
static func play_star_anim(panel, stars: Array, index: int, eof: int, isdelay: bool) -> void:
	if index >= eof:
		return
	if index >= stars.size():
		return
	var star: CanvasItem = stars[index].get("icon", null)
	if star == null or not is_instance_valid(star):
		return
	var osc: float = ReadequipIcon.STAR_SCALE
	var tw: Tween = panel.create_tween()
	if isdelay:
		tw.tween_interval(STAR_ANIM_DELAY)
	tw.tween_callback(func() -> void:
		if is_instance_valid(star):
			star.visible = true
			star.scale = Vector2(STAR_ANIM_SHOW_SCALE, STAR_ANIM_SHOW_SCALE))
	tw.tween_property(star, "scale", Vector2(osc, osc), STAR_ANIM_DUR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		EquipStrengthenAnim.play_star_anim(panel, stars, index + 1, eof, false))


# 源 playEnhanceAnim:1544-1553：createFcaNode("eff_UI_enhance_success") 挂 icon 中心（升
# 级时播）。路径照 battle_effect.create 范式（effect/ 子目录回退）；.abc zip 用
# FileAccess 检存在。资源缺失 → Tween 金星降级（原 2026-08-15 占位实现保留兜底）。
static func play_enhance_effect(panel, icon: Control) -> void:
	var atlas := AtlasSprite.new()
	var zip_path := "res://assets/anim_frames/" + ENHANCE_FX_RES + ".abc"
	if not FileAccess.file_exists(zip_path):
		zip_path = "res://assets/anim_frames/effect/" + ENHANCE_FX_RES + ".abc"
	if FileAccess.file_exists(zip_path) and atlas.load_atlas_from_ani(zip_path):
		var fca := FcaAnimation.new()
		if fca.load_from_ani(ENHANCE_FX_RES, atlas):
			var names := fca.get_action_names()
			var action := "Start" if fca.has_action("Start") else (names[0] if names.size() > 0 else "")
			if action == "":
				fca.free()
				_play_fallback_glow(panel, icon)
				return
			icon.add_child(fca)
			fca.position = icon.size * HALF   # 源 icon 中心锚 → Node2D 挂 Control 下 (size/2)
			fca.play(action, false)
			fca.action_finished.connect(func(_a: String) -> void:
				if is_instance_valid(fca):
					fca.queue_free())
			# 保险寿命：action_finished 不发（异常 action）时定时清理，防 icon 上特效节点泄漏
			if panel.is_inside_tree():
				var life_tw: Tween = panel.create_tween()
				life_tw.tween_interval(ENHANCE_FX_FALLBACK_LIFE)
				life_tw.tween_callback(func() -> void:
					if is_instance_valid(fca):
						fca.queue_free())
			return
	_play_fallback_glow(panel, icon)


# Tween 金星降级（资源缺失兜底）：icon 中心金星放大淡出（原占位实现）。
static func _play_fallback_glow(panel, icon: Control) -> void:
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
