extends GutTest
# ch203 Boss Skills 守卫（2026-10-09 用户需求"参考魔兽原型改进 Boss 动画和技能"）。
# 数据层：9 关 Boss Skills 4 组 / 组 id 全在 Skill 表 / 首组=该关 Boss 单位 Basic Skill。
# 引擎层：boss_skills config override 替换默认 SkillGroup 槽装载（battle_unit_skill），
# 且同单位作为玩家英雄（无 override）技能栏不受影响。

var cm: ConfigManager
var lib: SkillLibrary


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()
	lib = SkillLibrary.new(cm)


const BOSS_UNIT_BY_STAGE := {
	50022: 90002, 50023: 90003, 50024: 90004, 50025: 90005, 50026: 90006,
	50027: 90007, 50028: 90008, 50029: 90009, 50030: 90001,   # 90001-90009=换皮新角色段
}


func test_boss_skills_data_complete() -> void:
	var sd: Dictionary = cm.get_raw_table(&"StageDungeon")
	for sid in BOSS_UNIT_BY_STAGE:
		var groups: Array = sd.get(str(sid), {}).get("Boss Skills", [])
		assert_eq(groups.size(), 4, "关 %d Boss Skills 4 组（普攻/技1/技2/大招）" % sid)


func test_boss_skills_groups_exist() -> void:
	var sd: Dictionary = cm.get_raw_table(&"StageDungeon")
	var sk: Dictionary = cm.get_raw_table(&"Skill")
	for sid in BOSS_UNIT_BY_STAGE:
		for gid in sd.get(str(sid), {}).get("Boss Skills", []):
			assert_true(sk.has(str(int(gid))), "关 %d 组 %d 在 Skill 表存在" % [sid, int(gid)])


func test_boss_skills_first_is_basic_skill() -> void:
	var sd: Dictionary = cm.get_raw_table(&"StageDungeon")
	var unit: Dictionary = cm.get_raw_table(&"Unit")
	for sid in BOSS_UNIT_BY_STAGE:
		var uid: int = int(BOSS_UNIT_BY_STAGE[sid])
		var basic: int = int(unit.get(str(uid), {}).get("Basic Skill", 0))
		var first: int = int(sd.get(str(sid), {}).get("Boss Skills", [0])[0])
		assert_eq(first, basic, "关 %d 首组=单位 %d Basic Skill（普攻原判定）" % [sid, uid])


# 引擎 override：带 boss_skills 的怪物（照 battle_engine_waves boss 构建路径）装载借用技能组。
func test_boss_skills_override_loaded() -> void:
	var eng := BattleEngine.new()
	var config: Dictionary = {
		"is_monster": true, "estimate_rank": true, "estimate_skill": true,
		"boss_skills": [421, 352, 73, 350],
	}
	var boss := BattleUnit.new({"_tid": 42, "_level": 80, "_stars": 3}, BattleEngine.CAMP_ENEMY, config, cm, eng, {}, lib)
	var loaded_gids: Array = []
	for skill in boss.skill_list:
		loaded_gids.append(int((skill as BattleSkill).info.get("Skill Group ID", 0)))
	assert_true(loaded_gids.has(352), "override 组 352（Lich 冰环=霜之哀伤组件）装载")
	assert_true(loaded_gids.has(73), "override 组 73（QOP 暗影冲击波）装载")
	assert_false(loaded_gids.has(422), "原槽 422（LOA_atk2 治愈系）被 override 替换不装载")
	assert_not_null(boss.basic_skill, "basic_skill 仍绑定（首组 421 命中 Basic Skill 判定）")
	assert_eq(int(boss.manual_skill.info.get("Skill Group ID", 0)), 350, "Manual 大招=350（Lich_ult 连环霜冻）")


# 同单位作为玩家英雄（无 override）技能栏不受影响（槽 2 组 422 Unlock=2 + _skill_levels 供级）。
func test_hero_unit_not_affected() -> void:
	var eng := BattleEngine.new()
	var hero := BattleUnit.new(
		{"_tid": 42, "_level": 1, "_stars": 1, "_rank": 2, "_skill_levels": {"2": 1}},
		BattleEngine.CAMP_PLAYER, {}, cm, eng, {}, lib
	)
	var loaded_gids: Array = []
	for skill in hero.skill_list:
		loaded_gids.append(int((skill as BattleSkill).info.get("Skill Group ID", 0)))
	assert_true(loaded_gids.has(422), "玩家死骑 rank2 原槽 422 正常装载（Boss override 不影响英雄）")


