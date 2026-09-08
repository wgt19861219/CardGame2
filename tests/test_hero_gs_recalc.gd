extends GutTest
# 战斗力单一事实来源回归测试（2026-09-08 定稿）：
# hero.gs = 战斗单位全属性加权 gs（recalc_hero_gs = 源 recalcHeroGs 语义）。
# 回归背景：旧近似公式 calc_gs（5+Σ Equip.GS×EquipLevel+技能×10）不含等级/星级/附魔强化——
# 附魔/升级/升星后战力恒不变（用户报告）；废除后一切进 rebuild 属性的养成必须自动反映。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


# 单一来源不变式：hero.gs 恒等于"按战斗装配 proto 构建单位"的加权 gs（四舍五入）。
func test_gs_equals_battle_unit_weighted() -> void:
	var mgr := HeroManager.new(cm)
	var inst_id := mgr.add_hero(1)
	var hero := mgr.get_hero(inst_id)
	mgr.wear_equip(inst_id, 0)
	hero.equip_exp[0] = 20.0   # 手工注入强化经验（不依赖材料）
	hero.level = 30
	hero.stars = 3
	mgr.recalc_hero_gs(hero)
	var u := BattleUnit.new(hero.to_battle_proto(), BattleEngine.CAMP_PLAYER, {"estimate_rank": false}, cm)
	assert_eq(hero.gs, int(floor(u.gs + 0.5)), "hero.gs == 战斗单位加权 gs（同源不变式）")


# 回归主诉：附魔（装备强化）后战力必须上升。
func test_enhance_equip_increases_gs() -> void:
	var pd := PlayerData.new(cm)
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero := pd.hero_manager.get_hero(inst_id)
	# 找品质≥2 可强化装备 + 有 Enhance Value 的材料（排除魂石）
	var target_id := _find_enchantable_equip()
	var mat_id := _find_material_equip(target_id)
	assert_gt(target_id, 0, "前置：表内存在品质≥2 可强化装备")
	assert_gt(mat_id, 0, "前置：表内存在 Enhance Value 材料")
	hero.equip_slots[0] = target_id
	pd.hero_manager.recalc_hero_gs(hero)
	var gs0: int = hero.gs
	pd.items[mat_id] = 5000
	pd.hero_manager.add_money(99999999)
	var lv0: int = int(ReadequipData.get_equip_level(target_id, 0.0, cm)["level"])
	assert_true(EquipCraftManager.enhance_equip(pd, inst_id, 0, {mat_id: 5000}), "附魔成功前置")
	var lv1: int = int(ReadequipData.get_equip_level(target_id, hero.equip_exp[0], cm)["level"])
	assert_gt(lv1, lv0, "前置：强化等级跨级")
	assert_gt(hero.gs, gs0, "附魔跨级后 hero.gs 上升（回归主诉）")


# 旧公式缺陷回归：升级后战力必须上升（旧公式不含 level，恒不变）。
func test_add_exp_increases_gs() -> void:
	var mgr := HeroManager.new(cm)
	var inst_id := mgr.add_hero(1)
	var hero := mgr.get_hero(inst_id)
	var gs0: int = hero.gs
	assert_true(mgr.add_hero_exp(inst_id, 1000000), "升级前置")
	assert_gt(hero.level, 1, "前置：等级提升")
	assert_gt(hero.gs, gs0, "升级后 hero.gs 上升")


# 旧公式缺陷回归：升星后战力必须上升（旧公式不含 stars，恒不变）。
func test_evolve_increases_gs() -> void:
	var mgr := HeroManager.new(cm)
	var inst_id := mgr.add_hero(1)
	var hero := mgr.get_hero(inst_id)
	var gs0: int = hero.gs
	mgr.add_money(99999999)
	var frag_id: int = cm.get_int(&"Fragment", 1, &"Fragment ID")
	mgr.add_fragment(frag_id, 9999)
	assert_true(mgr.evolve(inst_id), "升星前置")
	assert_gt(hero.gs, gs0, "升星后 hero.gs 上升")


# 存档往返：旧存档的近似公式脏 gs 被 from_dict 尾部全量重算修正（照源登录后全量覆盖）。
func test_save_roundtrip_recalc_overrides_stale_gs() -> void:
	var mgr := HeroManager.new(cm)
	var inst_id := mgr.add_hero(1)
	var hero := mgr.get_hero(inst_id)
	mgr.wear_equip(inst_id, 0)
	hero.equip_exp[0] = 20.0
	hero.level = 30
	mgr.recalc_hero_gs(hero)
	var truth: int = hero.gs
	var data := mgr.to_dict()
	# 篡改存档 gs 为旧公式时代的典型脏值（5），模拟旧版本存档
	for h in data["heroes"]:
		if int(h["inst_id"]) == inst_id:
			h["gs"] = 5
	var mgr2 := HeroManager.from_dict(data, cm)
	assert_eq(mgr2.get_hero(inst_id).gs, truth, "读档后脏 gs 被全量重算修正为真值")


# 品质≥2 且有基础属性且可强化（ml>0）的装备（参考 test_equip_strengthen_panel 查找范式）。
func _find_enchantable_equip() -> int:
	var et: Dictionary = cm.get_raw_table(&"Equip")
	for id in et:
		var row: Dictionary = et[id]
		if int(row.get("Quality", 0)) >= 2 and String(row.get("Category", "")) != "EQUIP.SOUL_STONE":
			if float(row.get("GS", 0)) > 0.0 and int(ReadequipData.get_equip_level_exp(int(id), cm)["ml"]) > 0:
				return int(id)
	return 0


# 有 Enhance Value 且非目标装备本身的材料装备。
func _find_material_equip(exclude_id: int) -> int:
	var et: Dictionary = cm.get_raw_table(&"Equip")
	for id in et:
		if int(id) != exclude_id and float(et[id].get("Enhance Value", 0)) > 0.0:
			return int(id)
	return 0
