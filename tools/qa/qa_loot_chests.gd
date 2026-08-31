extends Node

## 一次性自动取证（战斗掉落宝箱接线验证 2026-08-31）：
## assemble_stage_battle(1) → BattleScene 挂 root（_battle_context 等价生产含 loots）→
## die 杀第一怪（monster_idx=1，槽位 (1,1) 照源）→ dump ui_list 宝箱数/坐标/可见性 →
## 点击收集一个 → loot_count 验证 → 截图。

const GmManager = preload("res://scripts/systems/gm_manager.gd")
const Combat = preload("res://scripts/systems/battle/battle_unit_combat.gd")


func _ready() -> void:
	if GameData.player == null:
		await GameData.ready
	var pd: Variant = GameData.player
	if pd == null:
		push_error("QA_AUTO: player null")
		return
	var cm: Variant = pd.cm
	pd.tutorial_manager.skip_all()
	GmManager.execute(pd, cm, {"_get_all_heroes": 1})
	var tids: Array[int] = []
	var unit_table: Dictionary = cm.get_raw_table("Unit")
	for tid_str in unit_table.keys():
		var row: Dictionary = unit_table[tid_str]
		if String(row.get("Unit Type", "")) == "Hero" and row.has("Portrait"):
			tids.append(int(tid_str))
		if tids.size() >= 5:
			break
	var rng := BattleRng.new(12345)
	var asm: Dictionary = pd.stage_manager.assemble_stage_battle(1, pd, tids, rng)
	if not bool(asm.get("ok", false)):
		push_error("QA_AUTO: assemble 失败 " + str(asm))
		return
	print("QA_AUTO: loots=", (asm["loots"] as Array).size(), " ", asm["loots"])
	await get_tree().process_frame   # 脱离 autoload busy 窗口（root.add_child 被拒坑）
	var scene: Node = (load("res://scenes/battle/battle_scene.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(scene)
	scene.setup(asm["engine"], cm, asm["battle_info"])
	# 生产链路 battle_prepare_panel 塞 battle_context（loots 在内）→ _ready 装配；
	# 本脚本直连 setup 须手动等价补全（缺键会在 finalize 崩）。
	scene._battle_context = {
		"mode": "stage", "loots": asm["loots"], "stage_id": 1,
		"player_tids": tids, "mgr": pd.stage_manager,
	}
	await get_tree().create_timer(2.5).timeout   # 等入场

	var eng: Variant = asm["engine"]
	var victim: Variant = null
	for u in eng.unit_list:
		if int(u.camp) == BattleEngine.CAMP_ENEMY and int(u.monster_idx) == 1 and bool(u.is_alive()):
			victim = u
			break
	if victim == null:
		push_error("QA_AUTO: 找不到 monster_idx=1 敌怪")
		return
	print("QA_AUTO: victim tid=", victim.tid, " hp=", victim.hp, " wave_id=", eng.wave_id)
	Combat.die(victim, null)
	await get_tree().create_timer(0.8).timeout   # 宝箱弹出 + 弹跳

	var chests: Array = []
	for ui in scene.ui_list:
		if ui.has_method("on_auto_collect") and is_instance_valid(ui):
			chests.append(ui)
	print("QA_AUTO: chests=", chests.size(), " loot_count=", eng.loot_count)
	for c in chests:
		var chest: Node2D = c as Node2D
		print("QA_AUTO:   chest id=", chest.get("loot_id"), " pos=", chest.position,
			" visible=", chest.visible, " parent=", chest.get_parent().name)

	if chests.is_empty():
		push_error("QA_AUTO: 宝箱未弹出（接线失败）")
		return
	# ① 点击收集第一个宝箱 → 飞抵 marker → add_loot_marker(1)
	var first: Variant = chests[0]
	first.on_tapped()
	await first.flew_to_marker
	print("QA_AUTO: after tap loot_count=", eng.loot_count, "（应 +1）")
	# marker 显示值一锤定音（截图小字判读存疑时以此为准）
	if scene.get("loot_marker") != null:
		var mk: Variant = scene.loot_marker
		print("QA_AUTO: loot_marker value=", mk.get_value(), " text=", (mk.find_children("*", "Label", true, false)[0] as Label).text)
	# ② 波清自动收集（用户验收项：波次结束宝箱应吸走；_on_wave_clear 并行收，源 :442）
	scene._on_wave_clear()
	await get_tree().create_timer(4.0).timeout   # 0.5 死亡等待 + 走路 + 剩余箱逐个吸
	var remaining: int = 0
	for ui in scene.ui_list:
		if is_instance_valid(ui) and ui.has_method("is_terminated") and not bool(ui.is_terminated()):
			remaining += 1
	print("QA_AUTO: after wave_clear wave_id=", eng.wave_id, " loot_count=", eng.loot_count,
		"（应=3） remaining_chests=", remaining, "（应=0）")
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://qa_loot_chests.png")
	print("QA_AUTO: DONE")
