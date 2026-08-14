extends GutTest
# Phase 2.7 英雄 hook 基础设施验证。
# 验证 BattleHeroScripts 分发（阶段三 T2 前为 BattleHeroRegistry） + 英雄脚本 apply 注册 hero_hooks + wrapper 行为（OD INT 免疫）。


class MockSkill:
	extends RefCounted
	var info: Dictionary = {}
	var hero_hooks: Dictionary = {}
	var target: Variant = null
	var caster: Variant = null
	var custom_data: Dictionary = {}  # 英雄 hook 运行时数据（SF current_num / Tiny thrown_unit）
	var start_default_arg: Variant = "_NOT_CALLED"  # 捕获 _start_default 传参（TitanHead atk6 null 验证）
	func _start_default(p_target: Variant) -> void:
		start_default_arg = p_target


class MockHero:
	extends RefCounted
	var skills: Dictionary = {}
	var hero_hooks: Dictionary = {}  # 单位级 hook（SNK die/update/onActionFinished）
	var config: Dictionary = {"dps_mod": 1.0}  # SilverDragon dps_mod 缩放
	var hp: float = 100.0  # SilverDragon ratio 判定（hp/HP=1.0>0.1 不触发 dps_mod）
	var attribs: Dictionary = {"HP": 100.0}
	var is_disapear_when_die: Variant = null  # SilverDragon setDisapearWhenDie
	var is_boss_create_with_effect: Variant = null  # AncientTreant
	var is_action_stage_change_by_manual: bool = false  # BossSil setActionStageChangeByManual
	var ai: Variant = null  # Troll ai.walkTo hook（MockAi 实例）
	var info: Dictionary = {}  # TB apply hero.info.mDuration
	var custom_data: Dictionary = {}  # TitanHead apply 存 npc_up/down/atk2damage/maxDamage/heroindex
	var proto: Dictionary = {}  # protoAwake 英雄 apply 读 proto（Lina/OK/TH/Ursa/Naga）
	var engine: Variant = null  # TitanHead apply create_npc + rng / Kael apply engine 引用
	# —— Kael apply 设字段（energy_ball_manager/skill_condition/delivered_balls/ai_mode/...）——
	var camp: int = 1
	var energy_ball_manager: Variant = null
	var skill_condition: Dictionary = {}
	var delivered_balls: Dictionary = {}
	var ordered_idx: Array = []
	var is_kael: bool = false
	var display_ball: bool = false
	var ai_mode: bool = false
	var auto_combat: bool = false
	var ult_time: float = 2.0
	var start_ult_time: bool = false
	var level: int = 1  # ExPhoenix apply 读（P1-10 max_shield by level）
	var max_shield: int = 0  # ExPhoenix apply 设（P1-10）
	var show_ball: Variant = null  # Kael apply 设 Callable（P1-5）
	func set_disapear_when_die(b: bool) -> void:
		is_disapear_when_die = b


class MockAi:
	extends RefCounted
	var hero_hooks: Dictionary = {}  # Troll walkTo hook


class MockEngine:
	extends RefCounted
	var rng: BattleRng = BattleRng.new(0)  # TitanHead apply randomHeros randf
	# Kael apply 读 arena_mode/replay_mode，设 player_kael_hero/enemy_kael_hero
	var arena_mode: bool = false
	var replay_mode: bool = false
	var player_kael_hero: Variant = null
	var enemy_kael_hero: Variant = null
	func create_npc(_npc_id: int, _is_flip: bool, _owner: Variant) -> Variant:
		return null  # TitanHead apply npc_up/down（Logic 测试仅验 hook 注册）


# Viper：apply 后 Viper_ult 注册 createProjectile hook。
func test_viper_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Viper_ult"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Viper", hero)
	assert_true(hero.skills["Viper_ult"].hero_hooks.has("createProjectile"), "Viper createProjectile hook 注册")
	assert_true(hero.skills["Viper_ult"].hero_hooks["createProjectile"].is_valid(), "hook Callable 有效")


# Sil：apply 后 Sil_atk3 注册 takeEffectOn hook。
func test_sil_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Sil_atk3"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Sil", hero)
	assert_true(hero.skills["Sil_atk3"].hero_hooks.has("takeEffectOn"), "Sil takeEffectOn hook 注册")


# OD：INT 主属性目标免疫（wrapper 直接 return false，不调 basefunc）。
func test_od_int_immune_returns_false() -> void:
	var hero := MockHero.new()
	var skill := MockSkill.new()
	hero.skills["OD_ult"] = skill
	BattleHeroScripts.apply("battle/heroes/OD", hero)
	var target := MockSkill.new()
	target.info["Main Attrib"] = "INT"
	var h: Callable = skill.hero_hooks["takeEffectOn"]
	var r: Array = h.call(skill, target, null)
	assert_false(bool(r[0]), "OD 对 INT 主属性目标免疫（succ=false，r[0]）")


# 未注册的 Script 路径安全跳过（不报错，hero_hooks 保持空）。
func test_unknown_script_skipped() -> void:
	var hero := MockHero.new()
	hero.skills["Foo_atk"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Unknown", hero)
	assert_false(hero.skills["Foo_atk"].hero_hooks.has("takeEffectOn"), "未知 Script 路径安全跳过")


# Mortar：apply 后 Mortar_atk 注册 createProjectile hook（抛物线 velocity，return projectile）。
func test_mortar_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Mortar_atk"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Mortar", hero)
	assert_true(hero.skills["Mortar_atk"].hero_hooks.has("createProjectile"), "Mortar createProjectile hook 注册")


# Gorilla：apply 后 Gorilla_atk2 注册 createProjectile hook（偏移目标 + 自 add + return null）。
func test_gorilla_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Gorilla_atk2"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Gorilla", hero)
	assert_true(hero.skills["Gorilla_atk2"].hero_hooks.has("createProjectile"), "Gorilla createProjectile hook 注册")


# Archer：apply 后 Archer_atk2 注册 createProjectile hook（抛物线 velocity + 自 add）。
func test_archer_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Archer_atk2"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Archer", hero)
	assert_true(hero.skills["Archer_atk2"].hero_hooks.has("createProjectile"), "Archer createProjectile hook 注册")


# DR：apply 后 DR_ult 注册 createProjectile hook（多发循环 + offset_list 偏移）。
func test_dr_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["DR_ult"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/DR", hero)
	assert_true(hero.skills["DR_ult"].hero_hooks.has("createProjectile"), "DR createProjectile hook 注册")


# Pugna：apply 后 Pugna_ult 注册 takeEffectOn hook（addBuff→basefunc→removeBuff，cm 查 Buff 17）。
func test_pugna_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Pugna_ult"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Pugna", hero)
	assert_true(hero.skills["Pugna_ult"].hero_hooks.has("takeEffectOn"), "Pugna takeEffectOn hook 注册")


