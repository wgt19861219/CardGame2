extends GutTest
# 切波能量保留守卫（2026-08-18 用户实跑"切波能量条清零"根因修复）：
# 源 unit.lua:54-57 initHpMpInfo 的 hpmpInited 守卫漏译——reset_unit_list 切波
# reset 把玩家 mp 重置初始值。守卫补回后：同对象 reset 不清 hp/mp；新 unit 首次 init 正常。


func test_wave_reset_preserves_player_mp() -> void:
	var cm := ConfigManager.new()
	cm.load_all()
	var mgr := StageManager.new(cm)
	mgr.skill_lib = GameData.skills   # 注入（战斗缠绕同款教训：裸建 mgr 无 lib 单位无技能）
	var r: Dictionary = mgr.assemble_stage_battle(1, GameData.player, [1, 2, 3, 4, 5], BattleRng.new(7))
	if not bool(r.get("ok", false)):
		fail_test("stage1 装配失败: %s" % str(r.get("error", "")))
		return
	var eng: BattleEngine = r["engine"]
	var hero: Variant = null
	for u in eng.foreach_alive_unit(BattleEngine.CAMP_PLAYER):
		hero = u
		break
	if hero == null:
		fail_test("无玩家单位")
		return
	var mp_max: int = int(hero.attribs.get("MP", 1))
	# 真实链前置：开局 supply（battle_start 即跑、supplied=true）——否则 next_battle 首跑补 supply，
	# MPS 回蓝（lvl≥成长阈值时 >0）混进 mp 断言（2026-08-29 存档态触发实证，+15=mps×1.0）。
	eng.battle_supply()
	hero.set_mp(int(mp_max * 0.6))
	var before: int = int(hero.mp)
	var hp_before: int = int(hero.hp)
	# 模拟 View 切波链的 Logic 侧（battle_wave_advancer.advance_wave → next_battle）
	BattleEngineWaves.next_battle(eng, cm)
	assert_eq(int(hero.mp), before, "切波后玩家 mp 保留（源 hpmpInited 守卫语义）")
	assert_eq(int(hero.hp), hp_before, "切波后玩家 hp 同样保留")


func test_new_unit_first_init_still_runs() -> void:
	# 新 unit（跨关新战斗/每波新怪）首次 init 不受守卫拦截
	var cm := ConfigManager.new()
	cm.load_all()
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(1)
	var u := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_rank": true}, cm, eng, {}, null)
	assert_true(u.hpmp_inited, "首次 init 后守卫置位")
	assert_eq(int(u.mp), 0, "新英雄 dyna 空 → 初始 mp=0（首关能量从零开始）")
	assert_gt(int(u.hp), 0, "新英雄 hp 按 attribs 正常初始化")


# 2026-08-18 二轮：能量满超框（变长）+ 大招不放。
func test_reset_reclamps_mp_to_rebuilt_cap() -> void:
	# rebuild 清 buff 后 MP 上限回落，保留 mp 须重钳（防 percent>1 条超底板）
	var cm := ConfigManager.new()
	cm.load_all()
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(1)
	var u := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_rank": true}, cm, eng, {}, null)
	var mp_max: int = int(u.attribs.get("MP", 1))
	u.mp = mp_max * 2   # 直接赋值绕钳，模拟"buff 期上限增益下攒到的高值 mp 活到切波"
	u.reset()
	assert_lte(int(u.mp), int(u.attribs.get("MP", mp_max)), "reset 后 mp 重钳 ≤ 当前上限（条不超框）")


func test_stage_player_auto_casts_manual_skill() -> void:
	# 源 PVE 默认 will_cast_manual_skill=true（旧错译 false 致大招永不放）
	var cm := ConfigManager.new()
	cm.load_all()
	var mgr := StageManager.new(cm)
	mgr.skill_lib = GameData.skills
	var r: Dictionary = mgr.assemble_stage_battle(1, GameData.player, [1], BattleRng.new(7))
	if not bool(r.get("ok", false)):
		fail_test("stage1 装配失败")
		return
	for u in r["engine"].foreach_alive_unit(BattleEngine.CAMP_PLAYER):
		assert_true(bool(u.ai.will_cast_manual_skill), "战役玩家 AI 自动放 manual 大招（源 :455-459 默认）")


