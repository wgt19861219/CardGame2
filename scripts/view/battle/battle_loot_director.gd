class_name BattleLootDirector
extends RefCounted

## 战斗掉落宝箱编排（View helper）— 照源 battle_scene.lua:908-930 showMonsterLoots 翻译。
## Phase 2.6 剥离 View 副作用成桩后入口缺失（battle_unit_combat.gd 头注释），此处补接线：
## LOOT_DROP 事件（敌怪死亡）→ 槽位过滤 → BattleLootView 弹出。
## 槽位语义照源 local_server.lua:397 makebits(3,1,3,1,10,rewardId) = (wave=1, monster=1) 固定，
## 即所有掉落挂第一波第一个怪，其死亡时全部弹出；hpLoots（受击百分比掉落）源单机不填充，不实现。
## 胜利结算前自动收集照源 battle_engine.lua:1530 autoCollectLoots（宝箱逐个飞 marker 后再结算）。

const COLLECT_STAGGER: float = 0.16666666666666666  # 源 autoCollectLoots 逐箱间隔 1/6s
const COLLECT_FLY_TIME: float = 0.35               # 末箱飞抵 marker（源飞行 0.3s + 余量）


## 槽位懒初始化：battle_context.loots（[{id,type}]，stage/dungeon 组装方塞入）→ [{wave,monster,id,type,spawned}]。
## pvp/excavate 无 loots 键 → 空数组（宝箱不弹，等价源 player.loots 为空）。
static func _slots(scene: Variant) -> Array:
	if scene.loot_slots == null:
		var slots: Array = []
		for loot in (scene._battle_context.get("loots", []) as Array):
			slots.append({
				"wave": 1, "monster": 1,
				"id": int(loot["id"]), "type": String(loot["type"]),
				"spawned": false,
			})
		scene.loot_slots = slots
	return scene.loot_slots


## 敌怪死亡弹出宝箱（源 onUnitDie → scene:showMonsterLoots(wave_id, unit) → getStageLootOfMonster 过滤）。
static func show_monster_loots(scene: Variant, unit: Variant) -> void:
	if int(unit.camp) != BattleEngine.CAMP_ENEMY:
		return
	var wave: int = int(scene.engine.wave_id)
	var monster_idx: int = int(unit.monster_idx)
	var spawned: Array = []
	for slot in _slots(scene):
		if not bool(slot["spawned"]) and int(slot["wave"]) == wave and int(slot["monster"]) == monster_idx:
			slot["spawned"] = true
			spawned.append(slot)
	for i in range(spawned.size()):
		# 源 ipairs idx 从 1 起（初速度 x = 100*idx，loot.lua:26）
		var chest: Variant = BattleLootView.create(null, spawned[i]["type"], unit, i + 1, int(spawned[i]["id"]), scene.ui_layer)
		chest.set_scene(scene)
		scene.ui_list.append(chest)


## 胜利结算前自动收集（源 result==0 → autoCollectLoots；失败/超时宝箱留场随场景销毁，照源）。
static func collect_before_finalize(scene: Variant) -> void:
	if scene.engine == null or int(scene.engine.last_result) != BattleEngine.RESULT_WIN:
		return
	var chests: Array = []
	for ui in scene.ui_list:
		if ui.has_method("on_auto_collect") and ui.has_method("is_terminated") and not bool(ui.is_terminated()):
			chests.append(ui)
	for i in range(chests.size()):
		await scene.get_tree().create_timer(COLLECT_STAGGER * float(i)).timeout
		chests[i].on_auto_collect()
	if not chests.is_empty():
		await scene.get_tree().create_timer(COLLECT_FLY_TIME).timeout
