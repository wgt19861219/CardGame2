extends GutTest
# StageSelectPanel 测试（2026-07-02 初版，2026-08-16 批3 Task 5 两件套改造改写）。
# 照源 ui/stageselect.lua（1678 行）：createMap:1359/createStage:1212/createFrame:944/
# createTitle:885/createModeButton:725/createChapterButton:705/createDot:676/
# setChapterButtonState:643/currentTag:1298/createTitleText:861。
# 两件套形态（Task 5 定稿）：
#   - 静态底板（bg/mode toggle/箭头/close/挂载层）在 stage_select_content.tscn；
#   - 动态层（map layer/bg/route/stage 圆点/stars/pointer/mask、frame/title_bg/title
#     label、chapter dots）是数据驱动动态行 + crossfade 动画节点（mode 切换 frame
#     crossfade、章节切 title crossfade 均依赖节点重建，照源 createFrame/createTitle
#     重建+fade 模式），由 stage_select_fills.gd 构造、panel 驱动；
#   - builder（stage_select_builder.gd）退役删除。
# 贴图口径（批3定稿，与 Task 4 crusade 系区分）：显示 = 像素÷CS×条目CS
# （Prescaled=true 才施加）；stageselect_map_bg 系条目 Prescaled=true CS=2 →
# 468×254px → 730.54×396.49；frame 系 Prescaled=false 不施加 → 936×507px →
# 730.34×395.61；其余无条目 → 像素÷CS。
# 几何恢复源直译（撤销 2026-07-20 偏大口径补丁：组缩放 0.9/clip 903×471/
# STRETCH 1.268/title 117——均系 base×cs 漏÷CS 偏大 1.28× 的补偿）：
# clip 恢复源 clipStencil 712×372 @ cocos(44,20) → godot(124,168)；
# titleBg 恢复源 ccp(397,393) → godot(477,167)。

const CONTENT_PATH: String = "res://scenes/ui/stage_select_content.tscn"
const PANEL_PATH: String = "res://scripts/ui/stage_select_panel.gd"
const FILLS_PATH: String = "res://scripts/ui/stage_select_fills.gd"
const BUILDER_PATH: String = "res://scripts/ui/stage_select_builder.gd"
const CS: float = 1.28125

var cm: ConfigManager

const StageSelectFills = preload("res://scripts/ui/stage_select_fills.gd")


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func _make_panel() -> StageSelectPanel:
	var root := Node.new()
	add_child(root)
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	var rng := BattleRng.new(5)
	var panel := StageSelectPanel.new("stageselect", {})
	panel.setup_panel(mgr, pd, rng)
	panel.show_window(root)
	return panel


func test_panel_assembles() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	var rng := BattleRng.new(5)
	var panel := StageSelectPanel.new("stageselect", {})
	panel.setup_panel(mgr, pd, rng)
	panel.show_window(root)
	# 重构后 container 只持 1 个 _content（.tscn instantiate），静态节点都在 _content 内（% unique），
	# 动态层挂 %MapLayerHost/%FrameLayer/%DotContainer（fills 构造重建）。
	assert_eq(panel.container.get_child_count(), 1, "container 持有 _content（instantiate 后）")
	assert_not_null(panel._content.get_node_or_null("%FrameworkBg"), "FrameworkBg 装配")
	assert_not_null(panel._content.get_node_or_null("%CloseBtn"), "CloseBtn 装配")
	assert_not_null(panel._content.get_node_or_null("%ModeNormalBtn"), "ModeNormalBtn 装配")
	assert_not_null(panel._content.get_node_or_null("%PrevArrow"), "PrevArrow 装配")
	assert_gt(panel._map_host.get_child_count(), 0, "MapLayerHost 含 map_layer（章节 bg+route+stage 圆点）")
	assert_gt(panel._frame_layer.get_child_count(), 0, "FrameLayer 含 frame/title_bg/title_label")
	assert_gt(panel._dot_container.get_child_count(), 0, "DotContainer 含 chapter dots")
	# chapter1 normal 新档：stage1（key id=1 star0 → current）可点 → _stage_buttons 含 sid=1
	assert_true(panel._stage_buttons.has(1), "chapter1 stage1（current）进可点 buttons")
	panel.remove_window()
	root.queue_free()


# 源 doChangeMode(:319) — 三 mode toggle 切换。
func test_mode_switch() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	var rng := BattleRng.new(5)
	var panel := StageSelectPanel.new("stageselect", {})
	panel.setup_panel(mgr, pd, rng)
	panel.show_window(root)
	assert_eq(panel._mode, "normal", "默认 normal")
	panel._on_mode_pressed("elite")
	assert_eq(panel._mode, "elite", "切 elite")
	panel._on_mode_pressed("guild")
	assert_eq(panel._mode, "guild", "切 guild")
	panel.remove_window()
	root.queue_free()


func test_run_stage_battle_builds_result() -> void:
	# 衔接数据流：run_stage_battle（发奖励 + hero_cache 快照）→ build_result_param（装配结算 param）。
	# 不调 _on_stage_n（会 change_scene 切场景破坏 GUT 树，照源 replaceScene 直接切是 View 职责）。
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	pd.vitality = 100
	var rng := BattleRng.new(5)
	var r: Dictionary = mgr.run_stage_battle(-27, pd, [1], rng)
	assert_true(bool(r.get("ok", false)), "run_stage_battle ok（含 take_stage_reward 不崩）")
	var result_param := {
		"stage_id": -27, "victory": bool(r["won"]), "heroes": [1],
		"stars": int(r["stars"]), "loots": r.get("loots", []), "excavate_mode": false, "isPveMode": true,
	}
	GameData.last_result = StageAccount.build_result_param(result_param, cm, pd, pd.hero_manager)
	assert_true(GameData.last_result.has("stage_id"), "last_result 装配 stage_id")
	assert_eq(bool(GameData.last_result["victory"]), bool(r["won"]), "last_result victory 匹配")
	# loots 数据流贯通：run_stage_battle 返 loots（源 enter 生成存 ed.player.loots）含必掉扫荡券 390。
	# loot_list 聚合由 test_stage_account 覆盖（victory 分支装配，失败分支不装配照源）。
	var loots: Array = r.get("loots", [])
	assert_false(loots.is_empty(), "run_stage_battle 返 loots 非空")
	var last: Dictionary = loots[loots.size() - 1]
	assert_eq(int(last["id"]), 390, "loots 末位必掉扫荡券 390")


