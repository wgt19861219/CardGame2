class_name StageManager
extends RefCounted

## PVE 关卡管理（Logic 层，Step 3.1）：关卡进度 + 解锁 + 结算(星数 max) + 掉落生成。
## 战斗对接上层（enter 返回 rseed，上层跑 BattleEngine，exit 接 result）。治旧版 _loots 空债。

const ELITE_THRESHOLD: int = 10000  # Stage ID >= 10000 为精英关
const PROB_DENOM: float = 100.0
const BATTLE_MAX_TICKS: int = 3000  # 战斗最大 tick（防死循环；需 ≥ time_limit/tick_interval = 90/0.033 ≈ 2727）
const STARS_FULL: int = 3          # 胜利满星
const EXP_MULTIPLIER: int = 10
const HERO_ID_MAX: int = 100
const EQUIP_ID_MAX: int = 600
const SWEEP_TICKET_ID: int = 390
const LOOT_DROP_DUPLICATE: int = 2
const HERO_PERC_MAX: int = 10000  # hp/mp 万分比（0-10000，对齐源 _hp_perc + battle_engine_result PERC_DENOM，addHpInfo setScaleX(hp/10000)）
# 副本段结算常量+逻辑见 StageDungeonLogic（控 ≤300 行拆出）
const SWEEP_PROB_MAX: int = 100
const SWEEP_PROB_DICE: int = 100
const SWEEP_DIAMOND_PRICE: int = 1
const RAID_BONUS_SLOTS: int = 4
# 章节星数奖励 tier（源 player.lua:925-932 getChapterStarRewardTiers 硬编码 3 档：30/60/90 星）
const CHAPTER_STAR_TIERS: Array = [
	{"tier": 1, "stars": 30, "rewards": [{"type": "money", "amount": 30000}, {"type": "item", "id": 14001, "amount": 2}]},
	{"tier": 2, "stars": 60, "rewards": [{"type": "money", "amount": 80000}, {"type": "item", "id": 14002, "amount": 2}]},
	{"tier": 3, "stars": 90, "rewards": [{"type": "rmb", "amount": 100}, {"type": "item", "id": 14003, "amount": 1}]},
]

var config: ConfigManager
var progress: Dictionary = {}  # stage_id(int) -> stars(int)，通关星数
var max_normal: int = 0        # 最远通关普通关
var dungeon_bosses_cleared: Dictionary = {}
var act_times: Dictionary = {}  # 副本组当日次数（源 getActTimes/addActTimes，group→count）
# 章节星数奖励已领记录（key "chapter_tier" → true）。源 player.lua:911 _chapter_star_claimed。
# 注：本项目 StageManager 不由 GameData 持久化（既有 stage 进度同此限制），claimed 会话内有效。
var chapter_star_claimed: Dictionary = {}
# 结构 {stage_key: {item_key: miss_count}}，会话内有效（照源 M.sweep_loot_record 生命周期）。
var sweep_loot_record: Dictionary = {}

# T3 依赖倒置：战斗表现音效钩子 + 技能库（GameData 装配后注入；缺省 Callable/null 静默降级，headless 可测）。
var sfx_hook: Callable = Callable(); var skill_lib: SkillLibrary = null

func _init(cm: ConfigManager) -> void:
	config = cm

func stage_stars(sid: int) -> int: return int(progress.get(sid, 0))


# ---- 章节星数奖励（照源 player.lua:910-973 chapter_star_reward handler 配套）----

func get_chapter_stars(chapter_id: int) -> int:
	var st: Dictionary = config.get_raw_table("Stage")
	var total: int = 0
	for sid_str in st:
		var sid: int = int(sid_str)
		if int(st[sid_str].get("Chapter ID", 0)) == chapter_id and StageAccount.stage_type(sid) == "normal":
			total += stage_stars(sid)
	return total


