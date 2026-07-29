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
# 技能升级 FCA + 飘字（源 skillstren.lua:74-124 playAttAnim）。
# FCA 在 icon ccp(32,30) 播 eff_UI_skill_level_up（:80-83）。
# 飘字 ccc3(231,206,19) 黄 + 黑描边 size 2（:96-101），从 ccp(100,35) 上浮 ccp(100,70) 后 FadeOut（:105-122）。
const SKILL_UP_FCA_RES: String = "res://assets/anim_frames/effect/eff_UI_skill_level_up.abc"
const SKILL_ATT_COLOR: Color = Color(231.0 / 255.0, 206.0 / 255.0, 19.0 / 255.0)
const SKILL_ATT_POPUP_FALLBACK: String = "技能+1"   # 源 att_anim_name 缺失时的通用文案
# 源 skillstren.lua createSkillLevelBoard :331-417：技能行金币图标（已静态化进 .tscn）+
# cost Label（getCost）+ levelAdd Label（refreshSkillAdd）。色值照源 ccc3() 0-255 → Godot 0-1。
const COST_INSUFFICIENT_COLOR: Color = Color(1.0, 0.3, 0.3)   # 源 refreshCostColor:230-241 钱不够时 cost 变红
const SKL_ADD_COLOR: Color = Color(17.0 / 255.0, 1.0, 23.0 / 255.0)   # 源 refreshSkillAdd:281-300 ccc3(17,255,23) 绿
# 技能点信息栏（源 skillstren.lua createInformationBar:476-486）：源两套 UI 动态切换，本项目简化单套。
# pre 标签色 ccc3(241,193,113) 金 + 数字色 ccc3(255,234,198) 米黄。本项目合并成单 Label 同金色。
const SKILL_POINT_PRE_COLOR: Color = Color(241.0 / 255.0, 193.0 / 255.0, 113.0 / 255.0)


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