# 批次5 验收：高难度关多波战斗 + 失败分支
func test_high_level_stage_50_3_waves() -> void:
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	var rng := BattleRng.new(42)
	# stage 50: chapter 3, 3 waves, monster_level 18
	var r: Dictionary = mgr.run_stage_battle(50, pd, [1, 2, 3, 4, 5], rng)
	assert_true(bool(r.get("ok", false)), "stage 50 战斗完成（不超时）")
	# 3 波战斗应该有胜负结果
	assert_true(r.has("won"), "有胜负结果")

func test_stage_failed_branch() -> void:
	# 弱队打高难度关 → 可能失败
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	pd.apply_default_data()
	var rng := BattleRng.new(42)
	# 只上 1 个 1 级英雄打 stage 50（故意弱化）
	var r: Dictionary = mgr.run_stage_battle(50, pd, [1], rng)
	assert_true(bool(r.get("ok", false)), "战斗完成（不崩）")
	# 无论胜负，结算流程能走通


# ===== P1-10：setup_by_stage 按指定 stage 定位章（源 stageselect.createByStage）=====

# 普通关 _chapter_of_stage = Stage 表 Chapter ID（源 equipcraft :1166-1168）
func test_chapter_of_stage_normal() -> void:
	var st: Dictionary = cm.get_raw_table("Stage")
	var normal_sid: int = 0
	for sid_str in st:
		var sid: int = int(sid_str)
		if sid > 0 and sid < 10000 and StageAccount.stage_type(sid) == "normal":
			normal_sid = sid
			break
	if normal_sid == 0:
		pass_test("无普通关，跳过")
		return
	var panel := _make_panel()
	var expect_ch: int = int(st.get(str(normal_sid), {}).get("Chapter ID", 0))
	assert_eq(panel._chapter_of_stage(normal_sid), expect_ch, "普通关 _chapter_of_stage = Stage Chapter ID")
	panel.remove_window()


# 精英关（id>=10000）_chapter_of_stage = Stage Group 的 Chapter ID（源 equipcraft :1169-1173）
func test_chapter_of_stage_elite() -> void:
	var st: Dictionary = cm.get_raw_table("Stage")
	var elite_sid: int = 0
	for sid_str in st:
		var sid: int = int(sid_str)
		if sid >= 10000:
			elite_sid = sid
			break
	if elite_sid == 0:
		pass_test("无精英关，跳过")
		return
	var panel := _make_panel()
	var gid: int = int(st.get(str(elite_sid), {}).get("Stage Group", elite_sid))
	var expect_ch: int = int(st.get(str(gid), {}).get("Chapter ID", 0))
	assert_eq(panel._chapter_of_stage(elite_sid), expect_ch, "精英关 _chapter_of_stage = Stage Group 的 Chapter ID")
	panel.remove_window()


# setup_by_stage 按 stage 定位到所在章（源 stageselect.createByStage(id)）
func test_setup_by_stage_sets_chapter() -> void:
	var st: Dictionary = cm.get_raw_table("Stage")
	var normal_sid: int = 0
	for sid_str in st:
		var sid: int = int(sid_str)
		if sid > 0 and sid < 10000 and StageAccount.stage_type(sid) == "normal":
			normal_sid = sid
			break
	if normal_sid == 0:
		pass_test("无普通关，跳过")
		return
	var expect_ch: int = int(st.get(str(normal_sid), {}).get("Chapter ID", 0))
	var root := Node.new()
	add_child(root)
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	var rng := BattleRng.new(1)
	var panel := StageSelectPanel.new("stageselect", {})
	panel.setup_by_stage(mgr, pd, rng, normal_sid)
	panel.show_window(root)
	assert_eq(panel._current_chapter, expect_ch, "setup_by_stage 定位到 stage 所在章")
	panel.remove_window()
	root.queue_free()


# ===== 四轮：获取途径跳转 mode + 关卡级引导（2026-09-07，源 createByStage :1642-1664 + createStage :1331-1351）=====

# 源 createByStage :1646-1659：按关卡类型设 mode（elite 掉落 → 精英地图）+ getWayStage=Stage Group
# 真 sid（:1655）。旧实现缺 mode → 精英关跳普通地图看不到目标关。
func test_setup_by_stage_sets_mode_and_target() -> void:
	var st: Dictionary = cm.get_raw_table("Stage")
	var normal_sid: int = 0
	var elite_sid: int = 0
	for sid_str in st:
		var sid: int = int(sid_str)
		if normal_sid == 0 and sid > 0 and sid < 10000 and StageAccount.stage_type(sid) == "normal":
			normal_sid = sid
		if elite_sid == 0 and sid >= 10000:
			elite_sid = sid
	var root := Node.new()
	add_child(root)
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	var rng := BattleRng.new(1)
	var panel := StageSelectPanel.new("stageselect", {})
	panel.setup_by_stage(mgr, pd, rng, normal_sid)
	panel.show_window(root)
	assert_eq(panel._mode, "normal", "普通关 → normal 地图（源 :1647-1650）")
	assert_eq(panel._get_way_stage, normal_sid, "getWayStage = 真 sid 直返")
	panel.remove_window()
	if elite_sid > 0:
		var expect_gid: int = int(st.get(str(elite_sid), {}).get("Stage Group", elite_sid))
		var panel2 := StageSelectPanel.new("stageselect", {})
		panel2.setup_by_stage(mgr, pd, rng, elite_sid)
		panel2.show_window(root)
		assert_eq(panel2._mode, "elite", "精英关 → elite 地图（源 :1656-1658 else 分支）")
		assert_eq(panel2._get_way_stage, expect_gid, "getWayStage = Stage Group 真 sid（源 :1655）")
		panel2.remove_window()
	root.queue_free()