# === Boss Aura 元素光环粒子（2026-10-09）===
const BossAuraScript := preload("res://scripts/view/battle/boss_aura.gd")

# 9 关 Boss Aura 字段齐且类型合法。
func test_boss_aura_data_complete() -> void:
	var sd: Dictionary = cm.get_raw_table(&"StageDungeon")
	for sid in BOSS_UNIT_BY_STAGE:
		var aura: String = String(sd.get(str(sid), {}).get("Boss Aura", ""))
		assert_ne(aura, "", "关 %d Boss Aura 非空" % sid)
		assert_true(aura in BossAuraScript.AURA_TYPES, "关 %d aura=%s 在类型枚举内" % [sid, aura])


# make() 各类型产出有效粒子节点（贴图/ramp/发射参数就绪；headless 可构造）。
func test_boss_aura_make_all_types() -> void:
	for aura_type in BossAuraScript.AURA_TYPES:
		var aura: CPUParticles2D = BossAuraScript.make(String(aura_type), 110.0)
		assert_not_null(aura, "%s make 非 null" % aura_type)
		assert_not_null(aura.texture, "%s 粒子贴图就绪" % aura_type)
		assert_not_null(aura.color_ramp, "%s 淡入淡出 ramp 就绪" % aura_type)
		assert_gt(aura.amount, 0, "%s 粒子数>0" % aura_type)
		aura.free()
	assert_null(BossAuraScript.make("nonexistent", 110.0), "未知类型返回 null（安全兜底）")


# === 换皮新角色资产接入（2026-10-09 Angel 管线首次接入战斗：巫妖王 LichKing）===

# Unit 90001 行与 Battle 50030 boss 引用一致（expand 工具注入）。
func test_lichking_unit_row() -> void:
	var unit: Dictionary = cm.get_raw_table(&"Unit")
	assert_true(unit.has("90001"), "Unit 90001 LichKing 存在")
	var row: Dictionary = unit.get("90001", {})
	assert_eq(String(row.get("Puppet", "")), "LichKing.cha", "Puppet=LichKing.cha（Puppet 表键带 .cha 后缀）")
	assert_eq(int(row.get("Basic Skill", 0)), 421, "Basic Skill=421（死骑普攻组，Boss Skills 首组一致）")
	var battle: Dictionary = cm.get_raw_table(&"Battle")
	assert_eq(int(battle.get("50030", {}).get("3", {}).get("Monster 4 ID", 0)), 90001,
		"Battle 50030 波3 Boss 槽=90001（换皮巫妖王出场）")


# 2026-10-10 抖动/不放技能根修守卫：①非首组禁混纯普攻（_atk 结尾且非 atkN——AI 拿普攻当
# 主动技反复选致 Boss 移动/攻击高频切换"抖"；旧 50022 三组 191 SNK_atk 错配）。
# ②Boss 槽 MP=1000（大招 Cost 1000；旧 400 起步 Gain MP 攒不满，AI 自动大招永放不出）。
func test_boss_skills_no_stray_basic_attack() -> void:
	var sd: Dictionary = cm.get_raw_table(&"StageDungeon")
	var sk: Dictionary = cm.get_raw_table(&"Skill")
	for sid in BOSS_UNIT_BY_STAGE:
		var groups: Array = sd.get(str(sid), {}).get("Boss Skills", [])
		for gi in range(1, groups.size()):
			var row: Dictionary = sk.get(str(int(groups[gi])), {})
			for sub in row.values():
				if sub is Dictionary and sub.has("Skill Name"):
					var sname: String = String(sub["Skill Name"])
					assert_false(sname.ends_with("_atk"),
						"关 %d 组 %d（%s）是纯普攻——普攻只允许首组" % [sid, int(groups[gi]), sname])
					break


func test_boss_wave_mp_full_for_ult() -> void:
	var battle: Dictionary = cm.get_raw_table(&"Battle")
	for sid in BOSS_UNIT_BY_STAGE:
		assert_eq(int(battle.get(str(sid), {}).get("3", {}).get("MP 4", 0)), 1000,
			"关 %d Boss 槽 MP=1000（进场满 MP 放大招）" % sid)


