class_name HeroManager
extends RefCounted

## 英雄管理（Logic 层）：拥有英雄集合 + 升星/分解/碎片合成。
## 消耗规则查 HeroStars / Fragment 表（ConfigManager）。金币与碎片由本管理器持有，
## 持久化由 2.4 PlayerData 接管。

var config: ConfigManager
var heroes: Dictionary = {}   # inst_id(int) -> HeroInstance
var fragments: Dictionary = {}  # fragment_id(int) -> count(int)
var gold: int = 0
var next_id: int = 1
var hero_cache: Dictionary = {}  # tid(int) -> {pre_exp,pre_level,exp_increment}（源 ed.player.heroCache，结算升级动画用，player.lua:1977-1982）

const MAX_EQUIP_RANK: int = 22  # 玩家装备 rank 进阶上限（源 player.lua:2066 canUpgrade `_rank < 22`；Hero_equip 表 23 档是数据，rank 23 玩家不可达，照源）
const EQUIP_SLOT_COUNT: int = 6  # 装备槽数（源 player._items 1-6，本项目 equip_slots 0-5）
const GS_BASE: int = 5  # 战斗力基础值（源 addHero hero._gs=5，player.lua:1490）
const GS_PER_SKILL_LEVEL: int = 10

func _init(cm: ConfigManager) -> void:
	config = cm

## 添加英雄（首次获得），返回实例 id。stars 取 Unit.Initial Stars。
func add_hero(tid: int) -> int:
	var data := HeroData.from_config(config, tid)
	var hero := HeroInstance.new(tid, data.initial_stars, next_id)
	_init_skill_levels(hero)
	hero.gs = calc_gs(hero)
	heroes[next_id] = hero
	next_id += 1
	return hero.inst_id


## 技能等级初始化（照源 player.lua:1502-1506：skill_levels[i] = SkillGroup[tid][i]["Init Level"]）。
## Coco slot 1-4 InitLevel = 1/1/21/41；显示等级 = skill_levels-InitLevel+1（统一初始 lv.1）。
## 高阶技能 InitLevel 高，等级上限检查 skill_levels[idx]>=hero.level 自然拦住低级英雄升高级技能。
func _init_skill_levels(hero: HeroInstance) -> void:
	var sg: Dictionary = config.get_raw_table(&"SkillGroup").get(str(hero.tid), {})
	for i in hero.skill_levels.size():
		var slot_info: Dictionary = sg.get(str(i + 1), {})
		hero.skill_levels[i] = int(slot_info.get("Init Level", 1))

func get_hero(inst_id: int) -> HeroInstance:
	return heroes.get(inst_id) as HeroInstance


## 已拥有英雄的 inst_id 列表（照源 ed.player.heroes 顺序；hero_detail 翻页用）。
func get_owned_hero_ids() -> Array:
	return heroes.keys()

## 升星：消耗专属碎片 × HeroStars.Upgrade Fragments + 金币 Upgrade Price；达 max_stars 不可升。
func evolve(inst_id: int) -> bool:
	var hero := get_hero(inst_id)
	if hero == null:
		return false
	var data := HeroData.from_config(config, hero.tid)
	if hero.stars >= data.max_stars:
		return false
	var frag_id := config.get_int(&"Fragment", hero.tid, &"Fragment ID")
	var cost_frags := config.get_int(&"HeroStars", hero.stars, &"Upgrade Fragments")
	var cost_gold := config.get_int(&"HeroStars", hero.stars, &"Upgrade Price")
	if _fragment_count(frag_id) < cost_frags or gold < cost_gold:
		return false
	_add_fragment(frag_id, -cost_frags)
	gold -= cost_gold
	hero.stars += 1
	return true


## 按 tid 查已有英雄实例（源 ed.player.heroes[tid]）。
func find_hero_by_tid(tid: int) -> HeroInstance:
	for hero in heroes.values():
		if (hero as HeroInstance).tid == tid:
			return hero
	return null