func get_chapter_star_status(player: PlayerData, chapter_id: int) -> Dictionary:
	var total: int = get_chapter_stars(chapter_id)
	var tiers: Array = []
	for t in CHAPTER_STAR_TIERS:
		var td: Dictionary = t
		var tier: int = int(td["tier"])
		var key: String = "%d_%d" % [chapter_id, tier]
		tiers.append({
			"tier": tier,
			"stars": int(td["stars"]),
			"unlocked": total >= int(td["stars"]),
			"claimed": bool(chapter_star_claimed.get(key, false)),
			"rewards": td["rewards"],
		})
	return {"tiers": tiers, "total_stars": total}


func claim_chapter_star_reward(player: PlayerData, chapter_id: int, tier: int) -> Dictionary:
	var td: Dictionary = {}
	for t in CHAPTER_STAR_TIERS:
		if int((t as Dictionary)["tier"]) == tier:
			td = t
			break
	if td.is_empty():
		return {"ok": false}
	if get_chapter_stars(chapter_id) < int(td["stars"]):
		return {"ok": false}
	var key: String = "%d_%d" % [chapter_id, tier]
	if bool(chapter_star_claimed.get(key, false)):
		return {"ok": false}
	for rw in td["rewards"]:
		var rwd: Dictionary = rw
		var rtype: String = String(rwd["type"])
		if rtype == "money":
			player.hero_manager.add_money(int(rwd["amount"]))
		elif rtype == "rmb":
			player.add_diamond(int(rwd["amount"]))
		elif rtype == "item": player.add_item(int(rwd["id"]), int(rwd["amount"]))
	chapter_star_claimed[key] = true
	return {"ok": true, "rewards": td["rewards"]}


func enter_stage(sid: int, _player: PlayerData) -> Dictionary: return {"ok": true, "stage_id": sid}


func enter_act_stage(stage_id: int, stage_group: int, player: PlayerData, rng: BattleRng) -> Dictionary:
	var table: StringName = &"StageDungeon" if StageData.is_dungeon_stage(stage_id) else &"Stage"
	var cfg: Dictionary = config.get_raw_table(table).get(str(stage_id), {})
	if cfg.is_empty():
		return {"ok": false, "error": "invalid_stage"}
	if player.team_level < int(cfg.get("Unlock Level", 0)):
		return {"ok": false, "error": "level_lock"}
	if StageData.is_dungeon_stage(stage_id):
		var err: String = StageDungeonLogic.check_enter_dungeon(self, stage_id, stage_group, player, config)
		if err != "":
			return {"ok": false, "error": err}
	var vit_cost: int = maxi(int(cfg.get("Vitality Cost", 0)) - int(cfg.get("Vit Return", 0)), 0)
	if vit_cost > 0 and not player.spend_vitality(vit_cost):
		return {"ok": false, "error": "no_vitality"}
	return {"ok": true, "rseed": rng.get_seed(), "loots": generate_loot_list(stage_id, rng), "stage_id": stage_id}


## 端到端（测试/扫荡用）：enter 扣体力 + exit 胜利结算。返 {ok, stars, exp}。
func run_stage_quick(sid: int, player: PlayerData, stars: int) -> Dictionary:
	var enter_r: Dictionary = enter_stage(sid, player)
	if not bool(enter_r["ok"]):
		return {"ok": false}
	var exit_r: Dictionary = exit_stage(sid, stars, true)
	return {"ok": true, "stars": int(exit_r["stars"]), "exp": int(exit_r["exp"])}


## 端到端真实战斗：assemble + 同步跑到胜负 + finalize（测试/扫荡用）。
## View 接入走 assemble_stage_battle → battle_scene._process 驱动 → finalize_stage_battle。
## 敌人装配归位 BattleEngineWaves.setup_battle（修旧版自加装配丢位置 X 镜像/stage_script/英雄重定位/hero_id_list）。
func run_stage_battle(sid: int, player: PlayerData, player_tids: Array[int], rng: BattleRng) -> Dictionary:
	var asm_r: Dictionary = assemble_stage_battle(sid, player, player_tids, rng)
	if not bool(asm_r["ok"]):
		return {"ok": false}
	var eng: BattleEngine = asm_r["engine"]
	var ticks_left: int = BATTLE_MAX_TICKS
	while eng.running and not eng.stage_ended and ticks_left > 0:
		eng.update(BattleEngine.TICK_INTERVAL)
		ticks_left -= 1
	return finalize_stage_battle(eng, sid, player, player_tids, asm_r["loots"])


