class_name StageChapterReward

## 章节星数奖励工具（stage_manager 章节奖励域下沉，LINT005 Logic 300 行守卫，
## 2026-09-12 架构体检压线预拆）。数据语义照源 player.lua:910-973 chapter_star_reward
## handler 配套：tier 3 档 30/60/90 星，领奖记录由 StageManager.chapter_star_claimed
## 持有（会话内有效，见 stage_manager 同名注释），serde 不变。

# 章节星数奖励 tier（源 player.lua:925-932 getChapterStarRewardTiers 硬编码 3 档：30/60/90 星）
const TIERS: Array = [
	{"tier": 1, "stars": 30, "rewards": [{"type": "money", "amount": 30000}, {"type": "item", "id": 14001, "amount": 2}]},
	{"tier": 2, "stars": 60, "rewards": [{"type": "money", "amount": 80000}, {"type": "item", "id": 14002, "amount": 2}]},
	{"tier": 3, "stars": 90, "rewards": [{"type": "rmb", "amount": 100}, {"type": "item", "id": 14003, "amount": 1}]},
]


## 章节内全部普通关星数合计（源按 Chapter ID 过滤 + normal 关求和）。
static func chapter_stars(progress: Dictionary, stage_table: Dictionary, chapter_id: int) -> int:
	var total: int = 0
	for sid_str in stage_table:
		var sid: int = int(sid_str)
		if int(stage_table[sid_str].get("Chapter ID", 0)) == chapter_id and StageAccount.stage_type(sid) == "normal":
			total += int(progress.get(sid, 0))
	return total


## 三档领奖状态（unlocked=星数达标 / claimed=已领）。
static func star_status(claimed: Dictionary, chapter_id: int, total_stars: int) -> Dictionary:
	var tiers: Array = []
	for t in TIERS:
		var td: Dictionary = t
		var tier: int = int(td["tier"])
		var key: String = "%d_%d" % [chapter_id, tier]
		tiers.append({
			"tier": tier,
			"stars": int(td["stars"]),
			"unlocked": total_stars >= int(td["stars"]),
			"claimed": bool(claimed.get(key, false)),
			"rewards": td["rewards"],
		})
	return {"tiers": tiers, "total_stars": total_stars}


## 领取：星数达标 + 未领过 → 发奖 + 记 claimed。返 {ok, rewards}；不满足返 {ok:false}。
static func claim(player: PlayerData, claimed: Dictionary, chapter_id: int, tier: int, total_stars: int) -> Dictionary:
	var td: Dictionary = {}
	for t in TIERS:
		if int((t as Dictionary)["tier"]) == tier:
			td = t
			break
	if td.is_empty():
		return {"ok": false}
	if total_stars < int(td["stars"]):
		return {"ok": false}
	var key: String = "%d_%d" % [chapter_id, tier]
	if bool(claimed.get(key, false)):
		return {"ok": false}
	for rw in td["rewards"]:
		var rwd: Dictionary = rw
		var rtype: String = String(rwd["type"])
		if rtype == "money":
			player.hero_manager.add_money(int(rwd["amount"]))
		elif rtype == "rmb":
			player.add_diamond(int(rwd["amount"]))
		elif rtype == "item": player.add_item(int(rwd["id"]), int(rwd["amount"]))
	claimed[key] = true
	return {"ok": true, "rewards": td["rewards"]}