## hero_evolve 统一入口（源 local_server.lua:905-987）：按英雄存在性分流。
## 已有英雄 → 升星（evolve）；未拥有 → 新英雄召唤（add_hero + Summon Fragments/Price）。
## 返 {ok:bool, inst_id:int}（召唤时返新 inst_id）。
func hero_evolve(tid: int) -> Dictionary:
	var existing := find_hero_by_tid(tid)
	if existing != null:
		return {"ok": evolve(existing.inst_id), "inst_id": existing.inst_id}
	# 新英雄召唤：读 HeroStars[initial_stars] Summon Fragments + Summon Price
	var data := HeroData.from_config(config, tid)
	var frag_id := config.get_int(&"Fragment", tid, &"Fragment ID")
	var cost_frags := config.get_int(&"HeroStars", data.initial_stars, &"Summon Fragments")
	var cost_gold := config.get_int(&"HeroStars", data.initial_stars, &"Summon Price")
	if _fragment_count(frag_id) < cost_frags or gold < cost_gold:
		return {"ok": false, "inst_id": 0}
	_add_fragment(frag_id, -cost_frags)
	gold -= cost_gold
	var new_id := add_hero(tid)
	return {"ok": true, "inst_id": new_id}

## 分解预览（照源 split 返还碎片）：返 {fragment_id, count}，不执行。供 splitwindow 显示返还详情。
func preview_split(inst_id: int) -> Dictionary:
	var hero := get_hero(inst_id)
	if hero == null:
		return {}
	var convert_count := config.get_int(&"HeroStars", hero.stars, &"Convert Fragments")
	var frag_id := config.get_int(&"Fragment", hero.tid, &"Fragment ID")
	return {"fragment_id": frag_id, "count": convert_count}


## 分解：返还 HeroStars.Convert Fragments 数量的专属碎片，移除英雄。
func split(inst_id: int) -> Dictionary:
	var hero := get_hero(inst_id)
	if hero == null:
		return {}
	var preview := preview_split(inst_id)
	heroes.erase(inst_id)
	_add_fragment(preview["fragment_id"], preview["count"])
	return preview

## 碎片合成：消耗 Fragment 表配方的专属+通用碎片+金币，获得目标英雄。
## 校验 frag_have + min(uni_have, uni_need) >= frag_need；已有英雄拒绝（:138）；金币不足单机化降级（:132 不弹 useMidas 点金手）。
func compose(target_tid: int) -> bool:
	if not config.has_entry(&"Fragment", target_tid):
		return false
	for inst_id in heroes:
		if (heroes[inst_id] as HeroInstance).tid == target_tid:
			return false
	var frag_id := config.get_int(&"Fragment", target_tid, &"Fragment ID")
	var frag_need := config.get_int(&"Fragment", target_tid, &"Fragment Count")
	var uni_id := config.get_int(&"Fragment", target_tid, &"Universal Fragment ID")
	var uni_need := config.get_int(&"Fragment", target_tid, &"Universal Fragment Count")
	var expense := config.get_int(&"Fragment", target_tid, &"Expense")
	var frag_have := _fragment_count(frag_id)
	var uni_have := _fragment_count(uni_id)
	var uni_avail: int = min(uni_have, uni_need)
	if frag_have + uni_avail < frag_need:
		return false
	if gold < expense:
		return false
	var frag_use: int = min(frag_have, frag_need)
	var uni_use: int = max(0, frag_need - frag_have)
	_add_fragment(frag_id, -frag_use)
	_add_fragment(uni_id, -uni_use)
	gold -= expense
	add_hero(target_tid)
	return true