## 装配阶段（View 接入用）：enter 扣体力 + 生成 loots + 创建并装配 BattleEngine，不跑战斗循环。
## 返 {ok, engine, loots, battle_info, stage_id}；体力不足等失败返 {ok:false}。
## act/raid/dungeon 走 enter_act_stage（扣净消耗 = Vitality Cost - Vit Return）。
func assemble_stage_battle(sid: int, player: PlayerData, player_tids: Array[int], rng: BattleRng) -> Dictionary:
	if StageData.is_dungeon_stage(sid) or StageAccount.stage_type(sid) in ["act", "raid"]:
		var table: StringName = &"StageDungeon" if StageData.is_dungeon_stage(sid) else &"Stage"
		var cfg: Dictionary = config.get_raw_table(table).get(str(sid), {})
		var vit_cost: int = maxi(int(cfg.get("Vitality Cost", 0)) - int(cfg.get("Vit Return", 0)), 0)
		if vit_cost > 0 and not player.spend_vitality(vit_cost):
			return {"ok": false, "error": "no_vitality"}
	var loots: Array[Dictionary] = generate_loot_list(sid, rng)
	var eng := BattleEngine.new()
	eng.rng = rng
	eng.sfx_hook = sfx_hook; eng.skill_lib = skill_lib   # T3 注入（胜/败音效 + waves 建怪技能库）
	_enter_stage(eng, sid, player, player_tids)
	var battle_info: Dictionary = BattleData.from_config(config, sid).battle_info
	return {"ok": true, "engine": eng, "loots": loots, "battle_info": battle_info, "stage_id": sid}


## 结算阶段（View 接入用）：从 engine 终态算胜负 + exit + 发奖。返 {ok, won, stars, exp, money, loots}。
func finalize_stage_battle(eng: BattleEngine, sid: int, player: PlayerData, player_tids: Array[int], loots: Array[Dictionary]) -> Dictionary:
	var won: bool = eng.foreach_alive_unit(BattleEngine.CAMP_ENEMY).is_empty()
	var stars: int = STARS_FULL if won else 0
	var exit_r: Dictionary = exit_stage(sid, stars, won)
	if won and player_tids.size() > 0:
		player.take_stage_reward(sid, stars, player_tids, loots)
		_record_stage_dailyjob(player, sid)
	return {"ok": true, "won": won, "stars": stars, "exp": int(exit_r["exp"]), "money": int(exit_r["money"]), "loots": loots, "hero_hp_mp": _collect_hero_hp_mp(eng), "lose_type": "timeout" if int(eng.last_result) == BattleEngine.RESULT_TIMEOUT else "fail"}


## 玩家单位 hp/mp 万分比快照（源 stageaccount:138-139 hp=hero:hp_perc() 返 0-10000，本项目 HeroInstance
## 无 hp/mp 从 BattleUnit 快照）。存活单位真实，死亡不在 alive → 不收录（stage_account 默认 0，照源死亡英雄 hp=0）。
func _collect_hero_hp_mp(eng: BattleEngine) -> Dictionary:
	var hp_mp: Dictionary = {}
	for u in eng.foreach_alive_unit(BattleEngine.CAMP_PLAYER):
		var tid: int = int(u.tid)
		var hp_max: int = int(u.attribs.get(&"HP", 1))
		var mp_max: int = int(u.attribs.get(&"MP", 1))
		# ceil 对齐 battle_engine_result.gd:26（源 _hp_perc 万分比 ceil，setHp 不丢血）
		var hp_perc: int = clampi(int(ceil(float(u.hp) / float(maxi(hp_max, 1)) * HERO_PERC_MAX)), 0, HERO_PERC_MAX)
		var mp_perc: int = clampi(int(ceil(float(u.mp) / float(maxi(mp_max, 1)) * HERO_PERC_MAX)), 0, HERO_PERC_MAX)
		hp_mp[tid] = {"hp": hp_perc, "mp": mp_perc}
	return hp_mp


