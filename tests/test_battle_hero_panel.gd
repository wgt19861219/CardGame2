extends GutTest
# Phase 4 hero_panel 测试（2026-07-02）。
# 验 BattleHeroPanel：装配（hp_bar/mp_bar/portrait/frame_btn/redmask）+ update state 切换
#   （cast/trigger/switch）+ 死亡变灰 + hp_low redmask + castHandler（frame_btn→unit.cast_manual_skill）。
# MockUnit/MockEngine duck-type（避真 unit cast_manual_skill 完整链复杂，照 test_battle_loot_view 模式）。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func after_all() -> void:
	UnitSprite.clear_atlas_cache()


class MockEngine:
	extends RefCounted
	var ticks: int = 0
	var running: bool = true
	var arena_mode: bool = false
	var replay_mode: bool = false


class MockSkill:
	extends RefCounted
	var can_trigger_ret: bool = true
	var will_cast_ret: bool = true
	func can_trigger() -> bool:
		return can_trigger_ret
	func will_cast() -> bool:
		return will_cast_ret


class MockUnit:
	extends RefCounted
	var tid: int = 1
	var stars: int = 1
	var camp: int = 1
	var rank: int = 1
	var info: Dictionary = {"MP Type": "MP"}
	var engine: Variant = null
	var can_cast_manual: bool = false
	var current_skill: Variant = null
	var hp_low: bool = false
	var mp: int = 1000
	var manual_skill: Variant = null
	var alive: bool = true
	var cast_called: bool = false
	var hp: float = 1000.0            # FloatingBar._refresh_percent 访问
	var attribs: Dictionary = {"HP": 1000.0}
	var buff_list: Array = []
	func is_alive() -> bool:
		return alive
	func is_hero() -> bool:
		return true
	func cast_manual_skill() -> void:
		cast_called = true


func _make_panel(u: MockUnit) -> BattleHeroPanel:
	u.engine = MockEngine.new()
	var panel := BattleHeroPanel.new()
	panel.setup(u, cm, null)
	return panel


# 源 HeroPanelCreate :8-78 — 装配 hp_bar/mp_bar/portrait/frame_btn/redmask。
func test_panel_assembles() -> void:
	var u := MockUnit.new()
	var panel := _make_panel(u)
	assert_not_null(panel.hp_bar, "hp_bar 装配（源 :15）")
	assert_not_null(panel.mp_bar, "mp_bar 装配（源 :16）")
	assert_not_null(panel.portrait, "portrait 装配（源 :17）")
	assert_not_null(panel.frame_btn, "frame_btn 装配（源 :38）")
	assert_not_null(panel.redmask, "redmask 装配（源 :72）")
	assert_eq(panel.frame_btn.disabled, true, "初始 frame_btn disabled（源 :62）")
	panel.queue_free()


# 源 update :97-99 — can_cast_manual + running → state cast。
func test_panel_update_cast_state() -> void:
	var u := MockUnit.new()
	u.can_cast_manual = true
	u.mp = 2000   # >= 1000 保持 cast（非 switch）
	var panel := _make_panel(u)
	panel.update(0.0)
	assert_eq(panel._state, "cast", "can_cast_manual+running → state cast（源 :98）")
	assert_eq(panel.frame_btn.disabled, false, "cast → frame_btn enabled（源 :106）")
	panel.queue_free()


# 源 :100-102 — current_skill canTrigger → state trigger。
func test_panel_update_trigger_state() -> void:
	var u := MockUnit.new()
	u.current_skill = MockSkill.new()
	var panel := _make_panel(u)
	panel.update(0.0)
	assert_eq(panel._state, "trigger", "current_skill canTrigger → state trigger（源 :101）")
	panel.queue_free()


# 源 :103-105 — cast + mp<1000 → state switch。
func test_panel_update_switch_state() -> void:
	var u := MockUnit.new()
	u.can_cast_manual = true
	u.mp = 500   # < 1000
	var panel := _make_panel(u)
	panel.update(0.0)
	assert_eq(panel._state, "switch", "cast + mp<1000 → state switch（源 :104）")
	panel.queue_free()


# 源 :123-126 — 死亡变灰 portrait.ori_icon setColor(100,100,100)。
func test_panel_dead_gray() -> void:
	var u := MockUnit.new()
	u.alive = false
	var panel := _make_panel(u)
	panel.update(0.0)
	assert_eq(panel.portrait.ori_icon.modulate, Color(100.0/255.0, 100.0/255.0, 100.0/255.0), "死亡 → portrait 变灰（源 :125）")
	assert_eq(panel.redmask.visible, false, "死亡 → redmask 隐（源 :124）")
	panel.queue_free()


# 源 :122 — hp_low → redmask 显。
func test_panel_hp_low_redmask() -> void:
	var u := MockUnit.new()
	u.hp_low = true
	var panel := _make_panel(u)
	panel.update(0.0)
	assert_eq(panel.redmask.visible, true, "hp_low → redmask 显（源 :122）")
	panel.queue_free()


# 源 :45-58 castHandler — frame_btn pressed → unit.cast_manual_skill + btn disabled。
func test_panel_frame_pressed_casts() -> void:
	var u := MockUnit.new()
	u.can_cast_manual = true
	u.mp = 2000
	var panel := _make_panel(u)
	panel.update(0.0)   # state cast → frame_btn enabled
	assert_eq(panel.frame_btn.disabled, false, "cast state → enabled")
	panel._on_frame_pressed()   # 模拟点击 frame_btn（源 castHandler）
	assert_true(u.cast_called, "frame_pressed → unit.cast_manual_skill（源 :47）")
	assert_eq(panel.frame_btn.disabled, true, "castHandler → frame_btn disabled（源 :48）")
	panel.queue_free()


