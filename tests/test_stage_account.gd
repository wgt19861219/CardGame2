extends GutTest
# StageAccount 测试（2026-07-03，Phase 4 续）— 照源 ui/stageaccount.lua 各函数分支。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_is_dungeon_stage() -> void:
	assert_true(StageAccount.is_dungeon_stage(50001), "新段 50001 副本")
	assert_true(StageAccount.is_dungeon_stage(53021), "新段末 53021 副本")
	assert_true(StageAccount.is_dungeon_stage(40001), "旧段 40001 副本")
	assert_true(StageAccount.is_dungeon_stage(42010), "旧段中 42010 副本")
	assert_false(StageAccount.is_dungeon_stage(1), "普通关 1 非副本")
	assert_false(StageAccount.is_dungeon_stage(-27), "PVP 占位 -27 非副本")


func test_stage_type() -> void:
	# 照源 player.lua:770-788 stageType 6 类型区间判定
	assert_eq(StageAccount.stage_type(1), "normal", "普通关 1-9999")
	assert_eq(StageAccount.stage_type(10001), "elite", "精英关 10001-19998")
	assert_eq(StageAccount.stage_type(20001), "act", "活动关 20001-29999")
	assert_eq(StageAccount.stage_type(-1), "pvp", "pvp -1")
	assert_eq(StageAccount.stage_type(40001), "raid", "raid 40001-49999")
	assert_eq(StageAccount.stage_type(50001), "dungeon", "副本 50001-53021")
	assert_eq(StageAccount.stage_type(-27), "", "占位 -27 无类型")


func test_get_lose_title_res() -> void:
	assert_eq(StageAccount.get_lose_title_res("timeout"), "UI/alpha/HVGA/overtime_title.png", "timeout→overtime")
	assert_eq(StageAccount.get_lose_title_res("fail"), "UI/alpha/HVGA/failed_title.png", "fail→failed")
	assert_eq(StageAccount.get_lose_title_res("other"), "", "其他→空")


func test_get_battle_bg_res() -> void:
	var res: String = StageAccount.get_battle_bg_res(-27, cm)
	assert_true(res.begins_with("UI/alpha/HVGA/"), "背景图路径含前缀")
	# Battle[-27][1] Background Pic 字段值（表数据，不断言具体文件名）


func test_get_stage_vitality_cost() -> void:
	# -27 PVP 占位 vitality_cost=0
	assert_eq(StageAccount.get_stage_vitality_cost(-27, cm), 0, "-27 体力消耗 0")


func test_aggregate_loots() -> void:
	# 直接测 deal_victory 的 loot 聚合（源 :61-71）：同 id 累加 amount
	var param: Dictionary = {
		"victory": true, "stage_id": -27, "heroes": [],
		"loots": [{"id": 101, "type": "equip"}, {"id": 101, "type": "equip"}, {"id": 105, "type": "hero"}],
	}
	var pd := PlayerData.new(cm)
	var r: Dictionary = StageAccount.deal_victory_param(param, cm, pd, pd.hero_manager)
	var loot_list: Dictionary = r["loot_list"]
	assert_eq(int(loot_list[101]["amount"]), 2, "同 id 101 聚合 amount=2")
	assert_eq(int(loot_list[105]["amount"]), 1, "id 105 amount=1")
	assert_eq(String(loot_list[101]["type"]), "equip", "type 保留")
	assert_eq(String(loot_list[105]["type"]), "hero", "hero type 保留")


func test_deal_victory_param_structure() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)   # tid=1 英雄，供 get_hero_info
	var param: Dictionary = {"victory": true, "stage_id": -27, "heroes": [1], "loots": []}
	var r: Dictionary = StageAccount.deal_victory_param(param, cm, pd, pd.hero_manager)
	# -27 Stage：Key Stage=false / Chapter=-1 / Heroexp Reward=0 → hero_exp=0
	assert_eq(bool(r["is_key_stage"]), false, "-27 非关键关")
	assert_eq(int(r["chapter"]), -1, "chapter=-1")
	assert_true(r.has("exp"), "exp 字段")
	assert_true(r.has("gold"), "gold 字段")
	assert_true(r.has("player_info"), "player_info 字段")
	assert_true(r["player_info"] is Dictionary, "player_info 是 Dictionary")
	var heroes: Array = r["heroes"]
	assert_eq(heroes.size(), 1, "heroes 数组长度=上场数")