## 单机化：跳过副本难度 diff 调整（联机 _pendingDungeonDifficulty）+ initUnitMercenaryData（View run_with_scene）。
func _enter_stage(eng: BattleEngine, sid: int, player: PlayerData, player_tids: Array[int]) -> void:
	eng.reset_stage()
	var stage_table: StringName = &"StageDungeon" if StageData.is_dungeon_stage(sid) else &"Stage"
	eng.stage_info = config.get_raw_table(stage_table).get(str(sid), {})
	_init_self_hero(eng, player, player_tids)
	eng.battle_lookup_id = sid
	var battle_info: Dictionary = BattleData.from_config(config, sid).battle_info
	if battle_info.is_empty():
		# 单机化兜底：Battle 表无配置（PVP 占位 stage/测试），加 tid=1 桩敌人；源 PVE 关必有配置无此分支。
		var stub := BattleUnit.new({"_tid": 1, "_level": 1, "_stars": 1}, BattleEngine.CAMP_ENEMY, {"estimate_rank": true}, config, eng, {}, null)
		eng.add_unit(stub)
	else:
		BattleEngineWaves.setup_battle(eng, config, battle_info)
	eng.mp_bonus = float(eng.stage_info.get(&"MP Bonus", 1.0))


## 源 battle_engine.lua:455-459 普通 PVE 不设 will_cast_manual_skill → 保持 AiCreate 默认 true
## （能量满 AI 自动放 manual 大招；仅 crusade/excavate 模式源 :504/:507 设 false——本项目两模式
## 自建装配跟随默认 true 属既有差异，记滚清单）。旧注释"照源设 false"系错译 :344 isbot 路径，2026-08-18 修正。
func _init_self_hero(eng: BattleEngine, player: PlayerData, player_tids: Array[int]) -> void:
	var sorted_tids: Array[int] = _sort_hero_list(player_tids)
	for tid in sorted_tids:
		var proto: Dictionary = {"_tid": tid}
		var hero: HeroInstance = _find_hero_by_tid(player.hero_manager, tid)
		if hero != null:
			proto["_level"] = hero.level; proto["_stars"] = hero.stars
			proto["_rank"] = hero.rank; proto["_items"] = _hero_items(hero)
			proto["_awake"] = hero.awake
			# 源 main.lua:1590 _skill_levels（漏传致只装 Basic Skill 无大招，2026-08-18 修）
			proto["_skill_levels"] = hero.skill_levels_by_slot()
		else:
			proto["_level"] = 1; proto["_stars"] = 1; proto["_skill_levels"] = {"1": 1, "2": 1, "3": 1, "4": 1}
		# lib=skill_lib（源 ed 全局 SkillLibrary，T3 改装配注入；lib null 致 init_skill 跳过→skill_list 空→不攻击 latent bug 修）
		var u := BattleUnit.new(proto, BattleEngine.CAMP_PLAYER, {"estimate_rank": false}, config, eng, {}, skill_lib)
		eng.add_unit(u)
		eng.hero_id_list.append(tid)


func _sort_hero_list(tids: Array[int]) -> Array[int]:
	if tids.size() <= 1:
		return tids
	var keyed: Array = []  # [range, tid]
	for tid in tids:
		keyed.append([_auto_attack_range(tid), tid])
	keyed.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var out: Array[int] = []
	for entry in keyed:
		out.append(int(entry[1]))
	return out


func _auto_attack_range(tid: int) -> float:
	var auto_attack: Variant = config.lookup(&"Unit", &"Basic Skill", tid)
	if auto_attack == null:
		return 0.0
	var r: Variant = config.lookup(&"Skill", &"Max Range", auto_attack)
	return float(r) if r != null else 0.0


## 按 tid 找玩家首个英雄实例（上场 tid→HeroInstance 映射；无则 null 走桩）。
static func _find_hero_by_tid(mgr: HeroManager, tid: int) -> HeroInstance:
	if mgr == null:
		return null
	for inst_id in mgr.heroes:
		var h: HeroInstance = mgr.heroes[inst_id]
		if h.tid == tid:
			return h
	return null


