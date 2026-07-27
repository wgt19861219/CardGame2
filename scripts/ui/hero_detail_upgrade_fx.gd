class_name HeroDetailUpgradeFx
extends RefCounted

## 进阶交互视觉特效 helper（照源 herodetail/window.lua:213-228 光效 + :609-686 特效 + playAttAdditionAnim）。
## 从 hero_detail_panel.gd 抽出以控 LINT005 ≤400 行。全 static，参数化传入 base_layer/gs_label/scene_root。
## 复用范式：FCA 抄 hero_awake_panel _add_fca / 光效抄 battle_loot_view _play_shine_anim /
## 飘字抄 equip_strengthen_material play_add_exp_anim。

const UPGRADE_LIGHT_RES: String = "res://assets/ui/alpha/HVGA/hero_upgrade_button_light.png"
const UPGRADE_FCA_1: String = "res://assets/anim_frames/effect/eff_UI_hero_upgrade_1.abc"
const UPGRADE_FCA_2: String = "res://assets/anim_frames/effect/eff_UI_hero_upgrade_2.abc"
const FCA_ROOT_POS: Vector2 = Vector2(480.0, 320.0)   # 源 ccp(460,220) → Godot 近中心


# 进阶 FCA 特效（源 upgradeReply :672-685 eff_UI_hero_upgrade_1/2）。抄 hero_awake_panel _add_fca。
static func play_upgrade_effect(base_layer: Control) -> void:
	for fca_res in [UPGRADE_FCA_1, UPGRADE_FCA_2]:
		if not FileAccess.file_exists(fca_res):
			continue
		var atlas := AtlasSprite.new()
		if not atlas.load_atlas_from_ani(fca_res):
			atlas.free()
			continue
		var fca := FcaAnimation.new()
		if not fca.load_from_ani(fca_res.get_file().get_basename(), atlas):
			fca.free()
			atlas.free()
			continue
		fca.position = FCA_ROOT_POS
		base_layer.add_child(fca)
		var actions: PackedStringArray = fca.get_action_names()
		if actions.size() > 0:
			fca.play(actions[0], false)
		fca.action_finished.connect(fca.queue_free)


# GS 增量飘字（源 playAttAdditionAnim）。抄 equip_strengthen_material play_add_exp_anim。
# scene_root 提供 create_tween（Node 才有 create_tween）。
static func play_att_addition_anim(base_layer: Control, gs_label: Label, old_gs: int, new_gs: int, scene_root: Node) -> void:
	var delta: int = new_gs - old_gs
	if delta <= 0 or gs_label == null:
		return
	var label := Label.new()
	label.text = "+" + str(delta)
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = Color(0.396, 0.812, 1.0)   # 蓝 65cfff（照源 att addition 色）
	label.position = gs_label.position + Vector2(80.0, 0.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_layer.add_child(label)
	label.modulate.a = 0.0
	var tw := scene_root.create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.2)
	tw.tween_interval(0.3)
	tw.tween_property(label, "position:y", label.position.y - 40.0, 0.5)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(label.queue_free)


# 进阶按钮光效（源 createUpgradeButtonLight :213-228，可进阶时 fade 循环闪烁）。
# 抄 battle_loot_view _play_shine_anim。返 {light, tween} 供调用方持有（退出时 kill）。
static func refresh_upgrade_light(base_layer: Control, btn: Button, can_upgrade: bool, scene_root: Node,
		prev_light: Sprite2D, prev_tween: Tween) -> Dictionary:
	if can_upgrade and prev_light == null:
		var light := Sprite2D.new()
		light.texture = load(UPGRADE_LIGHT_RES) as Texture2D
		light.centered = true
		light.position = btn.size * 0.5
		light.z_index = 1
		btn.add_child(light)
		var tween := scene_root.create_tween().set_loops()
		tween.tween_property(light, "modulate:a", 1.0, 0.5)
		tween.tween_property(light, "modulate:a", 0.0, 0.5)
		return {"light": light, "tween": tween}
	if not can_upgrade and prev_light != null:
		if prev_tween != null and prev_tween.is_valid():
			prev_tween.kill()
		prev_light.queue_free()
		return {"light": null, "tween": null}
	return {"light": prev_light, "tween": prev_tween}


