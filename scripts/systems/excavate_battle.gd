class_name ExcavateBattle
extends RefCounted

## 挖掘战斗（Logic 层）— 照源 excavateteam.lua go_battle:212 battleprepare excavateAttack +
## excavate.lua enterExcavate:571。装配 BattleEngineArena.enter_excavate。
## 阶段 2b：拆 assemble/finalize 接 battle_scene View（仿 stage_manager.assemble/finalize_stage_battle 范式）。
## View 接入走 assemble_excavate_battle → battle_scene._process 驱动 → finalize_excavate_battle。

const BATTLE_MAX_TICKS: int = 300   # 端到端测试用最大 tick（防死循环；View 接入由 battle_scene._ticks_left 控制）


## 装配挖掘战斗（View 接入用）：玩家阵容 vs monster 敌人。不跑战斗循环。
## 返 {ok, engine, battle_info, excavate_id, hero_list, enemy_list}；无矿点/非 monster/无敌人/无英雄返 {ok:false}。
static func assemble_excavate_battle(mgr: Variant, excavate_id: int, player: PlayerData, rng: BattleRng) -> Dictionary:
	var d: Dictionary = mgr.get_data(excavate_id)
	if d.is_empty() or String(d["_owner"]) != ExcavateManager.OWNER_MONSTER:
		return {"ok": false}
	var cm: ConfigManager = mgr.config
	var enemy: Array = mgr.get_enemy_heroes(excavate_id)
	if enemy.is_empty():
		return {"ok": false}
	var enemy_list: Array[Dictionary] = []
	for e in enemy:
		enemy_list.append(e["base"])
	var hero_list: Array[Dictionary] = _hero_list_from_player(player)
	if hero_list.is_empty():
		return {"ok": false}
	var eng := BattleEngine.new()
	eng.rng = rng
	var lib := SkillLibrary.new(cm)
	eng.sfx_hook = mgr.sfx_hook; eng.skill_lib = lib   # T3 注入（mgr.sfx_hook 由 GameData 装配注入）
	var stage_id: int = ExcavateData.get_wild_stage_id(cm, int(d["_wild_id"]))
	BattleEngineArena.enter_excavate(eng, cm, lib, hero_list, enemy_list, true, {}, {}, stage_id, int(d["_type_id"]))
	var battle_info: Dictionary = BattleData.from_config(cm, stage_id).battle_info
	return {"ok": true, "engine": eng, "battle_info": battle_info, "excavate_id": excavate_id,
			"hero_list": hero_list, "enemy_list": enemy_list}


## 结算挖掘战斗（View 接入用）：从 engine 终态算胜负 + 胜利占领（draw_battle_reward）+ 记历史。返 {ok, won}。
static func finalize_excavate_battle(mgr: Variant, engine: Variant, excavate_id: int, hero_list: Array[Dictionary], enemy_list: Array[Dictionary], now: int, player: PlayerData = null) -> Dictionary:
	var d: Dictionary = mgr.get_data(excavate_id)
	if d.is_empty():
		return {"ok": false, "won": false}
	var won: bool = engine.foreach_alive_unit(BattleEngine.CAMP_ENEMY).is_empty()
	if won:
		# draw_battle_reward 占领+算 loot+返 reward；grant_resource_reward 发给 player（原 bug 丢弃返值）。
		var r: Dictionary = mgr.draw_battle_reward(excavate_id, now)
		if bool(r.get("ok", false)):
			ExcavateData.grant_resource_reward(player, r.get("reward", {}))
	_record_history(mgr, mgr.config, d, hero_list, enemy_list, won, now)
	return {"ok": true, "won": won}


## 端到端（测试用）：assemble + 同步跑到胜负 + finalize。返 {ok, won}。
static func run_excavate_battle(mgr: Variant, excavate_id: int, player: PlayerData, rng: BattleRng, now: int) -> Dictionary:
	var asm_r: Dictionary = assemble_excavate_battle(mgr, excavate_id, player, rng)
	if not bool(asm_r.get("ok", false)):
		return {"ok": false, "won": false}
	var eng: BattleEngine = asm_r["engine"]
	var ticks: int = BATTLE_MAX_TICKS
	while eng.running and not eng.stage_ended and ticks > 0:
		eng.update(BattleEngine.TICK_INTERVAL)
		ticks -= 1
	return finalize_excavate_battle(mgr, eng, excavate_id, asm_r["hero_list"], asm_r["enemy_list"], now, player)


## 玩家上场英雄 → hero_list（照 assemble 内联段抽出，run/assemble 共用）。{_tid,_level,_stars,_rank,_items}。
static func _hero_list_from_player(player: PlayerData) -> Array[Dictionary]:
	var hero_list: Array[Dictionary] = []
	for inst_id in player.team:
		var hero: Variant = player.hero_manager.heroes.get(inst_id)
		if hero == null:
			continue
		hero_list.append({
			"_tid": hero.tid, "_level": hero.level, "_stars": hero.stars,
			"_rank": hero.rank, "_items": StageManager._hero_items(hero),
		})
	return hero_list


## 记战斗历史（单机：玩家打 monster 的战斗记录，照源服务端 push history 结构）。
## self/oppo_team 包成 {_hero:[{_base,_dyna}]}（照 excavatebattlereport.lua:126 teamData._hero[j]）。
static func _record_history(mgr: Variant, cm: ConfigManager, d: Dictionary, hero_list: Array[Dictionary], enemy_list: Array[Dictionary], won: bool, now: int) -> void:
	var wild_id: int = int(d["_wild_id"])
	var enemy_name: String = String(ExcavateData.get_wild_enemy(cm, wild_id).get("Player Name", ""))
	var self_heroes: Array = []
	for h in hero_list:
		self_heroes.append({"_base": h, "_dyna": {}})
	var oppo_heroes: Array = []
	for e in enemy_list:
		oppo_heroes.append({"_base": e, "_dyna": {}})
	mgr.history.add({
		"excavate_id": int(d["_type_id"]),
		"result": ExcavateHistory.RESULT_WIN if won else ExcavateHistory.RESULT_LOSE,
		"enemy_name": enemy_name,
		"_time": now,
		"self_team": {"_hero": self_heroes},
		"oppo_team": {"_hero": oppo_heroes},
	})