# Razor：apply 后 Razor_atk3 注册 takeEffectOn hook（basefunc→查 Buff AD 取负→addBuff）。
func test_razor_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Razor_atk3"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Razor", hero)
	assert_true(hero.skills["Razor_atk3"].hero_hooks.has("takeEffectOn"), "Razor takeEffectOn hook 注册")


# Huskar：apply 后 Huskar_ult 注册 takeEffectOn hook（counter==1 冲撞 / else 自残+buff+basefunc）。
func test_huskar_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Huskar_ult"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Huskar", hero)
	assert_true(hero.skills["Huskar_ult"].hero_hooks.has("takeEffectOn"), "Huskar takeEffectOn hook 注册")


# QOP：apply 后 QOP_atk3 注册 start hook（basefunc → 查 Buff → addBuff，cm 查表）。
func test_qop_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["QOP_atk3"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/QOP", hero)
	assert_true(hero.skills["QOP_atk3"].hero_hooks.has("start"), "QOP start hook 注册")


# Panda：apply 后 Panda_ult 注册 onAttackFrame hook（counter 分支 wraptable 覆盖 info）。
func test_panda_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Panda_ult"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Panda", hero)
	assert_true(hero.skills["Panda_ult"].hero_hooks.has("onAttackFrame"), "Panda onAttackFrame hook 注册")


# CW：apply 后 CW_atk3 注册 start + onAttackFrame hook（传送 + 冲撞 + counter==2 basefunc）。
func test_cw_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["CW_atk3"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/CW", hero)
	assert_true(hero.skills["CW_atk3"].hero_hooks.has("start"), "CW start hook 注册")
	assert_true(hero.skills["CW_atk3"].hero_hooks.has("onAttackFrame"), "CW onAttackFrame hook 注册")


# POM：apply 后 POM_atk2 注册 start + onAttackFrame hook（传送 + phase.duration 算冲撞速度）。
func test_pom_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["POM_atk2"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/POM", hero)
	assert_true(hero.skills["POM_atk2"].hero_hooks.has("start"), "POM start hook 注册")
	assert_true(hero.skills["POM_atk2"].hero_hooks.has("onAttackFrame"), "POM onAttackFrame hook 注册")


# Axe：apply 后 Axe_ult 注册 takeEffectOn + willCast hook（斩杀线强化 + 击杀回 mp）。
func test_axe_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Axe_ult"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Axe", hero)
	assert_true(hero.skills["Axe_ult"].hero_hooks.has("takeEffectOn"), "Axe takeEffectOn hook 注册")
	assert_true(hero.skills["Axe_ult"].hero_hooks.has("willCast"), "Axe willCast hook 注册")


# OM：apply 后 OM_ult/atk2/atk3 各注册 hook（multicast：rand 次数循环/多目标）。
func test_om_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["OM_ult"] = MockSkill.new()
	hero.skills["OM_atk2"] = MockSkill.new()
	hero.skills["OM_atk3"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/OM", hero)
	assert_true(hero.skills["OM_ult"].hero_hooks.has("takeEffectOn"), "OM_ult takeEffectOn hook 注册")
	assert_true(hero.skills["OM_atk2"].hero_hooks.has("createProjectile"), "OM_atk2 createProjectile hook 注册")
	assert_true(hero.skills["OM_atk3"].hero_hooks.has("takeEffectOn"), "OM_atk3 takeEffectOn hook 注册")


# Lich：apply 后 Lich_ult 注册 createProjectile hook（enableJump+enableTrack+覆盖 findNextTaeget）。
func test_lich_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Lich_ult"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Lich", hero)
	assert_true(hero.skills["Lich_ult"].hero_hooks.has("createProjectile"), "Lich createProjectile hook 注册")


# JUGG：apply 后 JUGG_ult（start/onAttackFrame/takeEffectOn）+ JUGG_atk2（start/onAttackFrame/finish）注册。
func test_jugg_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["JUGG_ult"] = MockSkill.new()
	hero.skills["JUGG_atk2"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/JUGG", hero)
	assert_true(hero.skills["JUGG_ult"].hero_hooks.has("start"), "JUGG_ult start hook 注册")
	assert_true(hero.skills["JUGG_atk2"].hero_hooks.has("finish"), "JUGG_atk2 finish hook 注册")


# Coco：apply 后 Coco_ult 注册 launchPoint hook（X 偏移 -400·direction + height=10）。
func test_coco_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Coco_ult"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Coco", hero)
	assert_true(hero.skills["Coco_ult"].hero_hooks.has("launchPoint"), "Coco launchPoint hook 注册")


# AM：apply 后 AM_ult（takeEffectAt）+ AM_atk2（start/takeEffectAt/takeEffectOn）注册。
func test_am_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["AM_ult"] = MockSkill.new()
	hero.skills["AM_atk2"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/AM", hero)
	assert_true(hero.skills["AM_ult"].hero_hooks.has("takeEffectAt"), "AM_ult takeEffectAt hook 注册")
	assert_true(hero.skills["AM_atk2"].hero_hooks.has("start"), "AM_atk2 start hook 注册")


# Bone：apply 后 Bone_awake 注册 selectTarget + onAttackFrame hook（吞噬召唤物）。
func test_bone_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Bone_awake"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Bone", hero)
	assert_true(hero.skills["Bone_awake"].hero_hooks.has("selectTarget"), "Bone selectTarget hook 注册")
	assert_true(hero.skills["Bone_awake"].hero_hooks.has("onAttackFrame"), "Bone onAttackFrame hook 注册")


# Footman：apply 后 Footman_atk2 注册 createBuff hook（buff 创建后设 onRemoved，移除时 AOE 爆发）。
func test_footman_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Footman_atk2"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Footman", hero)
	assert_true(hero.skills["Footman_atk2"].hero_hooks.has("createBuff"), "Footman createBuff hook 注册")


# LOA：apply 后 LOA_ult/atk3 注册 createBuff + LOA_atk2 takeEffectOn（buff onDamaged/onRemoved）。
func test_loa_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["LOA_ult"] = MockSkill.new()
	hero.skills["LOA_atk2"] = MockSkill.new()
	hero.skills["LOA_atk3"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/LOA", hero)
	assert_true(hero.skills["LOA_ult"].hero_hooks.has("createBuff"), "LOA_ult createBuff hook 注册")
	assert_true(hero.skills["LOA_atk2"].hero_hooks.has("takeEffectOn"), "LOA_atk2 takeEffectOn hook 注册")
	assert_true(hero.skills["LOA_atk3"].hero_hooks.has("createBuff"), "LOA_atk3 createBuff hook 注册")


# Sorceress：apply 后 Sorceress_atk2 注册 createBuff hook（飞行单位 → Buff 110）。
func test_sorceress_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Sorceress_atk2"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Sorceress", hero)
	assert_true(hero.skills["Sorceress_atk2"].hero_hooks.has("createBuff"), "Sorceress createBuff hook 注册")