# 技能 fill（从 hero_detail_panel._fill_skills 抽出控 LINT005）。
# rank_color_lstr: Dictionary（RANK_COLOR_LSTR） / skill_unlock_lstr: StringName
# on_toggle / on_upgrade: Callable（技能图标点击 / 升级按钮点击回调，参数 idx）
static func fill_skills(skill_view: Control, hero: HeroInstance, cm: Variant, skill_count: int,
		rank_color_lstr: Dictionary, skill_unlock_lstr: StringName,
		on_toggle: Callable, on_upgrade: Callable) -> void:
	if hero == null:
		return
	var sg: Dictionary = cm.get_raw_table(&"SkillGroup").get(str(hero.tid), {})
	for i in skill_count:
		var slot_info: Dictionary = sg.get(str(i + 1), {})
		var display_name: String = cm.get_lstr(String(slot_info.get("Display Name", "skill" + str(i + 1))))
		var init_level: int = int(slot_info.get("Init Level", 1))
		var unlock_rank: int = int(slot_info.get("Unlock", 1))
		var icon_res: String = String(slot_info.get("Icon", ""))
		var locked: bool = hero.rank < unlock_rank
		var slot_idx: int = i + 1
		var icon_btn: TextureButton = skill_view.get_node("%Skill" + str(slot_idx) + "Icon") as TextureButton
		var icon_tex: Texture2D = HeroDetailTabs.load_skill_icon(icon_res)
		if icon_tex != null:
			icon_btn.texture_normal = icon_tex
			icon_btn.texture_hover = icon_tex
		icon_btn.modulate = HeroDetailTabs.SKILL_GRAY_MODULATE if locked else Color.WHITE
		icon_btn.set_meta(&"skill_icon", true)
		for c in icon_btn.pressed.get_connections():
			icon_btn.pressed.disconnect(c.callable)
		icon_btn.pressed.connect(on_toggle.bind(i))
		var frame: TextureRect = skill_view.get_node("%Skill" + str(slot_idx) + "Frame") as TextureRect
		frame.modulate = HeroDetailTabs.SKILL_GRAY_MODULATE if locked else Color.WHITE
		var name_lbl: Label = skill_view.get_node("%Skill" + str(slot_idx) + "Name") as Label
		name_lbl.text = display_name
		var lvl_lbl: Label = skill_view.get_node("%Skill" + str(slot_idx) + "Lvl") as Label
		var btn: TextureButton = skill_view.get_node("%Skill" + str(slot_idx) + "Btn") as TextureButton
		if locked:
			var color_text: String = HeroDetailAttribs.get_lstr_fallback(String(rank_color_lstr.get(unlock_rank, "")), str(unlock_rank), cm)
			lvl_lbl.text = HeroDetailAttribs.get_lstr_fallback(String(skill_unlock_lstr), "rank %s 解锁", cm) % color_text
			btn.visible = false
		else:
			var cur_level: int = int(hero.skill_levels[i]) if i < hero.skill_levels.size() else 1
			lvl_lbl.text = "lv." + str(cur_level - init_level + 1)
			btn.visible = true
			for c in btn.pressed.get_connections():
				btn.pressed.disconnect(c.callable)
			btn.pressed.connect(on_upgrade.bind(i))
			btn.set_meta(&"skill_upgrade", true)


# 觉醒按钮设置（从 hero_detail_panel._setup_awake_button 抽出）。
# on_awake: Callable（觉醒按钮点击回调）。awake_lstr/awake_fallback: 文案。
static func setup_awake_button(base_layer: Control, hero: HeroInstance, cm: Variant,
		awake_lstr: StringName, awake_fallback: String, on_awake: Callable) -> void:
	var awake_btn: BaseButton = base_layer.get_node_or_null("%AwakeBtn") as BaseButton
	if awake_btn == null:
		return
	var can_show: bool = hero != null and not hero.awake and cm != null and cm.get_bool(&"Unit", int(hero.tid), &"Can Awake")
	awake_btn.visible = can_show
	if not can_show:
		return
	if awake_btn is Button:
		HeroDetailBuilder._apply_detail_style(awake_btn as Button)
		var lbl: Label = awake_btn.get_node_or_null("%AwakeLabel") as Label
		if lbl != null:
			lbl.text = String(cm.get_lstr(awake_lstr)) if cm != null and cm.has_method("get_lstr") else awake_fallback
			if lbl.text == String(awake_lstr):
				lbl.text = awake_fallback
	awake_btn.pressed.connect(func() -> void:
		AudioPlayer.play_sfx("common_click_feedback")
		on_awake.call())
