class_name StageDungeonLogic
extends RefCounted

## 副本段结算逻辑（Logic 层）— 从 StageManager 拆出控 ≤300 行。
## 照源 local_server.lua:686-712（次数校验+BuyCost）+ :787-829（副本结算：难度金币/硬币/dungeon_bosses_cleared）。
## static 方法，首参传 StageManager 实例（读 act_times/dungeon_bosses_cleared 字段）。

# 源 :795 难度金币表 goldByDiff（副本关结算按 Difficulty 查）
const DUNGEON_GOLD_BY_DIFF: Dictionary = {1: 2000, 2: 3500, 3: 5000, 4: 8000}
# 源 :801 getDungeonCoinReward（副本硬币按难度发放）
const DUNGEON_COIN_BY_DIFF: Dictionary = {1: 10, 2: 15, 3: 20, 4: 30}
const DUNGEON_BOSS_BASE: int = 50000  # 源 :815 baseId = 50000 + stage_id % 1000
const DUNGEON_BOSS_MOD: int = 1000    # 源 :815 baseId 模量
const DUNGEON_DAILY_LIMIT_DEFAULT: int = 2   # 源 :689 DailyLimit fallback
const DUNGEON_MAX_BUY_DEFAULT: int = 3       # 源 :690 MaxBuyPerDay fallback
const DUNGEON_BUYCOST_DEFAULT: int = 50      # 源 :700 BuyCost fallback
const DUNGEON_GOLD_FALLBACK: int = 2000      # 源 :796 fallback
const DUNGEON_COIN_FALLBACK: int = 10        # 源 :801 fallback
const EXP_MULTIPLIER: int = 10  # 源 PVE 经验 ×10


## 源 :686-712 副本关次数校验 + BuyCost。返 error 字符串（空=通过）。
static func check_enter_dungeon(mgr: StageManager, stage_id: int, stage_group: int, player: PlayerData, cm: ConfigManager) -> String:
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
	var coins: int = int(DUNGEON_COIN_BY_DIFF.get(diff, DUNGEON_COIN_FALLBACK))  # 源 :801
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