func test_deal_lose_param_non_excavate() -> void:
	var pd := PlayerData.new(cm)
	var param: Dictionary = {"victory": false, "stage_id": -27}
	var r: Dictionary = StageAccount.deal_lose_param(param, cm, pd)
	assert_false(r.has("exp"), "非 excavate 不加 exp")
	assert_false(r.has("player_info"), "非 excavate 不加 player_info")


func test_deal_lose_param_excavate() -> void:
	var pd := PlayerData.new(cm)
	var param: Dictionary = {"victory": false, "stage_id": -27, "excavate_mode": true}
	var r: Dictionary = StageAccount.deal_lose_param(param, cm, pd)
	assert_true(r.has("exp"), "excavate 加 exp")
	assert_true(r.has("player_info"), "excavate 加 player_info")


func test_build_result_param_branch() -> void:
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)
	# victory=true → 走 deal_victory
	var pw: Dictionary = StageAccount.build_result_param({"victory": true, "stage_id": -27, "heroes": [1]}, cm, pd, pd.hero_manager)
	assert_true(pw.has("heroes"), "victory 分支返 heroes")
	# victory=false → 走 deal_lose（deal_lose 不用 hero_manager，build_result_param 统一签名）
	var pl: Dictionary = StageAccount.build_result_param({"victory": false, "stage_id": -27}, cm, pd, pd.hero_manager)
	assert_false(pl.has("heroes"), "lose 分支无 heroes")


func test_get_player_info_anim_list() -> void:
	# 构造升级场景：add_exp > max_exp 触发 animList 多段（源 :158 while cExp<cAddExp）
	# PlayerLevel 表真实 Exp 值；这里测结构 + 字段完整性
	var info: Dictionary = {"exp": 10, "add_exp": 50, "level": 2, "max_exp": 100}
	var r: Dictionary = StageAccount.get_player_info(info, cm)
	assert_true(r.has("anim_list"), "返 anim_list")
	assert_true(r.has("ori_level"), "返 ori_level")
	assert_true(r.has("ori_exp"), "返 ori_exp")
	var anim_list: Array = r["anim_list"]
	assert_gte(anim_list.size(), 1, "anim_list 至少 1 段")
	var seg: Dictionary = anim_list[0]
	assert_true(seg.has("be") and seg.has("ee") and seg.has("len") and seg.has("lv"), "分段含 be/ee/len/lv")


func test_get_player_info_no_levelup() -> void:
	# add_exp <= exp → 单段无升级（while 不进）
	var info: Dictionary = {"exp": 100, "add_exp": 10, "level": 5, "max_exp": 200}
	var r: Dictionary = StageAccount.get_player_info(info, cm)
	var anim_list: Array = r["anim_list"]
	assert_eq(anim_list.size(), 1, "无升级 anim_list 单段")
	assert_eq(int(r["ori_level"]), 5, "ori_level=当前级")


func test_get_hero_info_with_cache() -> void:
	# 构造英雄 + 加经验写 hero_cache → get_hero_info 读 pre/tLevel
	var pd := PlayerData.new(cm)
	var inst_id: int = pd.hero_manager.add_hero(1)
	var hero: HeroInstance = pd.hero_manager.get_hero(inst_id)
	var pre_level: int = hero.level
	pd.hero_manager.add_hero_exp(inst_id, 50)   # 写 hero_cache[1]
	var r: Dictionary = StageAccount.get_hero_info(1, 25, cm, pd.hero_manager)
	assert_eq(int(r["id"]), 1, "id=tid")
	assert_eq(int(r["t_level"]), hero.level, "t_level=当前级")
	assert_eq(int(r["level"]), pre_level, "level=pre_level（快照）")
	assert_eq(int(r["add_hero_exp"]), 25, "add_hero_exp=传入 hero_exp")
	assert_eq(int(r["stars"]), int(hero.stars), "stars=英雄星级（源 stars=hero._stars，2026-08-28 补译）")
	assert_true(r.has("is_max_level"), "is_max_level 字段（playerlimit 未接入默认 false）")


func test_get_hero_info_missing_hero() -> void:
	# tid 不存在 → 返空字典（兜底不崩）
	var pd := PlayerData.new(cm)
	var r: Dictionary = StageAccount.get_hero_info(99999, 10, cm, pd.hero_manager)
	assert_eq(r.size(), 0, "缺失英雄返空字典")
