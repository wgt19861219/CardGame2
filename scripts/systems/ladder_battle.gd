class_name LadderBattle
extends RefCounted

## PVP 战斗（Logic 层）— 照源 ladder handler _start_battle(:3226) + enterArena 装配 / _end_battle(:3287) 结算。
## 阶段 2：拆 assemble/finalize 接 battle_scene View（仿 excavate_battle 范式）。
## View 接入走 assemble_pvp_battle → battle_scene._process 驱动 → finalize_pvp_battle。

const BATTLE_MAX_TICKS: int = 3000  # 端到端测试用最大 tick（View 接入由 battle_scene._ticks_left 控制）


## 装配 PVP 战斗（View 接入用）：玩家进攻阵容 vs AI 对手。不跑战斗循环。
## 返 {ok, engine, battle_info, oppo_user_id, hero_list, enemy_list}；无对手/无英雄返 {ok:false}。
static func assemble_pvp_battle(ladder: LadderManager, oppo_user_id: int, player: PlayerData, cm: ConfigManager, rng: BattleRng, now: int) -> Dictionary:
	var lineup: Array = _attack_lineup_tids(player)
	if lineup.is_empty():
		return {"ok": false}
	var reply: Dictionary = ladder.handle({"_start_battle": {"oppo_user_id": oppo_user_id, "attack_lineup": lineup}}, player, cm, rng, now)
	if not reply.has("_start_battle") or (reply["_start_battle"] as Dictionary).is_empty():
		return {"ok": false}
	var sb: Dictionary = reply["_start_battle"]
	var self_list: Array[Dictionary] = []
	for h in sb["self_heroes"]:
		self_list.append(h)
	var enemy_list: Array[Dictionary] = []
	for h in sb["heroes"]:
		enemy_list.append(h)
	var eng := BattleEngine.new()
	eng.rng = BattleRng.new(int(sb["rseed"]))
	var lib := SkillLibrary.new(cm)
	BattleEngineArena.enter_arena(eng, cm, lib, self_list, enemy_list, false, true)  # 玩家非 bot / AI 敌方 bot
	var battle_info: Dictionary = BattleData.from_config(cm, StageAccount.ARENA_STAGE_ID).battle_info
	return {"ok": true, "engine": eng, "battle_info": battle_info, "oppo_user_id": oppo_user_id, "hero_list": self_list, "enemy_list": enemy_list}


## 结算 PVP 战斗（View 接入用）：从 engine 终态算胜负 → ladder.handle(_end_battle) 排名互换 + 奖励。返 {ok, won, reply}。
static func finalize_pvp_battle(ladder: LadderManager, engine: Variant, player: PlayerData, cm: ConfigManager, rng: BattleRng, now: int) -> Dictionary:
	var won: bool = not engine.foreach_alive_unit(BattleEngine.CAMP_PLAYER).is_empty() and engine.foreach_alive_unit(BattleEngine.CAMP_ENEMY).is_empty()
	var result: String = "victory" if won else "defeat"
	var reply: Dictionary = ladder.handle({"_end_battle": {"result": result}}, player, cm, rng, now)
	# 源 record.lua chaosFarmStage :190 PVPBattle → 日常任务 PVPBattle
	if player != null and player.task_manager != null:
		player.task_manager.record_by_type(cm, "PVPBattle")
	return {"ok": true, "won": won, "reply": reply.get("_end_battle", {})}


## 端到端（测试用）：assemble + 同步跑到胜负 + finalize。
static func run_pvp_battle(ladder: LadderManager, oppo_user_id: int, player: PlayerData, cm: ConfigManager, rng: BattleRng, now: int) -> Dictionary:
	var asm_r: Dictionary = assemble_pvp_battle(ladder, oppo_user_id, player, cm, rng, now)
	if not bool(asm_r.get("ok", false)):
		return {"ok": false, "won": false}
	var eng: BattleEngine = asm_r["engine"]
	var ticks: int = BATTLE_MAX_TICKS
	while eng.running and not eng.stage_ended and ticks > 0:
		eng.update(BattleEngine.TICK_INTERVAL)
		ticks -= 1
	return finalize_pvp_battle(ladder, eng, player, cm, rng, now)


## 玩家进攻阵容 tid（player.team inst_id → tid；空则前 5 英雄）。
static func _attack_lineup_tids(player: PlayerData) -> Array:
	var tids: Array = []
	for inst_id in player.team:
		var h: Variant = player.hero_manager.heroes.get(inst_id)
		if h != null:
			tids.append(int(h.tid))
	if tids.is_empty():
		for inst_id in player.hero_manager.heroes:
			if tids.size() >= LadderManager.DEFEND_LINEUP_MAX:
				break
			tids.append(int(player.hero_manager.heroes[inst_id].tid))
	return tids