# 技能升级特效（源 skillstren.lua:74-124 playAttAnim）：FCA 光效 + 属性飘字。
# skill_view: %TabSkillView（含 Skill{1..4}Icon）。skill_idx: 0-3（升哪槽）。
# scene_root: 提供 create_tween（须在 tree 内）。资源缺/失败静默降级（同 _add_fca 容错范式）。
# AtlasSprite 是 RefCounted 不可手动 free（GC 回收）；FcaAnimation 是 Node2D 失败需 free。
static func play_skill_upgrade_fx(skill_view: Control, skill_idx: int, scene_root: Node) -> void:
	if skill_view == null:
		return
	var icon: TextureButton = skill_view.get_node_or_null("%Skill" + str(skill_idx + 1) + "Icon") as TextureButton
	if icon == null:
		return
	# FCA 光效：源 :80-83 effect:setPosition(ccp(32,30)) → Godot icon 内 (16,15)（坐标半值适配图标 40x40）。
	if FileAccess.file_exists(SKILL_UP_FCA_RES):
		var atlas := AtlasSprite.new()
		if atlas.load_atlas_from_ani(SKILL_UP_FCA_RES):
			var fca := FcaAnimation.new()
			if fca.load_from_ani(SKILL_UP_FCA_RES.get_file().get_basename(), atlas):
				fca.position = Vector2(16.0, 15.0)
				icon.add_child(fca)
				var actions: PackedStringArray = fca.get_action_names()
				if actions.size() > 0:
					fca.play(actions[0], false)
				fca.action_finished.connect(fca.queue_free)
			else:
				fca.free()   # Node2D 不在 tree 内用 free（queue_free 需 tree 内 frame 才生效）
	# 属性飘字：源 :85-122 多个 Label（这里只发 1 个，通用文案）。
	# 位置 ccp(100,35)→(100,70) 是 icon 父坐标系（SkillXBoard 局部坐标），用 icon.get_parent() 作 host。
	if scene_root == null or not scene_root.is_inside_tree():
		return   # 测试无 tree 时不播 tween（同 create_tween 前置要求）
	var host: Node = icon.get_parent()
	if host == null or not (host is Node2D or host is Control):
		host = skill_view
	var label := Label.new()
	label.text = SKILL_ATT_POPUP_FALLBACK
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", SKILL_ATT_COLOR)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.position = Vector2(100.0, 35.0)
	label.modulate.a = 0.0   # 源 visible=false，CCCallFunc setVisible(true)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(label)
	var tw := scene_root.create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.05)   # setVisible(true)
	tw.tween_property(label, "position:y", 70.0, 0.5)   # CCMoveTo 0.5s 上浮
	tw.tween_property(label, "modulate:a", 0.0, 0.1)   # CCFadeOut 0.1s
	tw.tween_callback(label.queue_free)


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
# gold: 玩家持有金币（钱不够时 cost 变红，源 skillstren.lua refreshCostColor:230-241）
# skl_add: 装备提供的 SKL 加成（源 unit.lua:331 calculateSKLAttri：rankInfo.SKL + Σ equip.SKL + +SKL*lv；
#   源 skillstren.lua refreshSkillAdd:281-300 显示 "+N" 绿色 +N if N>0 else ""）
static func fill_skills(skill_view: Control, hero: HeroInstance, cm: Variant, skill_count: int,
		rank_color_lstr: Dictionary, skill_unlock_lstr: StringName,
		on_toggle: Callable, on_upgrade: Callable, gold: int = -1, skl_add: int = 0) -> void:
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
		var money_icon: TextureRect = skill_view.get_node_or_null("%Skill" + str(slot_idx) + "MoneyIcon") as TextureRect
		var cost_lbl: Label = skill_view.get_node_or_null("%Skill" + str(slot_idx) + "Cost") as Label
		var lvl_add_lbl: Label = skill_view.get_node_or_null("%Skill" + str(slot_idx) + "LvlAdd") as Label
		if locked:
			var color_text: String = HeroDetailAttribs.get_lstr_fallback(String(rank_color_lstr.get(unlock_rank, "")), str(unlock_rank), cm)
			lvl_lbl.text = HeroDetailAttribs.get_lstr_fallback(String(skill_unlock_lstr), "rank %s 解锁", cm) % color_text
			btn.visible = false
			if money_icon != null:
				money_icon.visible = false
			if cost_lbl != null:
				cost_lbl.visible = false
			if lvl_add_lbl != null:
				lvl_add_lbl.visible = false
		else:
			var cur_level: int = int(hero.skill_levels[i]) if i < hero.skill_levels.size() else 1
			lvl_lbl.text = "lv." + str(cur_level - init_level + 1)
			btn.visible = true
			for c in btn.pressed.get_connections():
				btn.pressed.disconnect(c.callable)
			btn.pressed.connect(on_upgrade.bind(i))
			btn.set_meta(&"skill_upgrade", true)
			_fill_skill_cost(money_icon, cost_lbl, cur_level, gold, cm)
			_fill_skill_lvl_add(lvl_add_lbl, skl_add)


# 技能点信息栏 fill（源 skillstren.lua createInformationBar:476-486）。
# 源两套 UI 动态切换：chance>0 显 timesBar（剩余点数 + 倒计时） / chance<=0 显 cdBar（购买按钮 + 倒计时）。
# 本项目简化单套：点数>0 显"剩余技能点: N"（金色） + 隐藏购买按钮；点数=0 显购买按钮 + 提示文案。
# 倒计时本项目单机化：不做定时器，仅打开面板时算一次产出（recover_skill_point）。
# 返回 int：本次 recover 补产出的点数（调用方可用于 Toast 提示，源无显式 Toast，本项目可选）。
static func fill_skill_point_bar(label: Label, buy_btn: TextureButton, pd: PlayerData) -> int:
	if label == null:
		return 0
	if pd == null:
		label.visible = false
		if buy_btn != null:
			buy_btn.visible = false
		return 0
	# 补算产出（更新 pd.skill_points；CD 300s +1，受 VIP 上限）。
	var recovered: int = pd.recover_skill_point(Time.get_unix_time_from_system())
	label.visible = true
	label.add_theme_color_override("font_color", SKILL_POINT_PRE_COLOR)
	if pd.skill_points > 0:
		label.text = "剩余技能点: " + str(pd.skill_points)
		if buy_btn != null:
			buy_btn.visible = false
	else:
		# 点数不足：显提示文案 + 购买按钮（texture 已静态化进 .tscn）。
		label.text = "技能点不足"
		if buy_btn != null:
			buy_btn.visible = true
	return recovered