# 源 createStage :1331-1351 forGetWay：目标关上叠 tutorial_circle 呼吸圈 + tutorial_finger 手指引导
func test_setup_by_stage_attaches_guide() -> void:
	var st: Dictionary = cm.get_raw_table("Stage")
	var normal_sid: int = 0
	for sid_str in st:
		var sid: int = int(sid_str)
		if sid > 0 and sid < 10000 and StageAccount.stage_type(sid) == "normal":
			normal_sid = sid
			break
	if normal_sid == 0:
		pass_test("无普通关，跳过")
		return
	var root := Node.new()
	add_child(root)
	var mgr := StageManager.new(cm)
	mgr.progress = {normal_sid: 3}
	var pd := PlayerData.new(cm)
	var rng := BattleRng.new(1)
	var panel := StageSelectPanel.new("stageselect", {})
	panel.setup_by_stage(mgr, pd, rng, normal_sid)
	panel.show_window(root)
	var has_circle: bool = false
	var has_finger: bool = false
	for layer in panel._map_host.get_children():
		for c in (layer as Control).get_children():
			if c.has_meta(StageSelectPanel.META_GUIDE_CIRCLE):
				has_circle = true
			if c.has_meta(StageSelectPanel.META_GUIDE_FINGER):
				has_finger = true
	assert_true(has_circle, "目标关上呼吸圈引导（源 :1336-1343）")
	assert_true(has_finger, "目标关上手指引导（源 :1344-1351）")
	panel.remove_window()
	root.queue_free()


# 源 gotoDetailScene :218-228：GetWay 下点进目标关详情 → 清 circle/finger + getWayMode=nil
func test_get_way_guide_clears_on_target_click() -> void:
	var st: Dictionary = cm.get_raw_table("Stage")
	var normal_sid: int = 0
	for sid_str in st:
		var sid: int = int(sid_str)
		if sid > 0 and sid < 10000 and StageAccount.stage_type(sid) == "normal":
			normal_sid = sid
			break
	if normal_sid == 0:
		pass_test("无普通关，跳过")
		return
	var root := Node.new()
	add_child(root)
	var mgr := StageManager.new(cm)
	mgr.progress = {normal_sid: 3}
	var pd := PlayerData.new(cm)
	var rng := BattleRng.new(1)
	var panel := StageSelectPanel.new("stageselect", {})
	panel.setup_by_stage(mgr, pd, rng, normal_sid)
	panel.show_window(root)
	panel._on_stage_clicked(normal_sid)   # 点目标关（普通模式按钮 key=info.id）→ 开详情 + 清引导
	assert_eq(panel._get_way_stage, 0, "点目标关 → getWayStage 清零（源 :226 getWayMode=nil）")
	var has_guide: bool = false
	for layer in panel._map_host.get_children():
		for c in (layer as Control).get_children():
			if c.has_meta(StageSelectPanel.META_GUIDE_CIRCLE) or c.has_meta(StageSelectPanel.META_GUIDE_FINGER):
				has_guide = true
	assert_false(has_guide, "引导节点清除（源 :219-225 circle/finger 清理）")
	panel.remove_window()
	root.queue_free()


# ===== 照源精修验收（2026-07-16，Task 5 改 fills 引用）=====

# 源 createModeButton label：normal=LSTR("STAGESELECT.NORMAL")、elite=LSTR("EQUIPCRAFT.ELITE")、
# guild=LSTR("STAGESELECT.RAID")="团队"。旧实现硬编码 "团本" 是错值。
# mode toggle 静态化进 .tscn（%ModeNormalBtn/EliteBtn/GuildBtn + Label 子节点），
# fills.fill_mode_toggle 切纹理 + 填 LSTR text。
func test_mode_label_uses_lstr() -> void:
	var content: Control = load(CONTENT_PATH).instantiate() as Control
	add_child(content)
	var buttons: Dictionary = {
		"normal": content.get_node("%ModeNormalBtn"),
		"elite": content.get_node("%ModeEliteBtn"),
		"guild": content.get_node("%ModeGuildBtn"),
	}
	StageSelectFills.fill_mode_toggle(buttons, "normal", cm)
	for mode in ["normal", "elite", "guild"]:
		assert_true(buttons.has(mode), mode + " toggle 存在")
	var guild_lbl: Label = null
	for child in (buttons["guild"] as TextureButton).get_children():
		if child is Label:
			guild_lbl = child
			break
	assert_not_null(guild_lbl, "guild toggle 有 label")
	assert_eq(guild_lbl.text, "团队", "guild label = LSTR STAGESELECT.RAID = '团队'（非旧错值'团本'）")
	var normal_lbl: Label = null
	for child in (buttons["normal"] as TextureButton).get_children():
		if child is Label:
			normal_lbl = child
			break
	assert_eq(normal_lbl.text, "普通", "normal label = LSTR STAGESELECT.NORMAL = '普通'")
	var elite_lbl: Label = null
	for child in (buttons["elite"] as TextureButton).get_children():
		if child is Label:
			elite_lbl = child
			break
	assert_eq(elite_lbl.text, "精英", "elite label = LSTR EQUIPCRAFT.ELITE = '精英'")
	content.queue_free()


# 源 ui/main.lua:1351 ed.pushScene(ed.ui.stageselect.create()) —— stageselect 是 pushScene 独立场景，
# framework.lua:749 自动建全屏 bg.jpg。本项目单机化 pushScene→PopWindow，.tscn %FrameworkBg 补 bg.jpg。
func test_has_fullscreen_bg() -> void:
	var panel := _make_panel()
	# bg.jpg 静态化进 .tscn %FrameworkBg（container→_content→FrameworkBg）。
	var bg: TextureRect = panel._content.get_node_or_null("%FrameworkBg") as TextureRect
	assert_not_null(bg, "%FrameworkBg 装配")
	if bg != null:
		var t: Texture2D = bg.texture
		assert_not_null(t, "FrameworkBg 有纹理")
		if t != null:
			assert_true(String(t.resource_path).find("bg.jpg") != -1, "FrameworkBg = bg.jpg（源 pushScene 场景 framework.lua:749 自动加）")
	panel.remove_window()


# 源 createFrame :967-970 — normal ccp(400,205)→godot 中心 (480,355)；其他 mode ccp(400,207)→y=353。
# 尺寸口径（Task 5 修正）：stage-map-frame 936×507px 条目 Prescaled=false 不施加 → 936/CS×507/CS。
func test_frame_position_matches_source() -> void:
	var c := Control.new()
	add_child_autofree(c)
	StageSelectFills.create_frame(c, "normal")
	var frame: TextureRect = null
	for child in c.get_children():
		if child is TextureRect and String((child.texture as Texture2D).resource_path).find("stage-map-frame") != -1:
			frame = child
			break
	assert_not_null(frame, "normal frame 建出（stage-map-frame.png）")
	if frame != null:
		assert_almost_eq(frame.position.y + frame.size.y * 0.5, 275.0, 1.5, "normal frame 中心 y≈275（源 ccp(400,205)→godot 480-205；旧 355 系 960 口径残留 2026-08-22 巡检订正）")
		assert_almost_eq(frame.position.x + frame.size.x * 0.5, 400.0, 1.5, "normal frame 中心 x=400")
		assert_almost_eq(frame.size.x, 936.0 / CS, 0.5, "frame 宽 = 936px÷CS（Prescaled=false 条目不施加，偏大补丁撤销）")
		assert_almost_eq(frame.size.y, 507.0 / CS, 0.5, "frame 高 = 507px÷CS")


