class_name HeroDetailEvolveFx
extends RefCounted

## 灵魂石进化（升星）表现链 helper（照源 herodetail/window.lua doEvolveReply :783-816 补译）：
## 双 FCA（back/front）+ 21 属性差值多条飘字 + 英雄欢呼 + back 播完弹成长公告窗。
## 与 HeroDetailUpgradeFx（装备进阶 rank）并列；全 static，特效节点统一挂 panel 根
## （fx_host）——refresh_content 的 deferred 重建会 free BaseLayer 子树，挂根才存活
## （upgrade FCA 同范式；飘字源挂 self.container 根容器同理不被源重建波及）。

const EVOLVE_FCA_BACK: String = "res://assets/anim_frames/effect/eff_UI_herodetail_evolution_back.abc"
const EVOLVE_FCA_FRONT: String = "res://assets/anim_frames/effect/eff_UI_herodetail_evolution_front.abc"
# 源 doEvolveReply rootPos ccp(395,255) - createHeroFca ccp(400,265) = cocos(-5,-10)
# → godot(-5,+10)。英雄锚点运行时推导（详情 tab 右移 140 时自动跟随）复用 upgrade 范式。
const EVOLVE_POS_DELTA: Vector2 = Vector2(-5.0, 10.0)
# 源 back 默认层 / front addChild(...,115) → godot z_index 100/115（内容层 z=2~16）。
const BACK_Z_INDEX: int = 100
const FRONT_Z_INDEX: int = 115
# 飘字（源 playAttAdditionAnim :79-134）：绿 ccc3(0,255,0) 黑描边 2 号 20，
# 起点 ccp(395,390) → 上浮 ccp(395,440)（panel 根 800×480 坐标系，to_godot y=480-y）。
const ATT_ANIM_START: Vector2 = Vector2(395.0, 90.0)
const ATT_ANIM_END_Y: float = 40.0
const ATT_STAGGER: float = 0.4
const ATT_FLOAT_DURATION: float = 0.8
const ATT_COLOR: Color = Color(0.0, 1.0, 0.0)
const ATT_FONT_SIZE: int = 20


# 进化双 FCA 特效（源 :805-811）：back 播完触发 on_back_finished（源 registerEvolveAnim
# 等 back isTerminated 后 announce），两个都播完自毁；资源缺静默降级（同 _add_fca 容错）。
static func play_evolve_effect(fx_host: Control, on_back_finished: Callable) -> void:
	for pair in [[EVOLVE_FCA_BACK, BACK_Z_INDEX, true], [EVOLVE_FCA_FRONT, FRONT_Z_INDEX, false]]:
		var res_path: String = pair[0]
		if not FileAccess.file_exists(res_path):
			continue
		var atlas := AtlasSprite.new()
		if not atlas.load_atlas_from_ani(res_path):
			continue
		var fca := FcaAnimation.new()
		if not fca.load_from_ani(res_path.get_file().get_basename(), atlas):
			fca.free()
			continue
		fca.position = HeroDetailUpgradeFx._hero_anchor_on(fx_host) + EVOLVE_POS_DELTA
		fca.z_index = int(pair[1])
		fca.set_additive_blend()   # 源 C++ FCA 加色合成（upgrade 同款，A/B 实机定谳）
		fx_host.add_child(fca)
		var is_back: bool = bool(pair[2])
		if is_back:
			fca.action_finished.connect(func(_a: String) -> void: on_back_finished.call())
		var actions: PackedStringArray = fca.get_action_names()
		if actions.size() > 0:
			fca.play(actions[0], false)
		fca.action_finished.connect(func(_a: String) -> void: fca.queue_free())   # 信号带 action 参数，直连 queue_free 报参数数不匹配（实机 2026-09-13 抓获）


# 21 属性差值飘字（源 getAttChanged :60-77 + playAttAdditionAnim :79-134）：
# att_before/att_after 为 ReadheroAttribs.get_hero_att_by_hero 输出（{key:{base,add}}），
# 差值 = (base+add) 差（源 badd+aadd 合并口径）。每条交错 0.4s，0.8s 上浮淡出。
# 挂 fx_host（panel 根）不随 refresh_content 重建；scene_root 提供 create_tween。
static func play_att_multi_anim(fx_host: Control, att_before: Dictionary, att_after: Dictionary,
		cm: Variant, scene_root: Node) -> void:
	if scene_root == null or not scene_root.is_inside_tree():
		return   # 测试无 tree 时不播 tween（同 upgrade 飘字前置要求）
	var index: int = 0
	for key in HeroDetailAttribs.DISPLAY_ATTRIBS:
		var add: int = _att_delta(att_before, att_after, String(key))
		if add <= 0:
			continue
		var label := Label.new()
		var name_text: String = HeroDetailAttribs.get_lstr_fallback(
			String(HeroDetailAttribs.ATTR_PRE_LSTR.get(key, "")), String(key), cm)
		label.text = name_text + "+" + str(add)
		label.add_theme_font_size_override("font_size", ATT_FONT_SIZE)
		label.add_theme_color_override("font_color", ATT_COLOR)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 2)
		label.position = ATT_ANIM_START
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = BACK_Z_INDEX
		label.modulate.a = 0.0   # 源 visible=false → alpha 表达「不可见」，交错延迟后渐显（等价 setVisible(true)）
		fx_host.add_child(label)
		var tw := scene_root.create_tween()
		tw.tween_interval(ATT_STAGGER * index)
		tw.tween_property(label, "modulate:a", 1.0, 0.05)
		tw.tween_property(label, "position:y", ATT_ANIM_END_Y, ATT_FLOAT_DURATION)
		tw.parallel().tween_property(label, "modulate:a", 0.0, ATT_FLOAT_DURATION)
		tw.tween_callback(label.queue_free)
		index += 1


