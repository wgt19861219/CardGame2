extends GutTest
# 排行榜 NPC 假榜测试（照源 local_server.lua:2227-2332 query_ranklist）。
# selfParam 5 档聚合（源 :2234-2272）：top_gs/full_hero_gs/hero_team_gs/hero_evo_star/hero_arousal/default。

var cm: ConfigManager


func before_all() -> void:
	cm = ConfigManager.new()
	cm.load_all()


func test_generate_ranklist_20_entries() -> void:
	var rm := RanklistManager.new()
	var pd := PlayerData.new(cm)
	var r: Dictionary = rm.generate_ranklist(pd, "top_gs")
	var items: Array = r["items"]
	assert_eq(items.size(), 20, "20 NPC 假榜")
	for i in items.size():
		var item: Dictionary = items[i]
		assert_true(String(item["name"]) != "", "NPC 名非空")
		assert_gte(int(item["param"]), 10, "param 下限 10（源 :2281）")


func test_self_param_uses_hero_gs() -> void:
	# 源 :2234-2257 selfParam 基于英雄 gs（top15Gs），非旧简化 team_level×100
	var rm := RanklistManager.new()
	var pd := PlayerData.new(cm)
	pd.team_level = 99  # 故意高，验证 self_param 不再依赖 team_level
	var no_hero: int = int(rm.generate_ranklist(pd, "top_gs")["self_param"])
	assert_eq(no_hero, 0, "无英雄 self_param=0（top15Gs）")
	pd.hero_manager.add_hero(1)
	var with_hero: int = int(rm.generate_ranklist(pd, "top_gs")["self_param"])
	assert_gte(with_hero, no_hero, "加英雄后 self_param >= 加前（top15Gs 含英雄 gs）")


func test_rank_type_5_buckets() -> void:
	# 源 :2259-2272 5 档 rank_type 聚合不同维度（旧版 5 榜同分，修后应区分）
	var rm := RanklistManager.new()
	var pd := PlayerData.new(cm)
	pd.hero_manager.add_hero(1)  # HeroInstance: gs=calc_gs, stars=1, rank=1
	var top_gs: int = int(rm.generate_ranklist(pd, "top_gs")["self_param"])         # top15Gs
	var full_gs: int = int(rm.generate_ranklist(pd, "full_hero_gs")["self_param"])  # totalGs
	var evo_star: int = int(rm.generate_ranklist(pd, "hero_evo_star")["self_param"])  # Σstars
	var arousal: int = int(rm.generate_ranklist(pd, "hero_arousal")["self_param"])   # Σrank
	# 1 英雄：top15Gs == totalGs == top5Gs（都=该英雄 gs）
	assert_eq(top_gs, full_gs, "1 英雄 top_gs(top15)==full_hero_gs(totalGs)")
	assert_eq(evo_star, 1, "hero_evo_star = Σstars = 1（HeroInstance.stars 默认 1）")
	assert_eq(arousal, 1, "hero_arousal = Σrank = 1（HeroInstance.rank 默认 1）")


# 源 :2284-2292 guildliveness 公会活跃榜（假榜硬编码 guildNames，_guild_summary 结构 + param=max(3000-i*120,100)）。
# guildNames :2230 非联机数据（同 AI_NAMES 假名），不属公会裁剪范畴，照源补 Logic 分支。
func test_guildliveness_branch() -> void:
	var rm := RanklistManager.new()
	var pd := PlayerData.new(cm)
	var r: Dictionary = rm.generate_ranklist(pd, "guildliveness")
	var items: Array = r["items"]
	assert_eq(items.size(), 20, "公会活跃榜 20 条")
	# 源 :2288 _name=guildNames[ni]（非 user 榜的 npcNames）
	assert_eq(String(items[0]["name"]), "暗影军团", "第 1 名=暗影军团（GUILD_NAMES[0]，源 :2230）")
	# 源 :2291 param=max(3000-i*120,100)：第 1 名 2880 / 第 20 名 600
	assert_eq(int(items[0]["param"]), 2880, "第 1 名 param=3000-1×120=2880（源 :2291）")
	assert_eq(int(items[19]["param"]), 600, "第 20 名 param=3000-20×120=600（源 :2291）")
	# 源 _guild_summary 无 _level（user 榜 _user_summary 才有 _level）
	assert_eq(int(items[0]["level"]), 0, "公会榜无 level（源 _guild_summary 结构）")