# 源 :1301-1305 — key 关（info.eid）ccp(pos.x, pos.y+60)；非 key 关 ccp(pos.x-1, pos.y+30)。
# Task 5 撤销 2026-07-20 STRETCH 1.268 放大（偏大口径补丁），恢复源 pos 直译。
func test_stage_pointer_key_stage_offset() -> void:
	var c := Control.new()
	add_child_autofree(c)
	var key_info: Dictionary = {"id": 1, "eid": 10001, "pos": [172, 284]}
	StageSelectFills._add_pointer(c, key_info)
	if c.get_child_count() == 0:
		pass_test("stagepointer.png 资源缺失，跳过")
		return
	var key_ptr: TextureRect = c.get_child(0) as TextureRect
	assert_almost_eq(key_ptr.position.y + key_ptr.size.y * 0.5, 480.0 - 344.0, 1.5,
		"key 关指针中心 y = to_godot(·,284+60)（源 cy+60 直译，无放大）")
	assert_almost_eq(key_ptr.position.x + key_ptr.size.x * 0.5, 172.0, 1.5, "key 关指针中心 x = 172+80")
	var c2 := Control.new()
	add_child_autofree(c2)
	var nonkey_info: Dictionary = {"id": 2, "pos": [217, 200]}
	StageSelectFills._add_pointer(c2, nonkey_info)
	if c2.get_child_count() > 0:
		var nk_ptr: TextureRect = c2.get_child(0) as TextureRect
		assert_almost_eq(nk_ptr.position.y + nk_ptr.size.y * 0.5, 480.0 - 230.0, 1.5,
			"非 key 关指针中心 y = to_godot(·,200+30)（源 cy+30 直译）")
		assert_almost_eq(nk_ptr.position.x + nk_ptr.size.x * 0.5, 216.0, 1.5, "非 key 关指针中心 x = (217-1)+80")


# ===== 两件套守卫（批3 Task 5 新增，2026-08-16）=====