func test_stage_player_has_manual_skill_equipped() -> void:
	# 源 main.lua:1590 玩家 proto 须带 _skill_levels（漏传致只装 Basic Skill 无大招）
	var cm := ConfigManager.new()
	cm.load_all()
	var mgr := StageManager.new(cm)
	mgr.skill_lib = GameData.skills
	var r: Dictionary = mgr.assemble_stage_battle(1, GameData.player, [1, 2, 3, 4, 5], BattleRng.new(7))
	if not bool(r.get("ok", false)):
		fail_test("stage1 装配失败")
		return
	var any_manual: bool = false
	var any_multi: bool = false
	for u in r["engine"].foreach_alive_unit(BattleEngine.CAMP_PLAYER):
		if u.skill_list.size() > 1:
			any_multi = true
		if u.manual_skill != null:
			any_manual = true
	assert_true(any_multi, "玩家英雄技能数 >1（_skill_levels 装配）")
	assert_true(any_manual, "玩家英雄大招（manual_skill）已装备")


func test_mp_float_accumulation_reaches_cap() -> void:
	# 源 lua mp 是 float——int 截断会让 0.6/次 的回蓝永久卡 999（Cost 1000 大招差 1 永不放）
	var cm := ConfigManager.new()
	cm.load_all()
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(1)
	var u := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_rank": true}, cm, eng, {}, null)
	var mp_max: float = float(u.attribs.get("MP", 1))
	for i in range(2000):
		u.set_mp(u.mp + 0.6)
	assert_eq(u.mp, mp_max, "0.6/次累积 2000 次必达上限（不卡 999.6）")


# 2026-08-18 三轮：能量条满格超框——hero_panel 误用 FloatingBar 小条（bg 89 < mp_mana 104），
# 源 hero_panel.lua:15-16 两条均 HpBar 大条。守卫：HpBar 系全部 fg 宽 ≤ bg 宽（满格不超框）。
func test_hero_panel_bar_textures_fit() -> void:
	var bg: Texture2D = load("res://assets/ui/alpha/HVGA/hp_gray.png")
	for fg_name in ["hp_green.png", "hp_red.png", "mp_mana.png", "mp_energy.png", "mp_rage.png"]:
		var fg: Texture2D = load("res://assets/ui/alpha/HVGA/" + fg_name)
		assert_lte(fg.get_size().x, bg.get_size().x, fg_name + " 宽 ≤ HpBar bg（满格不超框）")


# 源 hp_bar.lua :61/68/71 fg/mid anchorPoint(0,0)+ccp(6,1)——从 bg 左下内缩。
# 守卫：fg 左上 = bg 左上 + OFFSET(6,1)（旧版直译 OFFSET 致 fg 从 bg 中心起画整条右偏半宽）。
func test_hp_bar_foreground_aligned_to_bg_left() -> void:
	var cm := ConfigManager.new()
	cm.load_all()
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(1)
	var u := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_PLAYER, {"estimate_rank": true}, cm, eng, {}, null)
	var bar: BattleHpBar = BattleHpBar.create(u, "Mana")
	add_child_autofree(bar)
	var bg: Sprite2D = bar.get("_background") as Sprite2D
	var fg: Sprite2D = bar.get("_foreground") as Sprite2D
	if bg == null or fg == null or bg.texture == null or fg.texture == null:
		fail_test("bar 节点/贴图缺失")
		return
	# 显示口径（2026-08-22 巡检根修 + 2026-08-31 空间修正：fg.position 是 bg 局部纹素空间，
	# ×bg.scale 转显示后才=源直译 左上=-half+OFFSET(6,1)；旧断言直比显示值系旧实现
	# 将显示值误填局部空间、fill 被二次缩放实际右移 ~7 逻辑px——本守卫锚显示结果非实现细节）
	var bg_size: Vector2 = bg.texture.get_size() / 1.28125
	var disp: Vector2 = fg.position * bg.scale
	var expect_left: float = -bg_size.x * 0.5 + 6.0   # bg centered=true 原点=中心 → 左上=-half+OFFSET
	assert_almost_eq(disp.x, expect_left, 0.1, "fg 显示左上 x = bg 左缘+6（源直译）")
	assert_almost_eq(disp.y, -bg_size.y * 0.5 + 1.0, 0.1, "fg 显示左上 y = bg 上缘+1")
	assert_lte(disp.x + fg.texture.get_size().x / 1.28125, bg_size.x * 0.5, "fg 满格右缘 ≤ bg 右缘")
