class_name BattleSceneFinalizer
extends RefCounted

## 战斗场景结算分支（View helper）— 从 BattleScene 拆出控 ≤400。
## static 方法第一参 scene，照 equip_strengthen_anim.gd 静态拆分范式。
## 主类 _finalize_battle 直接调本类（私有，不需转发桩）。
## 源 battle_scene.lua downExit → stageaccount 分支。
##
## 三种模式：excavate（回主菜单重弹 map）/ pvp（排名互换回 ladder_panel）/ stage（切结算场景）。

const STAGE_DONE_PATH: String = "res://scenes/battle/stage_done_scene.tscn"
const STAGE_FAILED_PATH: String = "res://scenes/battle/stage_failed_scene.tscn"
const MAIN_SCENE_PATH: String = "res://scenes/main_menu/main_scene.tscn"


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
	var r: Dictionary = ExcavateBattle.finalize_excavate_battle(mgr, scene.engine, excavate_id, hero_list, enemy_list, now)
	GameData.pending_excavate = {"id": excavate_id, "won": bool(r["won"])}
	GameData.battle_context.clear()
	SceneManager.change_scene(MAIN_SCENE_PATH)


# pvp 战斗结算：finalize_pvp_battle 排名互换+奖励 → 存 pending_pvp → 回主菜单。
static func finalize_pvp(scene) -> void:
	var ctx: Dictionary = scene._battle_context
	var ladder: Variant = ctx["mgr"]
	var now: int = int(Time.get_unix_time_from_system())
	var r: Dictionary = LadderBattle.finalize_pvp_battle(ladder, scene.engine, GameData.player, scene.cm, scene.engine.rng, now)
	GameData.pending_pvp = {"won": bool(r["won"]), "reply": r["reply"]}
	GameData.battle_context.clear()
	SceneManager.change_scene(MAIN_SCENE_PATH)


# stage 战斗结算：finalize_stage_battle 算胜负发奖 → 存 last_result → 切结算场景。
static func finalize_stage(scene) -> void:
	var ctx: Dictionary = scene._battle_context
	var sid: int = int(ctx["stage_id"])
	var tids: Array[int] = []
	tids.assign(ctx["player_tids"])
	var loots: Array[Dictionary] = []
	loots.assign(ctx["loots"])
	var mgr: Variant = ctx["mgr"]
	var r: Dictionary = mgr.finalize_stage_battle(scene.engine, sid, GameData.player, tids, loots)
	# 照源 downExit → stageaccount.initialize → replaceScene(stagedone/stagefailed)。
	var result_param: Dictionary = {
		"stage_id": sid, "victory": bool(r["won"]), "heroes": tids,
		"stars": int(r["stars"]), "loots": loots, "excavate_mode": false, "isPveMode": true,
		"hero_hp_mp": r.get("hero_hp_mp", {}),  # 源 stageaccount:138-139 hp/mp（BattleUnit 快照）
	}
	GameData.last_result = StageAccount.build_result_param(result_param, GameData.player.cm, GameData.player, GameData.player.hero_manager)
	SceneManager.change_scene(STAGE_DONE_PATH if bool(r["won"]) else STAGE_FAILED_PATH)