# 2026-10-09 占位图根修守卫：Unit.Puppet 必须能在 Puppet 表解析出 Resource（unit_sprite.gd
# 链路 Unit.Puppet→Puppet 表→Resource=anim_frames 目录），且 Resource 目录存在——首版注入
# 漏 .cha 后缀且未建 Puppet 表条目，战斗 Boss 全部回落占位图。
func test_boss_puppet_chain_resolves() -> void:
	var unit: Dictionary = cm.get_raw_table(&"Unit")
	var puppet_table: Dictionary = cm.get_raw_table(&"Puppet")
	for tid in range(90001, 90010):
		var row: Dictionary = unit.get(str(tid), {})
		var puppet_key: String = String(row.get("Puppet", ""))
		assert_true(puppet_key.ends_with(".cha"), "%d Puppet 键带 .cha（实际 %s）" % [tid, puppet_key])
		var puppet_row: Dictionary = puppet_table.get(puppet_key, {})
		assert_false(puppet_row.is_empty(), "Puppet 表含 %s" % puppet_key)
		var res: String = String(puppet_row.get("Resource", ""))
		assert_true(DirAccess.dir_exists_absolute("res://assets/anim_frames/" + res),
			"%s Resource=%s 目录存在" % [puppet_key, res])


# FcaAnimation 加载全部换皮角色（照 verify_angel_load.gd 范式：atlas+骨骼+动作表）。
const LICH_PUPPETS := [
	"LichKing", "Karathress", "Tidewalker", "LadyVashj", "RageWinter",
	"Anetheron", "Archimonde", "Sindragosa", "BloodQueen",
]


func test_lich_boss_puppets_load() -> void:
	for puppet in LICH_PUPPETS:
		var atlas := AtlasSprite.new()
		assert_true(atlas.load_atlas("res://assets/anim_frames/%s/sheet.plist" % puppet),
			"%s 图集加载" % puppet)
		var fca := FcaAnimation.new()
		add_child(fca)
		assert_true(fca.load_from_ani(puppet, atlas), "%s 骨骼动画加载" % puppet)
		var actions: PackedStringArray = fca.get_action_names()
		assert_true("Idle" in actions, "%s 动作表含 Idle" % puppet)
		assert_true("ult" in actions, "%s 动作表含 ult（Boss 大招演出依赖）" % puppet)
		fca.queue_free()


# 2026-10-10 Boss 卡死根修守卫：每个借技 Action(s) 的动画名必须在换皮资源的
# AnimAtkFrame/AnimDuration 表内有条目且 Duration>0——缺条目时 rebuild_phase_list
# 产空 phase_list，技能 start 后无动作无完成回调，Boss 钉死 ATTACK 态原地循环 Move
# （用户表现"抖来抖去不攻击不放技能"）。换皮资源时序照模板复制（expand_lich_data
# inject_boss_anim_tables），本测试防未来新增 Boss 漏拷。
func test_boss_anim_tables_cover_skills() -> void:
	var sd: Dictionary = cm.get_raw_table(&"StageDungeon")
	var unit: Dictionary = cm.get_raw_table(&"Unit")
	var puppet_table: Dictionary = cm.get_raw_table(&"Puppet")
	var atk_t: Dictionary = cm.get_raw_table(&"AnimAtkFrame")
	var dur_t: Dictionary = cm.get_raw_table(&"AnimDuration")
	var sk: Dictionary = cm.get_raw_table(&"Skill")
	for sid in BOSS_UNIT_BY_STAGE:
		var uid: int = int(BOSS_UNIT_BY_STAGE[sid])
		var puppet_key: String = String(unit.get(str(uid), {}).get("Puppet", ""))
		var res_key: String = String(puppet_table.get(puppet_key, {}).get("Resource", "")) + ".cha"
		var res_atk: Dictionary = atk_t.get(res_key, {})
		var res_dur: Dictionary = dur_t.get(res_key, {})
		assert_false(res_atk.is_empty(), "关 %d 资源 %s 在 AnimAtkFrame 有条目" % [sid, res_key])
		for gid in sd.get(str(sid), {}).get("Boss Skills", []):
			var row: Dictionary = sk.get(str(int(gid)), {}).get("0", {})
			var actions: Dictionary = row.get("Action(s)", {})
			for k in actions:
				var anim: String = String(actions[k])
				assert_true(res_atk.has(anim),
					"关 %d 组 %d 动画 %s 在 %s AnimAtkFrame（phase 构建依赖）" % [sid, int(gid), anim, res_key])
				var dur: float = float(res_dur.get(anim, {}).get("Duration", 0.0))
				assert_gt(dur, 0.0,
					"关 %d 组 %d 动画 %s Duration>0（0 会卡动作完成回调）" % [sid, int(gid), anim])
