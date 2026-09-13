class_name BattleSceneFinalizer
extends RefCounted

## 战斗场景结算分支（View helper）— 从 BattleScene 拆出控 ≤400。
## static 方法第一参 scene，照 equip_strengthen_anim.gd 静态拆分范式。
## 主类 _finalize_battle 直接调本类（私有，不需转发桩）。
##
## 四种模式：excavate（回主菜单重弹 map）/ crusade（胜利回远征面板、失败切结算场景）/
## pvp（排名互换回 ladder_panel）/ stage（切结算场景）。
## crusade 照源 crusade.lua:684-704 endBattle + battle_engine.lua:1117-1120 downExit
## crusade_mode 胜利短路（不进 stageaccount 结算页）。

const STAGE_DONE_PATH: String = "res://scenes/battle/stage_done_scene.tscn"
const STAGE_FAILED_PATH: String = "res://scenes/battle/stage_failed_scene.tscn"
const MAIN_SCENE_PATH: String = "res://scenes/main_menu/main_scene.tscn"
const UnitSpriteScript = preload("res://scripts/view/battle/unit_sprite.gd")


# 中途放弃战斗（源 battle_scene.lua:230-245 exit 按钮 → :331-344 exit()=exitStage(2,true)
# +popScene 回上一场景：不算胜负、不结算奖励；已扣的体力/副本次数照扣=源 enterStage 即计
# 次语义。2026-08-22 巡检接线：项目无场景栈且一切入口面板挂 main（stage_select 亦
# PopWindow），统一回 main_scene（同结算页 goto_main_scene 惯例）。
static func abort_battle(scene) -> void:
	GameData.mark_save_dirty()
	GameData.battle_context.clear()
	_clear_battle_resources()
	SceneManager.change_scene(MAIN_SCENE_PATH)


# 切场景前清战斗静态缓存：UnitSprite._atlas_cache/FcaAnimation._cache 持 atlas+Image+FCA 解析数据
# 生产从不清理 → 111 resources leak；BattlePopup._record 持 BattleUnit 对象图 → 5018 ObjectDB。
static func _clear_battle_resources() -> void:
	UnitSpriteScript.clear_atlas_cache()
	BattlePopup._record.clear()


# excavate 战斗结算：finalize_excavate_battle 占领/记历史 → 存 pending_excavate → 回主菜单。
static func finalize_excavate(scene) -> void:
	var ctx: Dictionary = scene._battle_context
	var excavate_id: int = int(ctx["excavate_id"])
	var mgr: Variant = ctx["mgr"]
	var hero_list: Array[Dictionary] = []
	hero_list.assign(ctx["hero_list"])
	var enemy_list: Array[Dictionary] = []
	enemy_list.assign(ctx["enemy_list"])
	var now: int = int(Time.get_unix_time_from_system())
	var r: Dictionary = ExcavateBattle.finalize_excavate_battle(mgr, scene.engine, excavate_id, hero_list, enemy_list, now, GameData.player)
	GameData.pending_excavate = {"id": excavate_id, "won": bool(r["won"])}
	GameData.mark_save_dirty()
	GameData.battle_context.clear()
	_clear_battle_resources()
	SceneManager.change_scene(MAIN_SCENE_PATH)


# crusade 战斗结算（源 crusade.lua:684-704 endBattle）：胜利→fight 存跨关 HP/MP+推进 →
# pending_crusade → 回 main_scene 重弹 CrusadePanel（无结算页，源 downExit :1117-1120 短路）；
# 失败→doFailed 语义切 stagefailed（源 :1050-1062），exp 走 Stage[-2-stage] 行（全 0）；
# 失败页 menu 回主城不重弹远征（源场景栈：失败页 popScene 回 main，仅胜利 replaceScene 重开 crusade）。
static func finalize_crusade(scene) -> void:
	var ctx: Dictionary = scene._battle_context
	var mgr: Variant = ctx["mgr"]
	var r: Dictionary = CrusadeBattle.finalize_crusade_battle(mgr, scene.engine)
	var won: bool = bool(r.get("won", false))
	if won:
		GameData.pending_crusade = {"won": true}
	else:
		var hero_tids: Array[int] = []
		hero_tids.assign(ctx.get("player_tids", []))
		var sid: int = int(ctx["stage_id"])
		var result_param: Dictionary = {
			"stage_id": sid, "victory": false, "heroes": hero_tids,
			"stars": 0, "loots": [], "excavate_mode": false, "isPveMode": false,
			"hero_hp_mp": r.get("hero_hp_mp", {}),
			"lose_type": "timeout" if int(scene.engine.last_result) == BattleEngine.RESULT_TIMEOUT else "fail",
			"unit_list": _snapshot_units(scene.engine),
		}
		GameData.last_result = StageAccount.build_result_param(result_param, GameData.player.cm, GameData.player, GameData.player.hero_manager)
	GameData.save()
	GameData.battle_context.clear()
	_clear_battle_resources()
	if won:
		SceneManager.change_scene(MAIN_SCENE_PATH)
	else:
		SceneManager.change_scene(STAGE_FAILED_PATH)


