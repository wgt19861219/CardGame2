class_name CrusadeBattle
extends RefCounted

## 远征战斗（Logic 层）— 照源 crusade.start（crusade.lua:431-441 传负数 stage_id=-2-currentStage）+
## battleprepare.lua doCrusade:392-408 gotoBattle → battle_engine.lua enterCrusade:555-569。
## 2026-09-14 拆 assemble/finalize 接 battle_scene View（仿 excavate_battle/ladder_battle 范式）：
## View 接入走 assemble_crusade_battle → battle_scene._process 驱动 → finalize_crusade_battle。
## 照源修正：装配 stage_id 用负数（-2-stage，Stage 表 crusade 专用行 -3~-17：Chapter ID=-3 →
## chapter-3 BGM + Battle[-3] bg；旧同步实现误传正数取第一章普通关卡行）。

const BATTLE_MAX_TICKS: int = 300    # 端到端测试用最大 tick（View 接入由 battle_scene._ticks_left 控制）
const STAGE_ID_OFFSET: int = 2       # 源 crusade.start：stageId = -2 - currentStage
const PERC_DENOM: int = 10000        # 万分比（hp/mp perc 序列化口径，同 CrusadeManager）


## 装配远征战斗（View 接入用）：玩家英雄（跨关 HP/MP）vs 敌人英雄（max_rank 装备）。不跑战斗循环。
## p_stage_id 为面板层负数关号（-2-stage）；返 {ok, engine, battle_info, hero_list, stage}；
## 空队/无 config/无敌人返 {ok:false}。
static func assemble_crusade_battle(mgr: CrusadeManager, p_stage_id: int, player: PlayerData, player_tids: Array[int], rng: BattleRng) -> Dictionary:
	# 空队伍拒绝（对齐源 enterStage 空队防护）：必败 fight() 会污染 crusade 跨关 HP/MP 与进度。
	if player_tids.is_empty():
		return {"ok": false, "error": "empty_team"}
	if mgr.config == null or rng == null:
		return {"ok": false}
	var stage: int = -p_stage_id - STAGE_ID_OFFSET
	var stage_enemies: Array = mgr.get_stage_enemies(stage)
	if stage_enemies.is_empty():
		return {"ok": false}
	var eng := BattleEngine.new()
	eng.rng = rng
	eng.sfx_hook = mgr.sfx_hook   # T3 注入（胜/败音效；crusade 不走 waves，无需 skill_lib）
	var hero_list: Array[Dictionary] = []
	var self_crusade: Dictionary = {}
	for tid in player_tids:
		var proto: Dictionary = {"_tid": tid}
		var hero: HeroInstance = StageManager._find_hero_by_tid(player.hero_manager, tid)
		if hero != null:
			proto["_level"] = hero.level
			proto["_stars"] = hero.stars
			proto["_rank"] = hero.rank
			proto["_items"] = StageManager._hero_items(hero)
		else:
			proto["_level"] = 1
			proto["_stars"] = 1
		hero_list.append(proto)
		self_crusade[tid] = {
			"_hp_perc": int(mgr.hero_hp(tid) * PERC_DENOM),
			"_mp_perc": int(mgr.hero_mp(tid) * PERC_DENOM),
		}
	var lib := SkillLibrary.new(mgr.config)
	BattleEngineArena.enter_crusade(eng, mgr.config, lib, hero_list, stage_enemies, true, self_crusade, {}, p_stage_id)
	var battle_info: Dictionary = BattleData.from_config(mgr.config, p_stage_id).battle_info
	return {"ok": true, "engine": eng, "battle_info": battle_info, "hero_list": hero_list, "stage": stage}


## 结算远征战斗（View 接入用）：engine 终态算胜负 + 存跨关 HP/MP + fight 推进（胜利过关）。
## 返 {ok, won, hero_hp_mp}。源 endBattle（crusade.lua:684-704）：胜利 currentStage+1（fight 内）。
static func finalize_crusade_battle(mgr: CrusadeManager, engine: Variant) -> Dictionary:
	var won: bool = engine.foreach_alive_unit(BattleEngine.CAMP_ENEMY).is_empty()
	# 存跨关 HP/MP（存活英雄当前 HP/MP 占比；阵亡 0）
	var hp_map: Dictionary = {}
	var mp_map: Dictionary = {}
	var player_units: Array = engine.foreach_alive_unit(BattleEngine.CAMP_PLAYER)
	for u in player_units:
		var max_hp: float = float(u.attribs.get("HP", 0.0))
		var max_mp: float = float(u.attribs.get("MP", 0.0))
		hp_map[u.tid] = float(u.hp) / max_hp if max_hp > 0 else 0.0
		mp_map[u.tid] = float(u.mp) / max_mp if max_mp > 0 else 0.0
	mgr.fight(won, hp_map, mp_map)
	return {"ok": true, "won": won, "hero_hp_mp": StageAccount.collect_hero_hp_mp(engine)}


## 端到端（测试用）：assemble + 同步跑到胜负 + finalize。p_stage 为正数关号（1-15）。
static func run_crusade_battle(mgr: CrusadeManager, p_stage: int, player: PlayerData, player_tids: Array[int], rng: BattleRng) -> Dictionary:
	var asm_r: Dictionary = assemble_crusade_battle(mgr, -p_stage - STAGE_ID_OFFSET, player, player_tids, rng)
	if not bool(asm_r.get("ok", false)):
		return {"ok": false, "error": String(asm_r.get("error", ""))}
	var eng: BattleEngine = asm_r["engine"]
	var ticks: int = BATTLE_MAX_TICKS
	while eng.running and not eng.stage_ended and ticks > 0:
		eng.update(BattleEngine.TICK_INTERVAL)
		ticks -= 1
	return finalize_crusade_battle(mgr, eng)