# fill 单行金币图标 + cost Label（源 skillstren.lua getCost = SkillLevels[level].Price
# + refreshCostColor:230-241 钱不够时 cost 变红）。gold=-1 表示不查金币（cost 永不变红）。
static func _fill_skill_cost(money_icon: TextureRect, cost_lbl: Label, cur_level: int,
		gold: int, cm: Variant) -> void:
	if money_icon == null and cost_lbl == null:
		return
	var cost: int = _get_skill_upgrade_cost(cur_level, cm)
	var affordable: bool = gold < 0 or gold >= cost
	if money_icon != null:
		money_icon.visible = true
	if cost_lbl != null:
		cost_lbl.visible = true
		cost_lbl.text = str(cost)
		cost_lbl.modulate = Color.WHITE if affordable else COST_INSUFFICIENT_COLOR


# fill 单行 levelAdd "+N"（源 skillstren.lua refreshSkillAdd:281-300：skl_add 变化时
# setVisible + setString "+N"，色 ccc3(17,255,23) 绿）。skl_add<=0 → 隐藏。
static func _fill_skill_lvl_add(lvl_add_lbl: Label, skl_add: int) -> void:
	if lvl_add_lbl == null:
		return
	if skl_add > 0:
		lvl_add_lbl.visible = true
		lvl_add_lbl.text = "+" + str(skl_add)
		lvl_add_lbl.modulate = SKL_ADD_COLOR
	else:
		lvl_add_lbl.visible = false


# 技能升级金币消耗（照源 skillstren.lua:469 getCost = SkillLevels[level].Price）。
# level 越界 fallback 末位/首位（源 t[level] or t[#t] or t[1]）。语义对齐 HeroManager._get_skill_upgrade_cost。
static func _get_skill_upgrade_cost(cur_level: int, cm: Variant) -> int:
	if cm == null or not cm.has_method("get_raw_table"):
		return 0
	var t: Dictionary = cm.get_raw_table(&"SkillLevels")
	var entry: Dictionary = t.get(str(cur_level), {})
	if entry.is_empty():
		entry = t.get(str(t.size()), t.get("1", {}))
	return int(entry.get(&"Price", 0))


# SKL 加成（源 unit.lua:331 calculateSKLAttri：rankInfo.SKL + Σ(equip.SKL + equip.+SKL * equip.level)）。
# 估算（estimate_rank=true）时源读 E.SKL 字段，本面板非估算固定用 SKL。
# equip.level = hero.equip_exp[slot] 整数（源 hero._items[slot] level）。返回 int（源 floor）。
static func calculate_skl_bonus(hero: HeroInstance, cm: Variant) -> int:
	if hero == null or cm == null or not cm.has_method("get_raw_table"):
		return 0
	var rank_table: Dictionary = cm.get_raw_table(&"UnitRank")
	var rank_info: Dictionary = rank_table.get(str(hero.tid), {}).get(str(hero.rank), {})
	var skl: float = float(rank_info.get(&"SKL", 0))
	var equip_table: Dictionary = cm.get_raw_table(&"Equip")
	for slot in range(hero.equip_slots.size()):
		var item_id: int = int(hero.equip_slots[slot])
		if item_id <= 0:
			continue
		var eq: Dictionary = equip_table.get(str(item_id), {})
		var lv: float = float(hero.equip_exp[slot]) if slot < hero.equip_exp.size() else 0.0
		skl += float(eq.get(&"SKL", 0)) + float(eq.get(&"+SKL", 0)) * lv
	return int(skl)


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