## 进阶条件（照源 player.lua:2059 canUpgrade）：6 槽全穿齐 hero_equip[tid][rank] 要求装备 + rank<上限。
func can_upgrade_rank(inst_id: int) -> bool:
	var hero := get_hero(inst_id)
	if hero == null:
		return false
	if hero.rank >= MAX_EQUIP_RANK:
		return false
	var rank_equip: Dictionary = config.get_raw_table(&"Hero_equip").get(str(hero.tid), {}).get(str(hero.rank), {})
	for slot in range(EQUIP_SLOT_COUNT):
		var requirement: int = int(rank_equip.get("Equip" + str(slot + 1) + " ID", 0))
		if int(hero.equip_slots[slot]) != requirement:
			return false
	return true


## 进阶（照源 player.lua:2069 upgrade）：canUpgrade 校验 → rank+1 → 重置 6 槽（_items={_item_id=0,_exp=0}）
## → 自动穿 hero_equip[tid][new_rank]["Init{i} ID"]。源 100% 成功（upgrade 无 addMoney 金币消耗）。
## 单机化照源不接 net reply；addExp(0) 触发属性重算由 add_hero_exp 入口衔接（此处不调）。
func upgrade_rank(inst_id: int) -> bool:
	var hero := get_hero(inst_id)
	if hero == null or not can_upgrade_rank(inst_id):
		return false
	hero.rank += 1
	var rank_equip: Dictionary = config.get_raw_table(&"Hero_equip").get(str(hero.tid), {}).get(str(hero.rank), {})
	for slot in range(EQUIP_SLOT_COUNT):
		hero.equip_slots[slot] = int(rank_equip.get("Init" + str(slot + 1) + " ID", 0))
		hero.equip_exp[slot] = 0.0
	hero.gs = calc_gs(hero)
	return true


## 战斗力 GS（照源 main.lua:1750 穿戴 delta + player.lua:1490 addHero _gs=5）：
## 重算 = 基础 5 + sum(6 槽 Equip.GS × Hero_equip.EquipLevel)。源增量维护 _gs（wear/upgrade ±delta，
## math.floor），本项目重算语义等价（calc_gs = GS_BASE + 当前 6 槽贡献总和，int floor）。
func calc_gs(hero: HeroInstance) -> int:
	var rank_equip: Dictionary = config.get_raw_table(&"Hero_equip").get(str(hero.tid), {}).get(str(hero.rank), {})
	var equip_level: float = float(rank_equip.get("EquipLevel", 1.0))
	var total: float = float(GS_BASE)
	for slot in range(EQUIP_SLOT_COUNT):
		var item_id: int = int(hero.equip_slots[slot])
		if item_id > 0:
			total += config.get_float(&"Equip", item_id, &"GS") * equip_level
	var sg: Dictionary = config.get_raw_table(&"SkillGroup").get(str(hero.tid), {})
	for i in hero.skill_levels.size():
		var init_lv: int = int(sg.get(str(i + 1), {}).get("Init Level", 1))
		total += maxi(hero.skill_levels[i] - init_lv, 0) * GS_PER_SKILL_LEVEL
	return int(total)


## 英雄加经验升级（照源 player.lua:1972-2010 addExp）：入口快照 hero_cache + 循环 Levels.Exp 累减升级。
## levelup_exp<=0（Levels 末位/缺失）自然停。返是否升过级。
## 单机化：源满级截断分支（else: hc.expIncrement 调整 + exp=levelup_exp）依赖 playerlimit.heroLevelLimit，
## 本项目 playerlimit 未接入，英雄无硬上限（靠 Levels 表末位停），照源不接满级截断。
func add_hero_exp(inst_id: int, exp: int) -> bool:
	var hero := get_hero(inst_id)
	if hero == null or exp <= 0:
		return false
	var oexp: int = hero.exp
	var olevel: int = hero.level
	hero.exp += exp
	var hc: Dictionary = hero_cache.get(hero.tid, {})
	hc["pre_exp"] = oexp
	hc["pre_level"] = olevel
	hc["exp_increment"] = exp
	hero_cache[hero.tid] = hc
	var leveled: bool = false
	var levels: Dictionary = config.get_raw_table(&"Levels")
	while true:
		var levelup_exp: int = int(levels.get(str(hero.level), {}).get(&"Exp", 0))
		if levelup_exp <= 0 or hero.exp < levelup_exp:
			break
		hero.exp -= levelup_exp
		hero.level += 1
		leveled = true
	return leveled