static func _hero_items(hero: HeroInstance) -> Array:
	var items: Array = []
	for i in range(hero.equip_slots.size()):
		var item_id: int = int(hero.equip_slots[i])
		if item_id > 0:
			items.append({"_item_id": item_id, "_exp": float(hero.equip_exp[i])})
	return items


## 关卡是否解锁（玩家等级 + 前置关卡星数）。
func is_unlocked(sid: int, player_level: int) -> bool:
	var data := StageData.from_config(config, sid)
	if player_level < data.unlock_level: return false
	return not (data.require_stage != 0 and stage_stars(data.require_stage) < data.require_stars)


func get_normal_progress() -> int: return StageAccount.get_normal_progress(progress)
func get_elite_progress() -> int: return StageAccount.get_elite_progress(progress, config.get_raw_table(&"Stage"))
func get_max_chapter(m: String) -> int: return StageAccount.get_max_chapter(m, progress, config.get_raw_table(&"Stage"))

## 结算：胜利取星数 max(历史,本次) + 发放奖励；失败不变。
## 副本关（is_dungeon_stage）照源 :787-829：难度金币 + 副本硬币 + dungeon_bosses_cleared 持久化。
func exit_stage(sid: int, result_stars: int, won: bool, player: PlayerData = null) -> Dictionary:
	var prev: int = stage_stars(sid)
	if won:
		var best: int = max(prev, result_stars)
		progress[sid] = best
		if sid < ELITE_THRESHOLD: max_normal = max(max_normal, sid)
		if StageData.is_dungeon_stage(sid):
			return StageDungeonLogic.exit_dungeon(self, config, sid, best, player)
		var d := StageData.from_config(config, sid)
		return {"stars": best, "exp": d.exp_reward * EXP_MULTIPLIER, "money": d.money_reward * EXP_MULTIPLIER}
	return {"stars": prev, "exp": 0, "money": 0}  # 失败不变

## 生成掉落（enter 预生成 / 扫荡用 item_id 列表）：7 槽概率判定，确定性 rng。
func generate_loots(sid: int, rng: BattleRng) -> Array[int]:
	var data := StageData.from_config(config, sid)
	var loots: Array[int] = []
	for drop in data.drops:
		if rng.randf() < float(int(drop["probability"])) / PROB_DENOM:
			loots.append(int(drop["item_id"]))
	return loots


## 生成掉落列表（照源 local_server.lua:383 generateLoots + player.lua:1265 getStageLoots 解包合并）。
## 概率判定（UI reward[i] / Pro）+ 翻倍（每个加 2 个）+ 必掉扫荡券 390。返 [{id,type}] 供 take_stage_reward 发放。
func generate_loot_list(sid: int, rng: BattleRng) -> Array[Dictionary]:
	var data := StageData.from_config(config, sid)
	var loots: Array[Dictionary] = []
	for drop in data.drops:
		if rng.randf() < float(int(drop["probability"])) / PROB_DENOM:
			var item_id: int = int(drop["item_id"])
			var loot: Dictionary = {"id": item_id, "type": _item_type(item_id)}
			for _i in range(LOOT_DROP_DUPLICATE):
				loots.append(loot)
	loots.append({"id": SWEEP_TICKET_ID, "type": _item_type(SWEEP_TICKET_ID)})
	return loots


## 物品类型判定（照源 player.lua:1180-1193 itemType：id < 100 hero / id < 600 equip / else ""）。
static func _item_type(item_id: int) -> String:
	if item_id < HERO_ID_MAX:
		return "hero"
	if item_id < EQUIP_ID_MAX:
		return "equip"
	return ""

