class_name StageDungeonLogic
extends RefCounted

## 副本段结算逻辑（Logic 层）— 从 StageManager 拆出控 ≤300 行。
## 照源 local_server.lua:686-712（次数校验+BuyCost）+ :787-829（副本结算：难度金币/硬币/dungeon_bosses_cleared）。
## static 方法，首参传 StageManager 实例（读 act_times/dungeon_bosses_cleared 字段）。

# 源 :795 难度金币表 goldByDiff（副本关结算按 Difficulty 查）
const DUNGEON_GOLD_BY_DIFF: Dictionary = {1: 2000, 2: 3500, 3: 5000, 4: 8000}
# 源 :417-418 getDungeonCoinReward ranges：按难度档随机 [low,high]（固定值改范围随机修复 A3）
const DUNGEON_COIN_RANGES: Dictionary = {
	1: Vector2i(5, 8),
	2: Vector2i(10, 15),
	3: Vector2i(20, 30),
	4: Vector2i(35, 50),
}
const DUNGEON_COIN_DIFF_DEFAULT: int = 1   # 源 :420 ranges[difficulty] or ranges[1] fallback
const DUNGEON_BOSS_BASE: int = 50000  # 源 :815 baseId = 50000 + stage_id % 1000
const DUNGEON_BOSS_MOD: int = 1000    # 源 :815 baseId 模量
const DUNGEON_DAILY_LIMIT_DEFAULT: int = 2   # 源 :689 DailyLimit fallback
const DUNGEON_MAX_BUY_DEFAULT: int = 3       # 源 :690 MaxBuyPerDay fallback
const DUNGEON_BUYCOST_DEFAULT: int = 50      # 源 :700 BuyCost fallback
const DUNGEON_GOLD_FALLBACK: int = 2000      # 源 :796 fallback
const EXP_MULTIPLIER: int = 10  # 源 PVE 经验 ×10
# 源 :476-480 heroicPrereq 映射：英雄副本组 → 对应普通副本组（要求该普通组所有 Boss 通关）
const HEROIC_PREREQ: Dictionary = {40005: 40001, 40006: 40002, 40007: 40003}


## 源 :416-422 getDungeonCoinReward：按难度档硬币范围随机。
## rng 参数便于单测固定种子；exit_dungeon 运行时传 RandomNumberGenerator.new()。
static func get_dungeon_coin_reward(difficulty: int, rng: RandomNumberGenerator) -> int:
	var key: int = difficulty if DUNGEON_COIN_RANGES.has(difficulty) else DUNGEON_COIN_DIFF_DEFAULT
	var range: Vector2i = DUNGEON_COIN_RANGES[key]
	return rng.randi_range(range.x, range.y)


## 源 :482-500 checkHeroicPrereq：英雄副本组前置（对应普通副本组所有 Boss 通关）。
## 返 {ok: bool, prereq_group: int}（ok=true 放行；ok=false 拒绝，prereq_group=待通关普通组）。
static func check_heroic_prereq(group_id: int, mgr: StageManager, cm: ConfigManager) -> Dictionary:
	# 源 :483-484 非英雄副本组无前置
	if not HEROIC_PREREQ.has(group_id):
		return {"ok": true, "prereq_group": 0}
	var normal_group: int = int(HEROIC_PREREQ[group_id])
	# 源 :485-487 普通组配置缺失 → 放行
	var group_cfg: Dictionary = cm.get_raw_table(&"ActStageGroupDungeon").get(str(normal_group), {})
	if group_cfg.is_empty():
		return {"ok": true, "prereq_group": 0}
	# 源 :488-489 Stages 字段缺失 → 放行
	var stages_raw: Variant = group_cfg.get("Stages", [])
	if stages_raw == null:
		return {"ok": true, "prereq_group": 0}
	# 源 :490-499 遍历 Stages，任一 sid>0 且未通关（stage_stars<1）→ 拒绝
	for sid in (stages_raw as Array):
		var stage_id: int = int(sid)
		if stage_id > 0 and mgr.stage_stars(stage_id) < 1:
			return {"ok": false, "prereq_group": normal_group}
	return {"ok": true, "prereq_group": 0}