## 装备强化移至 PlayerData.enhance_equip（照源 ed.player 统一入口，材料 Enhance Value 经验 +
## Unit Price 金币双消耗，退役旧版"扣 Price 金币买跳级"偏离源实现）。


## 技能升级（照源 skillstren.lua:144 doClickLvupButton + player.lua:697 strenHeroSkill）。
## 限制：① skill_levels[idx] >= hero.level 拒绝（源 :155 skl>=hlv，技能等级不可超英雄等级）
##      ② gold < SkillLevels[level].Price 拒绝（源 :157 cost>money）
## 扣 gold（源 :167 addMoney）+ skill_levels[idx]+1（源 strenHeroSkill）。
## 技能点由 player_data.upgrade_hero_skill 扣（源 net.lua:12 addSkillPoint）。
func upgrade_skill_level(inst_id: int, skill_idx: int) -> bool:
	var hero := get_hero(inst_id)
	if hero == null or skill_idx < 0 or skill_idx >= hero.skill_levels.size():
		return false
	var cur_level: int = hero.skill_levels[skill_idx]
	if cur_level >= hero.level:
		return false
	var cost: int = _get_skill_upgrade_cost(cur_level)
	if gold < cost:
		return false
	gold -= cost
	hero.skill_levels[skill_idx] += 1
	hero.gs = calc_gs(hero)
	return true


## 技能升级金币消耗（照源 skillstren.lua:469 getCost = SkillLevels[level].Price）。
## level 越界 fallback 末位/首位（源 t[level] or t[#t] or t[1]）。
func _get_skill_upgrade_cost(cur_level: int) -> int:
	var t: Dictionary = config.get_raw_table(&"SkillLevels")
	var entry: Dictionary = t.get(str(cur_level), {})
	if entry.is_empty():
		entry = t.get(str(t.size()), t.get("1", {}))
	return int(entry.get(&"Price", 0))


## 装备穿戴（照源 main.lua:1750 wear_equip + player.lua:2061 canUpgrade requirement）：
## 查该 rank 该槽应穿装备 → 客户端 hero._items[slot]=newItemId 落地。**不传 item_id（目标由 hero_equip
## 表 rank 决定）、不扣背包（材料在 equipcraft 合成时消耗）、不校验 level/rank（合成时保证）**。
## slot 本项目 0-5 → 源 1-6（"Equip{slot+1} ID"）。
func wear_equip(inst_id: int, slot: int) -> bool:
	var hero := get_hero(inst_id)
	if hero == null or slot < 0 or slot >= EQUIP_SLOT_COUNT:
		return false
	var rank_equip: Dictionary = config.get_raw_table(&"Hero_equip").get(str(hero.tid), {}).get(str(hero.rank), {})
	var item_id: int = int(rank_equip.get("Equip" + str(slot + 1) + " ID", 0))
	if item_id <= 0:
		return false
	hero.equip_slots[slot] = item_id
	hero.gs = calc_gs(hero)
	return true

func _fragment_count(frag_id: int) -> int:
	return int(fragments.get(frag_id, 0))


## 碎片可合成查询（照源 readequip.lua:810-840 isFragmentEnough + createIconWithTag :855-861）。
## 专属碎片持有 >= Fragment Count 且未拥有该英雄时返 true（背包图标 fragment_tick 角标用）。
## 仅判专属（源 createIconWithTag 同），不含通用补足（compose 的"专属+通用"更宽，角标照源只看专属，差异保留）。
func is_fragment_composable(tid: int) -> bool:
	var row: Dictionary = config.get_raw_table(&"Fragment").get(str(tid), {})
	if row.is_empty():
		return false
	var frag_id: int = int(row.get(&"Fragment ID", 0))
	var need: int = int(row.get(&"Fragment Count", 0))
	for inst_id in heroes:
		if (heroes[inst_id] as HeroInstance).tid == tid:
			return false
	return _fragment_count(frag_id) >= need