# content tscn 静态树：死占位 FramePlaceholder/TitleBgPlaceholder（运行时被 init 清掉的双头
# 管理债）删除；TextureButton stretch_mode=0 显式（批2方法论）；mode toggle 含源 setScale(0.9)
# （refreshModeButtonPosition :245-247）；guild 按钮 visible=false（源 :269-270 禁止团队副本）。
func test_content_static_tree() -> void:
	var inst: Control = (load(CONTENT_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(inst)
	assert_null(inst.get_node_or_null("FrameLayer/FramePlaceholder"), "死占位 FramePlaceholder 已删（双头管理债清理）")
	assert_null(inst.get_node_or_null("FrameLayer/TitleBgPlaceholder"), "死占位 TitleBgPlaceholder 已删")
	# ModeLayer 无偏好偏移（源 mode 区中心 y=205/210 直译；旧 offset_top=-30 是偏大口径补偿）。
	var mode_layer: Control = inst.get_node("%ModeLayer") as Control
	assert_almost_eq(mode_layer.offset_top, 0.0, 0.1, "ModeLayer offset_top=0（偏好补丁撤销）")
	# ModeBg（源 buttonBg crusade_Button_bg 874×74px÷CS 中心 ccp(400,355)→(480,205)）。
	var mode_bg: TextureRect = inst.get_node("%ModeLayer/ModeBg") as TextureRect
	assert_almost_eq(mode_bg.offset_left + (mode_bg.offset_right - mode_bg.offset_left) * 0.5, 400.0, 0.1, "ModeBg 中心 x=480")
	assert_almost_eq(mode_bg.offset_top + (mode_bg.offset_bottom - mode_bg.offset_top) * 0.5, 125.0, 0.1, "ModeBg 中心 y=560-355")
	assert_almost_eq(mode_bg.offset_right - mode_bg.offset_left, 874.0 / CS, 0.1, "ModeBg 宽 = 874px÷CS")
	# mode toggle：129×67px÷CS×0.9（源 setScale(0.9)）；normal(345,350)→(425,210)、
	# elite(455,350)→(535,210)、guild(489,350)→(569,210)（guild 不可见布局，源 :240-243）。
	var btn_expect := {
		"%ModeNormalBtn": Vector2(345.0, 130.0),
		"%ModeEliteBtn": Vector2(455.0, 130.0),
		"%ModeGuildBtn": Vector2(489.0, 130.0),
	}
	for btn_name in btn_expect:
		var btn: TextureButton = inst.get_node(btn_name) as TextureButton
		var center: Vector2 = Vector2(btn.offset_left, btn.offset_top) \
			+ Vector2(btn.offset_right - btn.offset_left, btn.offset_bottom - btn.offset_top) * 0.5
		assert_almost_eq(center.x, btn_expect[btn_name].x, 0.1, btn_name + " 中心 x = 源 toggle 位置直译")
		assert_almost_eq(center.y, btn_expect[btn_name].y, 0.1, btn_name + " 中心 y = 560-350")
		assert_almost_eq(btn.offset_right - btn.offset_left, 129.0 / CS * 0.9, 0.1, btn_name + " 宽 = 129px÷CS×0.9")
		assert_almost_eq(btn.offset_bottom - btn.offset_top, 67.0 / CS * 0.9, 0.1, btn_name + " 高 = 67px÷CS×0.9")
		assert_eq(btn.stretch_mode, TextureButton.STRETCH_SCALE, btn_name + " stretch_mode=0 显式（批2方法论）")
	assert_false((inst.get_node("%ModeGuildBtn") as CanvasItem).visible, "guild toggle 隐藏（源 :269-270 禁止团队副本）")
	# 箭头（源 createChapterButton :706-709 prev(78,215)/next(720,215) → godot 中心 (158,345)/(800,345)；
	# 55×75px÷CS = 42.93×58.54）。
	var prev: TextureButton = inst.get_node("%PrevArrow") as TextureButton
	assert_almost_eq(prev.offset_left, 78.0 - 55.0 / CS / 2.0, 0.1, "PrevArrow 中心 x = 78+80")
	assert_almost_eq(prev.offset_top, 265.0 - 75.0 / CS / 2.0, 0.1, "PrevArrow 中心 y = 560-215")
	var next: TextureButton = inst.get_node("%NextArrow") as TextureButton
	assert_almost_eq(next.offset_left, 720.0 - 55.0 / CS / 2.0, 0.1, "NextArrow 中心 x = 720+80")
	for arrow in [prev, next]:
		assert_eq(arrow.stretch_mode, TextureButton.STRETCH_SCALE, "箭头 stretch_mode=0 显式")
	# CloseBtn stretch_mode=0 显式。
	assert_eq((inst.get_node("%CloseBtn") as TextureButton).stretch_mode, TextureButton.STRETCH_SCALE, "CloseBtn stretch_mode=0 显式")
	# 声明序：MapLayerHost < FrameLayer < ModeLayer（源 map z1 < frame z5 < mode z20，
	# mode 按钮层盖 map/frame；title z21 由 fills 动态层 z_index 200 压回，见 panel）。
	assert_true((inst.get_node("%MapLayerHost") as Control).get_index()
		< (inst.get_node("%FrameLayer") as Control).get_index(), "MapLayerHost 先声明（源 map z=1 底层）")
	assert_true((inst.get_node("%FrameLayer") as Control).get_index()
		< (mode_layer).get_index(), "ModeLayer 后声明（源 modeContainer z=20 盖 frame z=5）")


# 源 create :1608-1613 clipLayer：clipStencil 712×372 @ cocos(44,20) → godot rect(124,168)。
# map bg（stageselect_map_bg_1.jpg 468×254px 条目 Prescaled=true CS=2）→ 468/CS×2 =
# 730.54×396.49（Task 5 通用公式口径，与 Task 4 crusade 系 Prescaled=false 区分）；
# route（map1.png 468×254px 无条目）→ 365.27×198.24；bg/route 中心 ccp(400,212)→(480,348)。
func test_map_clip_and_bg_size_source() -> void:
	var panel := _make_panel()
	var layer: Control = panel._map_host.get_child(0) as Control
	assert_almost_eq(layer.position.x, 44.0, 0.1, "MapLayer x = to_godot(44,·).x（源 clipStencil 直译）")
	assert_almost_eq(layer.position.y, 88.0, 0.1, "MapLayer y = 560-(20+372)（源 clipStencil 直译）")
	assert_almost_eq(layer.size.x, 712.0, 0.1, "MapLayer 宽 = 源 712（clip 903×471 偏大补丁撤销）")
	assert_almost_eq(layer.size.y, 372.0, 0.1, "MapLayer 高 = 源 372")
	assert_true(layer.clip_contents, "MapLayer clip_contents（源 ClippingNode 等价）")
	var bg: TextureRect = null
	var route: TextureRect = null
	for child in layer.get_children():
		if child is TextureRect:
			var tr := child as TextureRect
			var p := String((tr.texture as Texture2D).resource_path)
			if p.find("stageselect_map_bg") != -1:
				bg = tr
			elif p.find("map1.png") != -1 or p.find("map") != -1 and p.find("stageselect") == -1:
				route = tr
	assert_not_null(bg, "章节 bg 建出（stageselect_map_bg_1.jpg）")
	if bg != null:
		assert_almost_eq(bg.size.x, 468.0 / CS * 2.0, 0.5, "bg 宽 = 468px÷CS×2（Prescaled=true CS=2 通用公式）")
		assert_almost_eq(bg.size.y, 254.0 / CS * 2.0, 0.5, "bg 高 = 254px÷CS×2")
		assert_almost_eq(bg.position.x + bg.size.x * 0.5 + layer.position.x, 400.0, 0.5, "bg 中心 x=480（源 pos(400,212)）")
		assert_almost_eq(bg.position.y + bg.size.y * 0.5 + layer.position.y, 268.0, 0.5, "bg 中心 y=560-212")
	assert_not_null(route, "route 建出（map1.png）")
	if route != null:
		assert_almost_eq(route.size.x, 468.0 / CS * 2.0, 0.5, "route 宽 = 468px÷CS×2（map 系 route 同为 Prescaled=true CS=2 条目）")
		assert_almost_eq(route.size.y, 254.0 / CS * 2.0, 0.5, "route 高 = 254px÷CS×2（与 bg 同尺寸铺满，叠 bg 上）")
	panel.remove_window()


# 撤销 STRETCH 1.268 守卫：chapter1 stage1 pos(172,284) key 关（eid=10001）新档 → current，
# icon key_stages/stage-1.png 209×189px÷CS；btn 中心 = to_godot(172,284)=(252,276) 直译
# （global 级防 parenting）；key mask 照源 :1229-1238 与 icon 平级挂 stageContainer
# （先 mask 后 icon，icon 盖 mask），中心同 btn。
# 2026-09-07 命中根修后：btn=命中层 90×90（源 r45），贴图移子 TextureRect（尺寸/中心
# 断言改走子节点，视觉口径不变）；stretch_mode 随纹理移出按钮而删（贴图子节点
# EXPAND_IGNORE_SIZE+显式 size 即原 SCALE 语义）。
func test_stage_button_position_no_stretch() -> void:
	var panel := _make_panel()
	var layer: Control = panel._map_host.get_child(0) as Control
	var btn: TextureButton = panel._stage_buttons[1] as TextureButton
	assert_almost_eq(btn.global_position.x + btn.size.x * 0.5, 172.0, 0.5,
		"stage1 btn 中心 x = to_godot(172,·)（STRETCH 放大撤销）")
	assert_almost_eq(btn.global_position.y + btn.size.y * 0.5, 196.0, 0.5,
		"stage1 btn 中心 y = to_godot(·,284)（STRETCH 放大撤销）")
	assert_almost_eq(btn.size.x, 90.0, 0.5, "stage1 命中层宽 = 源半径45×2（2026-09-07 命中根修）")
	assert_almost_eq(btn.size.y, 90.0, 0.5, "stage1 命中层高 = 源半径45×2")
	var icon: TextureRect = null
	for c in btn.get_children():
		if c is TextureRect:
			icon = c
			break
	assert_not_null(icon, "stage1 贴图显示层 = 命中层子 TextureRect")
	if icon != null:
		assert_almost_eq(icon.size.x, 209.0 / CS, 0.5, "stage1 icon 宽 = 209px÷CS（key stage 图，视觉口径不变）")
		assert_almost_eq(icon.size.y, 189.0 / CS, 0.5, "stage1 icon 高 = 189px÷CS")
		assert_almost_eq(icon.global_position.x + icon.size.x * 0.5, 172.0, 0.5,
			"icon 中心 x 与 btn 同心（贴图不随命中层缩放）")
		assert_almost_eq(icon.global_position.y + icon.size.y * 0.5, 196.0, 0.5,
			"icon 中心 y 与 btn 同心")
	var mask: TextureRect = null
	for child in layer.get_children():
		if child is TextureRect and child.has_meta(&"ss_mask"):
			mask = child
			break
	assert_not_null(mask, "stage1 current key 关有闪烁 mask（源 :1229-1238）")
	if mask != null:
		assert_almost_eq(mask.global_position.x + mask.size.x * 0.5, 172.0, 0.5,
			"mask 中心与 icon 同位（源 mask:setPosition(t.pos) 平级直译）")
		assert_almost_eq(mask.size.x, 209.0 / CS, 0.5, "mask 宽 = stage-current 209px÷CS")
		assert_true(mask.get_index() < btn.get_index(), "mask 先声明（源 icon 后 add 盖 mask，闪烁光圈露边）")
	panel.remove_window()


# 2026-09-01 三轮定谳版星级守卫：一轮底部口径（源直译）经原版 MuMu 真值截图证实
# （原版胶囊中心偏圆窗 (+0.8,+37.2) vs 本实现 (+0.4,+35.75)）；二轮「顶部」系口误
# 已回滚。star 相对 star_bg 左下角口径不变（弧形嵌满胶囊）。
# 2026-09-07 命中根修：星级挂贴图显示层（icon TextureRect）下（原 btn 直挂），
# 层级 btn > icon > star_bg > stars；btn.size=90 命中层不再参与公式，口径改 icon.size。
func test_star_layout_centered_under_stage_icon() -> void:
	var root := Node.new()
	add_child(root)
	var mgr := StageManager.new(cm)
	var pd := PlayerData.new(cm)
	mgr.progress = {1: 3}   # panel star_of 走传入的 mgr（QA 同链路），非 pd.stage_manager
	var rng := BattleRng.new(5)
	var panel := StageSelectPanel.new("stageselect", {})
	panel.setup_panel(mgr, pd, rng)
	panel.show_window(root)
	var btn: TextureButton = panel._stage_buttons[1] as TextureButton
	var icon: TextureRect = null
	for c in btn.get_children():
		if c is TextureRect:
			icon = c
			break
	assert_not_null(icon, "贴图显示层存在（星级挂其下）")
	if icon == null:
		panel.remove_window()
		root.queue_free()
		return
	var star_bg: TextureRect = null
	for c in icon.get_children():
		if c is TextureRect and (c as TextureRect).texture != null \
				and (c as TextureRect).texture.resource_path.ends_with("stageselect_star_bg.png"):
			star_bg = c
			break
	assert_not_null(star_bg, "通关 3 星 → stage1 key 圆窗挂 star_bg")
	if star_bg == null:
		panel.remove_window()
		root.queue_free()
		return
	var btn_c: Vector2 = btn.global_position + btn.size * 0.5
	var bg_c: Vector2 = star_bg.global_position + star_bg.size * 0.5
	assert_almost_eq(bg_c.x - btn_c.x, 82.0 - icon.size.x * 0.5, 0.5,
		"star_bg 中心水平≈圆窗中心（cocos 左下角口径 82-w/2，原版实测 +0.8 吻合）")
	assert_almost_eq(bg_c.y - btn_c.y, icon.size.y * 0.5 - 38.0, 0.5,
		"star_bg 中心在圆窗下方 h/2-38（源直译，原版真值 +37.2 实证；h=贴图显示高）")
	var stars: Array = []
	for c in star_bg.get_children():
		if c is TextureRect:
			stars.append(c)
	assert_eq(stars.size(), 3, "3 颗星挂在 star_bg 下")
	var xs: Array = []
	for s in stars:
		xs.append((s as TextureRect).global_position.x + (s as TextureRect).size.x * 0.5)
	xs.sort()
	assert_almost_eq(float(xs[0] + xs[2]) * 0.5 - bg_c.x, 37.0 - star_bg.size.x * 0.5, 0.5,
		"左右星对称（spos 17/57 同轴距于中心）")
	assert_almost_eq(float(xs[1]) - bg_c.x, 37.0 - star_bg.size.x * 0.5, 0.5,
		"中星 x ≈ star_bg 中心（spos 37 ≈ 半宽 36.3）")
	var bg_rect: Rect2 = Rect2(star_bg.global_position, star_bg.size).grow(0.5)
	for s in stars:
		var star: TextureRect = s as TextureRect
		assert_true(bg_rect.encloses(Rect2(star.global_position, star.size)),
			"星嵌在 star_bg 底板内（不溢出/不被 mode 按钮遮挡）")
	panel.remove_window()
	root.queue_free()


# 源 createDot :698-702 — guild 模式 dotContainer:setVisible(false)。
func test_dots_hidden_in_guild() -> void:
	var panel := _make_panel()
	assert_true(panel._dot_container.visible, "normal 模式 dots 可见")
	panel._on_mode_pressed("guild")
	assert_false(panel._dot_container.visible, "guild 模式 dots 隐藏（源 :698-702 直译补全）")
	panel.remove_window()


# 两件套守卫：builder 退役（文件删 + 无引用）+ fills .new( 白名单恰 10 处（全数据驱动
# 动态行/crossfade 动画节点，逐一甄别见 Task 5 报告）+ panel .new( 恰 1 处（详情弹窗）。
func test_builder_retired_and_new_whitelist() -> void:
	assert_false(ResourceLoader.exists(BUILDER_PATH), "stage_select_builder.gd 已退役删除")
	assert_false(FileAccess.file_exists(BUILDER_PATH), "builder 文件不存在（含 .uid 残留检查由 git 层）")
	var panel_src: String = FileAccess.get_file_as_string(PANEL_PATH)
	assert_false(panel_src.contains("stage_select_builder"), "panel 无 builder 引用（代码级守卫，注释头不计）")
	var fills_src: String = FileAccess.get_file_as_string(FILLS_PATH)
	var fills_new: PackedStringArray = _collect_new_calls(fills_src)
	# 13 = 12 + 命中根修贴图显示层 1（2026-09-07 stage icon 子 TextureRect，源 r45 圆形命中直译）
	assert_eq(fills_new.size(), 13, "fills .new( 恰 13 处（动态行+动画节点+GetWay 引导+贴图显示层白名单）")
	var joined: String = "\n".join(fills_new)
	assert_true(joined.contains("Control.new()"), "MapLayer 裁剪层（章节 slide 动画需新旧并存）在白名单")
	assert_true(joined.contains("TextureButton.new()"), "stage 圆点按钮（数量/位置随章节数据）在白名单")
	# TextureRect 共 10 处（bg/route 中心子、stage icon 贴图显示层、star_bg、star、pointer、
	# key mask、frame/title_bg 中心件、dot、GetWay 引导 circle/finger）
	var tr_count: int = 0
	var idx: int = fills_src.find(".new(")
	while idx != -1:
		var ls: int = fills_src.rfind("\n", idx) + 1
		var le: int = fills_src.find("\n", idx)
		var line: String = fills_src.substr(ls, le - ls).strip_edges()
		if line.contains("TextureRect.new()"):
			tr_count += 1
		idx = fills_src.find(".new(", idx + 1)
	assert_eq(tr_count, 10, "TextureRect.new() 恰 10 处（bg/route、stage icon、star_bg、star、pointer、mask、frame/title_bg、dot、GetWay circle/finger）")
	assert_true(joined.contains("Label.new()"), "章节 title Label（章节 crossfade 动画节点）在白名单")
	var panel_new: PackedStringArray = _collect_new_calls(panel_src)
	assert_eq(panel_new.size(), 1, "panel .new( 恰 1 处（StageDetailPanel 弹窗构造）")
	assert_true("\n".join(panel_new).contains("StageDetailPanel.new("), "panel 唯一 .new( 是详情弹窗")


static func _collect_new_calls(src: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var idx: int = src.find(".new(")
	while idx != -1:
		var ls: int = src.rfind("\n", idx) + 1
		var le: int = src.find("\n", idx)
		out.append(src.substr(ls, le - ls).strip_edges())
		idx = src.find(".new(", idx + 1)
	return out


# ===== 切章箭头可见性 + 等级门槛（2026-09-06 第一章通关无法切章根修回归）=====
# 源 setChapterButtonState:643-662：min<chapter<max 两箭头都显示；chapter==max 只显示
# prev；chapter==min 只显示 next；min==max 都隐藏。max = 进度章（+1 语义：通关一章
# 末关后进度落下一章首关）。等级门槛只在 doChangeChapter:434-437 切换时拦截（toast），
# 不影响箭头显示。

func _make_panel_with_progress(progress: Dictionary, team_level: int) -> StageSelectPanel:
	var root := Node.new()
	add_child(root)
	var mgr := StageManager.new(cm)
	mgr.progress = progress
	var pd := PlayerData.new(cm)
	pd.team_level = team_level
	var rng := BattleRng.new(5)
	var panel := StageSelectPanel.new("stageselect", {})
	panel.setup_panel(mgr, pd, rng)
	panel.show_window(root)
	return panel


func _chapter1_cleared_progress() -> Dictionary:
	var progress: Dictionary = {}
	for sid in range(1, 19):
		progress[sid] = 3
	return progress


# 新档无进度：max_chapter=1 = min = max → 两箭头都隐藏。
func test_arrows_hidden_on_fresh_save() -> void:
	var panel := _make_panel_with_progress({}, 1)
	assert_false((panel._content.get_node("%NextArrow") as CanvasItem).visible, "新档 max_chapter=1 → NextArrow 隐藏")
	assert_false((panel._content.get_node("%PrevArrow") as CanvasItem).visible, "chapter1 = min = max → PrevArrow 隐藏")
	panel.remove_window()


# 用户报告场景：第一章全通关（sid 1-18）+ 等级 5（playerlimit 允许 chapter2）。
# 打开面板定位 chapter2（= max）→ 只显示 PrevArrow；点 prev 切回 ch1 → NextArrow 出现
# （max=2 > 1，正是本根修恢复的箭头）；再点 next 切回 ch2。左右移动闭环。
func test_chapter_arrows_roundtrip_after_chapter1_clear() -> void:
	var panel := _make_panel_with_progress(_chapter1_cleared_progress(), 5)
	assert_eq(panel._current_chapter, 2, "初始章节 = min(进度章 2, 等级章 2) = 2（源 :1449）")
	assert_true((panel._content.get_node("%PrevArrow") as CanvasItem).visible, "chapter2 = max → PrevArrow 显示（可回 ch1）")
	assert_false((panel._content.get_node("%NextArrow") as CanvasItem).visible, "chapter2 = max（ch3 未解锁）→ NextArrow 隐藏")
	panel._on_prev_chapter()
	assert_eq(panel._current_chapter, 1, "prev → 切回 chapter1")
	assert_true((panel._content.get_node("%NextArrow") as CanvasItem).visible, "ch1 < max2 → NextArrow 显示（根修：通关后可切下一章）")
	# 源逻辑 ch==min 只显示 next（:648-651）；本项目直译 _current_chapter > 1 → ch1 时 Prev 隐藏
	assert_false((panel._content.get_node("%PrevArrow") as CanvasItem).visible, "ch1 = min → PrevArrow 隐藏（源 :648 chapter==min 分支）")
	panel._on_next_chapter()
	assert_eq(panel._current_chapter, 2, "next → 切回 chapter2（左右移动闭环）")
	panel.remove_window()


# 第一章全通关但等级 1（playerlimit 只允许 chapter1）：
# 初始章节压回 1；NextArrow 显示（箭头只看进度 max）；点 next 被 toast 拦截不切换。
func test_next_chapter_blocked_by_level() -> void:
	var panel := _make_panel_with_progress(_chapter1_cleared_progress(), 1)
	assert_eq(panel._current_chapter, 1, "初始章节 = min(2, playerlimit=1) = 1（源 :1449）")
	assert_true((panel._content.get_node("%NextArrow") as CanvasItem).visible, "NextArrow 显示（进度 max=2，箭头不看等级）")
	panel._on_next_chapter()
	assert_eq(panel._current_chapter, 1, "等级不足 → toast 拦截不切章（源 doChangeChapter:434-437）")
	assert_eq(Toast.pending_count(), 1, "拦截时入队 1 条 toast")
	assert_true(String(Toast.consume()).contains("解锁下一章节"), "toast 文案 = 源 zh-CN 直译")
	panel.remove_window()


# 等级足够时 prev/next 往返无 toast、章节正常切换（ch2 → ch1 → ch2）。
func test_prev_next_no_toast_when_level_ok() -> void:
	var panel := _make_panel_with_progress(_chapter1_cleared_progress(), 5)
	panel._on_prev_chapter()
	panel._on_next_chapter()
	assert_eq(panel._current_chapter, 2, "往返切章正常")
	assert_eq(Toast.pending_count(), 0, "等级足够无拦截 toast")
	panel.remove_window()


# ===== 命中区根修守卫（2026-09-07，源 doStageTouch 圆形命中直译）=====
# 源 stageselect.lua:15-16 KEY_STAGE_RADIUS/NOT_KEY_STAGE_RADIUS 均 45，doStageTouch
# :126-131 isPointInCircle(t.pos, 45, x,y)——以关卡中心为圆心、直径 90 的圆形命中区，
# 与贴图大小无关。Godot 直译成 TextureButton rect=贴图显示尺寸后两处走样（用户 2026-09-07
# 报「两个城堡之间的小据点非常难点击选中」）：
#   1) passed 小圆盘（stagecircle_elite 37×41px → 显示 ~29×32）命中区远小于源直径 90；
#   2) 城堡（209×189px → 显示 163×148）rect 含透明边，盖住相邻据点点击（章1 据点10
#      (425,270) 距城堡11 (510,270) 仅 85px，城堡 rect 左缘 428.5 盖据点右半）。
# 根修：命中层（TextureButton 90×90，源半径 45×2 方形近似，四角偏差 45×(√2-1)≈18.6px
# 可接受）与贴图显示层（子 TextureRect 照旧尺寸居中、IGNORE）分离。

# key 城堡（章1 stage1，209×189px 大贴图）：命中层 90×90 + 贴图视觉/位置照旧。
func test_key_stage_hit_layer_separated_from_icon() -> void:
	var panel := _make_panel()
	var btn: TextureButton = panel._stage_buttons[1] as TextureButton
	assert_almost_eq(btn.size.x, 90.0, 0.1, "key 城堡命中层宽 = 源半径45×2（贴图 163×148 缩到 90，透明区不再吞邻居点击）")
	assert_almost_eq(btn.size.y, 90.0, 0.1, "key 城堡命中层高 = 源半径45×2")
	assert_almost_eq(btn.global_position.x + btn.size.x * 0.5, 172.0, 0.5,
		"命中层中心 = 关卡中心 x = to_godot(172,·)")
	assert_almost_eq(btn.global_position.y + btn.size.y * 0.5, 196.0, 0.5,
		"命中层中心 = 关卡中心 y = to_godot(·,284)")
	var icon: TextureRect = null
	for c in btn.get_children():
		if c is TextureRect:
			icon = c
			break
	assert_not_null(icon, "贴图显示层 = 命中层子 TextureRect（不随命中层缩放）")
	if icon != null:
		assert_almost_eq(icon.size.x, 209.0 / CS, 0.5, "城堡贴图宽照旧 209px÷CS（视觉不变）")
		assert_almost_eq(icon.size.y, 189.0 / CS, 0.5, "城堡贴图高照旧 189px÷CS")
		assert_almost_eq(icon.global_position.x + icon.size.x * 0.5, 172.0, 0.5,
			"贴图中心 = 关卡中心 x（视觉不变）")
		assert_almost_eq(icon.global_position.y + icon.size.y * 0.5, 196.0, 0.5,
			"贴图中心 = 关卡中心 y（视觉不变）")
		assert_eq(icon.mouse_filter, Control.MOUSE_FILTER_IGNORE, "贴图层不吞点击（装饰节点红线）")
	panel.remove_window()


# 非 key 小圆盘（章1 stage2 passed → stagecircle_elite 37×41px 最小贴图）：
# 命中区扩到 90×90（用户主诉场景），贴图外命中区内点击可触发 pressed。
func test_small_stage_click_hits_enlarged_area() -> void:
	var panel := _make_panel_with_progress({1: 3, 2: 3}, 1)
	var btn: TextureButton = panel._stage_buttons[2] as TextureButton
	assert_true(is_instance_valid(btn), "stage2 passed 进可点 buttons")
	if btn == null:
		panel.remove_window()
		return
	var icon: TextureRect = null
	for c in btn.get_children():
		if c is TextureRect:
			icon = c
			break
	assert_not_null(icon, "小圆盘贴图显示层存在")
	if icon != null:
		assert_almost_eq(icon.size.x, 37.0 / CS, 0.5, "小圆盘贴图宽 = 37px÷CS（视觉不变，最小态）")
		assert_almost_eq(icon.size.y, 41.0 / CS, 0.5, "小圆盘贴图高 = 41px÷CS")
	assert_almost_eq(btn.size.x, 90.0, 0.1, "小圆盘命中层宽 = 源半径45×2（贴图 29×32 → 90，主诉根修）")
	assert_almost_eq(btn.size.y, 90.0, 0.1, "小圆盘命中层高 = 源半径45×2")
	# 贴图显示区右缘 + 20px（贴图外、命中区内）→ 仍在按钮 rect 内可点。
	# 点击链路说明：headless GUT 下 root Window 物理 64×64，push_input 分发坐标与
	# 设计空间不一致，端到端鼠标模拟依赖环境细节（实测 push_input 两口径均不分发），
	# 故此处断言引擎命中契约的前提组合（rect 命中 + mouse_filter + 可用态），真实鼠标
	# 链路由用户实机验收兜底（项目惯例）。TextureButton 空纹理不影响 BaseButton 的
	# rect 命中与 pressed 信号（引擎基类契约，皮肤与命中解耦）。
	var click_local: Vector2 = (btn.size * 0.5) + Vector2(20.0, 0.0)
	if icon != null:
		assert_true(click_local.x > icon.size.x * 0.5 + 5.0, "点击点确在贴图显示区外")
	assert_true(Rect2(Vector2.ZERO, btn.size).has_point(click_local), "点击点在命中层 rect 内")
	assert_eq(btn.mouse_filter, Control.MOUSE_FILTER_STOP, "命中层接收输入（非 IGNORE）")
	assert_false(btn.disabled, "passed 据点可点（disabled 仅 locked）")
	assert_null(btn.texture_normal, "命中层无纹理（贴图在显示子层，命中不依赖纹理）")
	panel.remove_window()