# SNK：apply 后注册单位级 die/onActionFinished/update hook（首次死亡重生倒计时复活）。
func test_snk_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["SNK_pasv2"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/SNK", hero)
	assert_true(hero.hero_hooks.has("die"), "SNK die hook 注册")
	assert_true(hero.hero_hooks.has("onActionFinished"), "SNK onActionFinished hook 注册")
	assert_true(hero.hero_hooks.has("update"), "SNK update hook 注册")


# Ench：apply 后 Ench_atk3 注册 takeEffectOn hook（basefunc 后清 target cd）。
func test_ench_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Ench_atk3"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Ench", hero)
	assert_true(hero.skills["Ench_atk3"].hero_hooks.has("takeEffectOn"), "Ench takeEffectOn hook 注册")


# SP：apply 后 SP_atk3 注册 createBuff hook（保 1 血护盾 onDamaged）。
func test_sp_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["SP_atk3"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/SP", hero)
	assert_true(hero.skills["SP_atk3"].hero_hooks.has("createBuff"), "SP createBuff hook 注册")


# THD：apply 后 THD_ult 注册 createBuff hook（到期追加 Buff 70）。
func test_thd_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["THD_ult"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/THD", hero)
	assert_true(hero.skills["THD_ult"].hero_hooks.has("createBuff"), "THD createBuff hook 注册")


# VS：apply 后 VS_ult 注册 takeEffectOn hook（概率互换位置 + VS_atk2 追踪弹）。
func test_vs_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["VS_ult"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/VS", hero)
	assert_true(hero.skills["VS_ult"].hero_hooks.has("takeEffectOn"), "VS takeEffectOn hook 注册")


# Sniper：apply 后 Sniper_ult(start) + Sniper_atk3(createProjectile) + 单位 castManualSkill 注册。
func test_sniper_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Sniper_ult"] = MockSkill.new()
	hero.skills["Sniper_atk3"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Sniper", hero)
	assert_true(hero.skills["Sniper_ult"].hero_hooks.has("start"), "Sniper_ult start hook 注册")
	assert_true(hero.skills["Sniper_atk3"].hero_hooks.has("createProjectile"), "Sniper_atk3 createProjectile hook 注册")
	assert_true(hero.hero_hooks.has("castManualSkill"), "Sniper castManualSkill hook 注册")


# SuicideGoblinjr：apply 后 SuicideGoblinjr_atk 注册 start + takeEffectAt hook（自爆）。
func test_suicidegoblinjr_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["SuicideGoblinjr_atk"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/SuicideGoblinjr", hero)
	assert_true(hero.skills["SuicideGoblinjr_atk"].hero_hooks.has("start"), "SuicideGoblinjr start hook 注册")
	assert_true(hero.skills["SuicideGoblinjr_atk"].hero_hooks.has("takeEffectAt"), "SuicideGoblinjr takeEffectAt hook 注册")


# NEC：apply 后 NEC_ult(castManualSkill/takeEffectOn/update/start) + NEC_atk2(takeEffectOn/createProjectile) 注册。
func test_nec_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["NEC_ult"] = MockSkill.new()
	hero.skills["NEC_atk2"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/NEC", hero)
	assert_true(hero.hero_hooks.has("castManualSkill"), "NEC castManualSkill hook 注册")
	assert_true(hero.skills["NEC_ult"].hero_hooks.has("takeEffectOn"), "NEC_ult takeEffectOn hook 注册")
	assert_true(hero.skills["NEC_ult"].hero_hooks.has("update"), "NEC_ult update hook 注册")
	assert_true(hero.skills["NEC_atk2"].hero_hooks.has("createProjectile"), "NEC_atk2 createProjectile hook 注册")


# Tiny：apply 后 Tiny_ult 注册 onAttackFrame + update hook（投掷单位击退结束 AOE）。
func test_tiny_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Tiny_ult"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Tiny", hero)
	assert_true(hero.skills["Tiny_ult"].hero_hooks.has("onAttackFrame"), "Tiny onAttackFrame hook 注册")
	assert_true(hero.skills["Tiny_ult"].hero_hooks.has("update"), "Tiny update hook 注册")


# Luna：apply 后 Luna_ult(start) + Luna_atk3(createProjectile/power/takeEffectOn) 注册。
func test_luna_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Luna_ult"] = MockSkill.new()
	hero.skills["Luna_atk3"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Luna", hero)
	assert_true(hero.skills["Luna_ult"].hero_hooks.has("start"), "Luna_ult start hook 注册")
	assert_true(hero.skills["Luna_atk3"].hero_hooks.has("createProjectile"), "Luna_atk3 createProjectile hook 注册")
	assert_true(hero.skills["Luna_atk3"].hero_hooks.has("power"), "Luna_atk3 power hook 注册")


# Med：apply 后 Med_atk2(createProjectile/power) + Med_atk3(takeEffectAt) 注册。
func test_med_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Med_atk2"] = MockSkill.new()
	hero.skills["Med_atk3"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Med", hero)
	assert_true(hero.skills["Med_atk2"].hero_hooks.has("createProjectile"), "Med_atk2 createProjectile hook 注册")
	assert_true(hero.skills["Med_atk2"].hero_hooks.has("power"), "Med_atk2 power hook 注册")
	assert_true(hero.skills["Med_atk3"].hero_hooks.has("takeEffectAt"), "Med_atk3 takeEffectAt hook 注册")


# SF：apply 后注册单位 update/handleUnitDieEvent + SF_atk2(takeEffectAt/finish) hook。
# ⚠️ SF_ult.power 是源死代码（SF.lua:25-32 定义但 init_hero :49-58 未 override），照源不挂（第七轮 P0，[[source-dead-code-activation]]）。
func test_sf_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["SF_ult"] = MockSkill.new()
	hero.skills["SF_atk2"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/SF", hero)
	assert_true(hero.hero_hooks.has("update"), "SF update hook 注册")
	assert_true(hero.hero_hooks.has("handleUnitDieEvent"), "SF handleUnitDieEvent hook 注册")
	assert_false(hero.skills["SF_ult"].hero_hooks.has("power"), "SF_ult power 死代码不挂（源 init_hero 未 override）→ 走默认 power")
	assert_true(hero.skills["SF_atk2"].hero_hooks.has("finish"), "SF_atk2 finish hook 注册")


# Spider：apply 后 Spider_atk2 注册 createBuff + canCastWithTarget hook（低血急救 + 受控移除）。
func test_spider_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Spider_atk2"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Spider", hero)
	assert_true(hero.skills["Spider_atk2"].hero_hooks.has("createBuff"), "Spider createBuff hook 注册")
	assert_true(hero.skills["Spider_atk2"].hero_hooks.has("canCastWithTarget"), "Spider canCastWithTarget hook 注册")


# SilverDragon：apply 后 atk2_ice/atk_ice 注册 createBuff hook（frozen/MSPD 分支）。
func test_silverdragon_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["SilverDragon_atk2_ice"] = MockSkill.new()
	hero.skills["SilverDragon_atk_ice"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/SilverDragon", hero)
	assert_true(hero.skills["SilverDragon_atk2_ice"].hero_hooks.has("createBuff"), "SilverDragon atk2_ice createBuff hook 注册")
	assert_true(hero.skills["SilverDragon_atk_ice"].hero_hooks.has("createBuff"), "SilverDragon atk_ice createBuff hook 注册")


# WD：apply 后 WD_atk3(createProjectile/power/getDamage/createBuff) + WD_atk4(selectTarget) + WD_ult(start) 注册。
func test_wd_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["WD_atk3"] = MockSkill.new()
	hero.skills["WD_atk4"] = MockSkill.new()
	hero.skills["WD_ult"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/WD", hero)
	assert_true(hero.skills["WD_atk3"].hero_hooks.has("createProjectile"), "WD_atk3 createProjectile hook 注册")
	assert_true(hero.skills["WD_atk3"].hero_hooks.has("getDamage"), "WD_atk3 getDamage hook 注册")
	assert_true(hero.skills["WD_atk3"].hero_hooks.has("createBuff"), "WD_atk3 createBuff hook 注册")
	assert_true(hero.skills["WD_atk4"].hero_hooks.has("selectTarget"), "WD_atk4 selectTarget hook 注册")
	assert_true(hero.skills["WD_ult"].hero_hooks.has("start"), "WD_ult start hook 注册")


# Troll：apply 后 ai.hero_hooks 注册 walkTo（后排单位近战射程）。
func test_troll_hook_registered() -> void:
	var hero := MockHero.new()
	hero.ai = MockAi.new()
	hero.skills["Troll_atk3"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Troll", hero)
	assert_true(hero.ai.hero_hooks.has("walkTo"), "Troll ai.walkTo hook 注册")


# AncientTreant：apply 后 atk(createProjectile) + atk6(start/finish) 注册 hook。
func test_ancienttreant_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["AncientTreant_atk"] = MockSkill.new()
	hero.skills["AncientTreant_atk6"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/AncientTreant", hero)
	assert_true(hero.skills["AncientTreant_atk"].hero_hooks.has("createProjectile"), "AncientTreant atk createProjectile hook 注册")
	assert_true(hero.skills["AncientTreant_atk6"].hero_hooks.has("finish"), "AncientTreant atk6 finish hook 注册")


# KOTL：apply 后 KOTL_ult 注册 canTrigger/onAttackFrame/trigger/interrupt/power hook（蓄力大招流程）+ info No Speeder。
func test_kotl_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["KOTL_ult"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/KOTL", hero)
	assert_true(hero.skills["KOTL_ult"].hero_hooks.has("canTrigger"), "KOTL canTrigger hook 注册")
	assert_true(hero.skills["KOTL_ult"].hero_hooks.has("trigger"), "KOTL trigger hook 注册")
	assert_true(hero.skills["KOTL_ult"].hero_hooks.has("interrupt"), "KOTL interrupt hook 注册")
	assert_true(hero.skills["KOTL_ult"].hero_hooks.has("power"), "KOTL power hook 注册")
	assert_true(bool(hero.skills["KOTL_ult"].info.get("No Speeder", false)), "KOTL info No Speeder=true")


# TA：apply 后 TA_ult(selectTarget/takeEffectAt/start/power) + TA_atk2(createBuff) + TA_atk4(power) + 单位 handleUnitDieEvent 注册。
func test_ta_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["TA_ult"] = MockSkill.new()
	hero.skills["TA_atk2"] = MockSkill.new()
	hero.skills["TA_atk4"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/TA", hero)
	assert_true(hero.hero_hooks.has("handleUnitDieEvent"), "TA handleUnitDieEvent hook 注册")
	assert_true(hero.skills["TA_ult"].hero_hooks.has("selectTarget"), "TA_ult selectTarget hook 注册")
	assert_true(hero.skills["TA_ult"].hero_hooks.has("takeEffectAt"), "TA_ult takeEffectAt hook 注册")
	assert_true(hero.skills["TA_atk2"].hero_hooks.has("createBuff"), "TA_atk2 createBuff hook 注册")
	assert_true(hero.skills["TA_atk4"].hero_hooks.has("power"), "TA_atk4 power hook 注册")


# DP：apply 后 DP_ult 注册 createBuff hook（buff.update 周期 AP 累计 total_dmg，onRemoved 治疗 total_dmg*0.5）。
func test_dp_hook_registered() -> void:
	var hero := MockHero.new()
	hero.skills["DP_ult"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/DP", hero)
	assert_true(hero.skills["DP_ult"].hero_hooks.has("createBuff"), "DP createBuff hook 注册")


# TK：apply 后 TK_ult（onAttackFrame + createProjectile）+ TK_atk3（createProjectile）注册。
func test_tk_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["TK_ult"] = MockSkill.new()
	hero.skills["TK_atk3"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/TK", hero)
	assert_true(hero.skills["TK_ult"].hero_hooks.has("onAttackFrame"), "TK_ult onAttackFrame hook 注册")
	assert_true(hero.skills["TK_ult"].hero_hooks.has("createProjectile"), "TK_ult createProjectile hook 注册")
	assert_true(hero.skills["TK_atk3"].hero_hooks.has("createProjectile"), "TK_atk3 createProjectile hook 注册")


# Necromancersr：apply 后 Necromancersr_atk2 注册 selectTarget/onAttackFrame/takeEffectOn/targetSelector hook（对尸体召唤骷髅）。
func test_necromancersr_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Necromancersr_atk2"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Necromancersr", hero)
	assert_true(hero.skills["Necromancersr_atk2"].hero_hooks.has("selectTarget"), "Necromancersr selectTarget hook 注册")
	assert_true(hero.skills["Necromancersr_atk2"].hero_hooks.has("onAttackFrame"), "Necromancersr onAttackFrame hook 注册")
	assert_true(hero.skills["Necromancersr_atk2"].hero_hooks.has("takeEffectOn"), "Necromancersr takeEffectOn hook 注册")
	assert_true(hero.skills["Necromancersr_atk2"].hero_hooks.has("targetSelector"), "Necromancersr targetSelector hook 注册")


# WL：apply 后 WL_ult(createProjectile/takeEffectAt) + WL_atk2(createBuff) + 单位 die 注册（召唤地狱火）。
func test_wl_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["WL_ult"] = MockSkill.new()
	hero.skills["WL_atk2"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/WL", hero)
	assert_true(hero.skills["WL_ult"].hero_hooks.has("createProjectile"), "WL_ult createProjectile hook 注册")
	assert_true(hero.skills["WL_ult"].hero_hooks.has("takeEffectAt"), "WL_ult takeEffectAt hook 注册")
	assert_true(hero.skills["WL_atk2"].hero_hooks.has("createBuff"), "WL_atk2 createBuff hook 注册")
	assert_true(hero.hero_hooks.has("die"), "WL die hook 注册")


# TB：apply 后 TB_ult(createBuff/canCastWithTarget/finish/start/takeEffectOn) + TB_atk2(takeEffectAt) + TB_atk3(takeEffectOn/canCastWithTarget) 注册（变身+幻象）。
func test_tb_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["TB_ult"] = MockSkill.new()
	hero.skills["TB_atk2"] = MockSkill.new()
	hero.skills["TB_atk3"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/TB", hero)
	assert_true(hero.skills["TB_ult"].hero_hooks.has("createBuff"), "TB_ult createBuff hook 注册")
	assert_true(hero.skills["TB_ult"].hero_hooks.has("canCastWithTarget"), "TB_ult canCastWithTarget hook 注册")
	assert_true(hero.skills["TB_ult"].hero_hooks.has("finish"), "TB_ult finish hook 注册")
	assert_true(hero.skills["TB_ult"].hero_hooks.has("start"), "TB_ult start hook 注册")
	assert_true(hero.skills["TB_ult"].hero_hooks.has("takeEffectOn"), "TB_ult takeEffectOn hook 注册")
	assert_true(hero.skills["TB_atk2"].hero_hooks.has("takeEffectAt"), "TB_atk2 takeEffectAt hook 注册")
	assert_true(hero.skills["TB_atk3"].hero_hooks.has("takeEffectOn"), "TB_atk3 takeEffectOn hook 注册")


# PL：apply 后 Lancer_ult(takeEffectAt/power/onAttackFrame) + Lancer_atk2(takeEffectAt) + Lancer_atk(onPhaseFinished/start/finish) + Lancer_atk3(takeEffectOn/createProjectile) + die 注册。
func test_pl_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Lancer_ult"] = MockSkill.new()
	hero.skills["Lancer_atk2"] = MockSkill.new()
	hero.skills["Lancer_atk"] = MockSkill.new()
	hero.skills["Lancer_atk3"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/PL", hero)
	assert_true(hero.skills["Lancer_ult"].hero_hooks.has("power"), "Lancer_ult power hook 注册")
	assert_true(hero.skills["Lancer_ult"].hero_hooks.has("onAttackFrame"), "Lancer_ult onAttackFrame hook 注册")
	assert_true(hero.skills["Lancer_atk"].hero_hooks.has("onPhaseFinished"), "Lancer_atk onPhaseFinished hook 注册")
	assert_true(hero.skills["Lancer_atk"].hero_hooks.has("start"), "Lancer_atk start hook 注册")
	assert_true(hero.skills["Lancer_atk3"].hero_hooks.has("takeEffectOn"), "Lancer_atk3 takeEffectOn hook 注册")
	assert_true(hero.hero_hooks.has("die"), "PL die hook 注册")


# TitanHead：apply 后 atk(createProjectile) + atk2(power) + atk3(start/takeEffectAt) + atk4(createProjectile/start/update/finish) + atk5(createBuff) + atk6(start/finish) + 单位 takeDamage 注册（Boss）。
func test_titanhead_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.engine = MockEngine.new()
	hero.skills["TitanHead_atk"] = MockSkill.new()
	hero.skills["TitanHead_atk2"] = MockSkill.new()
	hero.skills["TitanHead_atk3"] = MockSkill.new()
	hero.skills["TitanHead_atk4"] = MockSkill.new()
	hero.skills["TitanHead_atk5"] = MockSkill.new()
	hero.skills["TitanHead_atk6"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/TitanHead", hero)
	assert_true(hero.skills["TitanHead_atk"].hero_hooks.has("createProjectile"), "TitanHead atk createProjectile hook 注册")
	assert_true(hero.skills["TitanHead_atk2"].hero_hooks.has("power"), "TitanHead atk2 power hook 注册")
	assert_true(hero.skills["TitanHead_atk3"].hero_hooks.has("takeEffectAt"), "TitanHead atk3 takeEffectAt hook 注册")
	assert_true(hero.skills["TitanHead_atk4"].hero_hooks.has("update"), "TitanHead atk4 update hook 注册")
	assert_true(hero.skills["TitanHead_atk5"].hero_hooks.has("createBuff"), "TitanHead atk5 createBuff hook 注册")
	assert_true(hero.skills["TitanHead_atk6"].hero_hooks.has("finish"), "TitanHead atk6 finish hook 注册")
	assert_true(hero.hero_hooks.has("takeDamage"), "TitanHead takeDamage hook 注册")


# TitanHead atk6 start 照源 :205 basefunc(skill) 不传 target（Boss 阶段大招无目标，AncientTreant 同模式）。
func test_titanhead_atk6_start_passes_null() -> void:
	var hero := MockHero.new()
	hero.engine = MockEngine.new()
	var atk6 := MockSkill.new()
	atk6.caster = hero  # _atk6_start 访问 caster.custom_data
	hero.skills["TitanHead_atk6"] = atk6
	BattleHeroScripts.apply("battle/heroes/TitanHead", hero)
	# 源 :205 basefunc(skill) 不传 target → _start_default(null)
	atk6.hero_hooks["start"].call(atk6, hero)  # _target=hero 传入但应被忽略
	assert_null(atk6.start_default_arg, "TitanHead atk6 start _start_default 收到 null（源 :205 basefunc 不传 target）")


# BossSil：apply 后 BossSil_atk3(takeEffectOn) + BossSil_atk6(start/onAttackFrame/finish) 注册。
func test_bosssil_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["BossSil_atk3"] = MockSkill.new()
	hero.skills["BossSil_atk6"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/BossSil", hero)
	assert_true(hero.skills["BossSil_atk3"].hero_hooks.has("takeEffectOn"), "BossSil atk3 takeEffectOn hook 注册")
	assert_true(hero.skills["BossSil_atk6"].hero_hooks.has("finish"), "BossSil atk6 finish hook 注册")


# BossCoco：apply 后 BossCoco_atk4(launchPoint) + BossCoco_atk6(start/finish) 注册。
func test_bosscoco_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["BossCoco_atk4"] = MockSkill.new()
	hero.skills["BossCoco_atk5"] = MockSkill.new()
	hero.skills["BossCoco_atk6"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/BossCoco", hero)
	assert_true(hero.skills["BossCoco_atk4"].hero_hooks.has("launchPoint"), "BossCoco atk4 launchPoint hook 注册")
	assert_true(hero.skills["BossCoco_atk5"].hero_hooks.has("takeEffectOn"), "BossCoco atk5 takeEffectOn hook 注册")
	assert_true(hero.skills["BossCoco_atk6"].hero_hooks.has("finish"), "BossCoco atk6 finish hook 注册")


# BossHuskar：apply 后 BossHuskar_atk3(takeEffectOn/finish) + BossHuskar_atk6 注册。
func test_bosshuskar_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["BossHuskar_atk3"] = MockSkill.new()
	hero.skills["BossHuskar_atk6"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/BossHuskar", hero)
	assert_true(hero.skills["BossHuskar_atk3"].hero_hooks.has("takeEffectOn"), "BossHuskar atk3 takeEffectOn hook 注册")
	assert_true(hero.skills["BossHuskar_atk3"].hero_hooks.has("finish"), "BossHuskar atk3 finish hook 注册")


# BossKOTL：apply 后 atk4(蓄力 canTrigger/trigger/interrupt/power/onAttackFrame) + atk2(takeEffectOn) + atk6 注册。
func test_bosskotl_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["BossKOTL_atk4"] = MockSkill.new()
	hero.skills["BossKOTL_atk2"] = MockSkill.new()
	hero.skills["BossKOTL_atk6"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/BossKOTL", hero)
	assert_true(hero.skills["BossKOTL_atk4"].hero_hooks.has("canTrigger"), "BossKOTL atk4 canTrigger hook 注册")
	assert_true(hero.skills["BossKOTL_atk4"].hero_hooks.has("power"), "BossKOTL atk4 power hook 注册")
	assert_true(hero.skills["BossKOTL_atk2"].hero_hooks.has("takeEffectOn"), "BossKOTL atk2 takeEffectOn hook 注册")
	assert_true(hero.skills["BossKOTL_atk6"].hero_hooks.has("finish"), "BossKOTL atk6 finish hook 注册")


# ExSilverDragon：apply 后单位 update + atk3_ice(takeEffectAt) + atk2_ice/atk_ice(createBuff) + frozen(takeEffectOn) 注册。
func test_exsilverdragon_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["ExSilverDragon_atk3_ice"] = MockSkill.new()
	hero.skills["ExSilverDragon_atk2_ice"] = MockSkill.new()
	hero.skills["ExSilverDragon_atk_ice"] = MockSkill.new()
	hero.skills["ExSilverDragon_frozen"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/ExSilverDragon", hero)
	assert_true(hero.hero_hooks.has("update"), "ExSilverDragon update hook 注册")
	assert_true(hero.skills["ExSilverDragon_atk3_ice"].hero_hooks.has("takeEffectAt"), "ExSilverDragon atk3_ice takeEffectAt hook 注册")
	assert_true(hero.skills["ExSilverDragon_atk2_ice"].hero_hooks.has("createBuff"), "ExSilverDragon atk2_ice createBuff hook 注册")
	assert_true(hero.skills["ExSilverDragon_frozen"].hero_hooks.has("takeEffectOn"), "ExSilverDragon frozen takeEffectOn hook 注册")


# Kael：apply 后单位 update/castSkill/reset/die + Kael_all(createBuff) + Kael_book(onAttackFrame) + Kael_atk(startPhase/onPhaseFinished/onAttackFrame) + Kael_fire3(power/takeEffectAt) 注册（能量球系统）。
func test_kael_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.engine = MockEngine.new()
	hero.camp = 1
	hero.skills["Kael_all"] = MockSkill.new()
	hero.skills["Kael_book"] = MockSkill.new()
	hero.skills["Kael_atk"] = MockSkill.new()
	hero.skills["Kael_fire3"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Kael", hero)
	assert_true(hero.hero_hooks.has("update"), "Kael update hook 注册")
	assert_true(hero.hero_hooks.has("castSkill"), "Kael castSkill hook 注册")
	assert_true(hero.hero_hooks.has("reset"), "Kael reset hook 注册")
	assert_true(hero.hero_hooks.has("die"), "Kael die hook 注册")
	assert_true(hero.skills["Kael_all"].hero_hooks.has("createBuff"), "Kael_all createBuff hook 注册")
	assert_true(hero.skills["Kael_book"].hero_hooks.has("onAttackFrame"), "Kael_book onAttackFrame hook 注册")
	assert_true(hero.skills["Kael_atk"].hero_hooks.has("startPhase"), "Kael_atk startPhase hook 注册")
	assert_true(hero.skills["Kael_atk"].hero_hooks.has("onPhaseFinished"), "Kael_atk onPhaseFinished hook 注册")
	assert_true(hero.skills["Kael_fire3"].hero_hooks.has("power"), "Kael_fire3 power hook 注册")
	assert_true(hero.is_kael, "Kael is_kael=true")
	assert_true(hero.engine.player_kael_hero == hero, "engine.player_kael_hero 设（camp=1）")


# ExBossHuskar：apply 后单位 reset + atk2 createProjectile + atk3 takeEffectOn 注册 + atk5 originfo 存原始 info（首次出场 Buff152 + 召唤物短 CD + 自残大招）。
func test_exbosshuskar_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["ExBossHuskar_atk2"] = MockSkill.new()
	hero.skills["ExBossHuskar_atk3"] = MockSkill.new()
	hero.skills["ExBossHuskar_atk5"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/ExBossHuskar", hero)
	assert_true(hero.hero_hooks.has("reset"), "ExBossHuskar 单位 reset hook 注册")
	assert_true(hero.skills["ExBossHuskar_atk2"].hero_hooks.has("createProjectile"), "ExBossHuskar atk2 createProjectile hook 注册")
	assert_true(hero.skills["ExBossHuskar_atk3"].hero_hooks.has("takeEffectOn"), "ExBossHuskar atk3 takeEffectOn hook 注册")
	assert_true(hero.skills["ExBossHuskar_atk5"].custom_data.has("originfo"), "ExBossHuskar atk5 originfo 存原始 info")


# ExBossSpider：apply 后单位 reset + atk2(start/onAttackFrame/createBuff) + atk4(createBuff) 注册（清负面+周期回血+周期 AP 伤）。
func test_exbossspider_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["ExBossSpider_atk2"] = MockSkill.new()
	hero.skills["ExBossSpider_atk4"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/ExBossSpider", hero)
	assert_true(hero.hero_hooks.has("reset"), "ExBossSpider 单位 reset hook 注册")
	assert_true(hero.skills["ExBossSpider_atk2"].hero_hooks.has("start"), "ExBossSpider atk2 start hook 注册")
	assert_true(hero.skills["ExBossSpider_atk2"].hero_hooks.has("onAttackFrame"), "ExBossSpider atk2 onAttackFrame hook 注册")
	assert_true(hero.skills["ExBossSpider_atk2"].hero_hooks.has("createBuff"), "ExBossSpider atk2 createBuff hook 注册")
	assert_true(hero.skills["ExBossSpider_atk4"].hero_hooks.has("createBuff"), "ExBossSpider atk4 createBuff hook 注册")


# BossTB：apply 后 atk2(takeEffectAt) + atk6(createBuff/finish/start/takeEffectOn) + atk3(canCastWithTarget) 注册 + hero.info.mDuration=10（变身系+4 幻象）。
func test_bosstb_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["BossTB_atk2"] = MockSkill.new()
	hero.skills["BossTB_atk3"] = MockSkill.new()
	hero.skills["BossTB_atk6"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/BossTB", hero)
	assert_true(hero.skills["BossTB_atk2"].hero_hooks.has("takeEffectAt"), "BossTB atk2 takeEffectAt hook 注册")
	assert_true(hero.skills["BossTB_atk6"].hero_hooks.has("createBuff"), "BossTB atk6 createBuff hook 注册")
	assert_true(hero.skills["BossTB_atk6"].hero_hooks.has("finish"), "BossTB atk6 finish hook 注册")
	assert_true(hero.skills["BossTB_atk6"].hero_hooks.has("start"), "BossTB atk6 start hook 注册")
	assert_true(hero.skills["BossTB_atk6"].hero_hooks.has("takeEffectOn"), "BossTB atk6 takeEffectOn hook 注册")
	assert_true(hero.skills["BossTB_atk3"].hero_hooks.has("canCastWithTarget"), "BossTB atk3 canCastWithTarget hook 注册")
	assert_eq(float(hero.info.get("mDuration", 0)), 10.0, "BossTB hero.info.mDuration=10")


# ExLoz：apply 后 ult(createProjectile) + atk2(start/createBuff/onAttackFrame) + atk4(createProjectile) + 单位 takeDamage 注册（多弹道+3D追踪+周期AP+免疫）。
func test_exloz_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["ExLoz_ult"] = MockSkill.new()
	hero.skills["ExLoz_atk2"] = MockSkill.new()
	hero.skills["ExLoz_atk4"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/ExLoz", hero)
	assert_true(hero.skills["ExLoz_ult"].hero_hooks.has("createProjectile"), "ExLoz ult createProjectile hook 注册")
	assert_true(hero.skills["ExLoz_atk2"].hero_hooks.has("start"), "ExLoz atk2 start hook 注册")
	assert_true(hero.skills["ExLoz_atk2"].hero_hooks.has("createBuff"), "ExLoz atk2 createBuff hook 注册")
	assert_true(hero.skills["ExLoz_atk2"].hero_hooks.has("onAttackFrame"), "ExLoz atk2 onAttackFrame hook 注册")
	assert_true(hero.skills["ExLoz_atk4"].hero_hooks.has("createProjectile"), "ExLoz atk4 createProjectile hook 注册")
	assert_true(hero.hero_hooks.has("takeDamage"), "ExLoz 单位 takeDamage hook 注册")


# SB：apply 后单位 reset + atk2(start/onAttackFrame) + ult(start) 注册（rush 冲撞 + 友军检测 + 传送）。
func test_sb_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.engine = MockEngine.new()
	hero.skills["SB_atk2"] = MockSkill.new()
	hero.skills["SB_ult"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/SB", hero)
	assert_true(hero.hero_hooks.has("reset"), "SB 单位 reset hook 注册")
	assert_true(hero.skills["SB_atk2"].hero_hooks.has("start"), "SB atk2 start hook 注册")
	assert_true(hero.skills["SB_atk2"].hero_hooks.has("onAttackFrame"), "SB atk2 onAttackFrame hook 注册")
	assert_true(hero.skills["SB_ult"].hero_hooks.has("start"), "SB ult start hook 注册")


# Marine：apply 后 ult(onPhaseFinished/takeEffectAt/takeEffectOn) + atk2(createBuff/canCastWithTarget+Cost HP20) + atk(start/power/onPhaseFinished) + 单位 update/castManualSkill + ai.findSkillToCast 注册（医疗兵强化态）。
func test_marine_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.ai = MockAi.new()
	hero.skills["Marine_ult"] = MockSkill.new()
	hero.skills["Marine_atk2"] = MockSkill.new()
	hero.skills["Marine_atk"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Marine", hero)
	assert_true(hero.skills["Marine_ult"].hero_hooks.has("onPhaseFinished"), "Marine ult onPhaseFinished hook 注册")
	assert_true(hero.skills["Marine_ult"].hero_hooks.has("takeEffectAt"), "Marine ult takeEffectAt hook 注册")
	assert_true(hero.skills["Marine_ult"].hero_hooks.has("takeEffectOn"), "Marine ult takeEffectOn hook 注册")
	assert_true(hero.skills["Marine_atk2"].hero_hooks.has("createBuff"), "Marine atk2 createBuff hook 注册")
	assert_true(hero.skills["Marine_atk2"].hero_hooks.has("canCastWithTarget"), "Marine atk2 canCastWithTarget hook 注册")
	assert_true(hero.skills["Marine_atk"].hero_hooks.has("start"), "Marine atk start hook 注册")
	assert_true(hero.skills["Marine_atk"].hero_hooks.has("power"), "Marine atk power hook 注册")
	assert_true(hero.skills["Marine_atk"].hero_hooks.has("onPhaseFinished"), "Marine atk onPhaseFinished hook 注册")
	assert_true(hero.hero_hooks.has("update"), "Marine 单位 update hook 注册")
	assert_true(hero.hero_hooks.has("castManualSkill"), "Marine 单位 castManualSkill hook 注册")
	assert_true(hero.ai.hero_hooks.has("findSkillToCast"), "Marine ai findSkillToCast hook 注册")
	assert_eq(int(hero.skills["Marine_atk2"].info.get("Cost HP", 0)), 20, "Marine atk2 Cost HP=20")


# Phoenix：apply 后单位 die+getLostHPAfterImmunity + atk2(createBuff) + ult(onAttackFrame+getDamage+finish) + atk3(onAttackFrame+canCastWithTarget) 注册（蛋形态）。
func test_phoenix_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Phoenix_atk2"] = MockSkill.new()
	hero.skills["Phoenix_pasv"] = MockSkill.new()
	hero.skills["Phoenix_ult"] = MockSkill.new()
	hero.skills["Phoenix_atk3"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Phoenix", hero)
	assert_true(hero.hero_hooks.has("die"), "Phoenix 单位 die hook 注册")
	assert_true(hero.hero_hooks.has("getLostHPAfterImmunity"), "Phoenix 单位 getLostHPAfterImmunity hook 注册")
	assert_true(hero.skills["Phoenix_atk2"].hero_hooks.has("createBuff"), "Phoenix atk2 createBuff hook 注册")
	assert_true(hero.skills["Phoenix_ult"].hero_hooks.has("onAttackFrame"), "Phoenix ult onAttackFrame hook 注册")
	assert_true(hero.skills["Phoenix_ult"].hero_hooks.has("getDamage"), "Phoenix ult getDamage hook 注册")
	assert_true(hero.skills["Phoenix_ult"].hero_hooks.has("finish"), "Phoenix ult finish hook 注册")
	assert_true(hero.skills["Phoenix_atk3"].hero_hooks.has("onAttackFrame"), "Phoenix atk3 onAttackFrame hook 注册")
	assert_true(hero.skills["Phoenix_atk3"].hero_hooks.has("canCastWithTarget"), "Phoenix atk3 canCastWithTarget hook 注册")


# BB：apply 后单位 takeDamage+getLostHPAfterImmunity+update + ult(createBuff/onAttackFrame/finish/canCastWithTarget) 注册（背击免疫+累计伤害大招）。
func test_bb_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["BB_atk3"] = MockSkill.new()
	hero.skills["BB_ult"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/BB", hero)
	assert_true(hero.hero_hooks.has("takeDamage"), "BB 单位 takeDamage hook 注册")
	assert_true(hero.hero_hooks.has("getLostHPAfterImmunity"), "BB 单位 getLostHPAfterImmunity hook 注册")
	assert_true(hero.hero_hooks.has("update"), "BB 单位 update hook 注册")
	assert_true(hero.skills["BB_ult"].hero_hooks.has("createBuff"), "BB ult createBuff hook 注册")
	assert_true(hero.skills["BB_ult"].hero_hooks.has("onAttackFrame"), "BB ult onAttackFrame hook 注册")
	assert_true(hero.skills["BB_ult"].hero_hooks.has("finish"), "BB ult finish hook 注册")
	assert_true(hero.skills["BB_ult"].hero_hooks.has("canCastWithTarget"), "BB ult canCastWithTarget hook 注册")
	assert_true(bool(hero.custom_data.get("totalDamage", null) == 0.0), "BB atk3 存在 totalDamage=0")
	assert_true(bool(hero.is_action_stage_change_by_manual), "BB setActionStageChangeByManual=true")


# ExPhoenix：apply 后单位 update+die+getLostHPAfterImmunity+reset + atk2(createBuff) + ult(onAttackFrame+getDamage+finish+start) + atk3(onAttackFrame+canCastWithTarget) 注册（Ex 版蛋形态+shield）。
func test_exphoenix_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["ExPhoenix_atk2"] = MockSkill.new()
	hero.skills["ExPhoenix_pasv"] = MockSkill.new()
	hero.skills["ExPhoenix_ult"] = MockSkill.new()
	hero.skills["ExPhoenix_atk3"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/ExPhoenix", hero)
	assert_true(hero.hero_hooks.has("update"), "ExPhoenix 单位 update hook 注册")
	assert_true(hero.hero_hooks.has("die"), "ExPhoenix 单位 die hook 注册")
	assert_true(hero.hero_hooks.has("getLostHPAfterImmunity"), "ExPhoenix 单位 getLostHPAfterImmunity hook 注册")
	assert_true(hero.hero_hooks.has("reset"), "ExPhoenix 单位 reset hook 注册")
	assert_true(hero.skills["ExPhoenix_atk2"].hero_hooks.has("createBuff"), "ExPhoenix atk2 createBuff hook 注册")
	assert_true(hero.skills["ExPhoenix_ult"].hero_hooks.has("onAttackFrame"), "ExPhoenix ult onAttackFrame hook 注册")
	assert_true(hero.skills["ExPhoenix_ult"].hero_hooks.has("getDamage"), "ExPhoenix ult getDamage hook 注册")
	assert_true(hero.skills["ExPhoenix_ult"].hero_hooks.has("finish"), "ExPhoenix ult finish hook 注册")
	assert_true(hero.skills["ExPhoenix_ult"].hero_hooks.has("start"), "ExPhoenix ult start hook 注册")
	assert_true(hero.skills["ExPhoenix_atk3"].hero_hooks.has("canCastWithTarget"), "ExPhoenix atk3 canCastWithTarget hook 注册")


# Lina：onAttackFrame 总挂（当前生效，非 protoAwake）+ takeEffectOn protoAwake 守卫（false 不挂）。
func test_lina_hooks_registered() -> void:
	var hero := MockHero.new()
	hero.skills["Lina_atk"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Lina", hero)
	assert_true(hero.skills["Lina_atk"].hero_hooks.has("onAttackFrame"), "Lina atk onAttackFrame 总挂（当前生效）")
	assert_false(hero.skills["Lina_atk"].hero_hooks.has("takeEffectOn"), "Lina takeEffectOn 不挂（proto_awake false，Phase5 激活）")


# protoAwake 读 proto._awake 字段（源 C++ compiled 无定义，实现读 HeroInstance.awake 养成控制）。
func test_proto_awake_reads_awake_field() -> void:
	assert_false(BattleHeroScripts.proto_awake({}), "proto 无 _awake 键 → false（不觉醒）")
	assert_false(BattleHeroScripts.proto_awake({"_awake": false}), "proto._awake=false → false")
	assert_true(BattleHeroScripts.proto_awake({"_awake": true}), "proto._awake=true → 觉醒激活")


# SB：proto._awake=true 时 awake_update 挂（dying 倒计投球）；false 不挂。
func test_sb_awake_update_hooked_when_awake() -> void:
	var hero := MockHero.new()
	hero.proto = {"_awake": true}
	BattleHeroScripts.apply("battle/heroes/SB", hero)
	assert_true(hero.hero_hooks.has("update"), "SB awake_update 挂（proto._awake=true）")
	#不觉醒时不挂
	var hero2 := MockHero.new()
	BattleHeroScripts.apply("battle/heroes/SB", hero2)
	assert_false(hero2.hero_hooks.has("update"), "SB awake_update 不挂（proto 无 _awake）")


# Naga：proto._awake=true 时 die/onHitMiss/update 全挂（觉醒激活）。
func test_naga_hooks_hooked_when_awake() -> void:
	var hero := MockHero.new()
	hero.proto = {"_awake": true}
	BattleHeroScripts.apply("battle/heroes/Naga", hero)
	assert_true(hero.hero_hooks.has("die"), "Naga die 挂（proto._awake=true）")
	assert_true(hero.hero_hooks.has("onHitMiss"), "Naga onHitMiss 挂（proto._awake=true）")
	assert_true(hero.hero_hooks.has("update"), "Naga update 挂（proto._awake=true）")


# Ursa：protoAwake 守卫，proto_awake false 时 getDamage 不挂（Buff134 怒意叠加待 Phase5 激活）。
func test_ursa_proto_awake_not_hooked() -> void:
	var hero := MockHero.new()
	hero.skills["Ursa_pasv3"] = MockSkill.new()
	hero.skills["Ursa_ult"] = MockSkill.new()
	hero.skills["Ursa_atk"] = MockSkill.new()
	BattleHeroScripts.apply("battle/heroes/Ursa", hero)
	assert_false(hero.skills["Ursa_pasv3"].hero_hooks.has("getDamage"), "Ursa pasv3 getDamage 不挂（proto_awake false）")


# Naga：mobcd=0 总设 + protoAwake 守卫（false 时 die/onHitMiss/update 不挂）。
func test_naga_proto_awake_not_hooked() -> void:
	var hero := MockHero.new()
	BattleHeroScripts.apply("battle/heroes/Naga", hero)
	assert_eq(float(hero.custom_data.get("mobcd", -1)), 0.0, "Naga mobcd=0 总设")
	assert_false(hero.hero_hooks.has("die"), "Naga die 不挂（proto_awake false）")
	assert_false(hero.hero_hooks.has("update"), "Naga update 不挂（proto_awake false）")