func _add_fragment(frag_id: int, delta: int) -> void:
	fragments[frag_id] = _fragment_count(frag_id) + delta


## 添加碎片（抽卡/副本奖励产出公开入口；包装 _add_fragment + 入口校验）。
func add_fragment(frag_id: int, count: int) -> void:
	if frag_id <= 0 or count <= 0:
		return
	_add_fragment(frag_id, count)


## 查碎片数（公开入口；觉醒养成 AwakeHelper.can_awake_with_count 用）。
func fragment_count(frag_id: int) -> int:
	return _fragment_count(frag_id)


## 扣碎片（单机化觉醒激活用；不足返 false，不部分扣）。
func spend_fragment(frag_id: int, count: int) -> bool:
	if frag_id <= 0 or count <= 0:
		return false
	if _fragment_count(frag_id) < count:
		return false
	_add_fragment(frag_id, -count)
	return true

## 序列化（持久化用，入口 int 校验）。
func to_dict() -> Dictionary:
	var heroes_data: Array[Dictionary] = []
	for inst_id in heroes:
		var h: HeroInstance = heroes[inst_id]
		heroes_data.append({
			"inst_id": inst_id, "tid": h.tid, "rank": h.rank,
			"level": h.level, "stars": h.stars, "exp": h.exp,
			"skill_levels": h.skill_levels,
			"equip_slots": h.equip_slots,
			"equip_exp": h.equip_exp,
			"gs": h.gs,
			"awake": h.awake,
		})
	return {"gold": gold, "fragments": fragments.duplicate(true), "heroes": heroes_data, "next_id": next_id, "hero_cache": hero_cache.duplicate(true)}


## 加金币（源 player.lua:434 addMoney：math.max(_money+money, 0)，非负保护）。
func add_money(amount: int) -> void:
	gold = maxi(0, gold + amount)


## 从字典重建（入口 int 校验，治存档 float→int）。
static func from_dict(data: Dictionary, cm: ConfigManager) -> HeroManager:
	var mgr := HeroManager.new(cm)
	mgr.gold = int(data.get("gold", 0))
	mgr.next_id = int(data.get("next_id", 1))
	var frags: Dictionary = data.get("fragments", {})
	for frag_id in frags:
		mgr.fragments[int(frag_id)] = int(frags[frag_id])
	var heroes_list: Array = data.get("heroes", [])
	for h in heroes_list:
		var hd: Dictionary = h
		var hero := HeroInstance.new(int(hd["tid"]), int(hd["stars"]), int(hd["inst_id"]))
		hero.rank = int(hd.get("rank", 1))
		hero.level = int(hd.get("level", 1))
		hero.exp = int(hd.get("exp", 0))
		hero.skill_levels = hd.get("skill_levels", [1, 1, 1, 1])
		var es: Array = hd.get("equip_slots", [0, 0, 0, 0, 0, 0])
		for j in range(hero.equip_slots.size()):
			if j < es.size():
				hero.equip_slots[j] = int(es[j])
		var ee: Array = hd.get("equip_exp", [])
		for j in range(hero.equip_exp.size()):
			if j < ee.size():
				hero.equip_exp[j] = float(ee[j])
		hero.gs = int(hd.get("gs", GS_BASE))
		hero.awake = bool(hd.get("awake", false))
		mgr.heroes[hero.inst_id] = hero
	var hc_data: Dictionary = data.get("hero_cache", {})
	for tid in hc_data:
		var src: Dictionary = hc_data[tid]
		var dst: Dictionary = {}
		dst["pre_exp"] = int(src.get("pre_exp", 0))
		dst["pre_level"] = int(src.get("pre_level", 0))
		dst["exp_increment"] = int(src.get("exp_increment", 0))
		mgr.hero_cache[int(tid)] = dst
	return mgr