# 进化成功整条表现链（源 doEvolveReply :789-816 收口）。欢呼走 upgrade 同款两帧延迟
# （refresh_content 的 deferred 重建跑完后落在重建后的立绘上）；on_announce 在 back FCA
# 播完时回调（源 announce heroEvolve 成长公告窗）。
static func play_evolve_success_sequence(fx_host: Control, att_before: Dictionary,
		cm: Variant, on_announce: Callable) -> void:
	play_evolve_effect(fx_host, on_announce)
	play_att_multi_anim(fx_host, att_before, ReadheroAttribs.get_hero_att_by_hero(
		_hero_of(fx_host), cm), cm, fx_host)
	if not fx_host.is_inside_tree():
		return   # 宿主不在树内（单测直调）：get_tree() 会推引擎 ERROR，跳过欢呼帧延迟
	var tree := fx_host.get_tree()
	var weak_host: WeakRef = weakref(fx_host)   # 弱引用：宿主 remove_window 后帧回调晚到不推引擎 ERROR
	var cheer := func() -> void:
		var host := weak_host.get_ref() as Control
		if host == null:
			return
		var portrait: Control = host.find_child("PortraitHost", true, false)
		HeroDetailUpgradeFx.play_hero_cheer(portrait)
	tree.process_frame.connect(func() -> void:
		tree.process_frame.connect(cheer, CONNECT_ONE_SHOT), CONNECT_ONE_SHOT)


# 进化全链（panel 薄壳转调，控 panel LINT005 行数）：扣碎片金币升星 + 音效/存档 +
# 表现链（源 doEvolveHandler/doEvolveReply :762-816 单机化收口）。
static func perform_evolve(panel: HeroDetailPanel) -> bool:
	if panel.hero_manager == null or panel.hero == null:
		return false
	var att_before: Dictionary = ReadheroAttribs.get_hero_att_by_hero(panel.hero, panel.cm) \
		if panel.cm != null else {}
	var ok: bool = panel.hero_manager.evolve(panel.hero.inst_id)
	if not ok:
		AudioPlayer.play_sfx("common_alert")   # heroDetail.clickDisabledUpgrade（条件不满足拒，soundres.lua:216）
		return false
	AudioPlayer.play_sfx("common_hero_upgrade")   # heroDetail.upgradeReply（升星回复成功，soundres.lua:223）
	GameData.save()   # 照源 main.lua:1991 evolve 回复后即时存（升星扣碎片+金币）
	play_evolve_success_sequence(panel, att_before, panel.cm, func() -> void:
		_show_evolve_announce(panel, att_before))
	return true


# 成长公告窗（源 registerEvolveAnim 等 back FCA 播完 → ed.announce heroEvolve）。
# 挂 panel.get_parent()（与 equip_craft 同宿主，后加盖 detail 之上）。
static func _show_evolve_announce(panel: HeroDetailPanel, att_before: Dictionary) -> void:
	if panel.hero == null:
		return
	var att_after: Dictionary = ReadheroAttribs.get_hero_att_by_hero(panel.hero, panel.cm) \
		if panel.cm != null else {}
	var delta: Dictionary = {}
	for key in HeroDetailAttribs.DISPLAY_ATTRIBS:
		var d: int = _att_delta(att_before, att_after, String(key))
		if d > 0:
			delta[String(key)] = d
	HeroEvolveAnnounce.show_announce(panel.get_parent(), panel.hero, delta, panel.cm)


# 属性差值（源 getAttChanged badd+aadd）：缺键按 0 计（进化前后键集一致，防御口径）。
static func _att_delta(att_before: Dictionary, att_after: Dictionary, key: String) -> int:
	var nv: Dictionary = att_after.get(key, {})
	var pv: Dictionary = att_before.get(key, {})
	var badd: int = int(nv.get("base", 0)) - int(pv.get("base", 0))
	var aadd: int = int(nv.get("add", 0)) - int(pv.get("add", 0))
	return badd + aadd


# 从 panel 根取 hero（飘字算差值需要进化后属性；取不到返 null 由 get_hero_att_by_hero 容错）。
static func _hero_of(fx_host: Control) -> HeroInstance:
	var panel := fx_host as HeroDetailPanel
	return panel.hero if panel != null else null