## 扫荡：奖励 × times + 掉落保底 × times + Raid Bonus（rng 可选）。
## player 传入时扣体力（power×times）+ sweep_type 分支消耗：free 扫荡券 / pay 钻石（照源回复处理 :4781-4790）。
## 门槛（stars/每日次数/体力）由 UI doClickSweep（stagedetail.lua:128-151）把关，Logic 不重复——照源分层。
## 返回 {ok, exp, money, loots, raid_bonus}：loots 物品 id 列表，raid_bonus 额外奖励 [{id,amount}]。
func sweep(sid: int, times: int, rng: Variant = null, player: PlayerData = null, sweep_type: String = "free") -> Dictionary:
	if times <= 0:
		return {"ok": false, "exp": 0, "money": 0, "loots": [], "raid_bonus": []}
	var data := StageData.from_config(config, sid)
	# power = Stage "Vitality Cost"（battleprepare.lua:218）。先查后扣保原子。
	if player != null:
		var sweep_power: int = data.vitality_cost * times
		if player.vitality < sweep_power:
			return {"ok": false, "reason": "no_vitality", "exp": 0, "money": 0, "loots": [], "raid_bonus": []}
		if not (player.use_sweep_times(times) if sweep_type == "free" else player.spend_diamond(SWEEP_DIAMOND_PRICE * times)):
			return {"ok": false, "reason": "no_sweep_coin" if sweep_type == "free" else "no_diamond", "exp": 0, "money": 0, "loots": [], "raid_bonus": []}
		player.spend_vitality(sweep_power)
	var stage_row: Dictionary = config.get_raw_table("Stage").get(str(sid), {})
	var loots: Array[int] = []
	if rng != null and rng is BattleRng:
		var stage_key: String = str(sid)
		sweep_loot_record[stage_key] = sweep_loot_record.get(stage_key, {})
		for _t in times:
			for drop in data.sweep_drops:
				var item_key: String = str(int(drop["item_id"]))
				var base_pro: int = int(drop["probability"])
				var miss_count: int = int(sweep_loot_record[stage_key].get(item_key, 0))
				var loot_pro: int = mini(base_pro if miss_count == 0 else base_pro * miss_count, SWEEP_PROB_MAX)
				if rng.randi_range(1, SWEEP_PROB_DICE) <= loot_pro:
					loots.append(int(drop["item_id"]))
					sweep_loot_record[stage_key][item_key] = 0
				else:
					sweep_loot_record[stage_key][item_key] = miss_count + 1
	var raid_bonus: Array[Dictionary] = []
	for i in range(1, RAID_BONUS_SLOTS + 1):
		var b_id: int = int(stage_row.get("Raid Bonus ID " + str(i), 0))
		var b_amt: int = int(stage_row.get("Raid Bonus Amount " + str(i), 0))
		if String(stage_row.get("Raid Bonus Type " + str(i), "")) == "Item" and b_id != 0 and b_amt > 0:
			raid_bonus.append({"id": b_id, "amount": b_amt * times})
	return {"ok": true, "exp": data.exp_reward * EXP_MULTIPLIER * times, "money": data.money_reward * EXP_MULTIPLIER * times, "loots": loots, "raid_bonus": raid_bonus}


func _record_stage_dailyjob(player: PlayerData, sid: int) -> void:
	if player == null or player.task_manager == null:
		return
	var stage_row: Dictionary = config.get_raw_table("Stage").get(str(sid), {})
	var chapter: int = int(stage_row.get("Chapter ID", 0))
	var s_type: String = StageAccount.stage_type(sid)
	player.task_manager.record_by_type(config, "FarmChapter")
	if s_type == "normal" or s_type == "elite":
		player.task_manager.record_by_type(config, "FarmPVEStage")
	if s_type == "elite":
		player.task_manager.record_by_type(config, "FarmElitePVEStage")


## 存档序列化。
func to_dict() -> Dictionary:
	return {"progress": progress.duplicate(true), "max_normal": max_normal, "chapter_star_claimed": chapter_star_claimed.duplicate(true), "sweep_loot_record": sweep_loot_record.duplicate(true), "dungeon_bosses_cleared": dungeon_bosses_cleared.duplicate(true), "act_times": act_times.duplicate(true)}

static func from_dict(data: Dictionary, cm: ConfigManager) -> StageManager:
	var mgr := StageManager.new(cm)
	mgr.progress = data.get("progress", {})
	mgr.max_normal = int(data.get("max_normal", 0))
	mgr.chapter_star_claimed = data.get("chapter_star_claimed", {})
	mgr.sweep_loot_record = data.get("sweep_loot_record", {})
	mgr.dungeon_bosses_cleared = data.get("dungeon_bosses_cleared", {})
	mgr.act_times = data.get("act_times", {})
	return mgr