## 源 :650-712 副本关进入校验：heroic 前置 + 钥匙消耗 + 次数/BuyCost。返 error 字符串（空=通过）。
static func check_enter_dungeon(mgr: StageManager, stage_id: int, stage_group: int, player: PlayerData, cm: ConfigManager) -> String:
	# 源 :668-673 英雄副本前置：通关对应普通副本组所有 Boss（heroicPrereq 映射）
	var prereq: Dictionary = check_heroic_prereq(stage_group, mgr, cm)
	if not bool(prereq.get("ok", true)):
		return "heroic_prereq"
	# 源 :675-682 钥匙消耗入口检查（Key Cost，英雄/噩梦难度，不足拒绝；实际扣除在 exit_dungeon :805-810）
	var key_cost: int = int(cm.get_raw_table(&"StageDungeon").get(str(stage_id), {}).get("Key Cost", 0))
	if key_cost > 0 and player.dungeonpoint < key_cost:
		return "not_enough_keys"
	var grp_cfg: Dictionary = cm.get_raw_table(&"ActStageGroupDungeon").get(str(stage_group), {})
	var daily_limit: int = int(grp_cfg.get("DailyLimit", DUNGEON_DAILY_LIMIT_DEFAULT))
	var max_buy: int = int(grp_cfg.get("MaxBuyPerDay", DUNGEON_MAX_BUY_DEFAULT))
	var used: int = int(mgr.act_times.get(stage_group, 0))
	if used >= daily_limit + max_buy:
		return "no_attempts"
	# 免费次数用完 → 扣 BuyCost 龙鳞硬币（源 :698-707）
	if used >= daily_limit:
		var buy_cost: int = int(grp_cfg.get("BuyCost", DUNGEON_BUYCOST_DEFAULT))
		if player.dungeonpoint < buy_cost:
			return "not_enough_coins"
		player.dungeonpoint -= buy_cost
	mgr.act_times[stage_group] = used + 1
	return ""


## 源 :787-829 副本关结算：难度金币 + 副本硬币 + dungeon_bosses_cleared 持久化。
## 返 {stars, exp, money, coins}。
static func exit_dungeon(mgr: StageManager, cm: ConfigManager, sid: int, stars: int, player: PlayerData) -> Dictionary:
	var cfg: Dictionary = cm.get_raw_table(&"StageDungeon").get(str(sid), {})
	var diff: int = int(cfg.get("Difficulty", 1))
	var exp_reward: int = int(cfg.get("Exp Reward", 0)) * EXP_MULTIPLIER  # 源 :794 ×10
	var gold_reward: int = int(DUNGEON_GOLD_BY_DIFF.get(diff, DUNGEON_GOLD_FALLBACK))  # 源 :795-796
	var coins: int = get_dungeon_coin_reward(diff, RandomNumberGenerator.new())  # 源 :416-422 + :801
	# 源 :813-829 dungeon_bosses_cleared 持久化（baseId=50000+sid%1000）
	var base_id: int = DUNGEON_BOSS_BASE + sid % DUNGEON_BOSS_MOD
	mgr.dungeon_bosses_cleared[base_id] = true
	if player != null:
		player.dungeonpoint += coins  # 源 :802-803 addDungeonPoint(coins)
		# 源 :805-810 扣钥匙消耗（Key Cost，英雄/噩梦难度，net = coins - keyCost）
		var key_cost: int = int(cfg.get("Key Cost", 0))
		if key_cost > 0:
			player.dungeonpoint -= key_cost  # 源 :808-809 addDungeonPoint(-keyCost)
	return {"stars": stars, "exp": exp_reward, "money": gold_reward, "coins": coins}
