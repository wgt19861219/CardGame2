class_name TaskQuery
extends RefCounted

## TaskPanel 查询 helper（task_panel 拆分 1/3，2026-07-24）。
## 从 task_panel.gd 外迁的纯查询逻辑：fast 路由 / 主任务进度 / 奖励解析 / pid 规整 /
## 英雄计数。全 static + 参数化（player/cm 显式传入），不依赖 Node/Control，便于单测。
## View 层 helper 非 Logic；核心领奖与计数落库仍在 TaskManager。

# fast_handler 路由表：Task Progress Type → main_scene._open_* 方法名（已移植 9 type）。
const FAST_ROUTE := {
	"FarmPVEStage": "_open_stage_select",
	"FarmElitePVEStage": "_open_stage_select",
	"FarmChapter": "_open_exercise_panel",
	"PVPBattle": "_open_ladder",
	"PVPWin": "_open_ladder",
	"SkillUpgradeSuccess": "_open_hero",
	"MidasUse": "_open_midas",
	"TavernGroupUse": "_open_tavern",
	"CompleteCrusadeStage": "_open_crusade",
}

# 未移植 type → Toast 降级文案（目标场景未实现：装备强化需选英雄 / 月卡充值联机 / 公会联机）。
const FAST_UNSUPPORTED := {
	"EnhanceLevelUp": "「装备强化」请从英雄详情进入（需选择英雄）",
	"MonthlyCardPeriod": "月卡充值入口未开放",
	"SendMercenary": "公会功能未开放",
	"EnterRaid": "公会功能未开放",
}


# 路由分派（纯查询，便于单测）：返 {"action":"call","method":...} 或 {"action":"toast","msg":...}。
# 13 type 照源 fast_handler 映射：9 已移植 / 4 未移植；未知 type → Toast 默认文案。
static func resolve_fast_target(ttype: String) -> Dictionary:
	var method: String = FAST_ROUTE.get(ttype, "")
	if not method.is_empty():
		return {"action": "call", "method": method}
	return {"action": "toast", "msg": FAST_UNSUPPORTED.get(ttype, "前往任务目标")}


# 主任务行装配（链 chain/tid + Task 表 row + 完成态）→ 渲染所需 Dictionary。
# is_finished 来自 TaskManager.task[entry].status == "finished"（由 panel 判定后传入）。
static func build_main_task(chain: int, tid: int, row: Dictionary, is_finished: bool,
		cm: ConfigManager, player: PlayerData) -> Dictionary:
	var target: int = int(row.get("Task Target", 1))
	var progress: int = get_main_progress(row, player)
	return {
		"kind": "task",
		"name": cm.get_lstr(str(row.get("Task Name", str(chain)))),
		"detail": cm.get_lstr(str(row.get("Task Detail", ""))),
		"target": target,
		"progress": min(progress, target),
		"isFinished": is_finished,
		"icon": str(row.get("Icon", "")),
		"reward": parse_rewards(row, false),
	}


# 主任务实时进度：按 Task Progress Type 查 player 状态（事件累计型降级 0，由 TaskManager 接）。
static func get_main_progress(row: Dictionary, player: PlayerData) -> int:
	var ptype: String = String(row.get("Task Progress Type", ""))
	var pids: Array = pid_values(row.get("Task Progress ID", {}))
	var target: int = int(row.get("Task Target", 1))
	return get_count(ptype, pids, target, player)


# 按 Task Progress Type 查 player 实时状态。9 type 全保留（Task 表实测用 5 个，
# 余 4 个 ItemQuantity/HeroLevel/MultiHeroLevel/KillMonster 为完整性留）。
static func get_count(ptype: String, pids: Array, target: int, player: PlayerData) -> int:
	match ptype:
		"CompleteStage":
			for v in pids:
				if int(v) != 0 and player.stage_manager.stage_stars(int(v)) > 0:
					return target
			return 0
		"PlayerLevel":
			return player.team_level
		"HeroRank":
			for v in pids:
				if int(v) != 0:
					var h: HeroInstance = player.hero_manager.find_hero_by_tid(int(v))
					if h != null:
						return h.rank
			return 0
		"MultiHeroRank":
			for v in pids:
				if int(v) != 0:
					return count_heroes_by_rank(player, int(v))
			return 0
		"MultiHeroLevel":
			for v in pids:
				if int(v) != 0:
					return count_heroes_by_level(player, int(v))
			return 0
		"HeroLevel":
			for v in pids:
				if int(v) != 0:
					var h: HeroInstance = player.hero_manager.find_hero_by_tid(int(v))
					if h != null:
						return h.level
			return 0
		"ItemQuantity":
			for v in pids:
				if int(v) != 0:
					return int(player.items.get(int(v), 0))
			return 0
		"KillMonster", "FarmStage":
			return 0
		_:
			return 0


# 统计 rank >= rank_min 的英雄数量。
static func count_heroes_by_rank(player: PlayerData, rank_min: int) -> int:
	var count: int = 0
	for inst_id in player.hero_manager.heroes:
		var h: HeroInstance = player.hero_manager.heroes[inst_id]
		if h.rank >= rank_min:
			count += 1
	return count


# 统计 level > level_min 的英雄数量。
static func count_heroes_by_level(player: PlayerData, level_min: int) -> int:
	var count: int = 0
	for inst_id in player.hero_manager.heroes:
		var h: HeroInstance = player.hero_manager.heroes[inst_id]
		if h.level > level_min:
			count += 1
	return count


# pid 字段规整：源 lua table {v1, v2} → JSON Dictionary {"1":v1,"2":v2}（取 values）；
# 兼容裸 Array / 单值（其他类型返空数组）。
static func pid_values(pid_raw: Variant) -> Array:
	if pid_raw is Dictionary:
		return (pid_raw as Dictionary).values()
	if pid_raw is Array:
		return pid_raw
	return []


# 奖励解析：主线单槽（Task Reward Type/ID/Amount）/ 日常双槽（Task Reward 1..2 Type/ID/Amount）。
# 日常 1 号奖励无编号 amount 字段（Todolist 表实测，amount 存于无编号 "Task Reward Amount"），
# fallback 照源 local_server.lua:4068-4069（发奖侧 task_manager.claim_job_reward 同款，
# 2026-09-03 奖励行空根修——漏译致 amount=0 被过滤、奖励链全空）。
static func parse_rewards(row: Dictionary, is_daily: bool) -> Array:
	var rewards: Array = []
	if is_daily:
		for i in range(1, 3):
			var rtype: String = str(row.get("Task Reward %d Type" % i, ""))
			if rtype == "":
				continue
			var ramount: int = int(row.get("Task Reward %d Amount" % i, 0))
			if ramount <= 0 and i == 1:
				ramount = int(row.get("Task Reward Amount", 0))
			rewards.append({
				"type": rtype,
				"id": int(row.get("Task Reward %d ID" % i, 0)),
				"amount": ramount,
			})
	else:
		var rtype: String = str(row.get("Task Reward Type", ""))
		if rtype != "":
			rewards.append({
				"type": rtype,
				"id": int(row.get("Task Reward ID", 0)),
				"amount": int(row.get("Task Reward Amount", 0)),
			})
	return rewards