# ── 战斗加速同步（2026-08-19）──

# 能量/血条渐追只允许 ui_list 单链路驱动（scene._advance_ui_list 加速 dt → update 末尾）。
# 曾有 _process(delta) 用未加速真实帧 delta 双驱动：2x 下每帧推进 INC*(delta+2delta)=3 份
# vs 1x 的 2 份，观感仅 1.5x（"能量条速度没两倍"根因）。守护：脚本不得再定义 _process。
func test_panel_no_process_double_drive() -> void:
	var u := MockUnit.new()
	var panel := _make_panel(u)
	assert_false(panel.get_script().has_method("_process"),
		"hero_panel 禁自定义 _process 驱动条（与 ui_list 加速链双驱动稀释倍率）")
	panel.queue_free()


# update(dt) 单次调用 → mp 渐追精确推进 MP_INC_SPEED*dt（单链路推进量锚点）。
func test_panel_update_advances_mp_bar_single_source() -> void:
	var u := MockUnit.new()
	u.attribs["MP"] = 1000.0
	u.mp = 500   # percent = 0.5
	var panel := _make_panel(u)
	panel.mp_bar.set("_fore_length", 0.0)
	panel.update(0.1)
	assert_almost_eq(float(panel.mp_bar.get("_fore_length")), 0.2, 0.0001,
		"update(0.1) 应单次推进渐追 MP_INC_SPEED*0.1=0.2（双驱动会推进 0.4）")
	panel.queue_free()


# apply_speed 切速同步 ready 光圈（scene._on_speed_changed → panel.apply_speed 链）。
func test_panel_apply_speed_sets_ready_effect() -> void:
	var u := MockUnit.new()
	u.can_cast_manual = true
	u.mp = 2000
	var panel := _make_panel(u)
	panel.apply_speed(2.0)   # _skill_ready_eff 未建时应静默不崩
	assert_null(panel.get("_skill_ready_eff"), "未播光圈时 apply_speed 不崩")
	panel.update(0.0)   # state cast → _play_skill_ready 建光圈
	var eff: Variant = panel.get("_skill_ready_eff")
	assert_not_null(eff, "cast state 应创建 ready 光圈 BattleEffect")
	panel.apply_speed(3.0)
	if eff != null:
		assert_eq(eff.get("_fca").get("_speed"), 3.0, "apply_speed 应同步光圈 fca 速度")
	panel.queue_free()


# ── 光圈挂载与定位（2026-08-19 紫色边框错位修复）──
# 源 hero_panel.lua:157/172 effect 挂 self.btn + setContent(ccp(36,31))；本项目等效=挂
# frame_btn + frame 贴图中心 (53,53)（FCA 内容中心≈节点原点，headless 实测）。
# 曾错挂 panel 原点无定位 → 紫色光圈（will_ready/can_switch）飘在面板左上角。

func test_ready_glow_mounts_on_frame_btn_centered() -> void:
	var u := MockUnit.new()
	u.can_cast_manual = true
	u.mp = 2000
	var panel := _make_panel(u)
	panel.update(0.0)   # state cast → _play_skill_ready
	var glow: Variant = panel.get("_skill_ready_effect")
	assert_not_null(glow, "cast state 应创建 ready 光圈节点")
	if glow == null:
		panel.queue_free()
		return
	assert_eq(glow.get_parent(), panel.frame_btn, "ready 光圈应挂 frame_btn（源 self.btn:addChild）")
	assert_eq(glow.position, panel.GLOW_POS, "ready 光圈应按内容中心校准定位（Loop 期中心对准按钮中心）")
	panel.queue_free()


func test_cast_glow_mounts_on_frame_btn_centered() -> void:
	var u := MockUnit.new()
	u.can_cast_manual = true
	u.mp = 2000
	var panel := _make_panel(u)
	panel.update(0.0)   # state cast → frame_btn enabled
	panel._on_frame_pressed()   # castHandler → _play_skill_cast_effect
	# 光圈节点是 FcaAnimation（带脚本）；同挂 frame_btn 的 Redmask 是 tscn 纯 Sprite2D（无脚本）
	var found: int = 0
	for child in panel.frame_btn.get_children():
		if child.get_script() != null and not child.is_queued_for_deletion():
			found += 1
			assert_eq(child.position, panel.GLOW_CAST_POS, "cast 光圈应按内容中心校准定位（-3.1,-33.9 补偿）")
	assert_eq(found, 1, "cast 光圈应挂 frame_btn 恰 1 个（不闪删）")
	panel.queue_free()


# 源 play_skill_cast_effect 开头 disable_cast + update newState==nil 分支 disable_cast：
# 施法/状态消退时 ready 光圈（紫色）须清，否则放完大招紫圈残留。
func test_cast_clears_ready_glow() -> void:
	var u := MockUnit.new()
	u.can_cast_manual = true
	u.mp = 2000
	var panel := _make_panel(u)
	panel.update(0.0)   # state cast → ready 光圈
	assert_not_null(panel.get("_skill_ready_effect"), "cast state 应有 ready 光圈")
	panel._on_frame_pressed()   # 施法 → _play_skill_cast_effect 开头 disable_cast
	assert_null(panel.get("_skill_ready_effect"), "施法应清 ready 光圈（源 disable_cast）")
	# 状态消退（mp 花掉 → state NONE）也应清
	panel.update(0.0)
	panel._play_skill_ready("")   # 显式 STATE_NONE 路径
	assert_null(panel.get("_skill_ready_effect"), "state NONE 应清光圈")
	panel.queue_free()
