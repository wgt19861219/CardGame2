extends Node

## GM 满强度注入 override（2026-10-09 用户指示：新本打不过，账号强度拉满）。
## 经 runtime install_override 注册为 MCPOVERRIDE autoload，重启游戏 _ready 跑一次：
## 战队 99/VIP 15/五币种拉满/全英雄收集 + 100 级满星 rank23 技能满/23 阶装备满强化 → 落盘。
## 不动关卡进度与上阵阵容（ch203 用户自己打）。注入前备份 save_save_1.pre_gmmax_20261009.json。
## 用完 uninstall_override 清注册。


const MAX_HERO_LEVEL: int = 100   # Levels 表末位（resources/data/Levels.json rows=100）
const TEAM_LEVEL: int = 99        # PlayerData.MAX_TEAM_LEVEL
const VIP_LEVEL: int = 15         # VIP 表末位（resources/data/VIP.json max=15）
const TOP_RANK: int = 23          # HeroManager.MAX_EQUIP_RANK
const RICH_RESOURCE: int = 99999999
const SWEEP_COIN_ID: int = 390    # PlayerData.SWEEP_COIN_ID
const SWEEP_TARGET: int = 999
const SLOT_COUNT: int = 6         # HeroManager.EQUIP_SLOT_COUNT
const HERO_ID_MAX: int = 100      # PlayerData.HERO_ID_MAX（90000+ 为程序生成 Boss 段）


func _ready() -> void:
	var pd: Variant = GameData.player
	var cm: Variant = GameData.config
	if pd == null or cm == null:
		print("[GM_MAX] FAIL: GameData not ready")
		return

	# 1) 账号层：战队等级 / VIP / 体力 / 五币种 + 扫荡券。
	pd.team_level = TEAM_LEVEL
	pd.team_exp = 0
	pd.vip_level = VIP_LEVEL
	pd.recalc_vitality_max()
	pd.vitality = pd.vitality_max
	pd.diamond = RICH_RESOURCE
	pd.hero_manager.gold = RICH_RESOURCE
	pd.crusade_point = RICH_RESOURCE
	pd.arena_point = RICH_RESOURCE
	pd.guildpoint = RICH_RESOURCE
	pd.dungeonpoint = RICH_RESOURCE
	pd.skill_points = 999
	if int(pd.items.get(SWEEP_COIN_ID, 0)) < SWEEP_TARGET:
		pd.items[SWEEP_COIN_ID] = SWEEP_TARGET

	# 2) 全英雄收集（Unit 表 1-99 行存在即拥有；90000+ Boss 段排除）。
	var unit_table: Dictionary = cm.get_raw_table(&"Unit")
	var added: int = 0
	for tid in unit_table.keys():
		var t: int = int(tid)
		if t <= 0 or t >= HERO_ID_MAX:
			continue
		if pd.hero_manager.find_hero_by_tid(t) == null:
			pd.hero_manager.add_hero(t)
			added += 1

	# 3) 每英雄拉满：等级 100 / 满星 / rank 23 / 技能=等级 / 觉醒 / 23 阶装备 + 强化满经验。
	var hero_equip_table: Dictionary = cm.get_raw_table(&"Hero_equip")
	var hero_data_script: Variant = load("res://scripts/data/hero_data.gd")
	var readequip_script: Variant = load("res://scripts/data/readequip_data.gd")
	var maxed: int = 0
	var top_gs: int = 0
	for inst_id in pd.hero_manager.heroes.keys():
		var hero: Variant = pd.hero_manager.heroes[inst_id]
		var hdata: Variant = hero_data_script.from_config(cm, hero.tid)
		hero.level = MAX_HERO_LEVEL
		hero.exp = 0
		hero.stars = maxi(int(hero.stars), int(hdata.max_stars))
		hero.awake = true
		hero.rank = TOP_RANK
		for i in range(int(hero.skill_levels.size())):
			hero.skill_levels[i] = MAX_HERO_LEVEL
		# rank 23 行 Equip{i} ID = 该阶该槽应穿装备（wear_equip 同口径）；配方槽递减 0 槽留空。
		var rank_equip: Dictionary = hero_equip_table.get(str(hero.tid), {}).get(str(TOP_RANK), {})
		for slot in range(SLOT_COUNT):
			var item_id: int = int(rank_equip.get("Equip" + str(slot + 1) + " ID", 0))
			hero.equip_slots[slot] = item_id
			if item_id <= 0:
				hero.equip_exp[slot] = 0.0
				continue
			# 强化满级（抄 enhance_equip_to_max 的 max_exp=Σ le，跳过钻石扣费）。
			var le_info: Dictionary = readequip_script.get_equip_level_exp(item_id, cm)
			var max_exp: float = 0.0
			for v in le_info["le"]:
				max_exp += float(v)
			hero.equip_exp[slot] = max_exp
		pd.hero_manager.recalc_hero_gs(hero)
		maxed += 1
		top_gs = maxi(top_gs, int(hero.gs))

	GameData.save()
	print("[GM_MAX] heroes_maxed=", maxed, " new_heroes=", added, " top_gs=", top_gs,
			" team_level=", pd.team_level, " vip=", pd.vip_level,
			" diamond=", pd.diamond, " gold=", pd.hero_manager.gold)