# pvp 战斗结算（照源 stageaccount.lua initialize：victory→stagedone / defeat→stagefailed，
# PVE/PVP 共用结算场景）：finalize_pvp_battle 排名互换+奖励+英雄经验入库 → last_result → 切结算场景。
# 玩家经验/金币=0（Stage[-1] 行）、英雄经验=PlayerLevel.Arena Hero Exp 均分（take_arena_reward）。
static func finalize_pvp(scene) -> void:
	var ctx: Dictionary = scene._battle_context
	var ladder: Variant = ctx["mgr"]
	var now: int = int(Time.get_unix_time_from_system())
	var r: Dictionary = LadderBattle.finalize_pvp_battle(ladder, scene.engine, GameData.player, scene.cm, scene.engine.rng, now)
	var hero_tids: Array[int] = []
	hero_tids.assign(ctx.get("hero_tids", []))
	var won: bool = bool(r["won"])
	if won:
		GameData.player.take_arena_reward(hero_tids)
	var result_param: Dictionary = {
		"stage_id": StageAccount.ARENA_STAGE_ID, "victory": won, "heroes": hero_tids,
		"stars": 0, "loots": [], "excavate_mode": false, "isPveMode": false,
		"hero_hp_mp": StageAccount.collect_hero_hp_mp(scene.engine),
		"lose_type": "timeout" if int(scene.engine.last_result) == BattleEngine.RESULT_TIMEOUT else "fail",
		"unit_list": _snapshot_units(scene.engine),
		"arena_mode": true,
		"best_rank_reward": int((r["reply"] as Dictionary).get("best_rank_reward", 0)),
		"best_rank": int((r["reply"] as Dictionary).get("best_rank", 0)),
		"cur_rank": int((r["reply"] as Dictionary).get("rank", 0)),
	}
	GameData.last_result = StageAccount.build_result_param(result_param, GameData.player.cm, GameData.player, GameData.player.hero_manager)
	GameData.save()
	GameData.battle_context.clear()
	_clear_battle_resources()
	SceneManager.change_scene(STAGE_DONE_PATH if won else STAGE_FAILED_PATH)


# stage 战斗结算：finalize_stage_battle 算胜负发奖 → 存 last_result → 切结算场景。
# 宝箱自动收集先于结算（源 battle_engine.lua:1530 result==0 autoCollectLoots：逐个飞 marker 后才 exit）。
static func finalize_stage(scene) -> void:
	await BattleLootDirector.collect_before_finalize(scene)
	var ctx: Dictionary = scene._battle_context
	var sid: int = int(ctx["stage_id"])
	var tids: Array[int] = []
	tids.assign(ctx["player_tids"])
	var loots: Array[Dictionary] = []
	loots.assign(ctx["loots"])
	var mgr: Variant = ctx["mgr"]
	var r: Dictionary = mgr.finalize_stage_battle(scene.engine, sid, GameData.player, tids, loots)
	var result_param: Dictionary = {
		"stage_id": sid, "victory": bool(r["won"]), "heroes": tids,
		"stars": int(r["stars"]), "loots": loots, "excavate_mode": false, "isPveMode": true,
		"hero_hp_mp": r.get("hero_hp_mp", {}),
		"lose_type": String(r.get("lose_type", "fail")),
		"unit_list": _snapshot_units(scene.engine),  # battleStatist 战斗统计弹窗用（源 ed.engine.unit_list，切场景销毁 engine 故快照）
	}
	GameData.last_result = StageAccount.build_result_param(result_param, GameData.player.cm, GameData.player, GameData.player.hero_manager)
	GameData.save()
	GameData.battle_context.clear()  # 释放 engine 引用链（5018 ObjectDB leak 根因；对比 excavate:28/pvp:40 都 clear）
	_clear_battle_resources()
	SceneManager.change_scene(STAGE_DONE_PATH if bool(r["won"]) else STAGE_FAILED_PATH)


# engine，故快照 unit_list 轻量 Dictionary（tid/camp/dmg_statistics/rank/stars/level，battleStatistics 需要的字段）。
static func _snapshot_units(engine: Variant) -> Array:
	var out: Array = []
	if engine == null:
		return out
	for unit in engine.unit_list:
		out.append({
			"tid": int(unit.tid), "camp": int(unit.camp),
			"dmg_statistics": float(unit.dmg_statistics),
			"rank": int(unit.rank), "stars": int(unit.stars), "level": int(unit.level),
		})
	return out
